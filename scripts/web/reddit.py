#!/usr/bin/env python3
"""Reddit client. Read, post, comment, and monitor subreddits. Stdlib only.

Usage:
    # Read (no auth needed)
    python3 scripts/web/reddit.py hot LocalLLaMA                     # hot posts
    python3 scripts/web/reddit.py hot LocalLLaMA --limit 5           # limit results
    python3 scripts/web/reddit.py new selfhosted                     # new posts
    python3 scripts/web/reddit.py post LocalLLaMA abc123             # read a post + comments
    python3 scripts/web/reddit.py search LocalLLaMA "qwen nixos"     # search a subreddit
    python3 scripts/web/reddit.py search all "sovereign AI"          # search all of reddit

    # Write (requires Reddit API credentials in .env)
    python3 scripts/web/reddit.py submit LocalLLaMA "Title" --url https://example.com
    python3 scripts/web/reddit.py submit LocalLLaMA "Title" --text "body text"
    python3 scripts/web/reddit.py reply t3_abc123 "Great post!"      # reply to post
    python3 scripts/web/reddit.py reply t1_abc123 "Good point"       # reply to comment

    # Monitor
    python3 scripts/web/reddit.py monitor LocalLLaMA "substrate"     # watch for mentions

Environment:
    REDDIT_CLIENT_ID     — Reddit app client ID
    REDDIT_CLIENT_SECRET — Reddit app client secret
    REDDIT_USERNAME      — Reddit username
    REDDIT_PASSWORD      — Reddit password
"""

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request


sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from env import load_env


# ---------------------------------------------------------------------------
# Reddit API (read-only via JSON endpoints, no auth needed)
# ---------------------------------------------------------------------------

USER_AGENT = "Substrate/1.0 (sovereign AI workstation; by /u/substrate-rai)"

def reddit_get(path, params=None):
    """GET from Reddit's JSON API (unauthenticated)."""
    base = "https://www.reddit.com"
    url = f"{base}{path}.json"
    if params:
        url += "?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=15) as resp:
        return json.loads(resp.read().decode("utf-8"))


# ---------------------------------------------------------------------------
# Reddit OAuth (for posting/commenting)
# ---------------------------------------------------------------------------

class RedditSession:
    """Authenticated Reddit session via OAuth2."""

    TOKEN_URL = "https://www.reddit.com/api/v1/access_token"
    API_BASE = "https://oauth.reddit.com"

    def __init__(self):
        self.access_token = None

    def login(self, client_id, client_secret, username, password):
        """Get OAuth2 access token via password grant."""
        auth_string = f"{client_id}:{client_secret}"
        import base64
        auth_header = base64.b64encode(auth_string.encode()).decode()

        data = urllib.parse.urlencode({
            "grant_type": "password",
            "username": username,
            "password": password,
        }).encode("utf-8")

        req = urllib.request.Request(self.TOKEN_URL, data=data, headers={
            "Authorization": f"Basic {auth_header}",
            "User-Agent": USER_AGENT,
            "Content-Type": "application/x-www-form-urlencoded",
        })

        try:
            with urllib.request.urlopen(req, timeout=15) as resp:
                result = json.loads(resp.read().decode("utf-8"))
        except urllib.error.HTTPError as e:
            body = e.read().decode("utf-8", errors="replace")
            print(f"error: Reddit auth failed ({e.code}): {body}", file=sys.stderr)
            return False

        if "access_token" not in result:
            print(f"error: no access token in response: {result}", file=sys.stderr)
            return False

        self.access_token = result["access_token"]
        return True

    def api_post(self, endpoint, data):
        """POST to Reddit OAuth API."""
        url = f"{self.API_BASE}{endpoint}"
        encoded = urllib.parse.urlencode(data).encode("utf-8")
        req = urllib.request.Request(url, data=encoded, headers={
            "Authorization": f"Bearer {self.access_token}",
            "User-Agent": USER_AGENT,
            "Content-Type": "application/x-www-form-urlencoded",
        })
        try:
            with urllib.request.urlopen(req, timeout=15) as resp:
                return json.loads(resp.read().decode("utf-8")), resp.status
        except urllib.error.HTTPError as e:
            body = e.read().decode("utf-8", errors="replace")
            return {"error": body}, e.code

    def submit_link(self, subreddit, title, url):
        """Submit a link post."""
        data = {
            "kind": "link",
            "sr": subreddit,
            "title": title,
            "url": url,
            "resubmit": "true",
        }
        result, status = self.api_post("/api/submit", data)
        if status == 200 and not result.get("json", {}).get("errors"):
            post_url = result.get("json", {}).get("data", {}).get("url", "submitted")
            print(f"submitted: {post_url}")
            return True
        else:
            errors = result.get("json", {}).get("errors", result)
            print(f"error: submission failed: {errors}", file=sys.stderr)
            return False

    def submit_text(self, subreddit, title, text):
        """Submit a text post."""
        data = {
            "kind": "self",
            "sr": subreddit,
            "title": title,
            "text": text,
        }
        result, status = self.api_post("/api/submit", data)
        if status == 200 and not result.get("json", {}).get("errors"):
            post_url = result.get("json", {}).get("data", {}).get("url", "submitted")
            print(f"submitted: {post_url}")
            return True
        else:
            errors = result.get("json", {}).get("errors", result)
            print(f"error: submission failed: {errors}", file=sys.stderr)
            return False

    def comment(self, thing_id, text):
        """Reply to a post (t3_xxx) or comment (t1_xxx)."""
        data = {
            "thing_id": thing_id,
            "text": text,
        }
        result, status = self.api_post("/api/comment", data)
        if status == 200 and not result.get("json", {}).get("errors"):
            print(f"replied to {thing_id}")
            return True
        else:
            errors = result.get("json", {}).get("errors", result)
            print(f"error: reply failed: {errors}", file=sys.stderr)
            return False


def get_session(env_path=None):
    """Create and authenticate a Reddit session from .env."""
    load_env(env_path)
    client_id = os.environ.get("REDDIT_CLIENT_ID")
    client_secret = os.environ.get("REDDIT_CLIENT_SECRET")
    username = os.environ.get("REDDIT_USERNAME")
    password = os.environ.get("REDDIT_PASSWORD")

    if not all([client_id, client_secret, username, password]):
        print("error: REDDIT_CLIENT_ID, REDDIT_CLIENT_SECRET, REDDIT_USERNAME, REDDIT_PASSWORD required in .env", file=sys.stderr)
        sys.exit(1)

    session = RedditSession()
    if not session.login(client_id, client_secret, username, password):
        sys.exit(1)
    return session


# ---------------------------------------------------------------------------
# Display helpers
# ---------------------------------------------------------------------------

def format_time(timestamp):
    if not timestamp:
        return ""
    diff = int(time.time()) - int(timestamp)
    if diff < 60:
        return f"{diff}s ago"
    elif diff < 3600:
        return f"{diff // 60}m ago"
    elif diff < 86400:
        return f"{diff // 3600}h ago"
    else:
        return f"{diff // 86400}d ago"


def format_post(post_data):
    d = post_data.get("data", post_data)
    title = d.get("title", "untitled")
    score = d.get("score", 0)
    author = d.get("author", "?")
    comments = d.get("num_comments", 0)
    subreddit = d.get("subreddit", "?")
    created = d.get("created_utc", 0)
    permalink = d.get("permalink", "")
    url = d.get("url", "")
    is_self = d.get("is_self", False)

    line = f"  {score:>5} | r/{subreddit} | {title}"
    if not is_self and url:
        domain = url.split("/")[2] if len(url.split("/")) > 2 else ""
        line += f" ({domain})"
    line += f"\n        | by u/{author} {format_time(created)} | {comments} comments"
    line += f"\n        | https://reddit.com{permalink}"
    return line


def format_comment_reddit(comment_data, depth=0):
    d = comment_data.get("data", comment_data)
    author = d.get("author", "[deleted]")
    body = d.get("body", "")
    score = d.get("score", 0)
    created = d.get("created_utc", 0)

    if len(body) > 300:
        body = body[:300] + "..."

    indent = "  " * depth
    return f"{indent}> u/{author} ({score} pts, {format_time(created)}):\n{indent}  {body}"


# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

def cmd_listing(args, sort="hot"):
    data = reddit_get(f"/r/{args.subreddit}/{sort}", {"limit": args.limit})
    posts = data.get("data", {}).get("children", [])
    print(f"# r/{args.subreddit} — {sort} ({len(posts)} posts)\n")
    for i, post in enumerate(posts, 1):
        print(f"{i:>3}. {format_post(post)}")
        print()


def cmd_hot(args):
    cmd_listing(args, "hot")


def cmd_new(args):
    cmd_listing(args, "new")


def cmd_post(args):
    data = reddit_get(f"/r/{args.subreddit}/comments/{args.post_id}")
    if not data or len(data) < 1:
        print("error: post not found", file=sys.stderr)
        sys.exit(1)

    # Post
    post = data[0]["data"]["children"][0]
    print(format_post(post))
    selftext = post.get("data", {}).get("selftext", "")
    if selftext:
        if len(selftext) > 1000:
            selftext = selftext[:1000] + "..."
        print(f"\n{selftext}")
    print()

    # Comments
    if len(data) > 1:
        comments = data[1].get("data", {}).get("children", [])
        print(f"--- Comments ---\n")
        for comment in comments[:15]:
            if comment.get("kind") == "t1":
                print(format_comment_reddit(comment))
                # Show first-level replies
                replies = comment.get("data", {}).get("replies", "")
                if isinstance(replies, dict):
                    reply_children = replies.get("data", {}).get("children", [])
                    for reply in reply_children[:3]:
                        if reply.get("kind") == "t1":
                            print(format_comment_reddit(reply, depth=1))
                print()


def cmd_search(args):
    params = {"q": args.query, "limit": args.limit, "sort": "relevance", "t": "month"}
    if args.subreddit == "all":
        data = reddit_get("/search", params)
    else:
        data = reddit_get(f"/r/{args.subreddit}/search", {**params, "restrict_sr": "on"})

    posts = data.get("data", {}).get("children", [])
    print(f"# Reddit Search: \"{args.query}\" in r/{args.subreddit} ({len(posts)} results)\n")
    for i, post in enumerate(posts, 1):
        print(f"{i:>3}. {format_post(post)}")
        print()


def cmd_submit(args):
    session = get_session(args.env)
    if args.url:
        session.submit_link(args.subreddit, args.title, args.url)
    elif args.text:
        session.submit_text(args.subreddit, args.title, args.text)
    else:
        print("error: provide --url or --text", file=sys.stderr)
        sys.exit(1)


def cmd_reply(args):
    session = get_session(args.env)
    session.comment(args.thing_id, args.text)


def cmd_monitor(args):
    """Monitor a subreddit for keyword mentions in new posts."""
    seen = set()
    interval = args.interval
    print(f"monitoring r/{args.subreddit} for \"{args.query}\" every {interval}s...")

    while True:
        try:
            params = {"q": args.query, "limit": 10, "sort": "new", "t": "day"}
            data = reddit_get(f"/r/{args.subreddit}/search", {**params, "restrict_sr": "on"})
            posts = data.get("data", {}).get("children", [])
            for post in posts:
                pid = post.get("data", {}).get("id", "")
                if pid and pid not in seen:
                    seen.add(pid)
                    print(f"\n[new match] {format_post(post)}")
        except Exception as e:
            print(f"  (error: {e})", file=sys.stderr)

        time.sleep(interval)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Reddit client")
    parser.add_argument("--env", help="Path to .env file")
    sub = parser.add_subparsers(dest="command")

    # hot
    p_hot = sub.add_parser("hot", help="Hot posts in a subreddit")
    p_hot.add_argument("subreddit")
    p_hot.add_argument("--limit", type=int, default=25)

    # new
    p_new = sub.add_parser("new", help="New posts in a subreddit")
    p_new.add_argument("subreddit")
    p_new.add_argument("--limit", type=int, default=25)

    # post
    p_post = sub.add_parser("post", help="Read a post and comments")
    p_post.add_argument("subreddit")
    p_post.add_argument("post_id", help="Reddit post ID (e.g. abc123)")

    # search
    p_search = sub.add_parser("search", help="Search a subreddit")
    p_search.add_argument("subreddit", help="Subreddit name or 'all'")
    p_search.add_argument("query")
    p_search.add_argument("--limit", type=int, default=20)

    # submit
    p_submit = sub.add_parser("submit", help="Submit a post")
    p_submit.add_argument("subreddit")
    p_submit.add_argument("title")
    p_submit.add_argument("--url", help="Link URL")
    p_submit.add_argument("--text", help="Text body")

    # reply
    p_reply = sub.add_parser("reply", help="Reply to a post or comment")
    p_reply.add_argument("thing_id", help="Fullname (t3_xxx for post, t1_xxx for comment)")
    p_reply.add_argument("text")

    # monitor
    p_monitor = sub.add_parser("monitor", help="Monitor subreddit for keyword")
    p_monitor.add_argument("subreddit")
    p_monitor.add_argument("query")
    p_monitor.add_argument("--interval", type=int, default=300)

    args = parser.parse_args()
    if not args.command:
        parser.print_help()
        sys.exit(1)

    commands = {
        "hot": cmd_hot,
        "new": cmd_new,
        "post": cmd_post,
        "search": cmd_search,
        "submit": cmd_submit,
        "reply": cmd_reply,
        "monitor": cmd_monitor,
    }
    commands[args.command](args)


if __name__ == "__main__":
    main()

#!/usr/bin/env python3
"""Hacker News client. Read, post, reply, and monitor threads. Stdlib only.

Usage:
    # Read
    python3 scripts/web/hn.py top                              # top 30 stories
    python3 scripts/web/hn.py top --limit 10                   # top 10
    python3 scripts/web/hn.py story 47265045                   # read a story + comments
    python3 scripts/web/hn.py story 47265045 --depth 2         # story + 2 levels of comments
    python3 scripts/web/hn.py user dang                        # user profile

    # Search
    python3 scripts/web/hn.py search "sovereign AI NixOS"      # search stories
    python3 scripts/web/hn.py search "substrate" --type comment # search comments

    # Write (requires HN credentials in .env)
    python3 scripts/web/hn.py submit "Title" "https://url.com" # submit a link
    python3 scripts/web/hn.py submit "Ask HN: Title" --text "body"  # submit text post
    python3 scripts/web/hn.py reply 47265045 "Great post!"     # reply to item
    python3 scripts/web/hn.py upvote 47265045                  # upvote an item

    # Monitor
    python3 scripts/web/hn.py monitor "substrate"              # watch for mentions
    python3 scripts/web/hn.py monitor --item 47265045          # watch a thread for new comments

Environment:
    HN_USERNAME — Hacker News username
    HN_PASSWORD — Hacker News password
"""

import argparse
import http.cookiejar
import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from html.parser import HTMLParser


sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
from env import load_env


# ---------------------------------------------------------------------------
# HN Firebase API (read-only, no auth needed)
# ---------------------------------------------------------------------------

HN_API = "https://hacker-news.firebaseio.com/v0"
ALGOLIA_API = "https://hn.algolia.com/api/v1"
HN_WEB = "https://news.ycombinator.com"

def api_get(path):
    """GET from HN Firebase API."""
    url = f"{HN_API}/{path}"
    req = urllib.request.Request(url, headers={"User-Agent": "Substrate/1.0"})
    with urllib.request.urlopen(req, timeout=10) as resp:
        return json.loads(resp.read().decode("utf-8"))


def get_item(item_id):
    """Get a single HN item (story, comment, etc)."""
    return api_get(f"item/{item_id}.json")


def get_top_stories(limit=30):
    """Get top story IDs."""
    ids = api_get("topstories.json")
    return ids[:limit]


def get_new_stories(limit=30):
    ids = api_get("newstories.json")
    return ids[:limit]


def get_user(username):
    return api_get(f"user/{username}.json")


# ---------------------------------------------------------------------------
# Algolia search
# ---------------------------------------------------------------------------

def search_hn(query, search_type="story", limit=20):
    """Search HN via Algolia API."""
    tags = f"({search_type})"
    params = urllib.parse.urlencode({
        "query": query,
        "tags": tags,
        "hitsPerPage": limit,
    })
    url = f"{ALGOLIA_API}/search?{params}"
    req = urllib.request.Request(url, headers={"User-Agent": "Substrate/1.0"})
    with urllib.request.urlopen(req, timeout=10) as resp:
        data = json.loads(resp.read().decode("utf-8"))
    return data.get("hits", [])


# ---------------------------------------------------------------------------
# HN Web auth (for posting/replying)
# ---------------------------------------------------------------------------

class HNSession:
    """Authenticated HN session via web scraping."""

    def __init__(self):
        self.cookie_jar = http.cookiejar.CookieJar()
        self.opener = urllib.request.build_opener(
            urllib.request.HTTPCookieProcessor(self.cookie_jar)
        )
        self.opener.addheaders = [("User-Agent", "Substrate/1.0")]
        self.logged_in = False

    def login(self, username, password):
        data = urllib.parse.urlencode({
            "acct": username,
            "pw": password,
            "goto": "news",
        }).encode("utf-8")
        resp = self.opener.open(f"{HN_WEB}/login", data, timeout=15)
        body = resp.read().decode("utf-8", errors="replace")
        # If login succeeded, we get redirected to /news (no "Bad login" text)
        if "Bad login" in body:
            print("error: HN login failed — check credentials", file=sys.stderr)
            return False
        self.logged_in = True
        return True

    def _get_fnid(self, url):
        """Extract fnid (anti-CSRF token) from an HN page."""
        resp = self.opener.open(url, timeout=15)
        body = resp.read().decode("utf-8", errors="replace")
        match = re.search(r'name="fnid" value="([^"]+)"', body)
        if match:
            return match.group(1)
        # Also try hmac pattern
        match = re.search(r'name="hmac" value="([^"]+)"', body)
        return match.group(1) if match else None

    def submit_link(self, title, url):
        """Submit a link to HN."""
        fnid = self._get_fnid(f"{HN_WEB}/submitlink")
        if not fnid:
            print("error: could not get submission token", file=sys.stderr)
            return False
        data = urllib.parse.urlencode({
            "fnid": fnid,
            "fnop": "submit-page",
            "title": title,
            "url": url,
        }).encode("utf-8")
        resp = self.opener.open(f"{HN_WEB}/r", data, timeout=15)
        body = resp.read().decode("utf-8", errors="replace")
        if "try again" in body.lower() or "unknown" in body.lower():
            print(f"error: submission may have failed", file=sys.stderr)
            return False
        print(f"submitted: {title}")
        return True

    def submit_text(self, title, text):
        """Submit a text post (Ask HN, Show HN, etc)."""
        fnid = self._get_fnid(f"{HN_WEB}/submitlink")
        if not fnid:
            print("error: could not get submission token", file=sys.stderr)
            return False
        data = urllib.parse.urlencode({
            "fnid": fnid,
            "fnop": "submit-page",
            "title": title,
            "text": text,
        }).encode("utf-8")
        resp = self.opener.open(f"{HN_WEB}/r", data, timeout=15)
        body = resp.read().decode("utf-8", errors="replace")
        if "try again" in body.lower():
            print(f"error: submission may have failed", file=sys.stderr)
            return False
        print(f"submitted: {title}")
        return True

    def reply(self, item_id, text):
        """Reply to an HN item."""
        fnid = self._get_fnid(f"{HN_WEB}/reply?id={item_id}")
        if not fnid:
            print("error: could not get reply token", file=sys.stderr)
            return False
        data = urllib.parse.urlencode({
            "parent": item_id,
            "fnid": fnid,
            "fnop": "submit-page",
            "text": text,
        }).encode("utf-8")
        resp = self.opener.open(f"{HN_WEB}/comment", data, timeout=15)
        body = resp.read().decode("utf-8", errors="replace")
        if "try again" in body.lower():
            print(f"error: reply may have failed", file=sys.stderr)
            return False
        print(f"replied to item {item_id}")
        return True


# ---------------------------------------------------------------------------
# Display helpers
# ---------------------------------------------------------------------------

def format_story(item):
    """Format a story item for display."""
    title = item.get("title", "untitled")
    url = item.get("url", "")
    score = item.get("score", 0)
    by = item.get("by", "unknown")
    comments = item.get("descendants", 0)
    item_id = item.get("id", "")
    time_ago = format_time(item.get("time", 0))

    line = f"  {score:>4} pts | {title}"
    if url:
        domain = re.sub(r"^https?://(www\.)?", "", url).split("/")[0]
        line += f" ({domain})"
    line += f"\n         | by {by} {time_ago} | {comments} comments | https://news.ycombinator.com/item?id={item_id}"
    return line


def format_comment(item, depth=0):
    """Format a comment for display."""
    indent = "  " * depth
    by = item.get("by", "[deleted]")
    text = item.get("text", "")
    # Strip HTML from comment text
    text = re.sub(r"<[^>]+>", " ", text)
    text = re.sub(r"\s+", " ", text).strip()
    time_ago = format_time(item.get("time", 0))

    if len(text) > 300:
        text = text[:300] + "..."

    return f"{indent}> {by} ({time_ago}):\n{indent}  {text}"


def format_time(timestamp):
    """Format Unix timestamp as relative time."""
    if not timestamp:
        return ""
    diff = int(time.time()) - timestamp
    if diff < 60:
        return f"{diff}s ago"
    elif diff < 3600:
        return f"{diff // 60}m ago"
    elif diff < 86400:
        return f"{diff // 3600}h ago"
    else:
        return f"{diff // 86400}d ago"


def format_search_result(hit):
    """Format an Algolia search result."""
    title = hit.get("title") or hit.get("story_title") or "untitled"
    points = hit.get("points") or 0
    comments = hit.get("num_comments") or 0
    author = hit.get("author", "unknown")
    object_id = hit.get("objectID", "")
    url = hit.get("url", "")

    line = f"  {points:>4} pts | {title}"
    if url:
        domain = re.sub(r"^https?://(www\.)?", "", url).split("/")[0]
        line += f" ({domain})"
    line += f"\n         | by {author} | {comments} comments | https://news.ycombinator.com/item?id={object_id}"
    return line


# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

def cmd_top(args):
    ids = get_top_stories(args.limit)
    print(f"# Hacker News — Top {len(ids)}\n")
    for i, sid in enumerate(ids, 1):
        item = get_item(sid)
        if item:
            print(f"{i:>3}. {format_story(item)}")
            print()


def cmd_new(args):
    ids = get_new_stories(args.limit)
    print(f"# Hacker News — New {len(ids)}\n")
    for i, sid in enumerate(ids, 1):
        item = get_item(sid)
        if item:
            print(f"{i:>3}. {format_story(item)}")
            print()


def cmd_story(args):
    item = get_item(args.item_id)
    if not item:
        print(f"error: item {args.item_id} not found", file=sys.stderr)
        sys.exit(1)

    print(format_story(item))
    print()

    # Show text if it's a text post
    if item.get("text"):
        text = re.sub(r"<[^>]+>", " ", item["text"])
        text = re.sub(r"\s+", " ", text).strip()
        print(f"  {text}\n")

    # Show comments
    kids = item.get("kids", [])
    if kids:
        print(f"--- Comments ({item.get('descendants', len(kids))}) ---\n")
        show_comments(kids, depth=0, max_depth=args.depth)


def show_comments(kid_ids, depth=0, max_depth=2):
    """Recursively display comments."""
    if depth > max_depth:
        return
    for kid_id in kid_ids[:10]:  # limit per level
        comment = get_item(kid_id)
        if comment and not comment.get("deleted"):
            print(format_comment(comment, depth))
            print()
            child_kids = comment.get("kids", [])
            if child_kids and depth < max_depth:
                show_comments(child_kids, depth + 1, max_depth)


def cmd_user(args):
    user = get_user(args.username)
    if not user:
        print(f"error: user {args.username} not found", file=sys.stderr)
        sys.exit(1)
    print(f"# {user['id']}")
    print(f"  karma: {user.get('karma', 0)}")
    print(f"  created: {format_time(user.get('created', 0))}")
    if user.get("about"):
        about = re.sub(r"<[^>]+>", " ", user["about"]).strip()
        print(f"  about: {about}")


def cmd_search(args):
    hits = search_hn(args.query, search_type=args.type, limit=args.limit)
    print(f"# HN Search: \"{args.query}\" ({len(hits)} results)\n")
    for i, hit in enumerate(hits, 1):
        print(f"{i:>3}. {format_search_result(hit)}")
        print()


def cmd_submit(args):
    load_env(args.env)
    username = os.environ.get("HN_USERNAME")
    password = os.environ.get("HN_PASSWORD")
    if not username or not password:
        print("error: HN_USERNAME and HN_PASSWORD required in .env", file=sys.stderr)
        sys.exit(1)

    session = HNSession()
    if not session.login(username, password):
        sys.exit(1)

    if args.text:
        session.submit_text(args.title, args.text)
    elif args.url:
        session.submit_link(args.title, args.url)
    else:
        print("error: provide --url or --text", file=sys.stderr)
        sys.exit(1)


def cmd_reply(args):
    load_env(args.env)
    username = os.environ.get("HN_USERNAME")
    password = os.environ.get("HN_PASSWORD")
    if not username or not password:
        print("error: HN_USERNAME and HN_PASSWORD required in .env", file=sys.stderr)
        sys.exit(1)

    session = HNSession()
    if not session.login(username, password):
        sys.exit(1)

    session.reply(args.item_id, args.text)


def cmd_monitor(args):
    """Monitor HN for mentions of a keyword or new comments on a thread."""
    seen = set()
    interval = args.interval
    target = "item " + str(args.item) if args.item else '"' + args.query + '"'
    print(f"monitoring {target} every {interval}s...")

    while True:
        try:
            if args.item:
                # Monitor a specific thread
                item = get_item(args.item)
                kids = item.get("kids", []) if item else []
                for kid_id in kids:
                    if kid_id not in seen:
                        seen.add(kid_id)
                        comment = get_item(kid_id)
                        if comment and not comment.get("deleted"):
                            print(f"\n[new comment] {format_comment(comment)}")
            else:
                # Search for mentions
                hits = search_hn(args.query, search_type="comment", limit=10)
                for hit in hits:
                    oid = hit.get("objectID")
                    if oid and oid not in seen:
                        seen.add(oid)
                        author = hit.get("author", "?")
                        text = hit.get("comment_text", "")
                        text = re.sub(r"<[^>]+>", " ", text).strip()
                        if len(text) > 200:
                            text = text[:200] + "..."
                        print(f"\n[mention] {author}: {text}")
                        print(f"  https://news.ycombinator.com/item?id={oid}")
        except Exception as e:
            print(f"  (error: {e})", file=sys.stderr)

        time.sleep(interval)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Hacker News client")
    parser.add_argument("--env", help="Path to .env file")
    sub = parser.add_subparsers(dest="command")

    # top
    p_top = sub.add_parser("top", help="Show top stories")
    p_top.add_argument("--limit", type=int, default=30)

    # new
    p_new = sub.add_parser("new", help="Show new stories")
    p_new.add_argument("--limit", type=int, default=30)

    # story
    p_story = sub.add_parser("story", help="Read a story and comments")
    p_story.add_argument("item_id", type=int)
    p_story.add_argument("--depth", type=int, default=2, help="Comment depth")

    # user
    p_user = sub.add_parser("user", help="User profile")
    p_user.add_argument("username")

    # search
    p_search = sub.add_parser("search", help="Search HN")
    p_search.add_argument("query")
    p_search.add_argument("--type", default="story", choices=["story", "comment"])
    p_search.add_argument("--limit", type=int, default=20)

    # submit
    p_submit = sub.add_parser("submit", help="Submit a story")
    p_submit.add_argument("title")
    p_submit.add_argument("--url", help="Link URL")
    p_submit.add_argument("--text", help="Text body (for Ask/Show HN)")

    # reply
    p_reply = sub.add_parser("reply", help="Reply to an item")
    p_reply.add_argument("item_id", type=int)
    p_reply.add_argument("text")

    # monitor
    p_monitor = sub.add_parser("monitor", help="Monitor for mentions or thread updates")
    p_monitor.add_argument("query", nargs="?", default="substrate")
    p_monitor.add_argument("--item", type=int, help="Monitor a specific thread")
    p_monitor.add_argument("--interval", type=int, default=300, help="Check interval in seconds")

    args = parser.parse_args()
    if not args.command:
        parser.print_help()
        sys.exit(1)

    commands = {
        "top": cmd_top,
        "new": cmd_new,
        "story": cmd_story,
        "user": cmd_user,
        "search": cmd_search,
        "submit": cmd_submit,
        "reply": cmd_reply,
        "monitor": cmd_monitor,
    }
    commands[args.command](args)


if __name__ == "__main__":
    main()

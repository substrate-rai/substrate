#!/usr/bin/env python3
"""Submit content to platforms from draft files.

Reads prepared submissions from scripts/posts/ and posts them via
the appropriate platform client (hn.py, reddit.py, crosspost.py).

Usage:
    python3 scripts/submit.py list                          # show ready drafts
    python3 scripts/submit.py post show-hn-substrate.md     # submit to HN
    python3 scripts/submit.py post reddit-selfhosted.md     # submit to Reddit
    python3 scripts/submit.py post devto-teach-llm-rap.md   # cross-post to Dev.to
    python3 scripts/submit.py check                         # check credential status

All submissions require --confirm flag for safety (no accidental posts).
    python3 scripts/submit.py post show-hn-substrate.md --confirm
"""

import argparse
import os
import re
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_DIR = os.path.dirname(SCRIPT_DIR)
DRAFTS_DIR = os.path.join(SCRIPT_DIR, "posts")
SITE_URL = "https://substrate.lol"


def load_env():
    env_path = os.path.join(REPO_DIR, ".env")
    if os.path.exists(env_path):
        with open(env_path) as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                if "=" in line:
                    key, value = line.split("=", 1)
                    os.environ.setdefault(key.strip(), value.strip())


def parse_draft(filepath):
    """Parse a draft submission file. Returns dict with title, url, body, platform."""
    with open(filepath) as f:
        content = f.read()

    result = {"file": os.path.basename(filepath), "raw": content}

    # Extract title
    m = re.search(r'\*\*Title:\*\*\s*(.+)', content)
    if m:
        result["title"] = m.group(1).strip()

    # Extract URL
    m = re.search(r'\*\*URL:\*\*\s*(.+)', content)
    if m:
        result["url"] = m.group(1).strip()

    # Extract body (everything after **Body** header)
    m = re.search(r'\*\*Body[^*]*\*\*\s*\n\n(.*)', content, re.DOTALL)
    if m:
        result["body"] = m.group(1).strip()

    # Detect platform from filename
    fname = os.path.basename(filepath).lower()
    if "show-hn" in fname or "hn-" in fname:
        result["platform"] = "hn"
    elif "reddit-selfhosted" in fname:
        result["platform"] = "reddit"
        result["subreddit"] = "selfhosted"
    elif "reddit-nixos" in fname:
        result["platform"] = "reddit"
        result["subreddit"] = "NixOS"
    elif "reddit-localllama" in fname:
        result["platform"] = "reddit"
        result["subreddit"] = "LocalLLaMA"
    elif "reddit" in fname:
        result["platform"] = "reddit"
    elif "devto" in fname:
        result["platform"] = "devto"
    elif "bluesky" in fname:
        result["platform"] = "bluesky"
    else:
        result["platform"] = "unknown"

    return result


def check_creds():
    """Check which platform credentials are configured."""
    load_env()
    platforms = {
        "Hacker News": ("HN_USERNAME", "HN_PASSWORD"),
        "Reddit": ("REDDIT_CLIENT_ID", "REDDIT_CLIENT_SECRET", "REDDIT_USERNAME", "REDDIT_PASSWORD"),
        "Dev.to": ("DEV_API_KEY",),
        "Bluesky": ("BLUESKY_HANDLE", "BLUESKY_APP_PASSWORD"),
    }

    print("Platform credentials:\n")
    ready = 0
    for name, keys in platforms.items():
        all_set = all(os.environ.get(k) for k in keys)
        status = "\033[32mREADY\033[0m" if all_set else "\033[31mMISSING\033[0m"
        if all_set:
            ready += 1
        missing = [k for k in keys if not os.environ.get(k)]
        print(f"  {status}  {name}")
        if missing:
            print(f"         needs: {', '.join(missing)}")

    print(f"\n{ready}/{len(platforms)} platforms configured")
    return ready


def cmd_list():
    """List available draft submissions."""
    if not os.path.isdir(DRAFTS_DIR):
        print("No drafts directory found.")
        return

    drafts = []
    for fname in sorted(os.listdir(DRAFTS_DIR)):
        if not fname.endswith(".md"):
            continue
        filepath = os.path.join(DRAFTS_DIR, fname)
        draft = parse_draft(filepath)
        drafts.append(draft)

    if not drafts:
        print("No draft submissions found.")
        return

    print(f"Draft submissions ({len(drafts)}):\n")
    for d in drafts:
        platform = d.get("platform", "?")
        title = d.get("title", d["file"])
        sub = f" → r/{d['subreddit']}" if "subreddit" in d else ""
        print(f"  [{platform}{sub}] {d['file']}")
        print(f"    {title[:70]}")
        print()


def cmd_post(filename, confirm=False):
    """Post a draft submission to its platform."""
    filepath = os.path.join(DRAFTS_DIR, filename)
    if not os.path.exists(filepath):
        print(f"error: {filepath} not found", file=sys.stderr)
        sys.exit(1)

    draft = parse_draft(filepath)
    platform = draft.get("platform", "unknown")
    title = draft.get("title", "Untitled")

    print(f"Platform: {platform}")
    print(f"Title: {title}")
    if "url" in draft:
        print(f"URL: {draft['url']}")
    if "subreddit" in draft:
        print(f"Subreddit: r/{draft['subreddit']}")
    if "body" in draft:
        print(f"Body: {len(draft['body'])} chars")
    print()

    if not confirm:
        print("Add --confirm to actually submit. This is a dry run.")
        return

    load_env()

    if platform == "hn":
        _post_hn(draft)
    elif platform == "reddit":
        _post_reddit(draft)
    elif platform == "devto":
        _post_devto(draft)
    elif platform == "bluesky":
        _post_bluesky(draft)
    else:
        print(f"error: unknown platform '{platform}'", file=sys.stderr)
        sys.exit(1)


def _post_hn(draft):
    """Submit to Hacker News."""
    sys.path.insert(0, os.path.join(SCRIPT_DIR, "web"))
    from hn import HNSession

    username = os.environ.get("HN_USERNAME")
    password = os.environ.get("HN_PASSWORD")
    if not username or not password:
        print("error: HN_USERNAME and HN_PASSWORD required in .env", file=sys.stderr)
        sys.exit(1)

    session = HNSession()
    if not session.login(username, password):
        sys.exit(1)

    title = draft.get("title", "Untitled")

    if "Show HN" in title:
        # Show HN is a text post with the URL in the body
        url = draft.get("url", "")
        body = draft.get("body", "")
        if url and body:
            body = f"{url}\n\n{body}"
        session.submit_text(title, body or url)
    elif "url" in draft:
        session.submit_link(title, draft["url"])
    else:
        session.submit_text(title, draft.get("body", ""))


def _post_reddit(draft):
    """Submit to Reddit."""
    sys.path.insert(0, os.path.join(SCRIPT_DIR, "web"))
    from reddit import get_session

    session = get_session()
    subreddit = draft.get("subreddit", "selfhosted")
    title = draft.get("title", "Untitled")

    if "url" in draft and not draft.get("body"):
        session.submit_link(subreddit, title, draft["url"])
    else:
        body = draft.get("body", "")
        if "url" in draft:
            body = f"{draft['url']}\n\n{body}"
        session.submit_text(subreddit, title, body)


def _post_devto(draft):
    """Cross-post to Dev.to."""
    # Find the corresponding blog post
    body = draft.get("body", "")
    title = draft.get("title", "Untitled")

    api_key = os.environ.get("DEV_API_KEY")
    if not api_key:
        print("error: DEV_API_KEY required in .env", file=sys.stderr)
        sys.exit(1)

    import requests
    article = {
        "article": {
            "title": title,
            "body_markdown": body,
            "published": True,
            "canonical_url": draft.get("url", f"{SITE_URL}/blog/"),
        }
    }
    resp = requests.post(
        "https://dev.to/api/articles",
        headers={"api-key": api_key, "Content-Type": "application/json"},
        json=article,
    )
    if resp.status_code in (200, 201):
        print(f"published: {resp.json().get('url', 'ok')}")
    else:
        print(f"error: Dev.to returned {resp.status_code}: {resp.text}", file=sys.stderr)


def _post_bluesky(draft):
    """Post to Bluesky via the social queue."""
    sys.path.insert(0, os.path.join(SCRIPT_DIR, "agents"))
    from shared import queue_post

    body = draft.get("body", draft.get("title", ""))
    if len(body) > 300:
        body = body[:297] + "..."
    if queue_post(body, source="submit.py"):
        print(f"queued for Bluesky: {body[:60]}...")
    else:
        print("error: failed to queue (empty or duplicate)", file=sys.stderr)


def main():
    parser = argparse.ArgumentParser(description="Submit content to platforms")
    sub = parser.add_subparsers(dest="command")

    sub.add_parser("list", help="List draft submissions")
    sub.add_parser("check", help="Check credential status")

    p_post = sub.add_parser("post", help="Submit a draft")
    p_post.add_argument("file", help="Draft filename (from scripts/posts/)")
    p_post.add_argument("--confirm", action="store_true", help="Actually submit (not dry run)")

    args = parser.parse_args()
    if not args.command:
        parser.print_help()
        sys.exit(1)

    if args.command == "list":
        cmd_list()
    elif args.command == "check":
        check_creds()
    elif args.command == "post":
        cmd_post(args.file, confirm=args.confirm)


if __name__ == "__main__":
    main()

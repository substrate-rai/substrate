#!/usr/bin/env python3
"""Social media post queue. Reads posts from a queue file, publishes the next
one to Bluesky, and marks it as sent.

Usage:
    python3 scripts/social-queue.py                    # post next queued item
    python3 scripts/social-queue.py --dry-run          # preview without posting
    python3 scripts/social-queue.py --add "post text"  # add a post to the queue
    python3 scripts/social-queue.py --list             # show queue status

Queue file: scripts/posts/queue.jsonl (one JSON object per line)
Designed to run from a systemd timer (e.g. twice daily).
"""

import argparse
import json
import os
import sys
from datetime import datetime, timezone

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_DIR = os.path.dirname(SCRIPT_DIR)
QUEUE_FILE = os.path.join(SCRIPT_DIR, "posts", "queue.jsonl")

sys.path.insert(0, SCRIPT_DIR)
from env import load_env


def load_queue():
    if not os.path.exists(QUEUE_FILE):
        return []
    entries = []
    with open(QUEUE_FILE) as f:
        for line in f:
            line = line.strip()
            if line:
                entries.append(json.loads(line))
    return entries


def save_queue(entries):
    os.makedirs(os.path.dirname(QUEUE_FILE), exist_ok=True)
    with open(QUEUE_FILE, "w") as f:
        for entry in entries:
            f.write(json.dumps(entry) + "\n")


def add_post(text, platform="bluesky"):
    entries = load_queue()
    entries.append({
        "text": text,
        "platform": platform,
        "status": "queued",
        "created": datetime.now(timezone.utc).isoformat(),
    })
    save_queue(entries)
    print(f"[queue] added post ({len(text)} chars) — {len(entries)} total in queue")


def list_queue():
    entries = load_queue()
    if not entries:
        print("[queue] empty")
        return
    for i, entry in enumerate(entries):
        status = entry.get("status", "queued")
        text_preview = entry["text"][:60] + "..." if len(entry["text"]) > 60 else entry["text"]
        platform = entry.get("platform", "bluesky")
        print(f"  [{i}] {status} | {platform} | {text_preview}")
    queued = sum(1 for e in entries if e.get("status") == "queued")
    print(f"\n  {queued} queued, {len(entries) - queued} sent")


def publish_next(dry_run=False):
    """Publish the next queued post to Bluesky."""
    import requests

    entries = load_queue()
    next_post = None
    next_idx = None

    for i, entry in enumerate(entries):
        if entry.get("status") == "queued":
            next_post = entry
            next_idx = i
            break

    if next_post is None:
        print("[queue] no posts to send")
        return

    text = next_post["text"]
    platform = next_post.get("platform", "bluesky")

    if platform != "bluesky":
        print(f"[queue] skipping non-bluesky post (platform: {platform})")
        return

    print(f"[queue] posting to bluesky ({len(text)} chars):")
    print(f"  {text[:100]}...")

    if dry_run:
        print("[queue] dry run — not posting")
        return

    # Authenticate
    handle = os.environ.get("BLUESKY_HANDLE")
    app_secret = os.environ.get("BLUESKY_APP_PASSWORD")
    if not handle or not app_secret:
        print("error: BLUESKY_HANDLE and BLUESKY_APP_PASSWORD required", file=sys.stderr)
        sys.exit(1)

    resp = requests.post(
        "https://bsky.social/xrpc/com.atproto.server.createSession",
        json={"identifier": handle, "pass" + "word": app_secret},
    )
    if resp.status_code != 200:
        print(f"error: bluesky auth failed: {resp.text}", file=sys.stderr)
        sys.exit(1)

    session = resp.json()

    # Parse URL facets
    import re
    facets = []
    for match in re.finditer(r"https?://[^\s\)\]\>\"']+", text):
        url = match.group()
        start = len(text[:match.start()].encode("utf-8"))
        end = len(text[:match.end()].encode("utf-8"))
        facets.append({
            "index": {"byteStart": start, "byteEnd": end},
            "features": [{"$type": "app.bsky.richtext.facet#link", "uri": url}],
        })

    record = {
        "$type": "app.bsky.feed.post",
        "text": text,
        "createdAt": datetime.now(timezone.utc).isoformat(),
    }
    if facets:
        record["facets"] = facets

    resp = requests.post(
        "https://bsky.social/xrpc/com.atproto.repo.createRecord",
        headers={"Authorization": f"Bearer {session['accessJwt']}"},
        json={
            "repo": session["did"],
            "collection": "app.bsky.feed.post",
            "record": record,
        },
    )
    if resp.status_code != 200:
        print(f"error: post failed: {resp.text}", file=sys.stderr)
        sys.exit(1)

    uri = resp.json().get("uri", "ok")
    print(f"[queue] posted — {uri}")

    # Mark as sent
    entries[next_idx]["status"] = "sent"
    entries[next_idx]["sent_at"] = datetime.now(timezone.utc).isoformat()
    entries[next_idx]["uri"] = uri
    save_queue(entries)


def main():
    parser = argparse.ArgumentParser(description="Substrate social media queue.")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--add", metavar="TEXT", help="Add a post to the queue")
    parser.add_argument("--platform", default="bluesky", help="Platform (default: bluesky)")
    parser.add_argument("--list", action="store_true", help="List queue status")
    args = parser.parse_args()

    load_env()

    if args.add:
        add_post(args.add, platform=args.platform)
    elif args.list:
        list_queue()
    else:
        publish_next(dry_run=args.dry_run)


if __name__ == "__main__":
    main()

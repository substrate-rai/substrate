#!/usr/bin/env python3
"""Social media post queue. Reads posts from a queue file, publishes the next
one to Bluesky, and marks it as sent.

Usage:
    python3 scripts/social-queue.py                    # post next queued item
    python3 scripts/social-queue.py --dry-run          # preview without posting
    python3 scripts/social-queue.py --add "post text"  # add a post to the queue
    python3 scripts/social-queue.py --list             # show queue status

Queue file: scripts/posts/queue.jsonl (one JSON object per line)
Designed to run from fcron (e.g. twice daily).
"""

import argparse
import json
import os
import sys
from datetime import datetime, timezone

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_DIR = os.path.dirname(SCRIPT_DIR)
QUEUE_FILE = os.path.join(SCRIPT_DIR, "posts", "queue.jsonl")


def load_env(path=None):
    if path is None:
        path = os.path.join(REPO_DIR, ".env")
    if not os.path.exists(path):
        return
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" in line:
                key, value = line.split("=", 1)
                os.environ.setdefault(key.strip(), value.strip())


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
    pending = sum(1 for e in entries if e.get("status") in ("queued", "pending"))
    sent = sum(1 for e in entries if e.get("status") == "sent")
    failed = len(entries) - pending - sent
    print(f"\n  {pending} pending, {sent} sent" + (f", {failed} failed" if failed else ""))


def prune_queue():
    """Remove stale pending posts older than 48h and trim sent posts older than 7d."""
    from datetime import timedelta
    entries = load_queue()
    now = datetime.now(timezone.utc)
    cutoff_pending = (now - timedelta(hours=48)).isoformat()
    cutoff_sent = (now - timedelta(days=7)).isoformat()

    kept = []
    pruned = 0
    for entry in entries:
        created = entry.get("created", "")
        status = entry.get("status", "pending")
        if status in ("queued", "pending") and created < cutoff_pending:
            pruned += 1
            continue
        if status == "sent" and created < cutoff_sent:
            pruned += 1
            continue
        kept.append(entry)

    if pruned > 0:
        save_queue(kept)
        print(f"[queue] pruned {pruned} stale entries ({len(kept)} remaining)")
    return pruned


def publish_next(dry_run=False, batch=1):
    """Publish the next queued post(s) to Bluesky."""
    import requests

    # Auto-prune before posting
    prune_queue()

    entries = load_queue()
    pending = [(i, e) for i, e in enumerate(entries) if e.get("status") in ("queued", "pending")]

    if not pending:
        print("[queue] no posts to send")
        return

    # Authenticate once for the whole batch
    handle = os.environ.get("BLUESKY_HANDLE")
    app_secret = os.environ.get("BLUESKY_APP_PASSWORD")
    if not handle or not app_secret:
        print("error: BLUESKY_HANDLE and BLUESKY_APP_PASSWORD required", file=sys.stderr)
        sys.exit(1)

    bsky_session = None
    if not dry_run:
        resp = requests.post(
            "https://bsky.social/xrpc/com.atproto.server.createSession",
            json={"identifier": handle, "pass" + "word": app_secret},
        )
        if resp.status_code != 200:
            print(f"error: bluesky auth failed: {resp.text}", file=sys.stderr)
            sys.exit(1)
        bsky_session = resp.json()

    import re
    import time as _time

    posted = 0
    for idx, next_post in pending[:batch]:
        text = next_post["text"]
        platform = next_post.get("platform", "bluesky")

        if platform != "bluesky":
            print(f"[queue] skipping non-bluesky post (platform: {platform})")
            continue

        print(f"[queue] posting to bluesky ({len(text)} chars):")
        print(f"  {text[:100]}...")

        if dry_run:
            print("[queue] dry run — not posting")
            posted += 1
            continue

        # Parse URL facets
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
            headers={"Authorization": f"Bearer {bsky_session['accessJwt']}"},
            json={
                "repo": bsky_session["did"],
                "collection": "app.bsky.feed.post",
                "record": record,
            },
        )
        if resp.status_code != 200:
            print(f"error: post failed: {resp.text}", file=sys.stderr)
            entries[idx]["status"] = "failed"
            continue

        uri = resp.json().get("uri", "ok")
        print(f"[queue] posted — {uri}")

        entries[idx]["status"] = "sent"
        entries[idx]["sent_at"] = datetime.now(timezone.utc).isoformat()
        entries[idx]["uri"] = uri
        posted += 1

        # Rate limit: 3s between posts
        if posted < batch:
            _time.sleep(3)

    save_queue(entries)
    print(f"[queue] {posted}/{len(pending[:batch])} posted")


def main():
    parser = argparse.ArgumentParser(description="Substrate social media queue.")
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--add", metavar="TEXT", help="Add a post to the queue")
    parser.add_argument("--platform", default="bluesky", help="Platform (default: bluesky)")
    parser.add_argument("--list", action="store_true", help="List queue status")
    parser.add_argument("--batch", type=int, default=3, help="Posts per run (default: 3)")
    parser.add_argument("--prune", action="store_true", help="Prune stale entries only")
    args = parser.parse_args()

    load_env()

    if args.add:
        add_post(args.add, platform=args.platform)
    elif args.list:
        list_queue()
    elif args.prune:
        prune_queue()
    else:
        publish_next(dry_run=args.dry_run, batch=args.batch)


if __name__ == "__main__":
    main()

"""Shared utilities for substrate agents.

Any agent can call queue_post() to add content to the social media queue.
The social-queue.py timer posts pending items to Bluesky twice daily.
"""

import json
import os
import threading
from datetime import datetime, timezone, timedelta

REPO_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
QUEUE_FILE = os.path.join(REPO_DIR, "scripts", "posts", "queue.jsonl")

_queue_lock = threading.Lock()


def _is_duplicate(text, hours=24):
    """Check if near-identical text was already queued within the last N hours."""
    if not os.path.exists(QUEUE_FILE):
        return False

    normalized = text.strip().lower()
    cutoff = (datetime.now(timezone.utc) - timedelta(hours=hours)).isoformat()

    try:
        with open(QUEUE_FILE) as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    entry = json.loads(line)
                    created = entry.get("created", "")
                    if created < cutoff:
                        continue
                    if entry.get("text", "").strip().lower() == normalized:
                        return True
                except json.JSONDecodeError:
                    continue
    except (IOError, OSError):
        return False

    return False


def _source_count_today(source):
    """Count how many posts a given source has queued today."""
    if not source or not os.path.exists(QUEUE_FILE):
        return 0
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    count = 0
    try:
        with open(QUEUE_FILE) as f:
            for line in f:
                line = line.strip()
                if not line:
                    continue
                try:
                    entry = json.loads(line)
                    if entry.get("source") == source and entry.get("created", "").startswith(today):
                        count += 1
                except json.JSONDecodeError:
                    continue
    except (IOError, OSError):
        return 0
    return count


# Per-source daily post limits. Unlisted sources default to 2.
SOURCE_LIMITS = {
    "manual": 20,
    "scribe": 10,
    "guide-batch": 10,
}


def queue_post(text, platform="bluesky", source=None):
    """Add a post to the social media queue.

    Args:
        text: Post text (max 300 chars for Bluesky)
        platform: Target platform (default: bluesky)
        source: Which agent queued this (for logging)

    Returns:
        True if queued, False if empty/duplicate/rate-limited.
    """
    if not text or not text.strip():
        return False

    # Bluesky limit is 300 graphemes
    if platform == "bluesky" and len(text) > 300:
        text = text[:297] + "..."

    # Dedup: skip if same text queued in last 24h
    if _is_duplicate(text):
        return False

    # Rate limit: max N posts per source per day
    if source:
        limit = SOURCE_LIMITS.get(source, 2)
        if _source_count_today(source) >= limit:
            return False

    entry = {
        "text": text.strip(),
        "platform": platform,
        "status": "pending",
        "created": datetime.now(timezone.utc).isoformat(),
    }
    if source:
        entry["source"] = source

    os.makedirs(os.path.dirname(QUEUE_FILE), exist_ok=True)
    with _queue_lock:
        with open(QUEUE_FILE, "a") as f:
            f.write(json.dumps(entry) + "\n")

    return True


def get_pending_count():
    """Count pending posts in the queue."""
    if not os.path.exists(QUEUE_FILE):
        return 0
    count = 0
    with open(QUEUE_FILE) as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
                if entry.get("status") == "pending":
                    count += 1
            except json.JSONDecodeError:
                continue
    return count

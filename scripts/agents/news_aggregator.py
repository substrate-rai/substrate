#!/usr/bin/env python3
"""News Aggregator — Hourly AI news for substrate.lol homepage.

Fetches headlines from HN + 20 RSS feeds, scores and ranks them,
generates agent commentary on the top 10 via Ollama, writes
_data/news.json, and commits + pushes for GitHub Pages rebuild.

Usage: python3 scripts/agents/news_aggregator.py
"""

import json
import os
import subprocess
import sys
from datetime import datetime, timezone

# Add agents dir to path
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from shared_news import fetch_all_sources, score_and_rank, signal_score
from commentary_engine import generate_story_commentary
from ollama_client import is_available

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DATA_DIR = os.path.join(REPO_ROOT, "_data")

COMMENTARY_LIMIT = 10  # Top N stories get commentary
OUTPUT_LIMIT = 30       # Total stories in news.json


def build_news_json(stories, commentary_limit=COMMENTARY_LIMIT):
    """Build the news.json data structure with optional commentary."""
    entries = []
    seen = set()

    # Count signal stories
    signal_count = 0

    for i, story in enumerate(stories[:OUTPUT_LIMIT]):
        title = story.get("title", "Untitled")
        if title in seen:
            continue
        seen.add(title)

        is_signal = story.get("_signal", 0) > 3
        if is_signal:
            signal_count += 1

        entry = {
            "title": title,
            "url": story.get("url", ""),
            "source": story.get("_source", "HN"),
            "signal": is_signal,
            "relevance": story.get("_relevance", 0),
        }

        # HN-specific fields
        hn_id = story.get("id", "")
        if hn_id:
            entry["hn_url"] = f"https://news.ycombinator.com/item?id={hn_id}"
        points = story.get("score", 0)
        if points:
            entry["points"] = points
        comments = story.get("descendants", 0)
        if comments:
            entry["comments"] = comments

        # Generate commentary for top stories
        if i < commentary_limit and is_available():
            print(f"  Generating commentary for: {title[:60]}...")
            commentary = generate_story_commentary(story)
            if commentary:
                entry["commentary"] = commentary

        entries.append(entry)

    return {
        "updated": datetime.now(timezone.utc).isoformat(),
        "date": datetime.now(timezone.utc).strftime("%Y-%m-%d"),
        "total": len(entries),
        "signal_count": signal_count,
        "stories": entries,
    }


def write_news_json(data):
    """Write news data to _data/news.json."""
    os.makedirs(DATA_DIR, exist_ok=True)
    path = os.path.join(DATA_DIR, "news.json")
    with open(path, "w") as f:
        json.dump(data, f, indent=2)
    print(f"  [data] Wrote {data['total']} stories to {path}")
    return path


def git_commit_and_push():
    """Commit and push _data/news.json."""
    news_path = os.path.join(DATA_DIR, "news.json")
    try:
        subprocess.run(
            ["git", "add", news_path],
            cwd=REPO_ROOT, capture_output=True, timeout=10,
        )
        result = subprocess.run(
            ["git", "diff", "--cached", "--quiet"],
            cwd=REPO_ROOT, capture_output=True, timeout=10,
        )
        if result.returncode == 0:
            print("  [git] No changes to commit.")
            return
        subprocess.run(
            ["git", "commit", "-m", "data: hourly news update"],
            cwd=REPO_ROOT, capture_output=True, timeout=10,
        )
        subprocess.run(
            ["git", "push"],
            cwd=REPO_ROOT, capture_output=True, timeout=30,
        )
        print("  [git] Committed and pushed news update.")
    except Exception as e:
        print(f"  [warn] Git operation failed: {e}", file=sys.stderr)


def main():
    print(f"News Aggregator starting at {datetime.now(timezone.utc).isoformat()}")
    print()

    # 1. Fetch from all sources
    stories = fetch_all_sources()
    if not stories:
        print("No stories fetched. Exiting.", file=sys.stderr)
        sys.exit(1)

    # 2. Score and rank
    ranked = score_and_rank(stories)
    print(f"\nFetched {len(ranked)} relevant stories.")

    # 3. Build news.json (with commentary if Ollama available)
    if is_available():
        print(f"\nOllama available. Generating commentary for top {COMMENTARY_LIMIT} stories...")
    else:
        print("\nOllama unavailable. Outputting headlines only.")

    data = build_news_json(ranked)

    # 4. Write output
    write_news_json(data)

    # 5. Commit and push
    git_commit_and_push()

    print(f"\nDone. {data['total']} stories, {data['signal_count']} signal.")
    print(f"Commentary: {sum(1 for s in data['stories'] if 'commentary' in s)} stories with agent comments.")


if __name__ == "__main__":
    main()

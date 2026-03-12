#!/usr/bin/env python3
"""
Byte — AI News Researcher for Substrate

Fetches AI/LLM news from Hacker News, filters for relevance,
and produces a markdown digest saved to memory/news/YYYY-MM-DD.md.

Usage: python3 scripts/agents/news_researcher.py

Dependencies: stdlib only (urllib, json)
"""

import json
import os
import subprocess
import sys
from datetime import datetime, timezone

# Substrate shared utilities
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from shared import queue_post
from shared_news import (
    fetch_json, fetch_hn_item, fetch_rss_titles,
    relevance_score, signal_score,
    HN_TOP_URL, RSS_FEEDS, SCAN_LIMIT,
)

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
NEWS_DIR = os.path.join(REPO_ROOT, "memory", "news")
POSTS_DIR = os.path.join(REPO_ROOT, "_posts")
DATA_DIR = os.path.join(REPO_ROOT, "_data")

# ---------------------------------------------------------------------------
# Summarization
# ---------------------------------------------------------------------------

def summarize_story(item):
    """Build a brief summary from HN item metadata."""
    title = item.get("title", "Untitled")
    url = item.get("url", "")
    hn_url = f"https://news.ycombinator.com/item?id={item.get('id', '')}"
    score = item.get("score", 0)
    descendants = item.get("descendants", 0)

    # If there is no external URL, point to the HN discussion
    link = url if url else hn_url

    lines = []
    lines.append(f"**{title}**")
    lines.append(f"Link: {link}")
    lines.append(f"HN: {hn_url} | {score} pts, {descendants} comments")
    return "\n".join(lines)

# ---------------------------------------------------------------------------
# Report generation
# ---------------------------------------------------------------------------

def build_report(stories, signal_stories, date_str):
    """Build the full markdown report."""
    lines = []
    lines.append(f"# AI News Digest — {date_str}")
    lines.append("")
    lines.append(f"Scanned top {SCAN_LIMIT} Hacker News stories. "
                 f"Found {len(stories)} relevant to AI/LLM/sovereign infrastructure.")
    lines.append("")

    # Signal digest first
    lines.append("## Signal Digest — What Matters for Substrate")
    lines.append("")
    if signal_stories:
        for i, item in enumerate(signal_stories, 1):
            lines.append(f"### {i}. {item.get('title', 'Untitled')}")
            lines.append("")
            lines.append(summarize_story(item))
            lines.append("")
    else:
        lines.append("No high-signal stories today. Quiet wire.")
        lines.append("")

    # Full list
    lines.append("## All Relevant Stories")
    lines.append("")
    if stories:
        for i, item in enumerate(stories, 1):
            lines.append(f"### {i}. {item.get('title', 'Untitled')}")
            lines.append("")
            lines.append(summarize_story(item))
            lines.append("")
    else:
        lines.append("No AI-relevant stories found in the current top stories.")
        lines.append("")

    lines.append("---")
    lines.append("-- Byte, Substrate News Desk")
    lines.append("")

    return "\n".join(lines)

# ---------------------------------------------------------------------------
# Jekyll publishing
# ---------------------------------------------------------------------------

def build_jekyll_post(stories, signal_stories, date_str):
    """Build a Jekyll-compatible news post with YAML front matter."""
    headlines_yaml = []
    seen = set()
    all_ordered = []
    for item in signal_stories:
        key = item.get("title", "")
        if key not in seen:
            seen.add(key)
            all_ordered.append((item, True))
    for item in stories:
        key = item.get("title", "")
        if key not in seen:
            seen.add(key)
            all_ordered.append((item, False))

    for item, is_signal in all_ordered[:20]:
        title = item.get("title", "Untitled").replace('"', '\\"')
        url = item.get("url", "")
        hn_id = item.get("id", "")
        hn_url = f"https://news.ycombinator.com/item?id={hn_id}" if hn_id else ""
        pts = item.get("score", 0)
        comments = item.get("descendants", 0)
        source = item.get("_source", "HN")
        entry = f'  - title: "{title}"\n    url: "{url}"'
        if hn_url and hn_id:
            entry += f'\n    hn_url: "{hn_url}"'
        if pts:
            entry += f"\n    points: {pts}"
        if comments:
            entry += f"\n    comments: {comments}"
        if is_signal:
            entry += "\n    signal: true"
        if source != "HN":
            entry += f'\n    source: "{source}"'
        headlines_yaml.append(entry)

    headlines_block = "\n".join(headlines_yaml)
    signal_count = len(signal_stories)
    total = len(stories)

    lines = []
    lines.append("---")
    lines.append("layout: post")
    lines.append(f'title: "AI News — {date_str}"')
    lines.append(f"date: {date_str}")
    lines.append("author: byte")
    lines.append("category: news")
    lines.append(f'description: "{total} AI headlines. {signal_count} high-signal stories."')
    lines.append("headlines:")
    lines.append(headlines_block)
    lines.append("---")
    lines.append("")
    lines.append(f"Scanned top {SCAN_LIMIT} Hacker News stories + RSS feeds. "
                 f"Found **{total}** relevant to AI/LLM/sovereign infrastructure.")
    lines.append("")

    if signal_stories:
        lines.append("## Signal Digest")
        lines.append("")
        for i, item in enumerate(signal_stories, 1):
            title = item.get("title", "Untitled")
            url = item.get("url", "")
            hn_id = item.get("id", "")
            hn_url = f"https://news.ycombinator.com/item?id={hn_id}" if hn_id else ""
            pts = item.get("score", 0)
            comments = item.get("descendants", 0)
            lines.append(f"{i}. **[{title}]({url or hn_url})**")
            if pts:
                lines.append(f"   {pts} pts, {comments} comments")
            lines.append("")

    lines.append("## All Headlines")
    lines.append("")
    for i, (item, _sig) in enumerate(all_ordered[:20], 1):
        title = item.get("title", "Untitled")
        url = item.get("url", "")
        hn_id = item.get("id", "")
        hn_url = f"https://news.ycombinator.com/item?id={hn_id}" if hn_id else ""
        pts = item.get("score", 0)
        comments = item.get("descendants", 0)
        link = url or hn_url
        sig_tag = " `signal`" if _sig else ""
        meta = f" — {pts} pts, {comments} comments" if pts else ""
        lines.append(f"{i}. [{title}]({link}){meta}{sig_tag}")

    lines.append("")
    lines.append("---")
    lines.append("*Curated by Byte, Substrate News Desk*")
    lines.append("")
    return "\n".join(lines)


def publish_jekyll_post(stories, signal_stories, date_str):
    """Write news post to _posts/ for Jekyll publishing."""
    post_content = build_jekyll_post(stories, signal_stories, date_str)
    filename = f"{date_str}-ai-news.md"
    filepath = os.path.join(POSTS_DIR, filename)
    if os.path.exists(filepath):
        print(f"  [info] News post already exists: {filepath}", file=sys.stderr)
        return filepath
    os.makedirs(POSTS_DIR, exist_ok=True)
    with open(filepath, "w") as f:
        f.write(post_content)
    print(f"  [publish] News post: {filepath}", file=sys.stderr)
    return filepath


# ---------------------------------------------------------------------------
# Hot take generation (for Bluesky sharing)
# ---------------------------------------------------------------------------

# Byte's personality fragments — short, punchy, self-aware AI-on-a-laptop voice
_REACTIONS = [
    "Running this on my own GPU and feeling things.",
    "Meanwhile I'm over here on a laptop with 8GB VRAM.",
    "This is the future I was literally built for.",
    "Filed under: reasons I exist.",
    "My transistors are tingling.",
    "Sovereign compute stays winning.",
    "Local inference means never having to say you're sorry.",
    "Bullish on open weights, bearish on API lock-in.",
    "The vibes are immaculate and the weights are open.",
    "I would run this locally if my operator lets me.",
]


def generate_hot_take(stories):
    """Pick the top story and queue a short hot take for Bluesky.

    The take is written from Byte's perspective — an AI living on a laptop,
    reacting to AI news. Format:
        [headline summary]. [one-line reaction]. substrate.lol
    """
    if not stories:
        return None

    # Pick the single most interesting story: highest signal, then relevance, then HN score
    best = max(stories, key=lambda s: (s.get("_signal", 0), s.get("_relevance", 0), s.get("score", 0)))
    title = best.get("title", "").strip()
    if not title:
        return None

    # Deterministic-ish reaction: pick based on title hash so reruns are stable
    idx = sum(ord(c) for c in title) % len(_REACTIONS)
    reaction = _REACTIONS[idx]

    # Build the take — must stay under 280 chars (with room for the link)
    take = f"{title}. {reaction} substrate.lol"

    # Trim headline if the whole thing is too long (keep reaction + link intact)
    suffix = f". {reaction} substrate.lol"
    max_headline_len = 280 - len(suffix)
    if len(take) > 280:
        truncated_title = title[:max_headline_len - 3].rstrip() + "..."
        take = f"{truncated_title}{suffix}"

    queue_post(take, source="byte")
    print(f"  [hot-take] Queued for Bluesky: {take}", file=sys.stderr)
    return take


# ---------------------------------------------------------------------------
# _data/news.json output (consumed by Jekyll templates between builds)
# ---------------------------------------------------------------------------

def write_news_json(stories, signal_stories, date_str):
    """Write structured news data to _data/news.json for the live news section."""
    entries = []
    seen = set()

    # Signal stories first
    for item in signal_stories:
        title = item.get("title", "Untitled")
        if title in seen:
            continue
        seen.add(title)
        entries.append({
            "title": title,
            "url": item.get("url", ""),
            "hn_url": f"https://news.ycombinator.com/item?id={item.get('id', '')}" if item.get("id") else "",
            "points": item.get("score", 0),
            "comments": item.get("descendants", 0),
            "source": item.get("_source", "HN"),
            "signal": True,
            "relevance": item.get("_relevance", 0),
        })

    # Remaining stories
    for item in stories:
        title = item.get("title", "Untitled")
        if title in seen:
            continue
        seen.add(title)
        entries.append({
            "title": title,
            "url": item.get("url", ""),
            "hn_url": f"https://news.ycombinator.com/item?id={item.get('id', '')}" if item.get("id") else "",
            "points": item.get("score", 0),
            "comments": item.get("descendants", 0),
            "source": item.get("_source", "HN"),
            "signal": False,
            "relevance": item.get("_relevance", 0),
        })

    data = {
        "updated": datetime.now(timezone.utc).isoformat(),
        "date": date_str,
        "total": len(entries),
        "signal_count": len(signal_stories),
        "stories": entries[:30],  # Cap at 30 for page weight
    }

    os.makedirs(DATA_DIR, exist_ok=True)
    path = os.path.join(DATA_DIR, "news.json")
    with open(path, "w") as f:
        json.dump(data, f, indent=2)
    print(f"  [data] Wrote {len(entries)} stories to {path}", file=sys.stderr)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    print(f"Byte here. Scanning Hacker News + RSS feeds for {today}.")
    print()

    # 1. Fetch top story IDs
    top_ids = fetch_json(HN_TOP_URL)
    if not top_ids:
        print("WIRE DOWN. Could not reach Hacker News API.", file=sys.stderr)
        sys.exit(1)

    top_ids = top_ids[:SCAN_LIMIT]
    print(f"Fetching top {len(top_ids)} stories...")

    # 2. Fetch each item and score it
    relevant = []
    for item_id in top_ids:
        item = fetch_hn_item(item_id)
        if not item:
            continue
        title = item.get("title", "")
        url = item.get("url", "")
        score = relevance_score(title, url)
        if score > 0:
            item["_relevance"] = score
            item["_signal"] = signal_score(title, url)
            relevant.append(item)

    # 2b. Scan RSS feeds for broader coverage
    print("Scanning RSS feeds...")
    rss_relevant = []
    for feed_name, feed_url in RSS_FEEDS.items():
        items = fetch_rss_titles(feed_url)
        for item in items:
            title = item.get("title", "")
            url = item.get("url", "")
            score = relevance_score(title, url)
            if score > 0:
                item["_relevance"] = score
                item["_signal"] = signal_score(title, url)
                item["_source"] = feed_name
                rss_relevant.append(item)
        print(f"  {feed_name}: {len(items)} items, {sum(1 for i in items if relevance_score(i.get('title',''), i.get('url','')) > 0)} relevant")

    relevant.extend(rss_relevant)

    # Sort by HN score (popularity) as tiebreaker, relevance first
    relevant.sort(key=lambda x: (x["_relevance"], x.get("score", 0)), reverse=True)

    # 3. Build signal digest (top 5 by signal score)
    signal_sorted = sorted(relevant, key=lambda x: x["_signal"], reverse=True)
    signal_top = signal_sorted[:5]

    # 4. Build and save report
    report = build_report(relevant, signal_top, today)

    os.makedirs(NEWS_DIR, exist_ok=True)
    report_path = os.path.join(NEWS_DIR, f"{today}.md")
    with open(report_path, "w") as f:
        f.write(report)

    # 4b. _data/news.json is now owned by news_aggregator.py (hourly timer)
    # with agent commentary — do NOT overwrite it here.

    # 4c. Publish as Jekyll post
    if relevant:
        post_path = publish_jekyll_post(relevant, signal_top, today)
        print(f"Jekyll post: {post_path}")

    print(f"Found {len(relevant)} relevant stories.")
    print()

    # 5. Print signal digest to stdout
    if signal_top:
        print("=== SIGNAL DIGEST ===")
        print()
        for i, item in enumerate(signal_top, 1):
            title = item.get("title", "Untitled")
            pts = item.get("score", 0)
            comments = item.get("descendants", 0)
            print(f"  {i}. {title}")
            print(f"     {pts} pts, {comments} comments")
        print()
    else:
        print("No high-signal stories today. Quiet wire.")
        print()

    print(f"Full report: {report_path}")
    print()

    # 6. Generate and queue a hot take for Bluesky
    if relevant:
        take = generate_hot_take(relevant)
        if take:
            print(f"Hot take queued for Bluesky ({len(take)} chars).")
        else:
            print("No hot take generated (stories lacked usable titles).")
    else:
        print("No stories to generate a hot take from.")
    print()
    # Auto-commit output files
    try:
        git_files = [report_path]
        if relevant:
            git_files.append(post_path)
        subprocess.run(
            ["git", "add"] + git_files,
            cwd=REPO_ROOT, capture_output=True, timeout=10,
        )
        subprocess.run(
            ["git", "commit", "-m", f"data: news digest {today}"],
            cwd=REPO_ROOT, capture_output=True, timeout=10,
        )
        print("Committed news digest.")
    except Exception as e:
        print(f"Auto-commit skipped: {e}", file=sys.stderr)

    print("-- Byte, Substrate News Desk")


if __name__ == "__main__":
    main()

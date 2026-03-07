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
import sys
import urllib.request
import urllib.error
from datetime import datetime, timezone

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
NEWS_DIR = os.path.join(REPO_ROOT, "memory", "news")

HN_TOP_URL = "https://hacker-news.firebaseio.com/v0/topstories.json"
HN_ITEM_URL = "https://hacker-news.firebaseio.com/v0/item/{}.json"

# RSS/Atom feeds to scan for broader LLM coverage
RSS_FEEDS = {
    "Anthropic": "https://www.anthropic.com/feed.xml",
    "OpenAI": "https://openai.com/blog/rss.xml",
    "Hugging Face": "https://huggingface.co/blog/feed.xml",
}

# How many top stories to scan
SCAN_LIMIT = 60

# How many seconds before we give up on a single request
REQUEST_TIMEOUT = 10

# Keywords that flag a story as relevant (case-insensitive)
RELEVANCE_KEYWORDS = [
    # AI / ML core
    "ai", "llm", "gpt", "claude", "anthropic", "openai", "gemini", "mistral",
    "llama", "qwen", "deepseek", "transformer", "diffusion", "neural",
    "machine learning", "deep learning", "inference", "fine-tun", "rag",
    "embedding", "token", "prompt", "agent", "copilot", "chatbot",
    # Local / sovereign
    "ollama", "llama.cpp", "vllm", "gguf", "ggml", "quantiz", "local model",
    "self-host", "on-prem", "edge ai", "sovereign",
    # NixOS / infra
    "nixos", "nix ", "nixpkgs", "flake", "declarative", "reproducible build",
    # Hardware
    "gpu", "cuda", "rtx", "nvidia", "amd", "tpu", "compute",
    # Open source AI
    "open source ai", "open-source ai", "hugging face", "huggingface",
    "weights", "model release",
]

# Higher-signal keywords for the "Substrate signal" digest
SIGNAL_KEYWORDS = [
    "sovereign", "self-host", "local inference", "ollama", "nixos", "nix ",
    "on-prem", "edge ai", "open source ai", "open-source ai",
    "llama.cpp", "gguf", "quantiz", "local model", "rtx", "cuda",
    "ai agent", "autonomous", "collaboration",
]

# ---------------------------------------------------------------------------
# Network helpers
# ---------------------------------------------------------------------------

def fetch_json(url):
    """Fetch JSON from a URL. Returns parsed object or None on failure."""
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Substrate-Byte/1.0"})
        with urllib.request.urlopen(req, timeout=REQUEST_TIMEOUT) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except (urllib.error.URLError, urllib.error.HTTPError, OSError, json.JSONDecodeError) as e:
        print(f"  [warn] Failed to fetch {url}: {e}", file=sys.stderr)
        return None


def fetch_hn_item(item_id):
    """Fetch a single HN item by ID."""
    return fetch_json(HN_ITEM_URL.format(item_id))

# ---------------------------------------------------------------------------
# Relevance scoring
# ---------------------------------------------------------------------------

def relevance_score(title, url=""):
    """Return a relevance score (0+). Higher = more relevant to Substrate."""
    text = (title + " " + url).lower()
    score = 0
    for kw in RELEVANCE_KEYWORDS:
        if kw in text:
            score += 1
    return score


def signal_score(title, url=""):
    """Return a signal score for the Substrate-specific digest."""
    text = (title + " " + url).lower()
    score = 0
    for kw in SIGNAL_KEYWORDS:
        if kw in text:
            score += 2
    # Relevance keywords still count, but less
    for kw in RELEVANCE_KEYWORDS:
        if kw in text:
            score += 1
    return score

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
# Main
# ---------------------------------------------------------------------------

def fetch_rss_titles(url):
    """Crude RSS/Atom parser — extract titles and links without xml.etree (some feeds break it)."""
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Substrate-Byte/1.0"})
        with urllib.request.urlopen(req, timeout=REQUEST_TIMEOUT) as resp:
            data = resp.read().decode("utf-8", errors="replace")
    except Exception as e:
        print(f"  [warn] RSS fetch failed for {url}: {e}", file=sys.stderr)
        return []

    import re
    items = []
    # Match <item> or <entry> blocks
    for block in re.findall(r'<(?:item|entry)[\s>].*?</(?:item|entry)>', data, re.DOTALL):
        title_m = re.search(r'<title[^>]*>(.*?)</title>', block, re.DOTALL)
        link_m = re.search(r'<link[^>]*href=["\']([^"\']+)["\']', block) or \
                 re.search(r'<link[^>]*>(.*?)</link>', block, re.DOTALL)
        if title_m:
            title = re.sub(r'<!\[CDATA\[|\]\]>', '', title_m.group(1)).strip()
            link = link_m.group(1).strip() if link_m else ""
            items.append({"title": title, "url": link, "score": 0, "descendants": 0, "id": ""})
    return items[:10]  # Latest 10 per feed


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
    print("-- Byte, Substrate News Desk")


if __name__ == "__main__":
    main()

"""Shared news functions for Substrate news agents.

Extracted from news_researcher.py to avoid duplication between the daily
digest (news_researcher.py) and the hourly aggregator (news_aggregator.py).

Usage:
    from shared_news import fetch_json, fetch_rss_titles, relevance_score, signal_score
"""

import json
import re
import sys
import urllib.request
import urllib.error

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

HN_TOP_URL = "https://hacker-news.firebaseio.com/v0/topstories.json"
HN_ITEM_URL = "https://hacker-news.firebaseio.com/v0/item/{}.json"

REQUEST_TIMEOUT = 10
SCAN_LIMIT = 60

# RSS/Atom feeds — organized by tier (verified working 2026-03)
RSS_FEEDS = {
    # Tier 1: Major AI labs
    "OpenAI": "https://openai.com/blog/rss.xml",
    "Hugging Face": "https://huggingface.co/blog/feed.xml",
    "Google DeepMind": "https://deepmind.google/blog/rss.xml",
    "Google AI": "https://blog.google/technology/ai/rss/",
    "Meta AI": "https://engineering.fb.com/category/ai-research/feed/",
    "Microsoft Research": "https://www.microsoft.com/en-us/research/feed/",
    # Tier 2: Research
    "arXiv cs.AI": "https://rss.arxiv.org/rss/cs.AI",
    "arXiv cs.CL": "https://rss.arxiv.org/rss/cs.CL",
    "arXiv cs.LG": "https://rss.arxiv.org/rss/cs.LG",
    # Tier 3: Community
    "r/LocalLLaMA": "https://www.reddit.com/r/LocalLLaMA/.rss",
    "r/MachineLearning": "https://www.reddit.com/r/MachineLearning/.rss",
    # Tier 4: Industry press
    "TechCrunch AI": "https://techcrunch.com/category/artificial-intelligence/feed/",
    "The Verge AI": "https://www.theverge.com/rss/ai-artificial-intelligence/index.xml",
    "Ars Technica AI": "https://arstechnica.com/tag/ai/feed/",
    "Wired AI": "https://www.wired.com/feed/tag/ai/latest/rss",
    "MIT Tech Review": "https://www.technologyreview.com/feed/",
    "VentureBeat AI": "https://venturebeat.com/category/ai/feed/",
    "IEEE Spectrum AI": "https://spectrum.ieee.org/feeds/feed.rss",
    "InfoQ AI/ML": "https://feed.infoq.com/ai-ml-data-eng/",
    # Tier 5: Policy
    "EFF Deeplinks": "https://www.eff.org/rss/updates.xml",
    "EU AI Act": "https://artificialintelligenceact.eu/feed/",
    # Note: Anthropic, Perplexity, xAI have no public RSS feeds (verified 2026-03)
}

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


def fetch_rss_titles(url):
    """Crude RSS/Atom parser -- extract titles and links without xml.etree."""
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Substrate-Byte/1.0"})
        with urllib.request.urlopen(req, timeout=REQUEST_TIMEOUT) as resp:
            data = resp.read().decode("utf-8", errors="replace")
    except Exception as e:
        print(f"  [warn] RSS fetch failed for {url}: {e}", file=sys.stderr)
        return []

    items = []
    for block in re.findall(r'<(?:item|entry)[\s>].*?</(?:item|entry)>', data, re.DOTALL):
        title_m = re.search(r'<title[^>]*>(.*?)</title>', block, re.DOTALL)
        link_m = re.search(r'<link[^>]*href=["\']([^"\']+)["\']', block) or \
                 re.search(r'<link[^>]*>(.*?)</link>', block, re.DOTALL)
        if title_m:
            title = re.sub(r'<!\[CDATA\[|\]\]>', '', title_m.group(1)).strip()
            link = link_m.group(1).strip() if link_m else ""
            items.append({"title": title, "url": link, "score": 0, "descendants": 0, "id": ""})
    return items[:10]


# ---------------------------------------------------------------------------
# Scoring
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
    for kw in RELEVANCE_KEYWORDS:
        if kw in text:
            score += 1
    return score


# ---------------------------------------------------------------------------
# Fetch + rank pipeline
# ---------------------------------------------------------------------------

def fetch_all_sources():
    """Fetch stories from HN + all RSS feeds. Returns list of story dicts."""
    stories = []

    # 1. Hacker News top stories
    print("Fetching Hacker News top stories...")
    top_ids = fetch_json(HN_TOP_URL)
    if top_ids:
        for item_id in top_ids[:SCAN_LIMIT]:
            item = fetch_hn_item(item_id)
            if not item:
                continue
            title = item.get("title", "")
            url = item.get("url", "")
            score = relevance_score(title, url)
            if score > 0:
                item["_relevance"] = score
                item["_signal"] = signal_score(title, url)
                item["_source"] = "HN"
                stories.append(item)
    else:
        print("  [warn] Could not reach Hacker News API.", file=sys.stderr)

    # 2. RSS feeds
    print("Scanning RSS feeds...")
    for feed_name, feed_url in RSS_FEEDS.items():
        items = fetch_rss_titles(feed_url)
        relevant_count = 0
        for item in items:
            title = item.get("title", "")
            url = item.get("url", "")
            score = relevance_score(title, url)
            if score > 0:
                item["_relevance"] = score
                item["_signal"] = signal_score(title, url)
                item["_source"] = feed_name
                stories.append(item)
                relevant_count += 1
        print(f"  {feed_name}: {len(items)} items, {relevant_count} relevant")

    return stories


def score_and_rank(stories):
    """Sort stories by relevance (primary) and HN score (secondary)."""
    stories.sort(key=lambda x: (x.get("_relevance", 0), x.get("score", 0)), reverse=True)
    return stories

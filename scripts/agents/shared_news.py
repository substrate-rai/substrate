"""Shared news functions for Substrate news agents.

Extracted from news_researcher.py to avoid duplication between the daily
digest (news_researcher.py) and the hourly aggregator (news_aggregator.py).

Usage:
    from shared_news import fetch_json, fetch_rss_titles, relevance_score, signal_score
"""

import html
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
    # Note: Anthropic has no RSS feed — scraped via fetch_anthropic_news() below
    "OpenAI": "https://openai.com/blog/rss.xml",
    "Google DeepMind": "https://deepmind.google/blog/rss.xml",
    "Google AI": "https://blog.google/technology/ai/rss/",
    # Tier 1: Major AI labs
    "Hugging Face": "https://huggingface.co/blog/feed.xml",
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
    # Note: Perplexity, xAI have no public RSS feeds (verified 2026-03)
}

# Markdown changelog sources — not RSS, parsed separately
CHANGELOG_SOURCES = {
    "Claude Code": "https://code.claude.com/docs/en/changelog.md",
}
# Full docs index: https://code.claude.com/docs/llms.txt

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

# Primary sources get a scoring boost — these are our main coverage targets
# and also our competition. Stories from these sources should rank higher.
PRIMARY_SOURCES = {
    "Anthropic", "Claude Code", "OpenAI", "Google DeepMind", "Google AI",
}
PRIMARY_SOURCE_BOOST = 3  # added to relevance score for primary sources


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
            title = html.unescape(re.sub(r'<!\[CDATA\[|\]\]>', '', title_m.group(1)).strip())
            link = link_m.group(1).strip() if link_m else ""
            items.append({"title": title, "url": link, "score": 0, "descendants": 0, "id": ""})
    return items[:10]


def fetch_anthropic_news(max_entries=10):
    """Scrape Anthropic's news and research pages (no RSS available)."""
    items = []
    for section in ("news", "research"):
        try:
            url = f"https://www.anthropic.com/{section}"
            req = urllib.request.Request(url, headers={"User-Agent": "Substrate-Byte/1.0"})
            with urllib.request.urlopen(req, timeout=REQUEST_TIMEOUT) as resp:
                data = resp.read().decode("utf-8", errors="replace")
        except Exception as e:
            print(f"  [warn] Anthropic {section} fetch failed: {e}", file=sys.stderr)
            continue

        # Extract links and titles from the HTML
        # Pattern: <a href="/news/slug">...<h3>Title</h3>... or similar heading tags
        for link_match in re.finditer(
            r'href="(/{section}/[^"]+)"[^>]*>.*?<(?:h[2-4]|span|p)[^>]*class="[^"]*(?:title|heading|name)[^"]*"[^>]*>(.*?)</(?:h[2-4]|span|p)>'.replace("{section}", section),
            data, re.DOTALL
        ):
            path = link_match.group(1)
            title = html.unescape(re.sub(r'<[^>]+>', '', link_match.group(2)).strip())
            if title and len(title) > 5:
                items.append({
                    "title": title,
                    "url": f"https://www.anthropic.com{path}",
                    "score": 0,
                    "descendants": 0,
                    "id": "",
                })

        # Fallback: simpler pattern — just find all /news/slug or /research/slug links
        if not any(i["url"].startswith(f"https://www.anthropic.com/{section}/") for i in items):
            for link_match in re.finditer(
                r'href="(/' + section + r'/[a-z0-9-]+)"',
                data
            ):
                path = link_match.group(1)
                slug = path.split("/")[-1]
                # Convert slug to title
                title = slug.replace("-", " ").title()
                if title and len(title) > 5:
                    items.append({
                        "title": f"Anthropic: {title}",
                        "url": f"https://www.anthropic.com{path}",
                        "score": 0,
                        "descendants": 0,
                        "id": "",
                    })

    # Deduplicate by URL
    seen_urls = set()
    unique = []
    for item in items:
        if item["url"] not in seen_urls:
            seen_urls.add(item["url"])
            unique.append(item)
    return unique[:max_entries]


def fetch_markdown_changelog(url, max_entries=5):
    """Parse a markdown changelog into story items.

    Supports two formats:
    - <Update label="VERSION" description="DATE"> XML tags (Claude Code docs)
    - ## Version (Date) markdown headers (generic changelogs)
    """
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Substrate-Byte/1.0"})
        with urllib.request.urlopen(req, timeout=REQUEST_TIMEOUT) as resp:
            data = resp.read().decode("utf-8", errors="replace")
    except Exception as e:
        print(f"  [warn] Changelog fetch failed for {url}: {e}", file=sys.stderr)
        return []

    items = []

    # Try <Update label="VERSION" description="DATE"> format first
    update_blocks = re.findall(
        r'<Update\s+label="([^"]+)"\s+description="([^"]+)">(.*?)</Update>',
        data, re.DOTALL
    )
    if update_blocks:
        for version, date, body in update_blocks[:max_entries]:
            bullets = [l.strip('* ').strip() for l in body.strip().split('\n') if l.strip().startswith('*')]
            title = f"Claude Code {version} ({date})"
            if bullets:
                first = bullets[0]
                if len(first) < 80:
                    title += f": {first}"
            items.append({
                "title": title,
                "url": url,
                "score": 0,
                "descendants": 0,
                "id": "",
            })
        return items

    # Fallback: ## header format
    sections = re.split(r'^## ', data, flags=re.MULTILINE)
    for section in sections[1:max_entries + 1]:
        lines = section.strip().split('\n')
        if not lines:
            continue
        header = lines[0].strip()
        bullets = [l.strip('- ').strip() for l in lines[1:] if l.strip().startswith('-')]
        title = f"Claude Code {header}" if "claude" not in header.lower() else header
        if bullets:
            title += f": {bullets[0]}" if len(bullets[0]) < 80 else ""
        items.append({
            "title": title,
            "url": url,
            "score": 0,
            "descendants": 0,
            "id": "",
        })
    return items


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
        is_primary = feed_name in PRIMARY_SOURCES
        for item in items:
            title = item.get("title", "")
            url = item.get("url", "")
            score = relevance_score(title, url)
            # Primary sources are always relevant and get a boost
            if is_primary:
                score = max(score, 2) + PRIMARY_SOURCE_BOOST
            if score > 0:
                item["_relevance"] = score
                item["_signal"] = signal_score(title, url)
                item["_source"] = feed_name
                stories.append(item)
                relevant_count += 1
        print(f"  {feed_name}: {len(items)} items, {relevant_count} relevant{'  [PRIMARY]' if is_primary else ''}")

    # 3. Anthropic (HTML scrape — no RSS available)
    print("Scraping Anthropic news...")
    anthropic_items = fetch_anthropic_news()
    for item in anthropic_items:
        title = item.get("title", "")
        url = item.get("url", "")
        score = relevance_score(title, url)
        score = max(score, 2) + PRIMARY_SOURCE_BOOST
        item["_relevance"] = score
        item["_signal"] = signal_score(title, url)
        item["_source"] = "Anthropic"
        stories.append(item)
    print(f"  Anthropic: {len(anthropic_items)} items  [PRIMARY]")

    # 4. Markdown changelogs (Claude Code, etc.)
    print("Scanning changelog sources...")
    for source_name, changelog_url in CHANGELOG_SOURCES.items():
        items = fetch_markdown_changelog(changelog_url)
        is_primary = source_name in PRIMARY_SOURCES
        for item in items:
            title = item.get("title", "")
            url = item.get("url", "")
            score = relevance_score(title, url)
            # Changelogs are always relevant — minimum score of 2
            score = max(score, 2)
            if is_primary:
                score += PRIMARY_SOURCE_BOOST
            item["_relevance"] = score
            item["_signal"] = signal_score(title, url)
            item["_source"] = source_name
            stories.append(item)
        print(f"  {source_name}: {len(items)} changelog entries{'  [PRIMARY]' if is_primary else ''}")

    return stories


def score_and_rank(stories, output_limit=30):
    """Sort stories by relevance, ensuring primary source diversity.

    Primary sources (Anthropic, Claude Code, OpenAI, Google) are guaranteed
    representation in the output — at least 2 stories per primary source if
    available, placed in the top positions.
    """
    stories.sort(key=lambda x: (x.get("_relevance", 0), x.get("score", 0)), reverse=True)

    # Guarantee primary sources appear: pull them to the front
    primary_stories = []
    other_stories = []
    primary_seen = {}  # source -> count

    for story in stories:
        source = story.get("_source", "")
        if source in PRIMARY_SOURCES:
            count = primary_seen.get(source, 0)
            if count < 3:  # Up to 3 per primary source guaranteed
                primary_stories.append(story)
                primary_seen[source] = count + 1
                continue
        other_stories.append(story)

    # Primary stories first (sorted by relevance), then the rest
    primary_stories.sort(key=lambda x: (x.get("_relevance", 0), x.get("score", 0)), reverse=True)
    return primary_stories + other_stories

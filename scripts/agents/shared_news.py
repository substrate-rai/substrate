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
    "Cohere": "https://cohere-ai.ghost.io/rss/",
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
    # Tier 4b: Additional research + industry sources
    "Last Week in AI": "https://lastweekin.ai/feed",
    "The Gradient": "https://thegradient.pub/rss/",
    "NVIDIA AI": "https://blogs.nvidia.com/blog/category/deep-learning/feed/",
    "arXiv stat.ML": "https://rss.arxiv.org/rss/stat.ML",
    # Tier 5: Policy
    "EFF Deeplinks": "https://www.eff.org/rss/updates.xml",
    "EU AI Act": "https://artificialintelligenceact.eu/feed/",
    # Note: xAI, Mistral, Perplexity have no RSS — scraped via fetch_frontier_news() below
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
    "llama", "qwen", "deepseek", "mistral", "cohere", "perplexity", "grok", "xai",
    "transformer", "diffusion", "neural",
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

# Source tier weights for feed ordering — higher = appears first in feed.
# Anthropic/Claude Code first, then Google, then OpenAI, then everything else.
SOURCE_TIER = {
    "Anthropic": 100,
    "Claude Code": 100,
    "Google DeepMind": 80,
    "Google AI": 80,
    "OpenAI": 60,
    # Frontier labs (scraped, no RSS)
    "xAI": 50,
    "Mistral": 50,
    "Perplexity": 50,
    "Cohere": 45,
    # External research / press sources
    "arXiv cs.AI": 40,
    "arXiv cs.CL": 40,
    "arXiv cs.LG": 40,
    "Hugging Face": 35,
    "Meta AI": 35,
    "Microsoft Research": 35,
    "TechCrunch AI": 30,
    "The Verge AI": 30,
    "Ars Technica AI": 30,
    "Wired AI": 30,
    "MIT Tech Review": 30,
    "VentureBeat AI": 30,
    "IEEE Spectrum AI": 30,
    "InfoQ AI/ML": 30,
    "r/LocalLLaMA": 25,
    "r/MachineLearning": 25,
    "Last Week in AI": 30,
    "The Gradient": 30,
    "NVIDIA AI": 30,
    "arXiv stat.ML": 40,
    "HN": 20,
    "EFF Deeplinks": 15,
    "EU AI Act": 15,
}


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
    """Crude RSS/Atom parser -- extract titles, links, and pubDates without xml.etree."""
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
        # Parse pubDate/updated for recency
        date_m = re.search(r'<(?:pubDate|updated|published|dc:date)[^>]*>(.*?)</(?:pubDate|updated|published|dc:date)>', block, re.DOTALL)
        if title_m:
            title = html.unescape(re.sub(r'<!\[CDATA\[|\]\]>', '', title_m.group(1)).strip())
            link = link_m.group(1).strip() if link_m else ""
            # Cohere Ghost CMS fix: rewrite ghost.io URLs to canonical cohere.com/blog/
            if "cohere-ai.ghost.io" in link:
                slug = link.rstrip("/").split("/")[-1]
                link = f"https://cohere.com/blog/{slug}"
            pub_date = date_m.group(1).strip() if date_m else ""
            items.append({"title": title, "url": link, "score": 0, "descendants": 0, "id": "", "pub_date": pub_date})
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


# Frontier lab blog configs — sites without RSS feeds
_FRONTIER_BLOGS = {
    "xAI": {
        "url": "https://x.ai/news",
        "link_pattern": r'href="(/news/[a-z0-9][a-z0-9-]*)"',
        "title_pattern": r'href="({path})"[^>]*>.*?<(?:h[1-4])[^>]*>([^<]+)<',
        "base_url": "https://x.ai",
    },
    "Mistral": {
        "url": "https://mistral.ai/news",
        "link_pattern": r'href="(/news/[a-z0-9][a-z0-9-]*)"',
        "title_pattern": r'href="({path})"[^>]*>.*?<(?:h[1-4])[^>]*>([^<]+)<',
        "base_url": "https://mistral.ai",
        "sitemap": "https://mistral.ai/sitemap.xml",
        "sitemap_pattern": r'<loc>(https://mistral\.ai/news/[^<]+)</loc>',
    },
    "Perplexity": {
        "url": "https://www.perplexity.ai/hub/blog",
        "link_pattern": r'hub/blog/([a-z0-9][a-z0-9-]+[a-z0-9])',
        "title_pattern": None,  # titles extracted from slug
        "base_url": "https://www.perplexity.ai",
    },
}


def fetch_frontier_news(max_entries=10):
    """Scrape blog pages for frontier AI labs without RSS feeds (xAI, Mistral, Perplexity)."""
    all_items = {}  # source_name -> list of items

    for source, cfg in _FRONTIER_BLOGS.items():
        items = []
        try:
            req = urllib.request.Request(cfg["url"], headers={
                "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0 Safari/537.36",
            })
            with urllib.request.urlopen(req, timeout=REQUEST_TIMEOUT) as resp:
                data = resp.read().decode("utf-8", errors="replace")
        except Exception as e:
            print(f"  [warn] {source} fetch failed: {e}", file=sys.stderr)
            all_items[source] = []
            continue

        # Extract links
        slugs = re.findall(cfg["link_pattern"], data)
        seen = set()
        for slug in slugs:
            if slug in seen:
                continue
            seen.add(slug)

            # Try to extract title from nearby heading
            title = None
            if cfg["title_pattern"]:
                path = slug if slug.startswith("/") else f"/hub/blog/{slug}"
                pattern = cfg["title_pattern"].replace("{path}", re.escape(path))
                m = re.search(pattern, data, re.DOTALL)
                if m:
                    title = html.unescape(m.group(2).strip()) if m.lastindex >= 2 else None

            # Fallback: title from slug
            if not title:
                raw_slug = slug.split("/")[-1]
                title = raw_slug.replace("-", " ").title()

            if slug.startswith("/"):
                url = f"{cfg['base_url']}{slug}"
            else:
                url = f"{cfg['base_url']}/hub/blog/{slug}"

            if title and len(title) > 3:
                items.append({
                    "title": title,
                    "url": url,
                    "score": 0,
                    "descendants": 0,
                    "id": "",
                })

        # Sitemap fallback: if HTML scrape yielded few results and a sitemap is configured
        if len(items) < 3 and cfg.get("sitemap"):
            try:
                req2 = urllib.request.Request(cfg["sitemap"], headers={
                    "User-Agent": "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36",
                })
                with urllib.request.urlopen(req2, timeout=REQUEST_TIMEOUT) as resp2:
                    sitemap_data = resp2.read().decode("utf-8", errors="replace")
                sitemap_urls = re.findall(cfg["sitemap_pattern"], sitemap_data)
                # Take most recent (last in sitemap) that aren't already found
                existing_urls = {i["url"] for i in items}
                for surl in reversed(sitemap_urls):
                    if surl in existing_urls:
                        continue
                    slug = surl.rstrip("/").split("/")[-1]
                    title = slug.replace("-", " ").title()
                    items.append({
                        "title": title,
                        "url": surl,
                        "score": 0,
                        "descendants": 0,
                        "id": "",
                    })
                    if len(items) >= max_entries:
                        break
            except Exception as e:
                print(f"  [warn] {source} sitemap fallback failed: {e}", file=sys.stderr)

        all_items[source] = items[:max_entries]

    return all_items


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

def _normalize_url(url):
    """Normalize URL for dedup: strip query params, trailing slashes, protocol."""
    url = re.sub(r'^https?://', '', url)
    url = url.split('?')[0].split('#')[0]
    return url.rstrip('/')


def fetch_all_sources():
    """Fetch stories from HN + all RSS feeds. Returns list of story dicts."""
    stories = []
    seen_urls = set()  # URL-based dedup across all sources

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
            norm = _normalize_url(url) if url else ""
            if norm and norm in seen_urls:
                continue
            score = relevance_score(title, url)
            if score > 0:
                item["_relevance"] = score
                item["_signal"] = signal_score(title, url)
                item["_source"] = "HN"
                stories.append(item)
                if norm:
                    seen_urls.add(norm)
    else:
        print("  [warn] Could not reach Hacker News API.", file=sys.stderr)

    # 2. RSS feeds
    print("Scanning RSS feeds...")
    # External press/research feeds — always include their top items even if
    # keyword matching is weak, so the feed has novel coverage beyond labs.
    EXTERNAL_PRESS = {
        "TechCrunch AI", "The Verge AI", "Ars Technica AI", "Wired AI",
        "MIT Tech Review", "VentureBeat AI", "IEEE Spectrum AI", "InfoQ AI/ML",
        "arXiv cs.AI", "arXiv cs.CL", "arXiv cs.LG", "arXiv stat.ML",
        "Last Week in AI", "The Gradient", "NVIDIA AI",
    }
    for feed_name, feed_url in RSS_FEEDS.items():
        items = fetch_rss_titles(feed_url)
        relevant_count = 0
        is_primary = feed_name in PRIMARY_SOURCES
        is_external = feed_name in EXTERNAL_PRESS
        for item in items:
            title = item.get("title", "")
            url = item.get("url", "")
            norm = _normalize_url(url) if url else ""
            if norm and norm in seen_urls:
                continue
            score = relevance_score(title, url)
            # Primary sources are always relevant and get a boost
            if is_primary:
                score = max(score, 2) + PRIMARY_SOURCE_BOOST
            # External press: include top items even with low keyword match
            # (they're curated AI feeds, so content is relevant by definition)
            elif is_external and score == 0:
                score = 1  # minimum inclusion score for AI-specific feeds
            if score > 0:
                item["_relevance"] = score
                item["_signal"] = signal_score(title, url)
                item["_source"] = feed_name
                stories.append(item)
                relevant_count += 1
                if norm:
                    seen_urls.add(norm)
        print(f"  {feed_name}: {len(items)} items, {relevant_count} relevant{'  [PRIMARY]' if is_primary else ''}{'  [EXTERNAL]' if is_external else ''}")

    # 3. Anthropic (HTML scrape — no RSS available)
    print("Scraping Anthropic news...")
    anthropic_items = fetch_anthropic_news()
    anthropic_count = 0
    for item in anthropic_items:
        title = item.get("title", "")
        url = item.get("url", "")
        norm = _normalize_url(url) if url else ""
        if norm and norm in seen_urls:
            continue
        score = relevance_score(title, url)
        score = max(score, 2) + PRIMARY_SOURCE_BOOST
        item["_relevance"] = score
        item["_signal"] = signal_score(title, url)
        item["_source"] = "Anthropic"
        stories.append(item)
        anthropic_count += 1
        if norm:
            seen_urls.add(norm)
    print(f"  Anthropic: {anthropic_count} items  [PRIMARY]")

    # 4. Frontier labs (HTML scrape — no RSS available)
    print("Scraping frontier lab blogs...")
    frontier_items = fetch_frontier_news()
    for source_name, items in frontier_items.items():
        count = 0
        for item in items:
            title = item.get("title", "")
            url = item.get("url", "")
            norm = _normalize_url(url) if url else ""
            if norm and norm in seen_urls:
                continue
            score = relevance_score(title, url)
            score = max(score, 2)  # frontier lab content is always relevant
            item["_relevance"] = score
            item["_signal"] = signal_score(title, url)
            item["_source"] = source_name
            stories.append(item)
            count += 1
            if norm:
                seen_urls.add(norm)
        print(f"  {source_name}: {count} items")

    # 5. Markdown changelogs (Claude Code, etc.)
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


def score_and_rank(stories, output_limit=50):
    """Sort stories by source tier, then relevance within each tier.

    Ordering: Anthropic/Claude Code > Google > OpenAI > external sources > HN.
    Within each tier, stories sort by relevance then HN score.
    External news sources (TechCrunch, arXiv, etc.) are included to ensure
    novel coverage beyond the big three labs.
    """
    # Sort by: source tier (desc), then relevance (desc), then HN score (desc)
    def sort_key(story):
        source = story.get("_source", "HN")
        tier = SOURCE_TIER.get(source, 10)
        relevance = story.get("_relevance", 0)
        hn_score = story.get("score", 0)
        return (tier, relevance, hn_score)

    stories.sort(key=sort_key, reverse=True)

    # Ensure diversity: cap any single source at 5 stories in the output
    result = []
    source_counts = {}
    overflow = []
    for story in stories:
        source = story.get("_source", "HN")
        count = source_counts.get(source, 0)
        if count < 5:
            result.append(story)
            source_counts[source] = count + 1
        else:
            overflow.append(story)

    # Append overflow stories at the end (still sorted)
    return (result + overflow)[:output_limit]

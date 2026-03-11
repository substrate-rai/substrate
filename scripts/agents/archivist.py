#!/usr/bin/env python3
"""Ink — Research Librarian for Substrate.

Gathers source material from external docs and internal project history,
producing structured research dossiers for guide authors.

Usage:
    python3 scripts/agents/archivist.py              # research top pending topic
    python3 scripts/agents/archivist.py --dry-run    # print to stdout, don't save
    python3 scripts/agents/archivist.py --topic ID   # research a specific topic

Mode: quick (no Ollama — HTTP fetching + file scanning only)
Dependencies: stdlib only (urllib, json)
"""

import argparse
import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_DIR = os.path.dirname(os.path.dirname(SCRIPT_DIR))
RESEARCH_DIR = os.path.join(REPO_DIR, "memory", "research")
TOPIC_QUEUE = os.path.join(RESEARCH_DIR, "topic-queue.json")
POSTS_DIR = os.path.join(REPO_DIR, "_posts")
SCRIPTS_DIR = os.path.join(REPO_DIR, "scripts")
NIX_DIR = os.path.join(REPO_DIR, "nix")
CLAUDE_MD = os.path.join(REPO_DIR, "CLAUDE.md")

REQUEST_TIMEOUT = 10
FETCH_DELAY = 2  # seconds between HTTP requests
MAX_URLS = 5

# Curated research URLs by topic domain
DOMAIN_URLS = {
    "nixos-ai": [
        "https://wiki.nixos.org/wiki/CUDA",
        "https://wiki.nixos.org/wiki/Ollama",
        "https://wiki.nixos.org/wiki/NVIDIA",
        "https://wiki.nixos.org/wiki/Python",
        "https://wiki.nixos.org/wiki/Flakes",
    ],
    "claude": [
        "https://docs.anthropic.com/en/docs/build-with-claude/overview",
        "https://docs.anthropic.com/en/docs/claude-code",
    ],
    "ollama": [
        "https://github.com/ollama/ollama/raw/main/README.md",
        "https://ollama.com/blog",
    ],
    "self-hosting": [
        "https://github.com/awesome-selfhosted/awesome-selfhosted/raw/master/README.md",
    ],
    "nixos-general": [
        "https://wiki.nixos.org/wiki/Systemd",
        "https://wiki.nixos.org/wiki/Configuration_Collection",
    ],
}


# ---------------------------------------------------------------------------
# Topic queue management
# ---------------------------------------------------------------------------

def load_queue():
    """Load the topic queue from JSON."""
    if not os.path.isfile(TOPIC_QUEUE):
        return []
    try:
        with open(TOPIC_QUEUE) as f:
            return json.load(f)
    except (json.JSONDecodeError, IOError) as e:
        print(f"[ink] queue load failed: {e}", file=sys.stderr)
        return []


def save_queue(topics):
    """Save the topic queue to JSON."""
    os.makedirs(RESEARCH_DIR, exist_ok=True)
    with open(TOPIC_QUEUE, "w") as f:
        json.dump(topics, f, indent=2)
        f.write("\n")


def find_pending_topic(topics, topic_id=None):
    """Find the highest-priority pending topic."""
    if topic_id:
        for t in topics:
            if t["id"] == topic_id:
                return t
        return None

    pending = [t for t in topics if t.get("status") == "pending"]
    if not pending:
        return None
    pending.sort(key=lambda t: t.get("priority", 999))
    return pending[0]


# ---------------------------------------------------------------------------
# HTTP fetching
# ---------------------------------------------------------------------------

def fetch_url(url):
    """Fetch a URL and return (status, content) tuple."""
    try:
        req = urllib.request.Request(url, headers={
            "User-Agent": "Substrate-Ink/1.0",
            "Accept": "text/html, text/plain, text/markdown, */*",
        })
        with urllib.request.urlopen(req, timeout=REQUEST_TIMEOUT) as resp:
            content = resp.read().decode("utf-8", errors="replace")
            return "fetched", content
    except urllib.error.HTTPError as e:
        return f"HTTP {e.code}", ""
    except urllib.error.URLError as e:
        return f"URL error: {e.reason}", ""
    except OSError as e:
        return f"error: {e}", ""


def extract_relevant_sections(content, topic_title, max_chars=3000):
    """Extract sections relevant to a topic from fetched content.

    Looks for headings and paragraphs containing topic keywords,
    then returns the most relevant chunks.
    """
    if not content:
        return ""

    # Clean HTML tags (crude but sufficient for wiki pages)
    text = re.sub(r'<script[^>]*>.*?</script>', '', content, flags=re.DOTALL)
    text = re.sub(r'<style[^>]*>.*?</style>', '', text, flags=re.DOTALL)
    text = re.sub(r'<[^>]+>', ' ', text)
    text = re.sub(r'&[a-z]+;', ' ', text)
    text = re.sub(r'\s+', ' ', text).strip()

    # If it's markdown (e.g. GitHub raw), keep it as-is but truncate
    if content.lstrip().startswith('#') or content.lstrip().startswith('---'):
        text = content

    # Extract keywords from topic title
    stop_words = {'how', 'to', 'the', 'a', 'an', 'on', 'in', 'for', 'and',
                  'or', 'with', 'what', 'is', 'are', 'was', 'be', 'your'}
    keywords = [w.lower() for w in re.findall(r'\w+', topic_title)
                if w.lower() not in stop_words and len(w) > 2]

    # Split into paragraphs/sections
    chunks = re.split(r'\n\s*\n|\n(?=#)', text)
    scored = []
    for chunk in chunks:
        chunk = chunk.strip()
        if not chunk or len(chunk) < 20:
            continue
        score = sum(1 for kw in keywords if kw in chunk.lower())
        if score > 0:
            scored.append((score, chunk))

    # Sort by relevance score, take top chunks
    scored.sort(key=lambda x: x[0], reverse=True)
    result = []
    total = 0
    for score, chunk in scored:
        if total + len(chunk) > max_chars:
            remaining = max_chars - total
            if remaining > 100:
                result.append(chunk[:remaining] + "...")
            break
        result.append(chunk)
        total += len(chunk)

    if not result and text:
        # No keyword matches — return first chunk as fallback
        return text[:max_chars] + ("..." if len(text) > max_chars else "")

    return "\n\n".join(result)


# ---------------------------------------------------------------------------
# Internal source scanning
# ---------------------------------------------------------------------------

def scan_git_log(keywords, max_entries=20):
    """Search git log for commits related to keywords."""
    try:
        result = subprocess.run(
            ["git", "log", "--oneline", "-200", "--no-decorate"],
            capture_output=True, text=True, timeout=10, cwd=REPO_DIR,
        )
        if result.returncode != 0:
            return ""

        relevant = []
        for line in result.stdout.strip().splitlines():
            text = line.lower()
            if any(kw in text for kw in keywords):
                relevant.append(line)
                if len(relevant) >= max_entries:
                    break

        return "\n".join(relevant) if relevant else "(no relevant commits found)"
    except (subprocess.TimeoutExpired, OSError):
        return "(git log unavailable)"


def scan_existing_posts(keywords, max_posts=5):
    """Find existing blog posts related to the topic."""
    if not os.path.isdir(POSTS_DIR):
        return ""

    results = []
    for fname in sorted(os.listdir(POSTS_DIR), reverse=True):
        if not fname.endswith(".md"):
            continue
        path = os.path.join(POSTS_DIR, fname)
        try:
            with open(path) as f:
                content = f.read(2000)  # front matter + intro
        except IOError:
            continue

        text = content.lower()
        if any(kw in text for kw in keywords):
            # Extract title from front matter
            title_match = re.search(r'title:\s*"?([^"\n]+)"?', content)
            title = title_match.group(1) if title_match else fname
            results.append(f"- `{fname}`: {title}")
            if len(results) >= max_posts:
                break

    return "\n".join(results) if results else "(no related posts found)"


def scan_scripts(keywords, max_files=5):
    """Find scripts related to the topic."""
    results = []
    for root, _dirs, files in os.walk(SCRIPTS_DIR):
        for fname in sorted(files):
            if not fname.endswith(".py"):
                continue
            path = os.path.join(root, fname)
            try:
                with open(path) as f:
                    header = f.read(500)  # docstring
            except IOError:
                continue

            text = header.lower()
            if any(kw in text for kw in keywords):
                rel = os.path.relpath(path, REPO_DIR)
                results.append(f"- `{rel}`")
                if len(results) >= max_files:
                    break
        if len(results) >= max_files:
            break

    return "\n".join(results) if results else "(no related scripts found)"


def scan_nix_config(keywords):
    """Extract relevant snippets from NixOS configuration."""
    config_file = os.path.join(NIX_DIR, "configuration.nix")
    if not os.path.isfile(config_file):
        return "(nix config not found)"

    try:
        with open(config_file) as f:
            content = f.read()
    except IOError:
        return "(could not read nix config)"

    # Find blocks containing keywords
    lines = content.splitlines()
    relevant = []
    context = 3  # lines before/after match
    matched_lines = set()

    for i, line in enumerate(lines):
        if any(kw in line.lower() for kw in keywords):
            for j in range(max(0, i - context), min(len(lines), i + context + 1)):
                matched_lines.add(j)

    if matched_lines:
        for i in sorted(matched_lines):
            relevant.append(lines[i])
        snippet = "\n".join(relevant)
        if len(snippet) > 1500:
            snippet = snippet[:1500] + "\n..."
        return f"```nix\n{snippet}\n```"

    return "(no relevant nix config found)"


# ---------------------------------------------------------------------------
# Dossier generation
# ---------------------------------------------------------------------------

def build_dossier(topic, url_results, internal):
    """Build the structured research dossier."""
    now = datetime.now(timezone.utc)
    sources_checked = len(url_results)
    sources_fetched = sum(1 for status, _ in url_results.values() if status == "fetched")

    lines = [
        f"# Research: {topic['title']}",
        f"Topic ID: {topic['id']}",
        f"Researched: {now.strftime('%Y-%m-%d %H:%M UTC')}",
        f"Sources checked: {sources_checked} ({sources_fetched} fetched)",
        "",
    ]

    # External findings
    lines.append("## External Findings")
    lines.append("")

    if not url_results:
        lines.append("No external URLs configured for this topic.")
        lines.append("")
    else:
        for url, (status, content) in url_results.items():
            lines.append(f"### {url}")
            lines.append(f"**Status:** {status}")
            lines.append("")
            if status == "fetched" and content:
                extracted = extract_relevant_sections(content, topic["title"])
                if extracted:
                    lines.append(extracted)
                else:
                    lines.append("(content fetched but no relevant sections found)")
            elif status != "fetched":
                lines.append(f"(could not fetch: {status})")
            lines.append("")

    # Internal evidence
    lines.append("## Internal Evidence (What Substrate Has Done)")
    lines.append("")

    lines.append("### Related Git Commits")
    lines.append(internal.get("git_log", "(unavailable)"))
    lines.append("")

    lines.append("### Existing Blog Posts")
    lines.append(internal.get("posts", "(none found)"))
    lines.append("")

    lines.append("### Related Scripts")
    lines.append(internal.get("scripts", "(none found)"))
    lines.append("")

    lines.append("### NixOS Configuration")
    lines.append(internal.get("nix_config", "(not scanned)"))
    lines.append("")

    # Guide outline suggestion
    lines.append("## Guide Outline Suggestion")
    lines.append("")
    lines.append(_suggest_outline(topic, url_results, internal))
    lines.append("")

    lines.append("---")
    lines.append("-- Ink, Substrate Research Library")
    lines.append("")

    return "\n".join(lines)


def _suggest_outline(topic, url_results, internal):
    """Generate a bullet-point outline based on findings."""
    title = topic["title"]
    tags = topic.get("tags", [])

    outline = []
    outline.append(f"Based on research for \"{title}\":")
    outline.append("")

    # Common guide structure
    outline.append("- **Prerequisites** — hardware, software, NixOS version")

    if any(t in tags for t in ["nixos", "cuda", "nvidia"]):
        outline.append("- **Error / Problem Statement** — lead with what breaks")
        outline.append("- **The Fix** — exact config, copy-pasteable")
        outline.append("- **Complete Configuration** — minimal working example")
        outline.append("- **Verification** — commands to confirm it works")
    elif any(t in tags for t in ["ai-agents", "autonomous"]):
        outline.append("- **Architecture Overview** — system diagram, component list")
        outline.append("- **Implementation** — step-by-step build")
        outline.append("- **Real Numbers** — performance, cost, VRAM usage")
    elif any(t in tags for t in ["cost-analysis", "survey"]):
        outline.append("- **Methodology** — how the data was collected")
        outline.append("- **Results** — tables, comparisons, benchmarks")
        outline.append("- **Analysis** — what the numbers mean")
    else:
        outline.append("- **Problem Statement** — what and why")
        outline.append("- **Solution** — step-by-step implementation")
        outline.append("- **Configuration** — complete working example")

    outline.append("- **Substrate Note** — what we run in production")
    outline.append("- **Troubleshooting** — error → fix format")
    outline.append("- **What's Next** — links to related guides")

    # Add topic-specific sections based on what we found
    if internal.get("nix_config") and "not found" not in internal["nix_config"]:
        outline.append("- **NixOS Config Snippets** — from our production flake")
    if internal.get("posts") and "none found" not in internal["posts"]:
        outline.append("- **Cross-references** — related Substrate posts")

    return "\n".join(outline)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Ink: Research Librarian")
    parser.add_argument("--dry-run", action="store_true",
                        help="Print dossier to stdout, don't save")
    parser.add_argument("--topic", default=None,
                        help="Research a specific topic ID")
    args = parser.parse_args()

    # Load queue
    topics = load_queue()
    if not topics:
        print("No topics in queue.")
        return

    # Find topic to research
    topic = find_pending_topic(topics, args.topic)
    if not topic:
        if args.topic:
            print(f"Topic '{args.topic}' not found in queue.")
        else:
            print("No pending topics. All researched or drafted.")
        return

    print(f"Ink here. Researching: {topic['title']}")
    print(f"Topic ID: {topic['id']} | Priority: {topic.get('priority', '?')}")
    print()

    # 1. Fetch external URLs
    urls = topic.get("urls", [])
    domain = topic.get("domain", "")
    domain_urls = DOMAIN_URLS.get(domain, [])

    # Combine topic-specific and domain URLs, deduplicate
    all_urls = list(dict.fromkeys(urls + domain_urls))[:MAX_URLS]

    url_results = {}
    for i, url in enumerate(all_urls):
        if i > 0:
            time.sleep(FETCH_DELAY)
        print(f"  Fetching [{i+1}/{len(all_urls)}]: {url}")
        status, content = fetch_url(url)
        url_results[url] = (status, content)
        print(f"    → {status} ({len(content)} chars)")

    print()

    # 2. Scan internal sources
    # Extract keywords from title and tags
    stop_words = {'how', 'to', 'the', 'a', 'an', 'on', 'in', 'for', 'and',
                  'or', 'with', 'what', 'is', 'are', 'complete', 'guide',
                  'single', 'run', 'build', 'your'}
    title_words = [w.lower() for w in re.findall(r'\w+', topic["title"])
                   if w.lower() not in stop_words and len(w) > 2]
    tag_words = [t.lower().replace("-", " ") for t in topic.get("tags", [])]
    keywords = list(dict.fromkeys(title_words + tag_words))

    print(f"  Scanning internal sources (keywords: {', '.join(keywords[:8])})")

    internal = {
        "git_log": scan_git_log(keywords),
        "posts": scan_existing_posts(keywords),
        "scripts": scan_scripts(keywords),
        "nix_config": scan_nix_config(keywords),
    }

    print(f"    Git log: {len(internal['git_log'])} chars")
    print(f"    Posts: {internal['posts'].count(chr(10)) + 1 if internal['posts'] else 0} matches")
    print(f"    Scripts: {internal['scripts'].count(chr(10)) + 1 if internal['scripts'] else 0} matches")
    print()

    # 3. Build dossier
    dossier = build_dossier(topic, url_results, internal)

    if args.dry_run:
        print("=== RESEARCH DOSSIER ===")
        print()
        print(dossier)
        return

    # Save dossier
    os.makedirs(RESEARCH_DIR, exist_ok=True)
    dossier_path = os.path.join(RESEARCH_DIR, f"{topic['id']}.md")
    with open(dossier_path, "w") as f:
        f.write(dossier)
    print(f"  Dossier saved: {dossier_path}")

    # Update topic status
    for t in topics:
        if t["id"] == topic["id"]:
            t["status"] = "researched"
            t["researched_at"] = datetime.now(timezone.utc).isoformat()
            break
    save_queue(topics)
    print(f"  Queue updated: {topic['id']} → researched")

    print()
    print(f"Research complete for: {topic['title']}")
    print(f"Sources: {len(url_results)} checked, "
          f"{sum(1 for s, _ in url_results.values() if s == 'fetched')} fetched")
    print()
    print("-- Ink, Substrate Research Library")


if __name__ == "__main__":
    main()

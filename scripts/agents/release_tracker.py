#!/usr/bin/env python3
"""Echo — Anthropic release tracker for Substrate.

Monitors Anthropic's public documentation for model updates and changelog
entries. Compares against a local cache to detect new information. When
changes are found, writes a structured release report to memory/releases/.

Usage:
    python3 scripts/agents/release_tracker.py              # check for updates
    python3 scripts/agents/release_tracker.py --dry-run    # print report, don't save
    python3 scripts/agents/release_tracker.py --force      # write report even if no changes

Designed to run standalone with stdlib only (no pip dependencies).
"""

import argparse
import hashlib
import json
import os
import re
import sys
from datetime import datetime, timezone
from urllib.request import urlopen, Request
from urllib.error import URLError, HTTPError

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_DIR = os.path.dirname(os.path.dirname(SCRIPT_DIR))
sys.path.insert(0, SCRIPT_DIR)
from shared import queue_post
RELEASES_DIR = os.path.join(REPO_DIR, "memory", "releases")
CACHE_FILE = os.path.join(RELEASES_DIR, "last_check.json")

SOURCES = [
    {
        "name": "Anthropic Models Documentation",
        "url": "https://docs.anthropic.com/en/docs/about-claude/models",
        "description": "Official model listing — names, context windows, pricing",
    },
    {
        "name": "Anthropic API Changelog",
        "url": "https://docs.anthropic.com/en/docs/about-claude/models",
        "description": "API changes and deprecations",
    },
]

# Patterns to extract from model documentation pages
MODEL_PATTERNS = [
    r"claude[\w\-\.]+\d",          # e.g. claude-3-opus, claude-3.5-sonnet
    r"claude[\s\-]+\d[\w\s\-\.]*",  # e.g. Claude 3 Opus, Claude 3.5 Sonnet
]

HEADERS = {
    "User-Agent": "Substrate/1.0 (sovereign-ai-workstation; release-tracker)",
    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
}


def fetch_page(url, timeout=30):
    """Fetch a URL and return its text content."""
    try:
        req = Request(url, headers=HEADERS)
        with urlopen(req, timeout=timeout) as resp:
            raw = resp.read()
            # Try UTF-8 first, fall back to latin-1
            try:
                return raw.decode("utf-8")
            except UnicodeDecodeError:
                return raw.decode("latin-1")
    except HTTPError as e:
        print(f"[echo] HTTP {e.code} fetching {url}", file=sys.stderr)
        return None
    except URLError as e:
        print(f"[echo] network error fetching {url}: {e.reason}", file=sys.stderr)
        return None
    except Exception as e:
        print(f"[echo] unexpected error fetching {url}: {e}", file=sys.stderr)
        return None


def strip_html(html):
    """Rough HTML-to-text conversion using only stdlib."""
    # Remove script and style blocks
    text = re.sub(r"<(script|style)[^>]*>.*?</\1>", "", html, flags=re.DOTALL | re.IGNORECASE)
    # Replace block-level tags with newlines
    text = re.sub(r"<(br|p|div|h[1-6]|li|tr)[^>]*>", "\n", text, flags=re.IGNORECASE)
    # Strip remaining tags
    text = re.sub(r"<[^>]+>", " ", text)
    # Decode common HTML entities
    for entity, char in [("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
                         ("&quot;", '"'), ("&#39;", "'"), ("&nbsp;", " ")]:
        text = text.replace(entity, char)
    # Collapse whitespace
    text = re.sub(r"[ \t]+", " ", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def content_hash(text):
    """SHA-256 hash of normalized text content."""
    normalized = re.sub(r"\s+", " ", text.lower().strip())
    return hashlib.sha256(normalized.encode("utf-8")).hexdigest()


def extract_model_names(text):
    """Pull out Claude model identifiers from page text."""
    models = set()
    for pattern in MODEL_PATTERNS:
        for match in re.finditer(pattern, text, re.IGNORECASE):
            name = match.group(0).strip().rstrip(".")
            if len(name) > 6:  # filter out noise
                models.add(name)
    return sorted(models)


def extract_key_sections(text):
    """Extract lines that look like they contain model info, pricing, or dates."""
    keywords = ["model", "claude", "context", "token", "price", "cost",
                "input", "output", "window", "release", "deprecat", "new",
                "launch", "available", "upgrade"]
    lines = []
    for line in text.split("\n"):
        line_lower = line.strip().lower()
        if any(kw in line_lower for kw in keywords) and len(line.strip()) > 10:
            lines.append(line.strip())
    return lines


def load_cache():
    """Load the last-check cache from disk."""
    if not os.path.exists(CACHE_FILE):
        return {"checks": {}, "last_run": None}
    try:
        with open(CACHE_FILE, "r") as f:
            return json.load(f)
    except (json.JSONDecodeError, IOError):
        return {"checks": {}, "last_run": None}


def save_cache(cache):
    """Write the cache to disk."""
    os.makedirs(RELEASES_DIR, exist_ok=True)
    with open(CACHE_FILE, "w") as f:
        json.dump(cache, f, indent=2)


def diff_sources(cache, current_results):
    """Compare current fetch results against cached hashes. Return changes."""
    changes = []
    for source_name, result in current_results.items():
        old_hash = cache.get("checks", {}).get(source_name, {}).get("hash", "")
        new_hash = result["hash"]
        if old_hash != new_hash:
            old_models = set(cache.get("checks", {}).get(source_name, {}).get("models", []))
            new_models = set(result["models"])
            changes.append({
                "source": source_name,
                "url": result["url"],
                "is_new_source": old_hash == "",
                "new_models": sorted(new_models - old_models),
                "removed_models": sorted(old_models - new_models),
                "all_models": result["models"],
                "key_lines": result["key_lines"][:30],  # cap for readability
                "hash_before": old_hash[:12] if old_hash else "(none)",
                "hash_after": new_hash[:12],
            })
    return changes


def format_report(changes, now_str):
    """Format a release report in markdown."""
    lines = [
        f"# Echo Release Report: {now_str}",
        "",
        f"**Checked:** {now_str}",
        f"**Sources scanned:** {len(changes) if changes else 0} with changes detected",
        "",
    ]

    if not changes:
        lines.append("No changes detected since last check.")
        lines.append("")
        lines.append("## Implications for Substrate: none at this time.")
        return "\n".join(lines)

    for i, change in enumerate(changes, 1):
        lines.append(f"## {i}. {change['source']}")
        lines.append(f"- **URL:** {change['url']}")
        lines.append(f"- **Hash:** {change['hash_before']} -> {change['hash_after']}")

        if change["is_new_source"]:
            lines.append("- **Status:** First scan of this source")
        else:
            lines.append("- **Status:** Content changed since last check")

        if change["new_models"]:
            lines.append("")
            lines.append("### New model references detected")
            for model in change["new_models"]:
                lines.append(f"  - {model}")

        if change["removed_models"]:
            lines.append("")
            lines.append("### Model references no longer present")
            for model in change["removed_models"]:
                lines.append(f"  - {model}")

        lines.append("")
        lines.append("### All current model references")
        if change["all_models"]:
            for model in change["all_models"]:
                lines.append(f"  - {model}")
        else:
            lines.append("  (none extracted)")

        lines.append("")
        lines.append("### Key content lines")
        if change["key_lines"]:
            for j, line in enumerate(change["key_lines"], 1):
                lines.append(f"  {j}. {line[:200]}")
        else:
            lines.append("  (no key lines extracted)")

        lines.append("")

    # Always end with implications
    lines.append("---")
    lines.append("")
    lines.append("## Implications for Substrate:")
    lines.append("")
    if any(c["new_models"] for c in changes):
        lines.append("- New model references detected. Review for capability upgrades,")
        lines.append("  pricing changes, or deprecations that affect Substrate's cloud brain.")
        lines.append("- Check if route.py model selection needs updating.")
        lines.append("- Evaluate cost impact on the ledger.")
    else:
        lines.append("- Page content changed but no new model names detected.")
        lines.append("- May indicate documentation updates, pricing adjustments, or")
        lines.append("  capability changes worth reviewing manually.")
    lines.append("")

    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="Echo: Anthropic release tracker")
    parser.add_argument("--dry-run", action="store_true",
                        help="Print report to stdout without saving")
    parser.add_argument("--force", action="store_true",
                        help="Write report even if no changes detected")
    args = parser.parse_args()

    now = datetime.now(timezone.utc)
    now_str = now.strftime("%Y-%m-%d %H:%M UTC")
    date_str = now.strftime("%Y-%m-%d")

    print(f"[echo] starting release check at {now_str}", file=sys.stderr)

    # Fetch all sources
    current_results = {}
    for source in SOURCES:
        print(f"[echo] fetching {source['name']}...", file=sys.stderr)
        html = fetch_page(source["url"])
        if html is None:
            print(f"[echo] skipping {source['name']} (fetch failed)", file=sys.stderr)
            continue

        text = strip_html(html)
        models = extract_model_names(text)
        key_lines = extract_key_sections(text)
        h = content_hash(text)

        print(f"[echo]   hash: {h[:12]}  models: {len(models)}  key lines: {len(key_lines)}",
              file=sys.stderr)

        current_results[source["name"]] = {
            "url": source["url"],
            "hash": h,
            "models": models,
            "key_lines": key_lines,
        }

    if not current_results:
        print("[echo] all fetches failed — aborting", file=sys.stderr)
        sys.exit(1)

    # Compare against cache
    cache = load_cache()
    changes = diff_sources(cache, current_results)

    if changes:
        print(f"[echo] {len(changes)} source(s) have changes", file=sys.stderr)
    else:
        print("[echo] no changes detected", file=sys.stderr)

    # Generate report
    report = format_report(changes, now_str)

    if args.dry_run:
        print(report)
    elif changes or args.force:
        os.makedirs(RELEASES_DIR, exist_ok=True)
        report_path = os.path.join(RELEASES_DIR, f"{date_str}.md")
        with open(report_path, "w") as f:
            f.write(report + "\n")
        print(f"[echo] report saved: {report_path}", file=sys.stderr)
    else:
        print("[echo] no changes — no report written (use --force to override)", file=sys.stderr)

    # Update cache
    for source_name, result in current_results.items():
        if "checks" not in cache:
            cache["checks"] = {}
        cache["checks"][source_name] = {
            "hash": result["hash"],
            "models": result["models"],
            "last_checked": now_str,
        }
    cache["last_run"] = now_str
    save_cache(cache)
    print(f"[echo] cache updated: {CACHE_FILE}", file=sys.stderr)

    # If changes detected, queue a breaking news post
    if changes:
        changed_sources = [c["source"] for c in changes]
        new_models = []
        for c in changes:
            new_models.extend(c.get("new_models", []))
        post = f"Anthropic docs just changed. "
        if new_models:
            post += f"New models spotted: {', '.join(new_models[:3])}. "
        post += (
            f"Echo tracks this automatically from a laptop on a shelf. "
            f"substrate.lol"
        )
        queue_post(post, source="echo")


if __name__ == "__main__":
    main()

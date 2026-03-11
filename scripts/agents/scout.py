#!/usr/bin/env python3
"""
Scout — AI Ecosystem Scout for Substrate

Monitors AI agent directories and ecosystem developments.
Checks if substrate.lol is listed, scans HN for agent keywords,
validates the A2A agent card, and tracks AI crawler activity.

Usage: python3 scripts/agents/scout.py

Dependencies: stdlib only (urllib, json)
"""

import json
import os
import sys
import urllib.request
import urllib.error
from datetime import datetime, timezone

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from shared import queue_post

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SCOUT_DIR = os.path.join(REPO_ROOT, "memory", "scout")

REQUEST_TIMEOUT = 10

# AI agent directories to monitor
DIRECTORIES = [
    {"name": "Google A2A",   "url": "https://github.com/google/A2A"},
    {"name": "Smithery MCP", "url": "https://smithery.ai/"},
    {"name": "mcp.so",       "url": "https://mcp.so/"},
    {"name": "PulseMCP",     "url": "https://pulsemcp.com/"},
    {"name": "OpenTools",    "url": "https://opentools.com/"},
]

# HN keywords for agent ecosystem stories
AGENT_KEYWORDS = [
    "a2a protocol", "agent card", "agent.json", "agent-to-agent",
    "mcp server", "model context protocol", "ai agent payment",
    "agent wallet", "x402", "autonomous agent", "multi-agent",
    "agent discovery", "llms.txt", "ai commerce",
]

HN_TOP_URL = "https://hacker-news.firebaseio.com/v0/topstories.json"
HN_ITEM_URL = "https://hacker-news.firebaseio.com/v0/item/{}.json"
SCAN_LIMIT = 40


# ---------------------------------------------------------------------------
# Functions
# ---------------------------------------------------------------------------

def _fetch_json(url):
    """Fetch JSON from a URL, return None on failure."""
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Substrate-Scout/1.0"})
        with urllib.request.urlopen(req, timeout=REQUEST_TIMEOUT) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except Exception:
        return None


def _fetch_text(url):
    """Fetch text content from a URL, return None on failure."""
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Substrate-Scout/1.0"})
        with urllib.request.urlopen(req, timeout=REQUEST_TIMEOUT) as resp:
            return resp.read().decode("utf-8", errors="replace")
    except Exception:
        return None


def check_agent_directories():
    """Check known AI directories for reachability and substrate mentions."""
    results = []
    for d in DIRECTORIES:
        text = _fetch_text(d["url"])
        if text is None:
            results.append({"name": d["name"], "status": "unreachable", "mentions_substrate": False})
        else:
            mentions = "substrate.lol" in text.lower() or "substrate-rai" in text.lower()
            results.append({
                "name": d["name"],
                "status": "reachable",
                "size": len(text),
                "mentions_substrate": mentions,
            })
    return results


def scan_hn_for_agents():
    """Scan HN top stories for agent ecosystem keywords."""
    story_ids = _fetch_json(HN_TOP_URL)
    if not story_ids:
        return []

    hits = []
    for sid in story_ids[:SCAN_LIMIT]:
        item = _fetch_json(HN_ITEM_URL.format(sid))
        if not item:
            continue
        title = (item.get("title") or "").lower()
        url = item.get("url") or ""
        score = item.get("score", 0)

        for kw in AGENT_KEYWORDS:
            if kw in title:
                hits.append({
                    "title": item.get("title", ""),
                    "url": url,
                    "score": score,
                    "keyword": kw,
                    "hn_id": sid,
                })
                break

    return sorted(hits, key=lambda x: x["score"], reverse=True)


def check_agent_json():
    """Verify .well-known/agent.json exists in the repo and is valid."""
    path = os.path.join(REPO_ROOT, ".well-known", "agent.json")
    if not os.path.isfile(path):
        return {"exists": False, "valid": False, "error": "file not found"}

    try:
        with open(path) as f:
            data = json.load(f)
        # Check required A2A fields
        required = ["name", "description", "url", "version", "skills"]
        missing = [k for k in required if k not in data]
        return {
            "exists": True,
            "valid": len(missing) == 0,
            "missing_fields": missing,
            "skills_count": len(data.get("skills", [])),
        }
    except json.JSONDecodeError as e:
        return {"exists": True, "valid": False, "error": str(e)}


def check_ai_crawlers():
    """Check recent metrics for AI crawler user-agent mentions."""
    metrics_dir = os.path.join(REPO_ROOT, "memory", "metrics")
    if not os.path.isdir(metrics_dir):
        return {"checked": False, "reason": "no metrics directory"}

    # Find latest metrics file
    files = sorted([f for f in os.listdir(metrics_dir) if f.endswith(".md")], reverse=True)
    if not files:
        return {"checked": False, "reason": "no metrics files"}

    crawler_names = ["ChatGPT-User", "OAI-SearchBot", "Claude-User", "PerplexityBot",
                     "Googlebot", "GPTBot", "ClaudeBot", "anthropic-ai"]
    found = []
    filepath = os.path.join(metrics_dir, files[0])
    try:
        with open(filepath) as f:
            content = f.read()
        for name in crawler_names:
            if name.lower() in content.lower():
                found.append(name)
    except (IOError, OSError):
        pass

    return {"checked": True, "file": files[0], "crawlers_found": found}


def build_report(directories, hn_hits, agent_json, crawlers):
    """Build the daily scout report."""
    now = datetime.now(timezone.utc)
    lines = [
        f"# Scout Report — {now.strftime('%Y-%m-%d')}",
        "",
        f"Generated: {now.strftime('%Y-%m-%d %H:%M UTC')}",
        "",
    ]

    # Agent directories
    lines.append("## AI Directory Status")
    lines.append("")
    for d in directories:
        status = d["status"]
        mention = " — **LISTS SUBSTRATE**" if d.get("mentions_substrate") else ""
        lines.append(f"- **{d['name']}**: {status}{mention}")
    lines.append("")

    listed_count = sum(1 for d in directories if d.get("mentions_substrate"))
    lines.append(f"Listed in {listed_count}/{len(directories)} directories.")
    lines.append("")

    # HN agent ecosystem
    lines.append("## HN Agent Ecosystem Stories")
    lines.append("")
    if hn_hits:
        for h in hn_hits[:10]:
            lines.append(f"- [{h['title']}]({h['url']}) (score: {h['score']}, keyword: {h['keyword']})")
    else:
        lines.append("No agent ecosystem stories in HN top 40 today.")
    lines.append("")

    # Agent card status
    lines.append("## A2A Agent Card (.well-known/agent.json)")
    lines.append("")
    if agent_json.get("valid"):
        lines.append(f"Valid. {agent_json.get('skills_count', 0)} skills defined.")
    elif agent_json.get("exists"):
        lines.append(f"Exists but invalid: {agent_json.get('error') or agent_json.get('missing_fields')}")
    else:
        lines.append("NOT FOUND — needs to be created.")
    lines.append("")

    # AI crawlers
    lines.append("## AI Crawler Activity")
    lines.append("")
    if crawlers.get("checked"):
        if crawlers["crawlers_found"]:
            for c in crawlers["crawlers_found"]:
                lines.append(f"- {c}")
        else:
            lines.append("No AI crawlers detected in latest metrics.")
    else:
        lines.append(f"Could not check: {crawlers.get('reason', 'unknown')}")
    lines.append("")

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    now = datetime.now()

    # Run all checks
    directories = check_agent_directories()
    hn_hits = scan_hn_for_agents()
    agent_json = check_agent_json()
    crawlers = check_ai_crawlers()

    # Build report
    report = build_report(directories, hn_hits, agent_json, crawlers)

    # Write report
    os.makedirs(SCOUT_DIR, exist_ok=True)
    filepath = os.path.join(SCOUT_DIR, f"{now.strftime('%Y-%m-%d')}.md")
    with open(filepath, "w") as f:
        f.write(report)

    # Summary for orchestrator
    listed = sum(1 for d in directories if d.get("mentions_substrate"))
    agent_ok = "valid" if agent_json.get("valid") else "MISSING/INVALID"
    print(f"[W>] Scout: {listed}/{len(directories)} directories list us | "
          f"agent.json: {agent_ok} | "
          f"{len(hn_hits)} HN agent stories")


if __name__ == "__main__":
    main()

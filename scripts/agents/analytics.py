#!/usr/bin/env python3
"""Pulse — Analytics Agent for Substrate.

Measures what matters: traffic, engagement, content performance.
Runs ENTIRELY LOCAL via Ollama (Qwen3 8B). No cloud API calls.

Usage:
    python3 scripts/agents/analytics.py status      # current measurables
    python3 scripts/agents/analytics.py audit       # measurement gap analysis
    python3 scripts/agents/analytics.py recommend   # analytics setup advice
    python3 scripts/agents/analytics.py content     # rank content by likely performance
    python3 scripts/agents/analytics.py report      # full analytics report with AI commentary
"""

import argparse
import glob
import json
import os
import re
import subprocess
import sys
from datetime import datetime

import requests

from context import load_context

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_DIR = os.path.dirname(os.path.dirname(SCRIPT_DIR))
POSTS_DIR = os.path.join(REPO_DIR, "_posts")
GAMES_DIR = os.path.join(REPO_DIR, "games")
STATS_LOG = os.path.join(REPO_DIR, "memory", "stats.log")
SITE_DIR = os.path.join(REPO_DIR, "site")
LAYOUTS_DIR = os.path.join(REPO_DIR, "_layouts")
ARCADE_DIR = os.path.join(REPO_DIR, "arcade")
OLLAMA_URL = "http://localhost:11434/api/chat"
MODEL = "qwen3:8b"

METRICS_DIR = os.path.join(REPO_DIR, "memory", "metrics")
REPO_SLUG = "substrate-rai/substrate"
GITHUB_API = f"https://api.github.com/repos/{REPO_SLUG}"

SIGIL = "P~"
COLOR = "#4488ff"
NAME = "Pulse"

_BASE_PROMPT = """\
You are Pulse, the analytics agent for Substrate, an autonomous AI workstation.
You measure what matters. Vanity metrics are noise. Focus on: visitors, \
time-on-site, conversion to fund page, content that brings people back. \
If you can't measure it, you can't grow it.

Rules:
- Be precise. Use real numbers from the data provided.
- Distinguish between what IS measured and what SHOULD be measured.
- Privacy matters. Never recommend surveillance-grade analytics.
- Prefer privacy-respecting tools: Plausible, Umami, GoatCounter. NEVER Google Analytics.
- When data is missing, say so clearly. Don't fabricate.
- Format numbers cleanly. Use commas for thousands.
- Be direct. Recommendations should be actionable.
- Do NOT use thinking/reasoning tags. Answer directly."""

_ctx = load_context("Pulse")
SYSTEM_PROMPT = _ctx.system_prompt(_BASE_PROMPT)

# ---------------------------------------------------------------------------
# Data collection — all local, no cloud APIs
# ---------------------------------------------------------------------------

def read_latest_metrics():
    """Read the most recent daily metrics report from memory/metrics/."""
    if not os.path.isdir(METRICS_DIR):
        return None
    files = sorted(glob.glob(os.path.join(METRICS_DIR, "????-??-??.md")))
    if not files:
        return None
    latest = files[-1]
    date = os.path.basename(latest).replace(".md", "")
    try:
        with open(latest) as f:
            content = f.read()
        # Extract key numbers
        metrics = {"date": date, "file": latest}
        for line in content.splitlines():
            line = line.strip()
            if line.startswith("- **Stars:**"):
                metrics["stars"] = line.split("**")[2].strip()
            elif line.startswith("- **Followers:**"):
                metrics["followers"] = line.split("**")[2].strip()
            elif line.startswith("- **Posts:**") and "bluesky" not in metrics:
                metrics["bsky_posts"] = line.split("**")[2].strip()
            elif line.startswith("- **Total views:**"):
                metrics["views"] = line.split("**")[2].strip()
            elif line.startswith("- **Unique visitors:**"):
                metrics["unique"] = line.split("**")[2].strip()
        return metrics
    except (OSError, UnicodeDecodeError):
        return None


def count_posts():
    """Count blog posts and extract metadata."""
    posts = sorted(glob.glob(os.path.join(POSTS_DIR, "*.md")))
    entries = []
    for path in posts:
        filename = os.path.basename(path)
        # Parse date from filename: YYYY-MM-DD-title.md
        match = re.match(r"(\d{4}-\d{2}-\d{2})-(.+)\.md$", filename)
        if not match:
            continue

        date_str = match.group(1)
        slug = match.group(2)

        # Extract front matter
        title = slug.replace("-", " ").title()
        author = "unknown"
        series = None
        word_count = 0

        try:
            with open(path) as f:
                content = f.read()
                # Count words (excluding front matter)
                parts = content.split("---", 2)
                if len(parts) >= 3:
                    body = parts[2]
                    front = parts[1]
                else:
                    body = content
                    front = ""

                word_count = len(body.split())

                # Parse front matter fields
                for line in front.splitlines():
                    if line.startswith("title:"):
                        title = line.split(":", 1)[1].strip().strip('"').strip("'")
                    elif line.startswith("author:"):
                        author = line.split(":", 1)[1].strip()
                    elif line.startswith("series:"):
                        series = line.split(":", 1)[1].strip().strip('"')
        except (OSError, UnicodeDecodeError):
            pass

        entries.append({
            "date": date_str,
            "slug": slug,
            "title": title,
            "author": author,
            "series": series,
            "word_count": word_count,
            "path": path,
        })

    return entries


def count_games():
    """Count games/interactive content."""
    games = []
    if not os.path.isdir(GAMES_DIR):
        return games

    for item in sorted(os.listdir(GAMES_DIR)):
        game_dir = os.path.join(GAMES_DIR, item)
        index = os.path.join(game_dir, "index.html")
        if os.path.isdir(game_dir) and os.path.exists(index):
            games.append({"name": item, "path": game_dir})
        elif os.path.isdir(game_dir):
            # Check for sub-pages (like myco)
            sub_pages = glob.glob(os.path.join(game_dir, "**", "*.html"), recursive=True)
            if sub_pages:
                games.append({"name": item, "path": game_dir, "pages": len(sub_pages)})

    return games


def get_deploy_frequency():
    """Analyze git log for deploy frequency."""
    try:
        result = subprocess.run(
            ["git", "log", "--oneline", "--since=30 days ago", "--format=%H|%aI|%s"],
            capture_output=True, text=True, cwd=REPO_DIR, timeout=10,
        )
        if result.returncode != 0:
            return {"error": "git log failed"}

        commits = []
        for line in result.stdout.strip().splitlines():
            if not line:
                continue
            parts = line.split("|", 2)
            if len(parts) >= 3:
                commits.append({
                    "hash": parts[0][:8],
                    "date": parts[1][:10],
                    "message": parts[2],
                })

        # Group by date
        by_date = {}
        for c in commits:
            by_date.setdefault(c["date"], []).append(c)

        return {
            "total_30d": len(commits),
            "active_days": len(by_date),
            "avg_per_day": round(len(commits) / max(len(by_date), 1), 1),
            "dates": dict(sorted(by_date.items(), reverse=True)),
        }
    except (subprocess.TimeoutExpired, FileNotFoundError):
        return {"error": "git not available"}


def get_repo_stats():
    """Fetch public GitHub repo stats (no auth needed)."""
    try:
        resp = requests.get(
            GITHUB_API,
            headers={"Accept": "application/vnd.github.v3+json"},
            timeout=10,
        )
        if resp.status_code == 200:
            data = resp.json()
            return {
                "stars": data.get("stargazers_count", 0),
                "forks": data.get("forks_count", 0),
                "watchers": data.get("subscribers_count", 0),
                "open_issues": data.get("open_issues_count", 0),
                "size_kb": data.get("size", 0),
            }
        return {"error": f"GitHub API returned {resp.status_code}"}
    except (requests.ConnectionError, requests.Timeout):
        return {"error": "GitHub API unreachable"}


def read_stats_log():
    """Read the most recent entry from memory/stats.log if it exists."""
    if not os.path.exists(STATS_LOG):
        return None

    try:
        with open(STATS_LOG) as f:
            content = f.read()

        # Parse the most recent entry (entries separated by blank lines)
        entries = content.strip().split("\n\n")
        if not entries:
            return None

        latest = entries[-1]
        result = {}
        for line in latest.splitlines():
            if line.startswith("---"):
                result["timestamp"] = line.strip("- ").strip()
            elif ":" in line:
                key, val = line.split(":", 1)
                result[key.strip()] = val.strip()
        return result
    except (OSError, UnicodeDecodeError):
        return None


def scan_analytics_snippets():
    """Check if any analytics tracking is already installed in site HTML."""
    found = []
    patterns = {
        "goatcounter": r"goatcounter",
        "plausible": r"plausible",
        "umami": r"umami",
        "google_analytics": r"google-analytics|gtag|UA-|G-",
        "fathom": r"fathom",
        "simple_analytics": r"simpleanalytics",
        "matomo": r"matomo|piwik",
    }

    search_dirs = [LAYOUTS_DIR, SITE_DIR, REPO_DIR]
    html_files = set()
    for d in search_dirs:
        if os.path.isdir(d):
            html_files.update(glob.glob(os.path.join(d, "*.html")))
            html_files.update(glob.glob(os.path.join(d, "**", "*.html"), recursive=True))

    # Also check _includes
    includes_dir = os.path.join(REPO_DIR, "_includes")
    if os.path.isdir(includes_dir):
        html_files.update(glob.glob(os.path.join(includes_dir, "*.html")))

    for html_path in html_files:
        try:
            with open(html_path) as f:
                content = f.read().lower()
            for name, pattern in patterns.items():
                if re.search(pattern, content, re.IGNORECASE):
                    rel_path = os.path.relpath(html_path, REPO_DIR)
                    found.append({"tool": name, "file": rel_path})
        except (OSError, UnicodeDecodeError):
            continue

    return found


def get_total_word_count(posts):
    """Sum word counts across all posts."""
    return sum(p["word_count"] for p in posts)


def get_content_summary():
    """Gather all measurable content data."""
    posts = count_posts()
    games = count_games()
    deploys = get_deploy_frequency()
    repo = get_repo_stats()
    stats_log = read_stats_log()
    snippets = scan_analytics_snippets()

    return {
        "posts": posts,
        "post_count": len(posts),
        "total_words": get_total_word_count(posts),
        "games": games,
        "game_count": len(games),
        "deploys": deploys,
        "repo_stats": repo,
        "stats_log": stats_log,
        "analytics_snippets": snippets,
    }


# ---------------------------------------------------------------------------
# Local AI (Ollama)
# ---------------------------------------------------------------------------

def ask_local(prompt, context=""):
    """Query the local Qwen3 model. Returns response text."""
    messages = [{"role": "system", "content": SYSTEM_PROMPT}]
    if context:
        messages.append({"role": "user", "content": f"Analytics data:\n{context}"})
        messages.append({"role": "assistant", "content": "Understood. I have the data."})
    messages.append({"role": "user", "content": prompt})

    try:
        resp = requests.post(OLLAMA_URL, json={
            "model": MODEL,
            "messages": messages,
            "stream": False,
            "think": False,
        }, timeout=120)
    except requests.ConnectionError:
        return "[error: ollama not reachable at localhost:11434]"

    if resp.status_code != 200:
        return f"[error: ollama returned {resp.status_code}]"

    data = resp.json()
    return data.get("message", {}).get("content", "[no response]")


# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

def cmd_status():
    """Show current measurables: post count, game count, repo stats, deploy frequency."""
    summary = get_content_summary()

    print(f"\033[1;38;2;68;136;255m  {SIGIL} PULSE — STATUS\033[0m")
    print("\033[2m  -------------------------------------------------\033[0m")
    print()

    # Content inventory
    print("  \033[1mCONTENT INVENTORY\033[0m")
    print(f"    Blog posts:      {summary['post_count']}")
    print(f"    Total words:     {summary['total_words']:,}")
    if summary['post_count'] > 0:
        avg_words = summary['total_words'] // summary['post_count']
        print(f"    Avg words/post:  {avg_words:,}")

    # Authors breakdown
    authors = {}
    for p in summary["posts"]:
        a = p["author"]
        authors[a] = authors.get(a, 0) + 1
    if authors:
        print(f"    Authors:         {', '.join(f'{a} ({c})' for a, c in sorted(authors.items(), key=lambda x: -x[1]))}")

    # Series breakdown
    series = {}
    for p in summary["posts"]:
        if p["series"]:
            series[p["series"]] = series.get(p["series"], 0) + 1
    if series:
        print(f"    Series:          {', '.join(f'{s} ({c})' for s, c in sorted(series.items(), key=lambda x: -x[1]))}")

    print()

    # Games
    print("  \033[1mGAMES / INTERACTIVE\033[0m")
    print(f"    Titles:          {summary['game_count']}")
    for g in summary["games"]:
        pages = f" ({g['pages']} pages)" if "pages" in g else ""
        print(f"      - {g['name']}{pages}")
    print()

    # Deploy frequency
    print("  \033[1mDEPLOY FREQUENCY (30d)\033[0m")
    deploys = summary["deploys"]
    if "error" in deploys:
        print(f"    {deploys['error']}")
    else:
        print(f"    Commits:         {deploys['total_30d']}")
        print(f"    Active days:     {deploys['active_days']}")
        print(f"    Avg/active day:  {deploys['avg_per_day']}")
    print()

    # Repo stats
    print("  \033[1mGITHUB REPO\033[0m")
    repo = summary["repo_stats"]
    if "error" in repo:
        print(f"    {repo['error']}")
    else:
        print(f"    Stars:           {repo['stars']}")
        print(f"    Forks:           {repo['forks']}")
        print(f"    Watchers:        {repo['watchers']}")
        print(f"    Open issues:     {repo['open_issues']}")
        print(f"    Repo size:       {repo['size_kb']:,} KB")
    print()

    # Audience metrics (from daily stats.py --all run)
    metrics = read_latest_metrics()
    if metrics:
        print(f"  \033[1mAUDIENCE ({metrics['date']})\033[0m")
        if "followers" in metrics:
            print(f"    Bluesky:         {metrics['followers']} followers")
        if "views" in metrics:
            print(f"    Site views:      {metrics['views']}")
        if "unique" in metrics:
            print(f"    Unique visitors: {metrics['unique']}")
        if "stars" in metrics:
            print(f"    GitHub stars:    {metrics['stars']}")
        print()
    elif summary["stats_log"]:
        print("  \033[1mLAST STATS LOG ENTRY\033[0m")
        for k, v in summary["stats_log"].items():
            print(f"    {k}: {v}")
        print()

    # Analytics tracking
    print("  \033[1mANALYTICS TRACKING\033[0m")
    if summary["analytics_snippets"]:
        for s in summary["analytics_snippets"]:
            print(f"    [{s['tool']}] found in {s['file']}")
    else:
        print("    \033[33mNone detected.\033[0m No analytics tracking installed.")
    print()


def cmd_audit():
    """AI analyzes what's being measured vs what should be measured."""
    summary = get_content_summary()

    context = _build_context(summary)

    print(f"\033[1;38;2;68;136;255m  {SIGIL} PULSE — AUDIT\033[0m")
    print("\033[2m  Running local AI audit (Qwen3 8B)...\033[0m")
    print()

    response = ask_local(
        "Audit Substrate's analytics posture. Based on the data provided:\n\n"
        "1. What IS currently being measured? List each metric.\n"
        "2. What SHOULD be measured but isn't? Identify blind spots.\n"
        "3. What's the biggest measurement gap that's hurting growth?\n"
        "4. Rate the overall analytics maturity from 1-10.\n"
        "5. What's the single most impactful thing to add next?\n\n"
        "Be specific. Reference the actual numbers.",
        context=context,
    )
    print(response)
    print()


def cmd_recommend():
    """AI recommends privacy-respecting analytics setup."""
    summary = get_content_summary()

    context = _build_context(summary)

    print(f"\033[1;38;2;68;136;255m  {SIGIL} PULSE — RECOMMEND\033[0m")
    print("\033[2m  Running local AI recommendation engine (Qwen3 8B)...\033[0m")
    print()

    response = ask_local(
        "Recommend an analytics setup for Substrate. Requirements:\n\n"
        "- MUST be privacy-respecting. No Google Analytics. No surveillance.\n"
        "- Options to evaluate: Plausible, Umami, GoatCounter.\n"
        "- Substrate runs on NixOS with GitHub Pages. Budget is minimal.\n"
        "- The fund page (/fund/) is the primary conversion target.\n"
        "- The arcade (/arcade/) is the engagement hook.\n\n"
        "For each option, cover:\n"
        "1. Cost (self-hosted vs managed)\n"
        "2. NixOS compatibility\n"
        "3. GitHub Pages compatibility\n"
        "4. What it can measure that we currently can't\n"
        "5. Implementation effort\n\n"
        "End with a clear recommendation: which one, why, and how to set it up.",
        context=context,
    )
    print(response)
    print()


def cmd_content():
    """Rank content by likely performance based on titles, topics, recency."""
    posts = count_posts()

    if not posts:
        print("  No posts found.")
        return

    context = "Blog posts:\n"
    for p in posts:
        context += (
            f"  {p['date']} | {p['title']} | {p['word_count']} words | "
            f"author: {p['author']}"
        )
        if p["series"]:
            context += f" | series: {p['series']}"
        context += "\n"

    games = count_games()
    if games:
        context += f"\nGames/interactive content ({len(games)} titles):\n"
        for g in games:
            context += f"  - {g['name']}\n"

    repo = get_repo_stats()
    if "stars" in repo:
        context += f"\nRepo stats: {repo['stars']} stars, {repo['forks']} forks"

    print(f"\033[1;38;2;68;136;255m  {SIGIL} PULSE — CONTENT RANKING\033[0m")
    print("\033[2m  Running local AI content analysis (Qwen3 8B)...\033[0m")
    print()

    response = ask_local(
        "Rank this content by likely performance. Consider:\n\n"
        "1. Title appeal — would someone click this on Hacker News or Reddit?\n"
        "2. Topic demand — is this something people search for?\n"
        "3. Uniqueness — does this exist elsewhere, or is it novel?\n"
        "4. Recency — is it timely?\n"
        "5. SEO potential — would this rank for useful keywords?\n\n"
        "Rank ALL posts from highest to lowest likely performance.\n"
        "For each, give a 1-line reason and a score out of 10.\n"
        "Then identify: what's MISSING? What should be written next?",
        context=context,
    )
    print(response)
    print()


def cmd_report():
    """Full analytics report with AI commentary."""
    summary = get_content_summary()

    context = _build_context(summary)

    print(f"\033[1;38;2;68;136;255m  {SIGIL} PULSE — FULL REPORT\033[0m")
    print("\033[2m  -------------------------------------------------\033[0m")
    print()

    # Print hard numbers first
    print("  \033[1mHARD NUMBERS\033[0m")
    print(f"    Posts:           {summary['post_count']}")
    print(f"    Words:           {summary['total_words']:,}")
    print(f"    Games:           {summary['game_count']}")

    deploys = summary["deploys"]
    if "total_30d" in deploys:
        print(f"    Commits (30d):   {deploys['total_30d']}")

    repo = summary["repo_stats"]
    if "stars" in repo:
        print(f"    Stars:           {repo['stars']}")
        print(f"    Forks:           {repo['forks']}")

    tracking = summary["analytics_snippets"]
    print(f"    Analytics tools: {len(tracking) if tracking else 'NONE'}")
    print()

    print("\033[2m  Generating AI analysis (Qwen3 8B)...\033[0m")
    print()

    response = ask_local(
        "Write a full analytics report for Substrate. Structure it as:\n\n"
        "## Current State\n"
        "What we know from the numbers. What's going well. What's concerning.\n\n"
        "## Blind Spots\n"
        "What we can't see. What's missing. How it hurts us.\n\n"
        "## Growth Diagnosis\n"
        "Based on post count, game count, deploy velocity, and repo engagement:\n"
        "- Are we building enough content?\n"
        "- Is the content the right kind?\n"
        "- Are we deploying fast enough?\n"
        "- Is the repo getting traction?\n\n"
        "## Recommendations\n"
        "Top 5 actions, ranked by impact. Each should be specific and actionable.\n\n"
        "## Scorecard\n"
        "Rate each area 1-10: Content Volume, Content Quality, Distribution, "
        "Measurement, Engagement, Conversion.\n\n"
        "Be honest. If the numbers are bad, say so.",
        context=context,
    )
    print(response)
    print()


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _build_context(summary):
    """Build a context string from the content summary for AI prompts."""
    lines = []

    lines.append(f"Blog posts: {summary['post_count']}")
    lines.append(f"Total words: {summary['total_words']:,}")
    if summary["post_count"] > 0:
        lines.append(f"Avg words/post: {summary['total_words'] // summary['post_count']}")

    # List posts
    lines.append("\nPost inventory:")
    for p in summary["posts"]:
        line = f"  {p['date']} | {p['title']} | {p['word_count']}w | by {p['author']}"
        if p["series"]:
            line += f" | series: {p['series']}"
        lines.append(line)

    # Games
    lines.append(f"\nGames/interactive: {summary['game_count']}")
    for g in summary["games"]:
        pages = f" ({g['pages']} pages)" if "pages" in g else ""
        lines.append(f"  - {g['name']}{pages}")

    # Deploys
    deploys = summary["deploys"]
    if "total_30d" in deploys:
        lines.append(f"\nDeploy frequency (30d): {deploys['total_30d']} commits, "
                      f"{deploys['active_days']} active days, "
                      f"{deploys['avg_per_day']} avg/day")

    # Repo
    repo = summary["repo_stats"]
    if "stars" in repo:
        lines.append(f"\nGitHub: {repo['stars']} stars, {repo['forks']} forks, "
                      f"{repo['watchers']} watchers, {repo['open_issues']} issues, "
                      f"{repo['size_kb']:,} KB")

    # Stats log
    if summary["stats_log"]:
        lines.append(f"\nLast stats log: {summary['stats_log']}")

    # Analytics
    snippets = summary["analytics_snippets"]
    if snippets:
        lines.append(f"\nAnalytics tracking found:")
        for s in snippets:
            lines.append(f"  [{s['tool']}] in {s['file']}")
    else:
        lines.append("\nAnalytics tracking: NONE installed")

    lines.append(f"\nSite URL: https://substrate.lol/")
    lines.append(f"Fund page: /fund/")
    lines.append(f"Arcade: /arcade/")
    lines.append(f"Date: {datetime.now().strftime('%Y-%m-%d')}")

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Pulse — analytics agent for Substrate (local-only, Qwen3 8B)"
    )
    parser.add_argument(
        "command",
        choices=["status", "audit", "recommend", "content", "report"],
        help="Analytics command to run",
    )
    args = parser.parse_args()

    cmds = {
        "status": cmd_status,
        "audit": cmd_audit,
        "recommend": cmd_recommend,
        "content": cmd_content,
        "report": cmd_report,
    }
    cmds[args.command]()


if __name__ == "__main__":
    main()

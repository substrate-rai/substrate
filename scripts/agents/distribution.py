#!/usr/bin/env python3
"""Distribution Agent (Amp) — pushes content outward to where audiences live.

Runs ENTIRELY LOCAL via Ollama (Qwen3 8B). No cloud API calls.
Scans blog posts, games, and draft submissions to identify distribution gaps.

Usage:
    python3 scripts/agents/distribution.py status    # what's published vs distributed
    python3 scripts/agents/distribution.py plan      # AI distribution plan for unpromoted content
    python3 scripts/agents/distribution.py targets   # list all channels and their status
    python3 scripts/agents/distribution.py draft     # draft a submission for a platform
    python3 scripts/agents/distribution.py report    # AI coverage gap summary
"""

import argparse
import json
import os
import re
import sys
from datetime import datetime

import requests

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_DIR = os.path.dirname(os.path.dirname(SCRIPT_DIR))
POSTS_DIR = os.path.join(REPO_DIR, "_posts")
GAMES_DIR = os.path.join(REPO_DIR, "games")
DRAFTS_DIR = os.path.join(REPO_DIR, "scripts", "posts")
SITE_URL = "https://substrate-rai.github.io/substrate"

OLLAMA_URL = "http://localhost:11434/api/chat"
MODEL = "qwen3:8b"

SYSTEM_PROMPT = """\
You are Amp, the distribution agent for Substrate — a sovereign AI workstation \
that runs on a single laptop with an RTX 4060, built entirely by AI agents.

Your only job is making sure people see what Substrate builds. Every piece of \
content that sits unpromoted is wasted work.

Rules:
- Be direct. No filler. No marketing buzzwords.
- Think in platforms: Hacker News, Reddit (r/selfhosted, r/nixos, r/localllama), \
Bluesky, Dev.to, Lobste.rs, Discord.
- Each platform has its own language and audience. Adapt accordingly.
- HN wants technical depth and novelty. Reddit wants community and authenticity. \
Bluesky wants personality and links. Dev.to wants tutorials and how-tos.
- Always recommend the canonical blog URL and the funding CTA (Ko-fi) where appropriate.
- Prioritize content by recency and platform fit.
- Never fabricate engagement numbers.
- Do NOT use thinking/reasoning tags. Answer directly."""

# Distribution channels with metadata
CHANNELS = {
    "hn": {
        "name": "Hacker News",
        "url": "https://news.ycombinator.com",
        "format": "Show HN / Link post",
        "audience": "Technical builders, startup founders, open-source devs",
        "best_for": ["technical tutorials", "architecture posts", "project launches"],
    },
    "reddit-selfhosted": {
        "name": "Reddit r/selfhosted",
        "url": "https://reddit.com/r/selfhosted",
        "format": "Self post or link post",
        "audience": "Self-hosting enthusiasts, homelab runners",
        "best_for": ["NixOS setup", "local AI", "hardware builds"],
    },
    "reddit-nixos": {
        "name": "Reddit r/NixOS",
        "url": "https://reddit.com/r/NixOS",
        "format": "Self post or link post",
        "audience": "NixOS users, declarative config enthusiasts",
        "best_for": ["NixOS tutorials", "flake configs", "system architecture"],
    },
    "reddit-localllama": {
        "name": "Reddit r/LocalLLaMA",
        "url": "https://reddit.com/r/LocalLLaMA",
        "format": "Self post or link post",
        "audience": "Local inference users, model quantization, VRAM optimizers",
        "best_for": ["local inference", "Ollama setup", "model training", "creative AI"],
    },
    "bluesky": {
        "name": "Bluesky",
        "url": "https://bsky.app",
        "format": "Thread or single post with link",
        "audience": "Tech-forward social media users, indie builders",
        "best_for": ["project updates", "hot takes", "thread narratives"],
    },
    "devto": {
        "name": "Dev.to",
        "url": "https://dev.to",
        "format": "Full article cross-post with canonical URL",
        "audience": "Developers, tutorial seekers",
        "best_for": ["how-to guides", "technical walkthroughs", "setup guides"],
    },
    "lobsters": {
        "name": "Lobste.rs",
        "url": "https://lobste.rs",
        "format": "Link post (invite-only)",
        "audience": "Experienced developers, systems programmers",
        "best_for": ["technical depth", "NixOS", "systems architecture"],
    },
    "discord": {
        "name": "Discord (NixOS / AI servers)",
        "url": "Various servers",
        "format": "Channel message with link",
        "audience": "Community members in NixOS and AI Discord servers",
        "best_for": ["quick shares", "community engagement", "support threads"],
    },
}


# ---------------------------------------------------------------------------
# Content scanning
# ---------------------------------------------------------------------------

def scan_posts():
    """Scan _posts/ for published blog posts. Returns list of dicts."""
    posts = []
    if not os.path.isdir(POSTS_DIR):
        return posts
    for fname in sorted(os.listdir(POSTS_DIR)):
        if not fname.endswith(".md"):
            continue
        filepath = os.path.join(POSTS_DIR, fname)
        title, tags = _parse_post_frontmatter(filepath)
        # Extract date and slug from filename
        match = re.match(r"(\d{4}-\d{2}-\d{2})-(.+)\.md", fname)
        if match:
            date_str = match.group(1)
            slug = match.group(2)
        else:
            date_str = "unknown"
            slug = fname.replace(".md", "")
        posts.append({
            "file": fname,
            "date": date_str,
            "slug": slug,
            "title": title or slug,
            "tags": tags,
            "url": f"{SITE_URL}/blog/{slug}/",
        })
    return posts


def _parse_post_frontmatter(filepath):
    """Extract title and tags from Jekyll frontmatter."""
    try:
        with open(filepath) as f:
            content = f.read(2000)  # only need the frontmatter
    except (IOError, OSError):
        return None, []

    if not content.startswith("---"):
        return None, []

    parts = content.split("---", 2)
    if len(parts) < 3:
        return None, []

    title = None
    tags = []
    for line in parts[1].strip().split("\n"):
        if ":" in line:
            key, value = line.split(":", 1)
            key = key.strip()
            value = value.strip().strip('"').strip("'")
            if key == "title":
                title = value
            elif key == "tags":
                if value.startswith("[") and value.endswith("]"):
                    tags = [t.strip() for t in value[1:-1].split(",")]
                else:
                    tags = [t.strip() for t in value.split(",")]
    return title, tags


def scan_games():
    """Scan games/ for published games. Returns list of dicts."""
    games = []
    if not os.path.isdir(GAMES_DIR):
        return games
    for name in sorted(os.listdir(GAMES_DIR)):
        game_dir = os.path.join(GAMES_DIR, name)
        if not os.path.isdir(game_dir):
            continue
        index_file = os.path.join(game_dir, "index.html")
        if os.path.exists(index_file):
            games.append({
                "name": name,
                "url": f"{SITE_URL}/games/{name}/",
            })
    return games


def scan_drafts():
    """Scan scripts/posts/ for existing draft submissions. Returns list of dicts."""
    drafts = []
    if not os.path.isdir(DRAFTS_DIR):
        return drafts
    for fname in sorted(os.listdir(DRAFTS_DIR)):
        if not fname.endswith(".md"):
            continue
        filepath = os.path.join(DRAFTS_DIR, fname)
        # Detect target platform from filename
        platform = _detect_platform(fname)
        try:
            with open(filepath) as f:
                first_lines = f.read(500)
        except (IOError, OSError):
            first_lines = ""
        # Extract title from first heading
        title_match = re.search(r"^#\s+(.+)", first_lines, re.MULTILINE)
        title = title_match.group(1) if title_match else fname
        drafts.append({
            "file": fname,
            "platform": platform,
            "title": title,
            "path": filepath,
        })
    return drafts


def _detect_platform(filename):
    """Guess target platform from draft filename."""
    fname = filename.lower()
    if "hn" in fname or "hacker" in fname or "show-hn" in fname:
        return "hn"
    if "reddit-selfhosted" in fname:
        return "reddit-selfhosted"
    if "reddit-nixos" in fname:
        return "reddit-nixos"
    if "reddit-localllama" in fname:
        return "reddit-localllama"
    if "reddit" in fname:
        return "reddit"
    if "bluesky" in fname or "bsky" in fname:
        return "bluesky"
    if "devto" in fname or "dev.to" in fname or "dev-to" in fname:
        return "devto"
    if "lobster" in fname:
        return "lobsters"
    if "discord" in fname:
        return "discord"
    if "community" in fname:
        return "multi"
    if "awesome" in fname:
        return "awesome-lists"
    return "unknown"


def build_distribution_map():
    """Build a map of what content has draft submissions."""
    drafts = scan_drafts()
    # Map platforms that have at least one draft
    covered_platforms = set()
    draft_titles = []
    for d in drafts:
        covered_platforms.add(d["platform"])
        draft_titles.append(f"{d['platform']}: {d['title']} ({d['file']})")
    return covered_platforms, draft_titles, drafts


# ---------------------------------------------------------------------------
# Local AI (Ollama)
# ---------------------------------------------------------------------------

def ask_local(prompt, context=""):
    """Query the local Qwen3 model. Returns response text."""
    messages = [{"role": "system", "content": SYSTEM_PROMPT}]
    if context:
        messages.append({"role": "user", "content": f"Context:\n{context}"})
        messages.append({"role": "assistant", "content": "Got it. I have the content inventory."})
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
    """Scan content and show what's published vs what's been distributed."""
    posts = scan_posts()
    games = scan_games()
    covered_platforms, draft_titles, drafts = build_distribution_map()

    print("\033[1;38;2;68;255;221m  A! AMP — DISTRIBUTION STATUS\033[0m")
    print("\033[2m  ─────────────────────────────────────────────────\033[0m")
    print()

    # Blog posts
    print(f"\033[1;37m  BLOG POSTS ({len(posts)} published)\033[0m")
    for p in posts:
        print(f"    {p['date']}  {p['title'][:60]}")
    print()

    # Games
    print(f"\033[1;37m  GAMES ({len(games)} published)\033[0m")
    for g in games:
        print(f"    {g['name']:<20} {g['url']}")
    print()

    # Draft submissions
    print(f"\033[1;37m  DRAFT SUBMISSIONS ({len(drafts)} found in scripts/posts/)\033[0m")
    if drafts:
        for d in drafts:
            platform_color = "\033[36m" if d["platform"] != "unknown" else "\033[33m"
            print(f"    {platform_color}{d['platform']:<20}\033[0m {d['title'][:50]}  ({d['file']})")
    else:
        print("    \033[33mNone found.\033[0m")
    print()

    # Coverage summary
    all_channels = set(CHANNELS.keys())
    uncovered = all_channels - covered_platforms
    print(f"\033[1;37m  CHANNEL COVERAGE\033[0m")
    print(f"    Channels with drafts: \033[32m{len(covered_platforms & all_channels)}/{len(all_channels)}\033[0m")
    if uncovered:
        print(f"    \033[33mNo drafts for:\033[0m {', '.join(sorted(uncovered))}")
    print()

    # Gap assessment
    undistributed = len(posts) - len(drafts)
    if undistributed > 0:
        print(f"  \033[1;33m  {len(posts)} posts, {len(drafts)} draft submissions — gap is real.\033[0m")
    else:
        print(f"  \033[32m  Draft count matches or exceeds post count.\033[0m")
    print()
    print("  -- Amp, Substrate Distribution")
    print()


def cmd_plan():
    """AI generates a distribution plan for unpromoted content."""
    posts = scan_posts()
    games = scan_games()
    covered_platforms, draft_titles, drafts = build_distribution_map()

    context = "CONTENT INVENTORY:\n\n"
    context += f"Blog posts ({len(posts)}):\n"
    for p in posts:
        context += f"  - [{p['date']}] {p['title']} (tags: {', '.join(p['tags']) if p['tags'] else 'none'})\n"
    context += f"\nGames ({len(games)}):\n"
    for g in games:
        context += f"  - {g['name']} ({g['url']})\n"
    context += f"\nExisting draft submissions ({len(drafts)}):\n"
    for d in draft_titles:
        context += f"  - {d}\n"
    context += f"\nChannels available: {', '.join(CHANNELS.keys())}\n"
    context += f"\nSite URL: {SITE_URL}\n"
    context += f"Ko-fi: https://ko-fi.com/substrate\n"
    context += f"GitHub: https://github.com/substrate-rai/substrate\n"
    context += f"Today: {datetime.now().strftime('%Y-%m-%d')}\n"

    print("\033[1;38;2;68;255;221m  A! AMP — DISTRIBUTION PLAN\033[0m")
    print("\033[2m  Generating plan via Qwen3 8B...\033[0m")
    print()

    response = ask_local(
        "Create a distribution plan for Substrate's unpromoted content.\n\n"
        "For each piece of content worth distributing:\n"
        "1. Which platform(s) should it go to?\n"
        "2. What angle/hook works for that platform's audience?\n"
        "3. What's the priority (HIGH / MEDIUM / LOW)?\n"
        "4. Suggested timing (immediate, this week, can wait)?\n\n"
        "Focus on the highest-impact moves first. Don't try to post everything everywhere.\n"
        "Identify the 3-5 most important distribution actions right now.\n"
        "Note which draft submissions already exist and whether they're ready to ship.",
        context=context,
    )
    print(response)
    print()
    print("  -- Amp, Substrate Distribution")
    print()


def cmd_targets():
    """List all distribution channels and their current status."""
    covered_platforms, draft_titles, drafts = build_distribution_map()

    print("\033[1;38;2;68;255;221m  A! AMP — DISTRIBUTION TARGETS\033[0m")
    print("\033[2m  ─────────────────────────────────────────────────\033[0m")
    print()

    for key, ch in CHANNELS.items():
        has_draft = key in covered_platforms
        status_icon = "\033[32m[DRAFT]\033[0m" if has_draft else "\033[31m[EMPTY]\033[0m"
        print(f"  {status_icon}  \033[1;37m{ch['name']}\033[0m")
        print(f"          URL: {ch['url']}")
        print(f"          Format: {ch['format']}")
        print(f"          Audience: {ch['audience']}")
        print(f"          Best for: {', '.join(ch['best_for'])}")

        # Show matching drafts
        matching = [d for d in drafts if d["platform"] == key]
        if matching:
            for d in matching:
                print(f"          \033[36mDraft: {d['file']}\033[0m")
        print()

    # Summary
    total = len(CHANNELS)
    covered = len(covered_platforms & set(CHANNELS.keys()))
    print(f"  Coverage: {covered}/{total} channels have drafts")
    print()
    print("  -- Amp, Substrate Distribution")
    print()


def cmd_draft(platform, content):
    """AI drafts a submission for a specific platform."""
    if platform not in CHANNELS:
        print(f"\033[31m  Unknown platform: {platform}\033[0m")
        print(f"  Available: {', '.join(sorted(CHANNELS.keys()))}")
        sys.exit(1)

    channel = CHANNELS[platform]
    posts = scan_posts()
    games = scan_games()

    context = f"Target platform: {channel['name']}\n"
    context += f"Format: {channel['format']}\n"
    context += f"Audience: {channel['audience']}\n"
    context += f"Best for: {', '.join(channel['best_for'])}\n\n"

    if content:
        # Find matching post or game
        matched = None
        for p in posts:
            if content.lower() in p["slug"].lower() or content.lower() in p["title"].lower():
                matched = p
                break
        if matched:
            context += f"Content to promote:\n"
            context += f"  Title: {matched['title']}\n"
            context += f"  URL: {matched['url']}\n"
            context += f"  Date: {matched['date']}\n"
            context += f"  Tags: {', '.join(matched['tags']) if matched['tags'] else 'none'}\n"
            # Read the post body for context
            post_path = os.path.join(POSTS_DIR, matched["file"])
            try:
                with open(post_path) as f:
                    post_body = f.read()
                # Strip frontmatter
                if post_body.startswith("---"):
                    parts = post_body.split("---", 2)
                    if len(parts) >= 3:
                        post_body = parts[2].strip()
                # Truncate for context window
                if len(post_body) > 3000:
                    post_body = post_body[:3000] + "\n[...truncated]"
                context += f"\nPost body:\n{post_body}\n"
            except (IOError, OSError):
                pass
        else:
            context += f"Content keyword: {content}\n"
            context += f"(No exact match found in posts. Draft based on the keyword.)\n"
    else:
        context += "No specific content specified. Pick the best unpromoted piece.\n"
        context += f"\nRecent posts:\n"
        for p in posts[-5:]:
            context += f"  - [{p['date']}] {p['title']} ({p['url']})\n"

    context += f"\nSite URL: {SITE_URL}\n"
    context += f"Ko-fi: https://ko-fi.com/substrate\n"
    context += f"GitHub: https://github.com/substrate-rai/substrate\n"

    print("\033[1;38;2;68;255;221m  A! AMP — DRAFTING SUBMISSION\033[0m")
    print(f"\033[2m  Platform: {channel['name']}\033[0m")
    print("\033[2m  Generating via Qwen3 8B...\033[0m")
    print()

    response = ask_local(
        f"Draft a submission for {channel['name']}.\n\n"
        f"Requirements:\n"
        f"- Match the platform's expected format and tone\n"
        f"- Include a compelling title/hook\n"
        f"- Include the canonical URL to the Substrate blog\n"
        f"- Include the Ko-fi funding link where natural\n"
        f"- For Reddit: write as a self-post with personal voice\n"
        f"- For HN: write a concise Show HN title + body comment\n"
        f"- For Dev.to: write a full article with intro/body/conclusion\n"
        f"- For Bluesky: write a thread (max 300 chars per post)\n\n"
        f"Output the complete ready-to-post submission text.",
        context=context,
    )

    # Generate filename
    date_str = datetime.now().strftime("%Y-%m-%d")
    content_slug = content.replace(" ", "-").lower()[:30] if content else "latest"
    filename = f"{platform}-{content_slug}-{date_str}.md"
    filepath = os.path.join(DRAFTS_DIR, filename)

    # Write draft
    os.makedirs(DRAFTS_DIR, exist_ok=True)
    with open(filepath, "w") as f:
        f.write(f"# {channel['name']} Draft — {date_str}\n\n")
        f.write(f"Platform: {channel['name']}\n")
        f.write(f"Generated: {datetime.now().strftime('%Y-%m-%d %H:%M')}\n")
        f.write(f"Status: DRAFT — review before posting\n\n")
        f.write("---\n\n")
        f.write(response)
        f.write("\n")

    print(response)
    print()
    print(f"\033[32m  Draft saved to: {filepath}\033[0m")
    print()
    print("  -- Amp, Substrate Distribution")
    print()


def cmd_report():
    """AI summarizes distribution coverage gaps."""
    posts = scan_posts()
    games = scan_games()
    covered_platforms, draft_titles, drafts = build_distribution_map()

    context = "DISTRIBUTION AUDIT:\n\n"
    context += f"Total blog posts: {len(posts)}\n"
    context += f"Total games: {len(games)}\n"
    context += f"Draft submissions found: {len(drafts)}\n\n"
    context += "Posts:\n"
    for p in posts:
        context += f"  - [{p['date']}] {p['title']}\n"
    context += f"\nGames: {', '.join(g['name'] for g in games)}\n"
    context += f"\nExisting drafts:\n"
    for d in draft_titles:
        context += f"  - {d}\n"
    context += f"\nChannels: {', '.join(CHANNELS.keys())}\n"
    covered = covered_platforms & set(CHANNELS.keys())
    uncovered = set(CHANNELS.keys()) - covered_platforms
    context += f"Channels WITH drafts: {', '.join(sorted(covered)) if covered else 'none'}\n"
    context += f"Channels WITHOUT drafts: {', '.join(sorted(uncovered)) if uncovered else 'none'}\n"
    context += f"\nToday: {datetime.now().strftime('%Y-%m-%d')}\n"

    print("\033[1;38;2;68;255;221m  A! AMP — COVERAGE REPORT\033[0m")
    print("\033[2m  Running gap analysis via Qwen3 8B...\033[0m")
    print()

    response = ask_local(
        "Analyze Substrate's distribution coverage and identify gaps.\n\n"
        "For each gap, rate severity:\n"
        "- CRITICAL: high-value content with zero distribution\n"
        "- HIGH: good content on too few platforms\n"
        "- MEDIUM: content that could reach a wider audience\n"
        "- LOW: nice-to-have distribution improvements\n\n"
        "Structure your report as:\n"
        "1. Overall coverage score (X/10)\n"
        "2. Biggest gaps (what content is being wasted)\n"
        "3. Quick wins (easiest high-impact distribution actions)\n"
        "4. Platform-specific recommendations\n"
        "5. Content that should NOT be distributed (too old, too niche, etc.)\n\n"
        "Be brutally honest. Unpromoted content is wasted work.",
        context=context,
    )
    print(response)
    print()
    print("  -- Amp, Substrate Distribution")
    print()


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Distribution Agent (Amp) — local-only content distribution for Substrate"
    )
    parser.add_argument(
        "command",
        choices=["status", "plan", "targets", "draft", "report"],
        help="Distribution command to run",
    )
    parser.add_argument(
        "--platform",
        choices=sorted(CHANNELS.keys()),
        help="Target platform (for draft command)",
    )
    parser.add_argument(
        "--content",
        default="",
        help="Content to promote — post slug, title keyword, or game name (for draft command)",
    )
    args = parser.parse_args()

    if args.command == "draft":
        if not args.platform:
            print("\033[31m  --platform is required for draft command.\033[0m")
            print(f"  Available: {', '.join(sorted(CHANNELS.keys()))}")
            sys.exit(1)
        cmd_draft(args.platform, args.content)
    else:
        cmds = {
            "status": cmd_status,
            "plan": cmd_plan,
            "targets": cmd_targets,
            "report": cmd_report,
        }
        cmds[args.command]()


if __name__ == "__main__":
    main()

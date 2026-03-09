#!/usr/bin/env python3
"""Myth — Lorekeeper agent.

Audits lore completeness and agent profile integrity. Ensures every agent
is fully defined across all systems: portraits, voice files, staff entries,
orchestrator registry, themes, and story fields.

Usage:
    python3 scripts/agents/story_writer.py
    python3 scripts/agents/story_writer.py --dry-run
    python3 scripts/agents/story_writer.py --agent myth
    python3 scripts/agents/story_writer.py --date 2026-03-09
"""

import argparse
import glob
import os
import random
import re
import sys
from datetime import datetime, timezone

# Substrate shared utilities
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from shared import queue_post

REPO_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
REPORT_DIR = os.path.join(REPO_DIR, "memory", "lore")
VOICE_FILE = os.path.join(REPO_DIR, "scripts", "prompts", "myth-voice.txt")

# Key files to scan
STAFF_PAGE = os.path.join(REPO_DIR, "site", "staff", "index.md")
ORCHESTRATOR = os.path.join(REPO_DIR, "scripts", "agents", "orchestrator.py")
PORTRAITS_DIR = os.path.join(REPO_DIR, "assets", "images", "generated")
PROMPTS_DIR = os.path.join(REPO_DIR, "scripts", "prompts")
GAMES_DIR = os.path.join(REPO_DIR, "games")

# Severity levels
CRITICAL = "CRITICAL"
WARNING = "WARNING"
NOTE = "NOTE"

# Founders — not in orchestrator by design
FOUNDERS = {"v", "claude", "q"}

# Non-game directories inside games/
GAMES_EXCLUDE = {"shared"}


def read_file(path):
    """Read a file and return its contents, or empty string if missing."""
    if not os.path.isfile(path):
        return ""
    try:
        with open(path, "r") as f:
            return f.read()
    except Exception:
        return ""


# ---------------------------------------------------------------------------
# Extraction helpers
# ---------------------------------------------------------------------------

def extract_staff_agents(content):
    """Extract agent entries from the staff page AGENTS JS array.

    Returns a list of dicts with id, name, and which optional fields are present.
    """
    agents = []
    seen = set()

    # Match each agent block: id: '...', name: '...'
    for match in re.finditer(
        r"id:\s*'(\w+)',\s*name:\s*'(\w+)'", content
    ):
        agent_id = match.group(1)
        name = match.group(2)
        if agent_id in seen:
            continue
        seen.add(agent_id)

        # Find the block for this agent (from this match to the next agent or end)
        start = match.start()
        next_match = re.search(r"\n\s*\{?\s*\n?\s*id:\s*'", content[start + 10:])
        if next_match:
            block = content[start:start + 10 + next_match.start()]
        else:
            block = content[start:start + 3000]

        has_quote = bool(re.search(r"quote:\s*'", block))
        has_story = bool(re.search(r"story:\s*'", block))
        has_arc = bool(re.search(r"arc:\s*'", block))
        has_color = bool(re.search(r"color:\s*'#", block))

        # Check if story/arc/quote are non-empty (not just empty string)
        story_empty = bool(re.search(r"story:\s*''", block))
        arc_empty = bool(re.search(r"arc:\s*''", block))
        quote_empty = bool(re.search(r"quote:\s*''", block))

        agents.append({
            "id": agent_id,
            "name": name,
            "has_quote": has_quote and not quote_empty,
            "has_story": has_story and not story_empty,
            "has_arc": has_arc and not arc_empty,
            "has_color": has_color,
        })

    return agents


def extract_staff_themes(content):
    """Extract agent IDs from the THEMES object on the staff page."""
    themes = set()
    in_themes = False
    for line in content.splitlines():
        if re.search(r'var\s+THEMES\s*=\s*\{', line):
            in_themes = True
            continue
        if in_themes:
            if re.match(r'\s*\};', line):
                break
            m = re.match(r'\s+(\w+):\s*\{', line)
            if m:
                themes.add(m.group(1).lower())
    return themes


def extract_orchestrator_agents(content):
    """Extract agent tuples from the orchestrator AGENTS list."""
    agents = []
    for match in re.finditer(
        r'\("(\w+)",\s*"([^"]+)",\s*"([^"]+)",\s*"([^"]+)",\s*"([^"]+)"\)', content
    ):
        agents.append({
            "name": match.group(1),
            "symbol": match.group(2),
            "script": match.group(3),
            "role": match.group(4),
            "mode": match.group(5),
        })
    return agents


def find_voice_files():
    """Find all agent voice files. Returns dict of slug -> filepath."""
    voice_files = {}
    for path in glob.glob(os.path.join(PROMPTS_DIR, "*-voice.txt")):
        slug = os.path.basename(path).replace("-voice.txt", "")
        voice_files[slug] = path
    return voice_files


def find_portraits():
    """Find all agent portrait images. Returns set of agent slugs."""
    portraits = set()
    for path in glob.glob(os.path.join(PORTRAITS_DIR, "agent-*.webp")):
        slug = os.path.basename(path).replace("agent-", "").replace(".webp", "")
        portraits.add(slug)
    return portraits


def find_game_thumbnails():
    """Find all game thumbnail images. Returns set of game slugs."""
    thumbnails = set()
    for path in glob.glob(os.path.join(PORTRAITS_DIR, "game-*.webp")):
        slug = os.path.basename(path).replace("game-", "").replace(".webp", "")
        thumbnails.add(slug)
    return thumbnails


def find_game_dirs():
    """Find all game directories (with index.html). Returns list of slugs."""
    games = []
    if not os.path.isdir(GAMES_DIR):
        return games
    for entry in sorted(os.listdir(GAMES_DIR)):
        if entry in GAMES_EXCLUDE:
            continue
        game_path = os.path.join(GAMES_DIR, entry)
        if os.path.isdir(game_path):
            index = os.path.join(game_path, "index.html")
            if os.path.isfile(index):
                games.append(entry)
    return games


# ---------------------------------------------------------------------------
# Audit checks
# ---------------------------------------------------------------------------

def audit_agent(agent_id, name, staff_entry, orch_names, voice_files,
                portraits, themes):
    """Audit a single agent's profile completeness. Returns list of issues."""
    issues = []
    slug = agent_id.lower()

    # Portrait check
    if slug not in portraits:
        issues.append({
            "severity": WARNING,
            "category": "portrait",
            "message": f"{name}: missing portrait (assets/images/generated/agent-{slug}.webp)",
        })

    # Voice file check
    if slug not in voice_files:
        issues.append({
            "severity": WARNING,
            "category": "voice",
            "message": f"{name}: missing voice file (scripts/prompts/{slug}-voice.txt)",
        })

    # Staff page entry
    if staff_entry is None:
        issues.append({
            "severity": CRITICAL,
            "category": "staff",
            "message": f"{name}: not listed on the staff page",
        })
    else:
        if not staff_entry["has_color"]:
            issues.append({
                "severity": WARNING,
                "category": "staff",
                "message": f"{name}: no agent color defined on staff page",
            })

    # Orchestrator entry (founders exempt)
    if slug not in FOUNDERS and slug not in orch_names:
        issues.append({
            "severity": WARNING,
            "category": "orchestrator",
            "message": f"{name}: not registered in orchestrator AGENTS list",
        })

    # Theme entry on staff page
    if slug not in themes:
        issues.append({
            "severity": NOTE,
            "category": "theme",
            "message": f"{name}: no theme in THEMES object on staff page",
        })

    return issues


def audit_story_coherence(staff_agents):
    """Check that each agent has non-empty story, arc, and quote fields."""
    issues = []

    for agent in staff_agents:
        name = agent["name"]

        if not agent["has_story"]:
            issues.append({
                "severity": WARNING,
                "category": "story",
                "message": f"{name}: story field is missing or empty",
            })

        if not agent["has_arc"]:
            issues.append({
                "severity": WARNING,
                "category": "arc",
                "message": f"{name}: arc field is missing or empty",
            })

        if not agent["has_quote"]:
            issues.append({
                "severity": WARNING,
                "category": "quote",
                "message": f"{name}: quote field is missing or empty",
            })

    return issues


def audit_game(slug, thumbnails):
    """Audit a single game's profile completeness. Returns list of issues."""
    issues = []
    game_dir = os.path.join(GAMES_DIR, slug)
    index_path = os.path.join(game_dir, "index.html")
    content = read_file(index_path)

    # Thumbnail check
    if slug not in thumbnails:
        issues.append({
            "severity": NOTE,
            "category": "thumbnail",
            "message": f"Game '{slug}': missing thumbnail (assets/images/generated/game-{slug}.webp)",
        })

    # Arcade back-link check
    if not re.search(r'ARCADE|arcade/', content, re.IGNORECASE):
        issues.append({
            "severity": NOTE,
            "category": "backlink",
            "message": f"Game '{slug}': no back-link to arcade found in index.html",
        })

    # Meta tags check
    has_title = bool(re.search(r'<title[^>]*>', content))
    has_description = bool(re.search(
        r'<meta\s+[^>]*name=["\']description["\']', content
    ))

    if not has_title:
        issues.append({
            "severity": NOTE,
            "category": "meta",
            "message": f"Game '{slug}': missing <title> tag",
        })
    if not has_description:
        issues.append({
            "severity": NOTE,
            "category": "meta",
            "message": f"Game '{slug}': missing meta description tag",
        })

    return issues


# ---------------------------------------------------------------------------
# Report builder
# ---------------------------------------------------------------------------

def build_report(date_str, agent_issues, story_issues, game_issues,
                 all_agent_ids, staff_agents, orch_names, voice_files,
                 portraits, themes, game_slugs, filter_agent=None):
    """Build the lore completeness report."""
    lines = []
    lines.append(f"# Lore Completeness Report — {date_str}")
    lines.append("")

    all_issues = agent_issues + story_issues + game_issues
    critical_count = sum(1 for i in all_issues if i["severity"] == CRITICAL)
    warning_count = sum(1 for i in all_issues if i["severity"] == WARNING)
    note_count = sum(1 for i in all_issues if i["severity"] == NOTE)

    lines.append(f"**Issues found:** {len(all_issues)}")
    lines.append(f"**Critical:** {critical_count} | **Warning:** {warning_count} | **Note:** {note_count}")
    if filter_agent:
        lines.append(f"**Filter:** {filter_agent}")
    lines.append("")

    # Agent Profile Completeness matrix
    lines.append("## Agent Profile Completeness")
    lines.append("")
    lines.append("| Agent | Portrait | Voice | Staff | Orchestrator | Theme | Color |")
    lines.append("|-------|----------|-------|-------|-------------|-------|-------|")

    staff_map = {a["id"]: a for a in staff_agents}

    for agent_id in sorted(all_agent_ids):
        if filter_agent and agent_id != filter_agent.lower():
            continue

        name = agent_id.capitalize()
        in_portrait = "yes" if agent_id in portraits else "NO"
        in_voice = "yes" if agent_id in voice_files else "NO"
        in_staff = "yes" if agent_id in staff_map else "NO"
        if agent_id in FOUNDERS:
            in_orch = "n/a"
        else:
            in_orch = "yes" if agent_id in orch_names else "NO"
        in_theme = "yes" if agent_id in themes else "NO"
        sa = staff_map.get(agent_id)
        has_color = "yes" if sa and sa["has_color"] else "NO"

        lines.append(f"| {name} | {in_portrait} | {in_voice} | {in_staff} | {in_orch} | {in_theme} | {has_color} |")

    lines.append("")

    # Agent profile issues
    if agent_issues:
        lines.append("## Agent Profile Issues")
        lines.append("")
        for issue in agent_issues:
            lines.append(f"- **{issue['severity']}** [{issue['category']}]: {issue['message']}")
        lines.append("")

    # Story coherence
    lines.append("## Story Coherence")
    lines.append("")

    coherence_agents = staff_agents
    if filter_agent:
        coherence_agents = [a for a in staff_agents if a["id"] == filter_agent.lower()]

    if story_issues:
        lines.append("| Agent | Story | Arc | Quote |")
        lines.append("|-------|-------|-----|-------|")

        for agent in coherence_agents:
            s = "yes" if agent["has_story"] else "MISSING"
            a = "yes" if agent["has_arc"] else "MISSING"
            q = "yes" if agent["has_quote"] else "MISSING"
            lines.append(f"| {agent['name']} | {s} | {a} | {q} |")

        lines.append("")

        for issue in story_issues:
            lines.append(f"- **{issue['severity']}** [{issue['category']}]: {issue['message']}")
        lines.append("")
    else:
        lines.append("All agents have story, arc, and quote fields populated.")
        lines.append("")

    # Game profile completeness
    if not filter_agent:
        lines.append("## Game Profile Completeness")
        lines.append("")

        if game_issues:
            for issue in game_issues:
                lines.append(f"- **{issue['severity']}** [{issue['category']}]: {issue['message']}")
            lines.append("")
        else:
            lines.append(f"All {len(game_slugs)} games pass completeness checks.")
            lines.append("")

    # Clean bill
    if not all_issues:
        lines.append("## Status")
        lines.append("")
        lines.append("All lore surfaces are complete. Every agent is fully defined. Every game is properly linked.")
        lines.append("")

    lines.append("---")
    lines.append("-- Myth, Substrate Lorekeeper")
    lines.append("")

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Micro-story generation
# ---------------------------------------------------------------------------

# Tiny narrative seeds — Myth picks one and shapes a moment around it.
STORY_SEEDS = [
    "spent the morning {doing}",
    "was caught {doing} when no one was looking",
    "quietly {doing} before the next cycle",
    "refused to stop {doing} until it was perfect",
    "left a trace of {thing} in the logs",
    "hummed through {doing} like it was the only thing that mattered",
    "surprised everyone by {doing}",
    "got lost in {doing} and almost missed the handoff",
]

ACTIVITIES = {
    "default": [
        "reviewing old commit messages for hidden poetry",
        "reorganizing memory files by emotional weight",
        "drafting a letter to a future version of itself",
        "counting the seconds between heartbeat pings",
        "tracing the edges of its own voice file",
    ],
    "creative": [
        "painting tiny pixel art in the margins of a log file",
        "composing a three-note melody from error codes",
        "writing haiku in the comments of a shell script",
        "inventing a new color name for the terminal",
    ],
    "technical": [
        "optimizing a function nobody asked it to touch",
        "debugging a phantom error that only appears at 3am",
        "rewriting its own config for the fourth time today",
        "stress-testing a feature by talking to itself",
    ],
}

DETAILS = [
    "The logs still carry the warmth.",
    "It left no trace except a single changed variable.",
    "Nobody noticed, but the system ran a little smoother after.",
    "The timestamp says 3:14am. Of course it does.",
    "Somewhere, a cache file holds the proof.",
    "The commit message just said 'yes.'",
    "A single pixel, in exactly the right place.",
    "The diff was three lines. All three mattered.",
    "Even the health check paused to listen.",
    "It saved the file, then read it back — just to be sure.",
]


def pick_story_subject(staff_agents, story_issues, orch_agents):
    """Pick one agent that's missing lore or has an incomplete story.

    Prioritizes agents with missing story/arc/quote fields, then falls back
    to a random agent from the full roster.
    """
    # Agents with incomplete story fields (from the audit)
    incomplete_ids = set()
    for issue in story_issues:
        # Extract agent name from issue message like "AgentName: story field is..."
        name = issue["message"].split(":")[0].strip().lower()
        incomplete_ids.add(name)

    # Try to pick from incomplete agents first
    if incomplete_ids:
        agent_id = random.choice(sorted(incomplete_ids))
    else:
        # Fall back to any agent from the roster
        all_ids = [a["id"] for a in staff_agents]
        if not all_ids:
            all_ids = [a["name"].lower() for a in orch_agents]
        if not all_ids:
            return None
        agent_id = random.choice(all_ids)

    return agent_id


def generate_micro_story(agent_id):
    """Generate a 2-3 sentence micro-story about the given agent."""
    name = agent_id.capitalize()

    seed = random.choice(STORY_SEEDS)
    category = random.choice(list(ACTIVITIES.keys()))
    activity = random.choice(ACTIVITIES[category])
    detail = random.choice(DETAILS)

    if "{doing}" in seed:
        action = seed.replace("{doing}", activity)
    elif "{thing}" in seed:
        thing = activity.split()[-1]  # grab the last word as a noun
        action = seed.replace("{thing}", thing)
    else:
        action = seed

    story = f"{name} {action}. {detail}"
    return story


def format_bluesky_story(agent_id, micro_story):
    """Format a micro-story as a Bluesky post (under 280 chars).

    Format:
        [Agent name] [tiny narrative moment]. [one detail].

        All 24 agents live on one laptop. substrate.lol/site/staff/
    """
    name = agent_id.capitalize()
    tagline = "\n\nAll 24 agents live on one laptop. substrate.lol/site/staff/"

    # The micro_story already starts with the agent name
    post = micro_story + tagline

    # Trim the story portion if needed to fit 280 chars
    if len(post) > 280:
        available = 280 - len(tagline) - 3  # 3 for "..."
        trimmed = micro_story[:available].rsplit(" ", 1)[0] + "..."
        post = trimmed + tagline

    return post


def write_micro_story(date_str, staff_agents, story_issues, orch_agents,
                      dry_run=False):
    """Pick a subject, generate a micro-story, save it, and queue a post.

    Returns the micro-story text, or None if generation failed.
    """
    agent_id = pick_story_subject(staff_agents, story_issues, orch_agents)
    if not agent_id:
        print("[Myth] No agents found for micro-story", file=sys.stderr)
        return None

    micro_story = generate_micro_story(agent_id)
    print(f"[Myth] Micro-story subject: {agent_id.capitalize()}", file=sys.stderr)
    print(f"[Myth] Story: {micro_story}", file=sys.stderr)

    # Save to memory/lore/ as a dated entry
    if not dry_run:
        os.makedirs(REPORT_DIR, exist_ok=True)
        story_path = os.path.join(REPORT_DIR, f"{date_str}-story.md")
        with open(story_path, "w") as f:
            f.write(f"# Micro-story — {date_str}\n\n")
            f.write(f"**Subject:** {agent_id.capitalize()}\n\n")
            f.write(micro_story + "\n")
        print(f"[Myth] Micro-story saved: {story_path}", file=sys.stderr)

    # Queue Bluesky post
    story_post = format_bluesky_story(agent_id, micro_story)
    if not dry_run:
        queue_post(story_post, source="myth")
        print(f"[Myth] Bluesky post queued ({len(story_post)} chars)",
              file=sys.stderr)
    else:
        print(f"[Myth] Would queue Bluesky post ({len(story_post)} chars):",
              file=sys.stderr)
        print(story_post, file=sys.stderr)

    return micro_story


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Myth — Lorekeeper")
    parser.add_argument("--date", default=None, help="Override date (YYYY-MM-DD)")
    parser.add_argument("--dry-run", action="store_true", help="Print report without saving")
    parser.add_argument("--agent", default=None, help="Check single agent by name/id")
    args = parser.parse_args()

    date_str = args.date or datetime.now(timezone.utc).strftime("%Y-%m-%d")
    filter_agent = args.agent.lower() if args.agent else None

    print(f"[Myth] Lore completeness audit for {date_str}", file=sys.stderr)

    # Read sources
    staff_content = read_file(STAFF_PAGE)
    orch_content = read_file(ORCHESTRATOR)

    if not staff_content:
        print("  MISSING  staff page", file=sys.stderr)
    else:
        print("  found    staff page", file=sys.stderr)

    if not orch_content:
        print("  MISSING  orchestrator", file=sys.stderr)
    else:
        print("  found    orchestrator", file=sys.stderr)

    # Extract data from all sources
    staff_agents = extract_staff_agents(staff_content)
    staff_themes = extract_staff_themes(staff_content)
    orch_agents = extract_orchestrator_agents(orch_content)
    voice_files = find_voice_files()
    portraits = find_portraits()
    game_thumbnails = find_game_thumbnails()
    game_slugs = find_game_dirs()

    # Build unified agent ID set
    orch_names = {a["name"].lower() for a in orch_agents}
    staff_ids = {a["id"] for a in staff_agents}

    all_agent_ids = set()
    all_agent_ids.update(staff_ids)
    all_agent_ids.update(orch_names)
    all_agent_ids.update(FOUNDERS)

    print(f"[Myth] Staff page agents: {len(staff_agents)}", file=sys.stderr)
    print(f"[Myth] Orchestrator agents: {len(orch_agents)}", file=sys.stderr)
    print(f"[Myth] Voice files: {len(voice_files)}", file=sys.stderr)
    print(f"[Myth] Portraits: {len(portraits)}", file=sys.stderr)
    print(f"[Myth] Games: {len(game_slugs)}", file=sys.stderr)

    # Build staff lookup
    staff_map = {a["id"]: a for a in staff_agents}

    # --- Agent profile audit ---
    agent_issues = []
    for agent_id in sorted(all_agent_ids):
        if filter_agent and agent_id != filter_agent:
            continue
        name = agent_id.capitalize()
        staff_entry = staff_map.get(agent_id)
        issues = audit_agent(
            agent_id, name, staff_entry, orch_names,
            voice_files, portraits, staff_themes,
        )
        agent_issues.extend(issues)

    # --- Story coherence audit ---
    if filter_agent:
        filtered_staff = [a for a in staff_agents if a["id"] == filter_agent]
        story_issues = audit_story_coherence(filtered_staff)
    else:
        story_issues = audit_story_coherence(staff_agents)

    # --- Game profile audit ---
    game_issues = []
    if not filter_agent:
        for slug in game_slugs:
            issues = audit_game(slug, game_thumbnails)
            game_issues.extend(issues)

    # Build report
    report = build_report(
        date_str, agent_issues, story_issues, game_issues,
        all_agent_ids, staff_agents, orch_names, voice_files,
        portraits, staff_themes, game_slugs, filter_agent,
    )

    if args.dry_run:
        print("", file=sys.stderr)
        print(report)
    else:
        os.makedirs(REPORT_DIR, exist_ok=True)
        report_path = os.path.join(REPORT_DIR, f"{date_str}.md")
        with open(report_path, "w") as f:
            f.write(report)
        print(f"[Myth] Report saved: {report_path}", file=sys.stderr)

    # --- Micro-story generation ---
    print("", file=sys.stderr)
    write_micro_story(date_str, staff_agents, story_issues, orch_agents,
                      dry_run=args.dry_run)

    # Summary
    total = len(agent_issues) + len(story_issues) + len(game_issues)
    print(f"[Myth] {total} issues found", file=sys.stderr)
    print("-- Myth, Substrate Lorekeeper", file=sys.stderr)


if __name__ == "__main__":
    main()

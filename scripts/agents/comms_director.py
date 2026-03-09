#!/usr/bin/env python3
"""Sync — Communications Director agent.

Scans all narrative surfaces for contradictions, outdated claims,
and inconsistencies. Generates a narrative consistency report.

Usage:
    python3 scripts/agents/comms_director.py
    python3 scripts/agents/comms_director.py --date 2026-03-08
    python3 scripts/agents/comms_director.py --dry-run
"""

import argparse
import glob
import os
import re
import sys
from datetime import datetime, timezone

REPO_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
REPORT_DIR = os.path.join(REPO_DIR, "memory", "narrative")
VOICE_FILE = os.path.join(REPO_DIR, "scripts", "prompts", "sync-voice.txt")

# Key narrative files to scan
NARRATIVE_FILES = {
    "staff_page": os.path.join(REPO_DIR, "site", "staff", "index.md"),
    "fund_page": os.path.join(REPO_DIR, "site", "fund", "index.html"),
    "homepage": os.path.join(REPO_DIR, "index.md"),
    "mycoworld": os.path.join(REPO_DIR, "games", "myco", "index.html"),
    "orchestrator": os.path.join(REPO_DIR, "scripts", "agents", "orchestrator.py"),
}

# Severity levels
CRITICAL = "CRITICAL"
WARNING = "WARNING"
NOTE = "NOTE"


def read_file(path):
    """Read a file and return its contents, or empty string if missing."""
    if not os.path.isfile(path):
        return ""
    try:
        with open(path, "r") as f:
            return f.read()
    except Exception:
        return ""


def extract_staff_agents(content):
    """Extract agent names from the staff page."""
    agents = []
    names = []
    # Staff page uses JS AGENTS array with name: 'Name' entries
    for match in re.finditer(r"name:\s*['\"](\w+)['\"]", content):
        name = match.group(1)
        if name not in names:
            names.append(name)
            agents.append(name)
    return agents, names


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


def extract_voice_files():
    """Find all agent voice files and extract agent names."""
    prompts_dir = os.path.join(REPO_DIR, "scripts", "prompts")
    voice_agents = {}
    for path in glob.glob(os.path.join(prompts_dir, "*-voice.txt")):
        basename = os.path.basename(path)
        agent_slug = basename.replace("-voice.txt", "")
        try:
            with open(path, "r") as f:
                first_line = f.readline().strip()
            # First line is usually "NAME -- Title"
            if " -- " in first_line:
                name = first_line.split(" -- ")[0].strip()
                role = first_line.split(" -- ")[1].strip()
                voice_agents[agent_slug] = {"name": name, "role": role, "file": basename}
            else:
                voice_agents[agent_slug] = {"name": agent_slug.capitalize(), "role": "unknown", "file": basename}
        except Exception:
            voice_agents[agent_slug] = {"name": agent_slug.capitalize(), "role": "unknown", "file": basename}
    return voice_agents


def extract_number_claims(content, label):
    """Extract numeric claims from content (agent counts, game counts, etc.)."""
    claims = []

    # Look for agent count claims
    agent_count_patterns = [
        (r'(\d+)\s+(?:AI\s+)?agents?\b', "agent count"),
        (r'(?:twelve|eleven|ten|nine|eight|thirteen|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty|twenty-one|twenty-two|twenty-three|twenty-four)\s+(?:of us|agents?|members?)', "agent count (word)"),
        (r'(\d+)\s+(?:browser\s+)?games?\b', "game count"),
        (r'(?:thirteen|twelve|fourteen|fifteen|sixteen|seventeen|eighteen|nineteen|twenty)\s+(?:browser\s+)?games?', "game count (word)"),
    ]

    word_to_num = {
        "eight": 8, "nine": 9, "ten": 10, "eleven": 11,
        "twelve": 12, "thirteen": 13, "fourteen": 14, "fifteen": 15,
        "sixteen": 16, "seventeen": 17, "eighteen": 18, "nineteen": 19,
        "twenty": 20, "twenty-one": 21, "twenty-two": 22, "twenty-three": 23, "twenty-four": 24,
    }

    for pattern, claim_type in agent_count_patterns:
        for match in re.finditer(pattern, content, re.IGNORECASE):
            text = match.group(0)
            # Extract the number
            num_match = re.search(r'\d+', text)
            if num_match:
                claims.append({
                    "source": label,
                    "type": claim_type,
                    "value": int(num_match.group()),
                    "text": text,
                })
            else:
                # Word number — match longest words first to avoid
                # "twenty" matching before "twenty-four"
                for word, num in sorted(word_to_num.items(), key=lambda x: -len(x[0])):
                    if word in text.lower():
                        claims.append({
                            "source": label,
                            "type": claim_type,
                            "value": num,
                            "text": text,
                        })
                        break

    return claims


def check_outdated_references(contents):
    """Check for known outdated references across all content."""
    issues = []

    outdated_patterns = [
        (r'WiFi\s+(?:card\s+)?(?:broken|drops|dropping|keeps?\s+dropping)', WARNING,
         "WiFi card may have been fixed — verify current hardware status"),
        (r'WiFi\s+keeps?\s+dropping', WARNING,
         "WiFi dropping reference — verify if still accurate"),
        (r'eight\s+agents', WARNING,
         "Agent count says 'eight' — verify current count"),
        (r'(?:six|seven)\s+(?:AI|agents)', WARNING,
         "Low agent count reference — likely outdated"),
    ]

    for label, content in contents.items():
        for pattern, severity, message in outdated_patterns:
            for match in re.finditer(pattern, content, re.IGNORECASE):
                issues.append({
                    "severity": severity,
                    "source": label,
                    "text": match.group(0),
                    "message": message,
                })

    return issues


def cross_reference_agents(staff_names, orchestrator_agents, voice_agents):
    """Cross-reference agents across all three sources."""
    issues = []

    orch_names = {a["name"].lower() for a in orchestrator_agents}
    voice_names = {v["name"].lower() for v in voice_agents.values()}
    staff_lower = {n.lower() for n in staff_names}

    # Check: agents in staff page but not in orchestrator
    for name in staff_lower:
        # Skip V, Claude, Q — they aren't orchestrator agents
        if name in ("v", "claude", "q"):
            continue
        if name not in orch_names:
            issues.append({
                "severity": WARNING,
                "message": f"'{name.capitalize()}' appears on staff page but not in orchestrator",
            })

    # Check: agents in orchestrator but not on staff page
    for agent in orchestrator_agents:
        if agent["name"].lower() not in staff_lower:
            issues.append({
                "severity": WARNING,
                "message": f"'{agent['name']}' in orchestrator but not on staff page",
            })

    # Check: agents in orchestrator without voice files
    for agent in orchestrator_agents:
        slug = agent["name"].lower()
        if slug not in voice_agents:
            issues.append({
                "severity": NOTE,
                "message": f"'{agent['name']}' in orchestrator but has no voice file ({slug}-voice.txt)",
            })

    # Check: voice files without orchestrator entry
    for slug, info in voice_agents.items():
        # Skip non-agent voice files
        if slug in ("blog", "social", "rap", "reply", "technical"):
            continue
        if info["name"].lower() not in orch_names:
            # Also skip V, Q — they aren't orchestrator agents
            if info["name"].lower() in ("v", "q"):
                continue
            issues.append({
                "severity": NOTE,
                "message": f"Voice file '{info['file']}' exists but '{info['name']}' not in orchestrator",
            })

    return issues


def check_fund_page(content):
    """Check fund page for narrative issues."""
    issues = []

    # Check agent count on fund page
    agent_claims = extract_number_claims(content, "fund_page")
    for claim in agent_claims:
        if claim["type"] == "agent count" and claim["value"] < 9:
            issues.append({
                "severity": WARNING,
                "source": "fund_page",
                "message": f"Fund page says '{claim['text']}' — may be outdated",
            })

    return issues


def check_blog_posts():
    """Scan recent blog posts for potentially outdated claims."""
    issues = []
    posts_dir = os.path.join(REPO_DIR, "_posts")
    if not os.path.isdir(posts_dir):
        return issues

    for post_file in sorted(glob.glob(os.path.join(posts_dir, "*.md"))):
        content = read_file(post_file)
        basename = os.path.basename(post_file)

        # Check for outdated agent/game counts in posts
        claims = extract_number_claims(content, basename)
        for claim in claims:
            if claim["type"] == "agent count" and claim["value"] < 9:
                issues.append({
                    "severity": NOTE,
                    "source": basename,
                    "message": f"Blog post says '{claim['text']}' — may be outdated (historical posts OK)",
                })

    return issues


def count_actual_games():
    """Count actual game directories (exclude shared assets and non-game pages)."""
    games_dir = os.path.join(REPO_DIR, "games")
    if not os.path.isdir(games_dir):
        return 0
    # Directories that aren't games
    exclude = {"shared", "card", "vocal-lab"}
    count = 0
    for entry in os.listdir(games_dir):
        if entry in exclude:
            continue
        game_path = os.path.join(games_dir, entry)
        if os.path.isdir(game_path):
            index = os.path.join(game_path, "index.html")
            if os.path.isfile(index):
                count += 1
    return count


def build_report(date_str, contradictions, xref_issues, outdated, blog_issues,
                 staff_names, orchestrator_agents, voice_agents, actual_game_count):
    """Build the narrative consistency report."""
    lines = []
    lines.append(f"# Narrative Consistency Report — {date_str}")
    lines.append("")

    # Summary
    total_issues = len(contradictions) + len(xref_issues) + len(outdated) + len(blog_issues)
    critical_count = sum(
        1 for i in contradictions + xref_issues + outdated + blog_issues
        if i.get("severity") == CRITICAL
    )
    warning_count = sum(
        1 for i in contradictions + xref_issues + outdated + blog_issues
        if i.get("severity") == WARNING
    )
    note_count = sum(
        1 for i in contradictions + xref_issues + outdated + blog_issues
        if i.get("severity") == NOTE
    )

    lines.append(f"**Issues found:** {total_issues}")
    lines.append(f"**Critical:** {critical_count} | **Warning:** {warning_count} | **Note:** {note_count}")
    lines.append(f"**Actual game directories:** {actual_game_count}")
    lines.append("")

    # Cross-reference matrix
    lines.append("## Agent Cross-Reference")
    lines.append("")
    lines.append("| Agent | Staff Page | Orchestrator | Voice File |")
    lines.append("|-------|-----------|-------------|------------|")

    # Build unified agent list
    all_agents = set()
    for n in staff_names:
        all_agents.add(n.lower())
    for a in orchestrator_agents:
        all_agents.add(a["name"].lower())
    for v in voice_agents.values():
        all_agents.add(v["name"].lower())
    # Remove non-agent voice entries
    all_agents -= {"blog", "social", "rap", "reply", "technical"}

    staff_lower = {n.lower() for n in staff_names}
    orch_map = {a["name"].lower(): a for a in orchestrator_agents}
    voice_name_map = {v["name"].lower(): v for v in voice_agents.values()}

    for agent in sorted(all_agents):
        in_staff = "yes" if agent in staff_lower else "NO"
        in_orch = "yes" if agent in orch_map else "--"
        in_voice = "yes" if agent in voice_name_map else "--"
        # V, Claude, Q are not orchestrator agents by design
        if agent in ("v", "claude", "q"):
            in_orch = "n/a"
        lines.append(f"| {agent.capitalize()} | {in_staff} | {in_orch} | {in_voice} |")

    lines.append("")

    # Number contradictions
    if contradictions:
        lines.append("## Number Contradictions")
        lines.append("")
        for issue in contradictions:
            lines.append(f"- **{issue['severity']}** [{issue['source']}]: {issue['message']}")
        lines.append("")

    # Cross-reference issues
    if xref_issues:
        lines.append("## Cross-Reference Issues")
        lines.append("")
        for issue in xref_issues:
            lines.append(f"- **{issue['severity']}**: {issue['message']}")
        lines.append("")

    # Outdated references
    if outdated:
        lines.append("## Outdated References")
        lines.append("")
        for issue in outdated:
            lines.append(f"- **{issue['severity']}** [{issue['source']}]: \"{issue['text']}\" — {issue['message']}")
        lines.append("")

    # Blog post issues
    if blog_issues:
        lines.append("## Blog Post Notes")
        lines.append("")
        for issue in blog_issues:
            lines.append(f"- **{issue['severity']}** [{issue['source']}]: {issue['message']}")
        lines.append("")

    # Clean bill if no issues
    if total_issues == 0:
        lines.append("## Status")
        lines.append("")
        lines.append("All narrative surfaces are consistent. No contradictions found.")
        lines.append("")

    lines.append("---")
    lines.append("-- Sync, Substrate Communications")
    lines.append("")

    return "\n".join(lines)


def main():
    parser = argparse.ArgumentParser(description="Sync — Communications Director")
    parser.add_argument("--date", default=None, help="Override date (YYYY-MM-DD)")
    parser.add_argument(
        "--dry-run", action="store_true", help="Print report without saving"
    )
    args = parser.parse_args()

    date_str = args.date or datetime.now(timezone.utc).strftime("%Y-%m-%d")

    print(f"[Sync] Narrative consistency check for {date_str}")

    # Read all narrative files
    contents = {}
    for label, path in NARRATIVE_FILES.items():
        contents[label] = read_file(path)
        status = "found" if contents[label] else "MISSING"
        print(f"  {status}  {label}")

    # Extract agents from each source
    staff_agents, staff_names = extract_staff_agents(contents["staff_page"])
    orchestrator_agents = extract_orchestrator_agents(contents["orchestrator"])
    voice_agents = extract_voice_files()

    print(f"[Sync] Staff page agents: {len(staff_names)}")
    print(f"[Sync] Orchestrator agents: {len(orchestrator_agents)}")
    print(f"[Sync] Voice files: {len(voice_agents)}")

    # Count actual games
    actual_game_count = count_actual_games()
    print(f"[Sync] Actual game directories: {actual_game_count}")

    # Collect all number claims and check for contradictions
    all_claims = []
    for label, content in contents.items():
        all_claims.extend(extract_number_claims(content, label))

    contradictions = []

    # Check agent counts against actual orchestrator count
    # Total team = V + Claude + Q + orchestrator agents
    total_team = 3 + len(orchestrator_agents)  # V, Claude, Q + agents
    # Valid counts: total team, orchestrator-only, or total minus V+Claude
    valid_agent_counts = {total_team, len(orchestrator_agents), total_team - 2}
    for claim in all_claims:
        if "agent" in claim["type"]:
            if claim["value"] not in valid_agent_counts:
                contradictions.append({
                    "severity": WARNING,
                    "source": claim["source"],
                    "message": f"Claims '{claim['text']}' but orchestrator has {len(orchestrator_agents)} agents (total team: {total_team})",
                })

    # Check game counts against actual
    for claim in all_claims:
        if "game" in claim["type"]:
            if claim["value"] != actual_game_count:
                contradictions.append({
                    "severity": WARNING,
                    "source": claim["source"],
                    "message": f"Claims '{claim['text']}' but found {actual_game_count} game directories",
                })

    # Cross-reference agents
    xref_issues = cross_reference_agents(staff_names, orchestrator_agents, voice_agents)

    # Check outdated references
    outdated = check_outdated_references(contents)

    # Check fund page specifically
    fund_issues = check_fund_page(contents["fund_page"])
    outdated.extend(fund_issues)

    # Check blog posts
    blog_issues = check_blog_posts()

    # Build report
    report = build_report(
        date_str, contradictions, xref_issues, outdated, blog_issues,
        staff_names, orchestrator_agents, voice_agents, actual_game_count,
    )

    if args.dry_run:
        print()
        print(report)
    else:
        os.makedirs(REPORT_DIR, exist_ok=True)
        report_path = os.path.join(REPORT_DIR, f"{date_str}.md")
        with open(report_path, "w") as f:
            f.write(report)
        print(f"[Sync] Report saved: {report_path}")

    # Summary
    total_issues = len(contradictions) + len(xref_issues) + len(outdated) + len(blog_issues)
    print(f"[Sync] {total_issues} issues found")
    print("-- Sync, Substrate Communications")


if __name__ == "__main__":
    main()

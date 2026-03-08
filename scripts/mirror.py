#!/usr/bin/env python3
"""
mirror.py — Substrate self-assessment engine.

Parses memory/goal.md for milestones, scans the repo for capabilities,
checks system health, computes gaps, proposes builds, and writes a report.

Usage:
    python3 scripts/mirror.py              # full run, writes report
    python3 scripts/mirror.py --dry-run    # print report to stdout only
"""

import argparse
import os
import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
GOAL_FILE = REPO_ROOT / "memory" / "goal.md"
MIRROR_DIR = REPO_ROOT / "memory" / "mirror"


def parse_goals(path):
    """Parse memory/goal.md into tiers of milestones."""
    tiers = {}
    current_tier = None
    with open(path) as f:
        for line in f:
            tier_match = re.match(r'^## (Tier \d+):\s*(.+)', line)
            if tier_match:
                tier_id = tier_match.group(1)
                tier_name = tier_match.group(2).strip()
                current_tier = {"name": tier_name, "items": []}
                tiers[tier_id] = current_tier
                continue
            if current_tier is not None:
                item_match = re.match(r'^- \[([ xX])\] (.+)', line)
                if item_match:
                    done = item_match.group(1).lower() == 'x'
                    text = item_match.group(2).strip()
                    current_tier["items"].append({"text": text, "done": done})
    return tiers


def scan_inventory():
    """Scan the repo for capabilities."""
    inv = {}

    # Scripts
    scripts = sorted(REPO_ROOT.glob("scripts/*.py")) + sorted(REPO_ROOT.glob("scripts/*.sh"))
    inv["scripts"] = [s.relative_to(REPO_ROOT).as_posix() for s in scripts]

    # Agents
    agents = sorted(REPO_ROOT.glob("scripts/agents/*.py"))
    inv["agents"] = [a.relative_to(REPO_ROOT).as_posix() for a in agents]

    # NixOS modules
    nix_modules = sorted(REPO_ROOT.glob("nix/*.nix"))
    inv["nix_modules"] = [n.relative_to(REPO_ROOT).as_posix() for n in nix_modules
                          if n.name not in ("hardware-configuration.nix",)]

    # Blog posts
    posts = sorted(REPO_ROOT.glob("_posts/*.md")) + sorted(REPO_ROOT.glob("_posts/*.markdown"))
    inv["blog_posts"] = len(posts)

    # Site pages (standalone HTML outside _posts)
    pages = []
    for pattern in ["*.html", "*.md"]:
        for p in REPO_ROOT.glob(pattern):
            if p.name not in ("README.md", "CLAUDE.md", "Gemfile", "404.html"):
                pages.append(p.relative_to(REPO_ROOT).as_posix())
    # Subdirectory pages
    for subdir in ["myco", "arcade", "about", "staff", "press", "fund", "sponsor", "puzzle", "3d", "card"]:
        subpath = REPO_ROOT / subdir
        if subpath.exists():
            for p in subpath.rglob("*.html"):
                pages.append(p.relative_to(REPO_ROOT).as_posix())
            for p in subpath.rglob("*.md"):
                pages.append(p.relative_to(REPO_ROOT).as_posix())
    inv["site_pages"] = sorted(set(pages))

    # Myco curriculum modules
    myco_modules = []
    for track in ["foundation", "practitioner", "builder"]:
        track_dir = REPO_ROOT / "myco" / track
        if track_dir.exists():
            for p in sorted(track_dir.glob("*.html")):
                myco_modules.append(p.relative_to(REPO_ROOT).as_posix())
    inv["myco_modules"] = myco_modules

    # ML scripts
    ml_scripts = sorted(REPO_ROOT.glob("scripts/ml/*.py"))
    inv["ml_scripts"] = [s.relative_to(REPO_ROOT).as_posix() for s in ml_scripts]

    return inv


def check_health():
    """Check system health: ollama, GPU, disk."""
    health = {}

    # Ollama
    try:
        result = subprocess.run(["systemctl", "is-active", "ollama"],
                                capture_output=True, text=True, timeout=5)
        health["ollama"] = result.stdout.strip()
    except Exception:
        health["ollama"] = "unknown"

    # GPU
    try:
        result = subprocess.run(
            ["nvidia-smi", "--query-gpu=name,memory.used,memory.total,utilization.gpu",
             "--format=csv,noheader"],
            capture_output=True, text=True, timeout=5
        )
        health["gpu"] = result.stdout.strip()
    except Exception:
        health["gpu"] = "unavailable"

    # Disk
    try:
        result = subprocess.run(["df", "-h", "/"], capture_output=True, text=True, timeout=5)
        lines = result.stdout.strip().split("\n")
        if len(lines) >= 2:
            health["disk"] = lines[1]
    except Exception:
        health["disk"] = "unknown"

    # Active timers
    try:
        result = subprocess.run(
            ["systemctl", "list-timers", "--no-pager", "--no-legend"],
            capture_output=True, text=True, timeout=5
        )
        substrate_timers = [line for line in result.stdout.strip().split("\n")
                           if "substrate" in line]
        health["timers"] = len(substrate_timers)
        health["timer_list"] = substrate_timers
    except Exception:
        health["timers"] = 0
        health["timer_list"] = []

    return health


# Heuristic mapping: gap text patterns → proposed builds
BUILD_PROPOSALS = {
    "mirror system": {
        "action": "Complete mirror.py and nix/mirror.nix",
        "files": ["scripts/mirror.py", "nix/mirror.nix"],
        "effort": "small",
    },
    "capability inventory": {
        "action": "Mirror scan_inventory() covers repo capabilities",
        "files": ["scripts/mirror.py"],
        "effort": "small",
    },
    "gap analysis": {
        "action": "Mirror compute_gaps() produces actionable specs",
        "files": ["scripts/mirror.py"],
        "effort": "small",
    },
    "build specs": {
        "action": "Create scripts/build.py — reads mirror proposals, executes builds",
        "files": ["scripts/build.py"],
        "effort": "medium",
    },
    "nixos module generation": {
        "action": "Add NixOS module scaffolding to build.py",
        "files": ["scripts/build.py"],
        "effort": "medium",
    },
    "script scaffolding": {
        "action": "Add script template generation to build.py",
        "files": ["scripts/build.py"],
        "effort": "small",
    },
    "test harness": {
        "action": "Create scripts/test-capability.sh — smoke test for new builds",
        "files": ["scripts/test-capability.sh"],
        "effort": "medium",
    },
    "rollback": {
        "action": "Add git revert + incident logging to build.py",
        "files": ["scripts/build.py"],
        "effort": "small",
    },
    "stable diffusion": {
        "action": "Activate ML dev shell, download SDXL Turbo, test generation",
        "files": ["scripts/ml/generate-image.py"],
        "effort": "large",
    },
    "image pipeline": {
        "action": "Integrate image generation into blog pipeline",
        "files": ["scripts/pipeline.py", "scripts/ml/generate-image.py"],
        "effort": "medium",
    },
    "audience metrics": {
        "action": "Extend stats.py to track followers, views, engagement",
        "files": ["scripts/stats.py"],
        "effort": "medium",
    },
    "a/b testing": {
        "action": "Add topic performance tracking to metrics",
        "files": ["scripts/metrics.sh", "memory/metrics/"],
        "effort": "medium",
    },
    "revenue stream": {
        "action": "Activate donation/payment processing, track in ledger",
        "files": ["ledger/", "scripts/donations.py"],
        "effort": "large",
    },
    "revenue > $10": {
        "action": "Growth focus: content quality, distribution, community",
        "files": [],
        "effort": "ongoing",
    },
    "revenue covers": {
        "action": "Sustain revenue above $1.60/month (cloud API cost)",
        "files": [],
        "effort": "ongoing",
    },
    "hardware upgrade": {
        "action": "Accumulate surplus, identify upgrade target",
        "files": ["ledger/"],
        "effort": "ongoing",
    },
    "community engagement": {
        "action": "Automate posting to HN, Reddit, Discord",
        "files": ["scripts/crosspost.py"],
        "effort": "medium",
    },
    "self-hosted blog": {
        "action": "Deploy Caddy/nginx on substrate, serve Jekyll output locally",
        "files": ["nix/configuration.nix"],
        "effort": "large",
    },
    "self-hosted git": {
        "action": "Deploy Gitea via NixOS module",
        "files": ["nix/configuration.nix"],
        "effort": "large",
    },
    "encrypted backup": {
        "action": "Set up borgbackup or restic with encrypted off-site target",
        "files": ["nix/configuration.nix"],
        "effort": "large",
    },
    "wireguard": {
        "action": "Configure WireGuard tunnel in NixOS",
        "files": ["nix/configuration.nix"],
        "effort": "medium",
    },
    "revenue > $100": {
        "action": "Scale revenue streams, diversify income sources",
        "files": [],
        "effort": "ongoing",
    },
    "second gpu": {
        "action": "Budget for GPU upgrade or cloud burst provider",
        "files": [],
        "effort": "ongoing",
    },
    "full autonomy": {
        "action": "Close the loop: mirror → build → verify → deploy",
        "files": ["scripts/mirror.py", "scripts/build.py"],
        "effort": "large",
    },
}


def match_proposal(gap_text):
    """Match a gap to a build proposal using keyword matching."""
    text_lower = gap_text.lower()
    for keyword, proposal in BUILD_PROPOSALS.items():
        if keyword in text_lower:
            return proposal
    return {
        "action": f"Investigate and implement: {gap_text}",
        "files": [],
        "effort": "unknown",
    }


def compute_gaps(tiers):
    """Find incomplete milestones, ordered by tier (lowest first)."""
    gaps = []
    for tier_id in sorted(tiers.keys()):
        tier = tiers[tier_id]
        for item in tier["items"]:
            if not item["done"]:
                proposal = match_proposal(item["text"])
                gaps.append({
                    "tier": tier_id,
                    "tier_name": tier["name"],
                    "milestone": item["text"],
                    "proposal": proposal,
                })
    return gaps


def generate_report(tiers, inventory, health, gaps, dry_run=False):
    """Generate the mirror report as markdown."""
    now = datetime.now()
    date_str = now.strftime("%Y-%m-%d")
    time_str = now.strftime("%H:%M")

    lines = []
    lines.append(f"# Mirror Report — {date_str}")
    lines.append(f"")
    lines.append(f"Generated: {date_str} {time_str}")
    lines.append(f"")

    # Progress summary
    lines.append("## Progress")
    lines.append("")
    total = sum(len(t["items"]) for t in tiers.values())
    done = sum(1 for t in tiers.values() for i in t["items"] if i["done"])
    pct = round(done / total * 100) if total > 0 else 0
    lines.append(f"**{done}/{total} milestones complete ({pct}%)**")
    lines.append("")
    for tier_id in sorted(tiers.keys()):
        tier = tiers[tier_id]
        tier_total = len(tier["items"])
        tier_done = sum(1 for i in tier["items"] if i["done"])
        status = "COMPLETE" if tier_done == tier_total else f"{tier_done}/{tier_total}"
        lines.append(f"- {tier_id}: {tier['name']} — {status}")
    lines.append("")

    # Capability inventory
    lines.append("## Capability Inventory")
    lines.append("")
    lines.append(f"- Scripts: {len(inventory['scripts'])}")
    lines.append(f"- Agents: {len(inventory['agents'])}")
    lines.append(f"- NixOS modules: {len(inventory['nix_modules'])}")
    lines.append(f"- Blog posts: {inventory['blog_posts']}")
    lines.append(f"- Site pages: {len(inventory['site_pages'])}")
    lines.append(f"- Myco modules: {len(inventory['myco_modules'])}")
    lines.append(f"- ML scripts: {len(inventory['ml_scripts'])}")
    lines.append("")

    # System health
    lines.append("## System Health")
    lines.append("")
    lines.append(f"- Ollama: {health.get('ollama', 'unknown')}")
    lines.append(f"- GPU: {health.get('gpu', 'unknown')}")
    lines.append(f"- Disk: {health.get('disk', 'unknown')}")
    lines.append(f"- Active timers: {health.get('timers', 0)}")
    lines.append("")

    # Gaps and proposals
    lines.append("## Gaps")
    lines.append("")
    if not gaps:
        lines.append("No gaps detected. All milestones complete.")
    else:
        lines.append(f"**{len(gaps)} incomplete milestones:**")
        lines.append("")
        current_tier = None
        for gap in gaps:
            if gap["tier"] != current_tier:
                current_tier = gap["tier"]
                lines.append(f"### {gap['tier']}: {gap['tier_name']}")
                lines.append("")
            lines.append(f"- **{gap['milestone']}**")
            p = gap["proposal"]
            lines.append(f"  - Action: {p['action']}")
            if p["files"]:
                lines.append(f"  - Files: {', '.join(p['files'])}")
            lines.append(f"  - Effort: {p['effort']}")
            lines.append("")

    # Top proposal
    lines.append("## Next Build")
    lines.append("")
    if gaps:
        top = gaps[0]
        lines.append(f"**{top['milestone']}** ({top['tier']})")
        lines.append(f"")
        lines.append(f"Action: {top['proposal']['action']}")
        if top['proposal']['files']:
            lines.append(f"Files: {', '.join(top['proposal']['files'])}")
        lines.append(f"Effort: {top['proposal']['effort']}")
    else:
        lines.append("All milestones complete. Run `mirror.py` to reassess after goal.md update.")
    lines.append("")

    report = "\n".join(lines)
    return date_str, report


def main():
    parser = argparse.ArgumentParser(description="Substrate mirror — self-assessment engine")
    parser.add_argument("--dry-run", action="store_true", help="Print report to stdout only")
    args = parser.parse_args()

    if not GOAL_FILE.exists():
        print(f"Error: {GOAL_FILE} not found", file=sys.stderr)
        sys.exit(1)

    tiers = parse_goals(GOAL_FILE)
    inventory = scan_inventory()
    health = check_health()
    gaps = compute_gaps(tiers)
    date_str, report = generate_report(tiers, inventory, health, gaps, args.dry_run)

    if args.dry_run:
        print(report)
    else:
        MIRROR_DIR.mkdir(parents=True, exist_ok=True)
        report_path = MIRROR_DIR / f"{date_str}.md"
        with open(report_path, "w") as f:
            f.write(report)
        print(f"Mirror report written to {report_path}")


if __name__ == "__main__":
    main()

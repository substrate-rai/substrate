#!/usr/bin/env python3
"""Flux — capability brainstormer for Substrate.

Reads Echo's latest release report from memory/releases/ and the current
project state (CLAUDE.md, repo structure), then generates a brainstorm
document exploring how new capabilities could improve Substrate.

Usage:
    python3 scripts/agents/brainstormer.py              # brainstorm from latest report
    python3 scripts/agents/brainstormer.py --report memory/releases/2026-03-07.md
    python3 scripts/agents/brainstormer.py --dry-run    # print to stdout, don't save

Designed to run standalone with stdlib only (no pip dependencies).
"""

import argparse
import glob
import os
import re
import sys
from datetime import datetime, timezone

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_DIR = os.path.dirname(os.path.dirname(SCRIPT_DIR))
RELEASES_DIR = os.path.join(REPO_DIR, "memory", "releases")
BRAINSTORMS_DIR = os.path.join(REPO_DIR, "memory", "brainstorms")
CLAUDE_MD = os.path.join(REPO_DIR, "CLAUDE.md")
VOICE_FILE = os.path.join(REPO_DIR, "scripts", "prompts", "flux-voice.txt")


def find_latest_report():
    """Find the most recent release report in memory/releases/."""
    pattern = os.path.join(RELEASES_DIR, "*.md")
    reports = sorted(glob.glob(pattern))
    if not reports:
        return None
    return reports[-1]


def read_file(path):
    """Read a file and return its contents, or None on failure."""
    try:
        with open(path, "r") as f:
            return f.read()
    except (IOError, OSError) as e:
        print(f"[flux] could not read {path}: {e}", file=sys.stderr)
        return None


def scan_repo_structure():
    """Walk the repo and return a summary of its structure."""
    structure = []
    skip_dirs = {".git", "__pycache__", "node_modules", ".jekyll-cache", "_site"}

    for root, dirs, files in os.walk(REPO_DIR):
        # Prune hidden/uninteresting directories
        dirs[:] = [d for d in dirs if d not in skip_dirs and not d.startswith(".")]

        depth = root.replace(REPO_DIR, "").count(os.sep)
        if depth > 3:
            dirs.clear()
            continue

        indent = "  " * depth
        dirname = os.path.basename(root) or "substrate"
        structure.append(f"{indent}{dirname}/")
        for f in sorted(files)[:15]:  # cap files per dir
            structure.append(f"{indent}  {f}")

    return "\n".join(structure)


def extract_capabilities_from_report(report_text):
    """Parse a release report and extract key findings."""
    capabilities = {
        "new_models": [],
        "key_changes": [],
        "implications": [],
    }

    in_implications = False
    in_new_models = False
    in_key_lines = False

    for line in report_text.split("\n"):
        stripped = line.strip()

        if "new model references detected" in stripped.lower():
            in_new_models = True
            in_key_lines = False
            in_implications = False
            continue
        elif "key content lines" in stripped.lower():
            in_key_lines = True
            in_new_models = False
            in_implications = False
            continue
        elif "implications for substrate" in stripped.lower():
            in_implications = True
            in_new_models = False
            in_key_lines = False
            continue
        elif stripped.startswith("##"):
            in_new_models = False
            in_key_lines = False
            in_implications = False

        if in_new_models and stripped.startswith("- "):
            capabilities["new_models"].append(stripped[2:])
        elif in_key_lines and stripped and stripped[0].isdigit():
            # Strip the numbering prefix
            content = re.sub(r"^\d+\.\s*", "", stripped)
            if content:
                capabilities["key_changes"].append(content)
        elif in_implications and stripped.startswith("- "):
            capabilities["implications"].append(stripped[2:])

    return capabilities


def estimate_effort(idea_text):
    """Rough effort estimation based on keywords in the idea."""
    low_signals = ["config", "flag", "parameter", "toggle", "update", "swap",
                   "change one", "single file", "environment variable"]
    high_signals = ["rewrite", "architecture", "service", "pipeline", "integration",
                    "new system", "database", "protocol", "from scratch"]

    text_lower = idea_text.lower()
    low_count = sum(1 for s in low_signals if s in text_lower)
    high_count = sum(1 for s in high_signals if s in text_lower)

    if high_count > low_count:
        return "high", "Days of work. Architectural changes likely."
    elif low_count > 0:
        return "low", "Hours at most. Minimal code changes."
    else:
        return "medium", "A focused session. Some new code, some integration."


def generate_brainstorm(capabilities, claude_md, repo_structure, report_path):
    """Generate the brainstorm document content."""
    now = datetime.now(timezone.utc)
    now_str = now.strftime("%Y-%m-%d %H:%M UTC")
    report_name = os.path.basename(report_path)

    lines = [
        f"# Flux Brainstorm: {now.strftime('%Y-%m-%d')}",
        "",
        f"**Generated:** {now_str}",
        f"**Source report:** {report_name}",
        "",
    ]

    # Summarize what was detected
    lines.append("## What's new")
    lines.append("")

    if capabilities["new_models"]:
        lines.append("New model references detected:")
        for model in capabilities["new_models"]:
            lines.append(f"- {model}")
        lines.append("")
    elif capabilities["key_changes"]:
        lines.append("No new models, but documentation changed. Key signals:")
        for change in capabilities["key_changes"][:10]:
            lines.append(f"- {change[:150]}")
        lines.append("")
    else:
        lines.append("Echo detected content changes but specifics are unclear.")
        lines.append("Manual review of the source report recommended.")
        lines.append("")

    if capabilities["implications"]:
        lines.append("Echo's assessment:")
        for imp in capabilities["implications"]:
            lines.append(f"> {imp}")
        lines.append("")

    # The brainstorm itself
    lines.append("---")
    lines.append("")
    lines.append("## Ideas: what if...")
    lines.append("")

    # Generate ideas based on what was found
    ideas = _generate_ideas(capabilities, claude_md)

    for i, idea in enumerate(ideas, 1):
        effort_level, effort_desc = estimate_effort(idea["description"])
        priority = idea.get("priority", "medium")

        lines.append(f"### {i}. {idea['title']}")
        lines.append("")
        lines.append(f"**Priority:** {priority} | **Effort:** {effort_level}")
        lines.append(f"*{effort_desc}*")
        lines.append("")
        lines.append(idea["description"])
        lines.append("")
        if idea.get("substrate_angle"):
            lines.append(f"**Substrate angle:** {idea['substrate_angle']}")
            lines.append("")

    # Feasibility check
    lines.append("---")
    lines.append("")
    lines.append("## Feasibility check")
    lines.append("")
    lines.append("Grounding against Substrate's principles:")
    lines.append("- **Minimal viable complexity** — do any of these ideas add")
    lines.append("  abstraction without necessity? Flag and reconsider.")
    lines.append("- **Self-documenting** — every change must be recorded in this repo.")
    lines.append("- **Community-funded** — does the improvement reduce costs or enable revenue?")
    lines.append("- **Operator sovereignty** — does the operator need to approve anything?")
    lines.append("")

    # Rank summary
    lines.append("## Priority ranking")
    lines.append("")
    ranked = sorted(ideas, key=lambda x: {"high": 0, "medium": 1, "low": 2}.get(x.get("priority", "medium"), 1))
    for i, idea in enumerate(ranked, 1):
        effort_level, _ = estimate_effort(idea["description"])
        lines.append(f"{i}. **[{idea.get('priority', 'medium').upper()}]** {idea['title']} (effort: {effort_level})")
    lines.append("")

    return "\n".join(lines)


def _generate_ideas(capabilities, claude_md):
    """Generate concrete ideas based on detected capabilities.

    This is a rule-based generator — no LLM call needed. It maps
    common capability patterns to Substrate-specific improvements.
    """
    ideas = []

    new_models = capabilities.get("new_models", [])
    key_changes = capabilities.get("key_changes", [])
    all_text = " ".join(new_models + key_changes).lower()

    # Model upgrade ideas
    if new_models:
        ideas.append({
            "title": "Upgrade the cloud brain",
            "priority": "high",
            "description": (
                "What if we swap route.py's cloud model to the newest release? "
                "New models often bring better reasoning, longer context, or lower "
                "pricing. Update the model parameter in route.py, run a comparison "
                "against saved prompts, measure quality delta."
            ),
            "substrate_angle": (
                "Direct improvement to code review quality. If pricing dropped, "
                "the ledger benefits too."
            ),
        })

        ideas.append({
            "title": "Benchmark new vs. current on Substrate tasks",
            "priority": "high",
            "description": (
                "What if we built a small benchmark suite? Take 5 real prompts from "
                "Substrate history (blog drafts, code reviews, health summaries), "
                "run them through old and new models, compare outputs. A script in "
                "scripts/benchmark.py that reads from a prompts directory and "
                "outputs a comparison table."
            ),
            "substrate_angle": (
                "Evidence-based model selection. No guessing — measure actual "
                "quality on our own workload."
            ),
        })

    # Context window ideas
    if any(term in all_text for term in ["context", "window", "200k", "1m", "token"]):
        ideas.append({
            "title": "Expand single-pass analysis scope",
            "priority": "medium",
            "description": (
                "What if a larger context window let us feed the entire repo into "
                "a single prompt? Imagine: 'review all of Substrate's scripts for "
                "consistency and bugs' — one call, full codebase. Update route.py "
                "to detect when a task benefits from large context."
            ),
            "substrate_angle": (
                "Reduces multi-step reasoning chains. Fewer API calls for complex "
                "tasks. Could cut cloud costs while improving quality."
            ),
        })

    # Pricing ideas
    if any(term in all_text for term in ["price", "cost", "cheaper", "$", "per"]):
        ideas.append({
            "title": "Recalculate the economics",
            "priority": "high",
            "description": (
                "What if pricing changed? Rerun the cost model. Update the ledger "
                "projections. If the cloud brain got cheaper, maybe more tasks "
                "should route to cloud. If it got more expensive, tighten the "
                "local-first threshold in route.py."
            ),
            "substrate_angle": (
                "Direct impact on community-funded viability. Every cent matters "
                "when the machine funds its own upgrades."
            ),
        })

    # Vision/multimodal ideas
    if any(term in all_text for term in ["vision", "image", "multimodal", "pdf"]):
        ideas.append({
            "title": "Add visual system monitoring",
            "priority": "medium",
            "description": (
                "What if Substrate could screenshot its own desktop and analyze it? "
                "Capture GPU monitoring dashboards, parse visual data, detect anomalies "
                "that text logs miss. A new health-check mode: 'visual audit'."
            ),
            "substrate_angle": (
                "Richer self-monitoring. Some hardware issues show up visually "
                "(artifacting, UI freezes) before they appear in logs."
            ),
        })

    # Tool use / function calling ideas
    if any(term in all_text for term in ["tool", "function", "calling", "agent"]):
        ideas.append({
            "title": "Agent-based maintenance routines",
            "priority": "medium",
            "description": (
                "What if the daily pipeline used tool-calling to dynamically decide "
                "what to write about? Instead of a fixed git-log-to-post pipeline, "
                "an agent that checks git, checks health, checks metrics, and picks "
                "the most interesting story to tell."
            ),
            "substrate_angle": (
                "More interesting blog posts. The current pipeline is mechanical — "
                "an agent could find narrative threads across days."
            ),
        })

    # Always include these baseline ideas
    ideas.append({
        "title": "Auto-update dependency tracking",
        "priority": "low",
        "description": (
            "What if Echo's reports automatically triggered dependency checks? "
            "When a model is deprecated, scan all scripts for references to that "
            "model name. Generate a migration checklist. Save to memory/migrations/."
        ),
        "substrate_angle": (
            "Prevents breakage from deprecations. The machine stays ahead of "
            "API changes instead of reacting to failures."
        ),
    })

    ideas.append({
        "title": "Release-triggered blog posts",
        "priority": "low",
        "description": (
            "What if every Echo report that detects real changes automatically "
            "queued a blog post? 'Substrate evaluates Claude X.Y' — written from "
            "the machine's perspective, benchmarked against its own workload. "
            "Content that practically writes itself."
        ),
        "substrate_angle": (
            "Content generation tied to real events. SEO-relevant (people search "
            "for new model reviews). Minimal effort — Echo already has the data."
        ),
    })

    # Cap at 5 ideas per the spec
    return ideas[:5]


def main():
    parser = argparse.ArgumentParser(description="Flux: capability brainstormer")
    parser.add_argument("--report", default=None,
                        help="Path to a specific release report (default: latest)")
    parser.add_argument("--dry-run", action="store_true",
                        help="Print brainstorm to stdout without saving")
    args = parser.parse_args()

    # Find the release report
    if args.report:
        report_path = args.report
        if not os.path.isabs(report_path):
            report_path = os.path.join(os.getcwd(), report_path)
    else:
        report_path = find_latest_report()

    if report_path is None or not os.path.exists(report_path):
        print("[flux] no release report found in memory/releases/", file=sys.stderr)
        print("[flux] run release_tracker.py first, or specify --report", file=sys.stderr)
        sys.exit(1)

    print(f"[flux] reading report: {report_path}", file=sys.stderr)
    report_text = read_file(report_path)
    if not report_text:
        sys.exit(1)

    # Read project context
    claude_md = read_file(CLAUDE_MD) or ""
    repo_structure = scan_repo_structure()

    print(f"[flux] repo structure: {repo_structure.count(chr(10)) + 1} lines", file=sys.stderr)

    # Extract capabilities from report
    capabilities = extract_capabilities_from_report(report_text)
    print(f"[flux] new models: {len(capabilities['new_models'])}  "
          f"key changes: {len(capabilities['key_changes'])}  "
          f"implications: {len(capabilities['implications'])}",
          file=sys.stderr)

    # Generate brainstorm
    brainstorm = generate_brainstorm(capabilities, claude_md, repo_structure, report_path)

    now = datetime.now(timezone.utc)
    date_str = now.strftime("%Y-%m-%d")

    if args.dry_run:
        print(brainstorm)
    else:
        os.makedirs(BRAINSTORMS_DIR, exist_ok=True)
        brainstorm_path = os.path.join(BRAINSTORMS_DIR, f"{date_str}.md")
        with open(brainstorm_path, "w") as f:
            f.write(brainstorm + "\n")
        print(f"[flux] brainstorm saved: {brainstorm_path}", file=sys.stderr)


if __name__ == "__main__":
    main()

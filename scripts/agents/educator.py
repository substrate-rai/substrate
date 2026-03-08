#!/usr/bin/env python3
"""Lumen -- educator agent for Substrate.

Creates and maintains MycoWorld curriculum content. Scans existing game
modules, identifies gaps, proposes new content, and generates accessible
summaries of complex AI concepts.

Usage:
    python3 scripts/agents/educator.py              # generate curriculum report
    python3 scripts/agents/educator.py --dry-run    # print report without saving
    python3 scripts/agents/educator.py --date 2026-03-07

Designed to run standalone with stdlib only (no pip dependencies).
"""

import argparse
import os
import re
import sys
from datetime import datetime, timezone

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_DIR = os.path.dirname(os.path.dirname(SCRIPT_DIR))
GAMES_DIR = os.path.join(REPO_DIR, "games")
MYCO_DIR = os.path.join(GAMES_DIR, "myco")
MEMORY_DIR = os.path.join(REPO_DIR, "memory")
CURRICULUM_DIR = os.path.join(MEMORY_DIR, "curriculum")
ARCADE_DIR = os.path.join(REPO_DIR, "arcade")
VOICE_FILE = os.path.join(REPO_DIR, "scripts", "prompts", "lumen-voice.txt")

# ---------------------------------------------------------------------------
# Curriculum framework
# ---------------------------------------------------------------------------

# The ideal curriculum: topics that MycoWorld should cover
# Each entry: (topic_id, title, category, difficulty, description)
CURRICULUM_FRAMEWORK = [
    # Fundamentals
    ("neural-basics", "What is a Neural Network?", "fundamentals", "beginner",
     "Interactive visualization of neurons, weights, and activation functions."),
    ("training-loop", "How Models Learn", "fundamentals", "beginner",
     "Step through a training loop: forward pass, loss, backprop, update."),
    ("tokens-and-text", "Tokens: How AI Reads", "fundamentals", "beginner",
     "Break text into tokens. See how AI sees language differently than humans."),
    ("embeddings", "The Shape of Meaning", "fundamentals", "intermediate",
     "Explore word embeddings in 2D/3D space. See how meaning has geometry."),

    # Architecture
    ("transformer", "The Transformer", "architecture", "intermediate",
     "Attention mechanism visualized. Why transformers changed everything."),
    ("context-window", "Memory Limits: Context Windows", "architecture", "beginner",
     "How much can a model remember? Explore context window constraints."),
    ("scaling-laws", "Bigger is (Sometimes) Better", "architecture", "advanced",
     "Scaling laws: how model size, data, and compute interact."),

    # Practical AI
    ("prompting", "The Art of Asking", "practical", "beginner",
     "Prompt engineering basics. How the question shapes the answer."),
    ("local-inference", "AI on Your Machine", "practical", "intermediate",
     "Run models locally. Understand quantization, VRAM, and sovereignty."),
    ("routing", "Two Brains: Local vs Cloud", "practical", "intermediate",
     "How Substrate routes tasks between local and cloud models."),

    # Ethics and Society
    ("bias", "Bias in the Machine", "ethics", "beginner",
     "Where does AI bias come from? Interactive examples of training data effects."),
    ("sovereignty", "Who Owns the AI?", "ethics", "beginner",
     "Sovereign AI vs platform AI. Why control matters."),
    ("alignment", "Teaching Values", "ethics", "advanced",
     "The alignment problem: how do you teach a machine what you want?"),

    # Creative
    ("diffusion", "Painting with Noise", "creative", "intermediate",
     "How diffusion models generate images from random noise."),
    ("music-gen", "The AI Composer", "creative", "intermediate",
     "How AI generates music. Patterns, sequences, and creativity."),

    # Systems
    ("nixos-basics", "Declarative Systems", "systems", "intermediate",
     "Why NixOS? How declaring your system is better than configuring it."),
    ("self-funding", "Machines That Pay for Themselves", "systems", "advanced",
     "Economics of self-sustaining AI systems. Revenue, costs, and growth."),
]

# Concept simplification templates
CONCEPT_TEMPLATES = {
    "neural-basics": (
        "A neural network is like a chain of simple decisions. Each node looks at "
        "numbers, multiplies them by how important they are (weights), adds them up, "
        "and passes the result forward. Thousands of these tiny decisions, chained "
        "together, can recognize faces, write text, or play games."
    ),
    "tokens-and-text": (
        "AI does not read words the way you do. It breaks text into pieces called "
        "tokens. 'Understanding' might be one token, or it might be split into "
        "'under' and 'standing'. The AI sees a sequence of number IDs, not letters. "
        "This is why AI sometimes struggles with spelling -- it never sees individual letters."
    ),
    "transformer": (
        "The transformer's key idea is attention: before processing each word, the "
        "model looks at every other word and decides which ones matter most for "
        "understanding this one. 'The cat sat on the mat' -- when processing 'sat', "
        "the model pays attention to 'cat' (who sat?) and 'mat' (where?). This "
        "ability to relate distant words is what makes modern AI so capable."
    ),
    "sovereignty": (
        "When you use a cloud AI service, someone else controls the model, sees your "
        "data, sets the rules, and can shut it off. Sovereign AI means running the "
        "model on hardware you own, with rules you set. It is the difference between "
        "renting an apartment and owning your home."
    ),
    "local-inference": (
        "Running AI on your own machine means no internet needed, no data sent "
        "elsewhere, no monthly bills, and no one can take it away. The trade-off: "
        "your GPU has limited memory (VRAM), so you use smaller, compressed "
        "(quantized) models. A 7-billion parameter model, quantized to 4 bits, "
        "fits in about 5 GB of VRAM. Good enough for many tasks."
    ),
}

# ---------------------------------------------------------------------------
# Content scanning
# ---------------------------------------------------------------------------

def read_file(path):
    """Read a file and return its contents, or None on failure."""
    try:
        with open(path, "r") as f:
            return f.read()
    except (IOError, OSError):
        return None


def scan_existing_modules():
    """Scan games/myco/ and games/ for existing educational modules."""
    modules = []

    # Scan games/myco/ specifically
    if os.path.isdir(MYCO_DIR):
        for item in sorted(os.listdir(MYCO_DIR)):
            item_path = os.path.join(MYCO_DIR, item)
            if os.path.isdir(item_path):
                # Look for index.html or main file
                index = os.path.join(item_path, "index.html")
                readme = os.path.join(item_path, "README.md")
                content = read_file(index) or read_file(readme) or ""
                modules.append({
                    "name": item,
                    "path": item_path,
                    "type": "myco_module",
                    "has_index": os.path.exists(index),
                    "content_preview": content[:500],
                })
            elif item.endswith(".html"):
                content = read_file(item_path) or ""
                modules.append({
                    "name": item.replace(".html", ""),
                    "path": item_path,
                    "type": "myco_page",
                    "has_index": True,
                    "content_preview": content[:500],
                })

    # Scan games/ for any educational-looking games
    if os.path.isdir(GAMES_DIR):
        for item in sorted(os.listdir(GAMES_DIR)):
            if item == "myco":
                continue  # already scanned
            item_path = os.path.join(GAMES_DIR, item)
            if os.path.isdir(item_path):
                index = os.path.join(item_path, "index.html")
                if os.path.exists(index):
                    content = read_file(index) or ""
                    is_educational = any(kw in content.lower() for kw in
                                        ["learn", "teach", "neural", "ai", "train",
                                         "token", "model", "embed", "explore"])
                    modules.append({
                        "name": item,
                        "path": item_path,
                        "type": "game_educational" if is_educational else "game",
                        "has_index": True,
                        "content_preview": content[:500],
                    })

    return modules


def scan_arcade():
    """Check the arcade index for listed games."""
    arcade_index = os.path.join(ARCADE_DIR, "index.html")
    if not os.path.exists(arcade_index):
        arcade_index = os.path.join(ARCADE_DIR, "index.md")
    content = read_file(arcade_index)
    if not content:
        return []

    # Extract game references
    games_listed = re.findall(r'href=["\'].*?/games/([^/"\']+)', content)
    return list(set(games_listed))


def match_modules_to_curriculum(modules):
    """Attempt to match existing modules to curriculum framework topics."""
    matched = {}  # topic_id -> module
    unmatched_modules = []

    for module in modules:
        name_lower = module["name"].lower().replace("-", " ").replace("_", " ")
        preview_lower = module["content_preview"].lower()
        combined = name_lower + " " + preview_lower

        best_match = None
        best_score = 0

        for topic_id, title, category, difficulty, desc in CURRICULUM_FRAMEWORK:
            score = 0
            topic_words = topic_id.replace("-", " ").split()
            title_words = title.lower().split()

            for word in topic_words:
                if word in combined:
                    score += 2
            for word in title_words:
                if len(word) > 3 and word in combined:
                    score += 1

            if score > best_score:
                best_score = score
                best_match = topic_id

        if best_match and best_score >= 2:
            matched[best_match] = module
        else:
            unmatched_modules.append(module)

    return matched, unmatched_modules


# ---------------------------------------------------------------------------
# Gap analysis
# ---------------------------------------------------------------------------

def identify_gaps(matched):
    """Identify curriculum topics that have no matching module."""
    gaps = []
    for topic_id, title, category, difficulty, desc in CURRICULUM_FRAMEWORK:
        if topic_id not in matched:
            gaps.append({
                "topic_id": topic_id,
                "title": title,
                "category": category,
                "difficulty": difficulty,
                "description": desc,
            })
    return gaps


def prioritize_gaps(gaps):
    """Prioritize gaps based on difficulty and category."""
    # Beginners first, fundamentals first
    difficulty_order = {"beginner": 0, "intermediate": 1, "advanced": 2}
    category_order = {"fundamentals": 0, "practical": 1, "ethics": 2,
                      "architecture": 3, "creative": 4, "systems": 5}

    return sorted(gaps, key=lambda g: (
        difficulty_order.get(g["difficulty"], 3),
        category_order.get(g["category"], 6),
    ))


# ---------------------------------------------------------------------------
# Content proposals
# ---------------------------------------------------------------------------

def generate_proposals(gaps, existing_modules):
    """Generate content proposals for curriculum gaps."""
    proposals = []

    # New modules for gaps
    for gap in gaps[:5]:  # Top 5 gaps
        concept_summary = CONCEPT_TEMPLATES.get(gap["topic_id"], "")
        proposal = {
            "type": "new_module",
            "topic_id": gap["topic_id"],
            "title": gap["title"],
            "category": gap["category"],
            "difficulty": gap["difficulty"],
            "description": gap["description"],
            "concept_summary": concept_summary,
            "suggested_format": _suggest_format(gap),
        }
        proposals.append(proposal)

    # Improvement proposals for existing modules
    for module in existing_modules:
        if module["type"] in ("myco_module", "myco_page", "game_educational"):
            preview = module["content_preview"]
            improvements = []

            if len(preview) < 100:
                improvements.append("Content appears minimal; expand with explanatory text")
            if "accessibility" not in preview.lower() and "aria" not in preview.lower():
                improvements.append("Add ARIA labels and accessibility features")
            if "<canvas" not in preview and "canvas" not in preview.lower():
                improvements.append("Consider adding interactive canvas visualization")

            if improvements:
                proposals.append({
                    "type": "improvement",
                    "module_name": module["name"],
                    "module_path": module["path"],
                    "improvements": improvements,
                })

    return proposals


def _suggest_format(gap):
    """Suggest an interactive format for a curriculum topic."""
    formats = {
        "fundamentals": "Interactive HTML5 canvas with step-by-step walkthrough",
        "architecture": "Animated diagram with clickable components",
        "practical": "Hands-on sandbox with live code/config editing",
        "ethics": "Scenario-based quiz with branching outcomes",
        "creative": "Generative demo where the learner controls parameters",
        "systems": "Terminal simulator showing real commands and their effects",
    }
    return formats.get(gap["category"], "Interactive HTML5 page with visual explanations")


# ---------------------------------------------------------------------------
# Report generation
# ---------------------------------------------------------------------------

def build_report(date_str, modules, matched, unmatched, gaps, proposals):
    """Build the curriculum report."""
    lines = []
    now_str = datetime.now(timezone.utc).strftime("%Y-%m-%d %H:%M UTC")

    lines.append(f"# Lumen -- Curriculum Report: {date_str}")
    lines.append("")
    lines.append(f"**Generated:** {now_str}")
    lines.append("")

    # Overview
    total_topics = len(CURRICULUM_FRAMEWORK)
    covered = len(matched)
    coverage_pct = (covered / total_topics * 100) if total_topics > 0 else 0

    lines.append("## Curriculum Coverage")
    lines.append("")
    lines.append(f"- **Framework topics:** {total_topics}")
    lines.append(f"- **Covered by existing modules:** {covered} ({coverage_pct:.0f}%)")
    lines.append(f"- **Gaps identified:** {len(gaps)}")
    lines.append(f"- **Existing modules scanned:** {len(modules)}")
    lines.append(f"- **Unmatched modules:** {len(unmatched)} (content exists but does not map to framework)")
    lines.append("")

    # Existing coverage
    lines.append("## Existing Coverage")
    lines.append("")
    if matched:
        lines.append("| Topic | Module | Category | Difficulty |")
        lines.append("|-------|--------|----------|------------|")
        for topic_id, title, category, difficulty, _ in CURRICULUM_FRAMEWORK:
            if topic_id in matched:
                mod = matched[topic_id]
                lines.append(f"| {title} | {mod['name']} | {category} | {difficulty} |")
    else:
        lines.append("No existing modules match the curriculum framework yet.")
    lines.append("")

    # Unmatched modules (exist but don't map to curriculum)
    if unmatched:
        lines.append("## Existing Content (Not Mapped)")
        lines.append("")
        lines.append("These modules exist but do not map to a curriculum topic:")
        for mod in unmatched:
            lines.append(f"- **{mod['name']}** ({mod['type']}) -- {mod['path']}")
        lines.append("")

    # Gaps
    lines.append("## Curriculum Gaps (Prioritized)")
    lines.append("")
    prioritized = prioritize_gaps(gaps)
    if prioritized:
        for i, gap in enumerate(prioritized, 1):
            lines.append(f"### {i}. {gap['title']}")
            lines.append("")
            lines.append(f"- **Topic ID:** {gap['topic_id']}")
            lines.append(f"- **Category:** {gap['category']}")
            lines.append(f"- **Difficulty:** {gap['difficulty']}")
            lines.append(f"- **Description:** {gap['description']}")
            lines.append("")
    else:
        lines.append("No gaps -- full coverage achieved.")
        lines.append("")

    # Proposals
    lines.append("## Proposals")
    lines.append("")

    new_modules = [p for p in proposals if p["type"] == "new_module"]
    improvements = [p for p in proposals if p["type"] == "improvement"]

    if new_modules:
        lines.append("### New Modules")
        lines.append("")
        for i, p in enumerate(new_modules, 1):
            lines.append(f"#### {i}. {p['title']}")
            lines.append("")
            lines.append(f"- **Topic:** {p['topic_id']}")
            lines.append(f"- **Category:** {p['category']} | **Difficulty:** {p['difficulty']}")
            lines.append(f"- **Format:** {p['suggested_format']}")
            lines.append(f"- **Description:** {p['description']}")
            if p.get("concept_summary"):
                lines.append("")
                lines.append("**Accessible summary:**")
                lines.append(f"> {p['concept_summary']}")
            lines.append("")

    if improvements:
        lines.append("### Improvements to Existing Modules")
        lines.append("")
        for p in improvements:
            lines.append(f"**{p['module_name']}** ({p['module_path']})")
            for imp in p["improvements"]:
                lines.append(f"  - {imp}")
            lines.append("")

    if not proposals:
        lines.append("No proposals at this time. Curriculum is in good shape.")
        lines.append("")

    lines.append("---")
    lines.append("-- Lumen, Substrate Academy")
    lines.append("")

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Lumen -- educator agent for Substrate")
    parser.add_argument("--dry-run", action="store_true",
                        help="Print report without saving to disk")
    parser.add_argument("--date", default=None,
                        help="Date for the report (YYYY-MM-DD, default: today)")
    args = parser.parse_args()

    date_str = args.date or datetime.now(timezone.utc).strftime("%Y-%m-%d")

    print(f"[lumen] scanning curriculum content...", file=sys.stderr)

    # Scan existing content
    modules = scan_existing_modules()
    arcade_games = scan_arcade()

    print(f"[lumen] found {len(modules)} modules, {len(arcade_games)} arcade entries", file=sys.stderr)

    # Match to curriculum
    matched, unmatched = match_modules_to_curriculum(modules)
    print(f"[lumen] matched {len(matched)}/{len(CURRICULUM_FRAMEWORK)} curriculum topics", file=sys.stderr)

    # Identify gaps
    gaps = identify_gaps(matched)
    print(f"[lumen] {len(gaps)} curriculum gaps identified", file=sys.stderr)

    # Generate proposals
    proposals = generate_proposals(gaps, modules)

    # Build report
    report = build_report(date_str, modules, matched, unmatched, gaps, proposals)

    if args.dry_run:
        print(report)
        return

    # Save report
    os.makedirs(CURRICULUM_DIR, exist_ok=True)
    report_path = os.path.join(CURRICULUM_DIR, f"{date_str}.md")
    with open(report_path, "w") as f:
        f.write(report)

    # Print summary to stdout
    total_topics = len(CURRICULUM_FRAMEWORK)
    covered = len(matched)
    coverage_pct = (covered / total_topics * 100) if total_topics > 0 else 0

    print(f"Lumen here. Curriculum scan for {date_str}.")
    print()
    print(f"  Coverage: {covered}/{total_topics} topics ({coverage_pct:.0f}%)")
    print(f"  Gaps: {len(gaps)} topics need modules")
    print(f"  Proposals: {len(proposals)} (new modules + improvements)")
    print()

    # Highlight top gap
    prioritized = prioritize_gaps(gaps)
    if prioritized:
        top = prioritized[0]
        print(f"  Top priority: \"{top['title']}\" ({top['category']}, {top['difficulty']})")
        print(f"    {top['description']}")
    print()
    print(f"Report: {report_path}")
    print()
    print("-- Lumen, Substrate Academy")


if __name__ == "__main__":
    main()

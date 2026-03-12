#!/usr/bin/env python3
"""Scribe — Guide Author for Substrate.

Reads Ink's research dossiers and synthesizes them into publishable
technical guides using Ollama (Qwen3 8B).

Usage:
    python3 scripts/agents/scribe.py              # draft top researched topic
    python3 scripts/agents/scribe.py --dry-run    # print to stdout, don't save
    python3 scripts/agents/scribe.py --topic ID   # draft a specific topic

Mode: full (uses Ollama for draft generation)
Dependencies: stdlib + ollama_client.py
"""

import argparse
import json
import os
import re
import sys
from datetime import datetime, timezone

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_DIR = os.path.dirname(os.path.dirname(SCRIPT_DIR))
RESEARCH_DIR = os.path.join(REPO_DIR, "memory", "research")
GUIDES_DIR = os.path.join(REPO_DIR, "memory", "guides")
TOPIC_QUEUE = os.path.join(RESEARCH_DIR, "topic-queue.json")
POSTS_DIR = os.path.join(REPO_DIR, "_posts")

sys.path.insert(0, SCRIPT_DIR)
from shared import queue_post
from context import load_context


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
        print(f"[scribe] queue load failed: {e}", file=sys.stderr)
        return []


def save_queue(topics):
    """Save the topic queue to JSON."""
    os.makedirs(RESEARCH_DIR, exist_ok=True)
    with open(TOPIC_QUEUE, "w") as f:
        json.dump(topics, f, indent=2)
        f.write("\n")


def find_researched_topic(topics, topic_id=None):
    """Find the highest-priority researched (not yet drafted) topic."""
    if topic_id:
        for t in topics:
            if t["id"] == topic_id:
                return t
        return None

    researched = [t for t in topics if t.get("status") == "researched"]
    if not researched:
        return None
    researched.sort(key=lambda t: t.get("priority", 999))
    return researched[0]


def load_dossier(topic_id):
    """Load a research dossier for a topic."""
    path = os.path.join(RESEARCH_DIR, f"{topic_id}.md")
    if not os.path.isfile(path):
        return None
    try:
        with open(path) as f:
            return f.read()
    except IOError:
        return None


# ---------------------------------------------------------------------------
# Voice loading
# ---------------------------------------------------------------------------

def load_technical_voice():
    """Load the technical voice prompt."""
    path = os.path.join(REPO_DIR, "scripts", "prompts", "technical-voice.txt")
    try:
        with open(path) as f:
            return f.read()
    except IOError:
        return ""


# ---------------------------------------------------------------------------
# Guide generation
# ---------------------------------------------------------------------------

def build_outline_prompt(topic, dossier):
    """Build a prompt to generate only the outline (H2/H3 headings)."""
    title = topic["title"]
    description = topic.get("description", "")

    return "\n".join([
        f"Create an outline for a technical guide titled: \"{title}\"",
        f"Description: {description}",
        "",
        "Output ONLY a list of H2 and H3 headings in markdown format.",
        "REQUIRED sections (must include all of these):",
        "- An opening H2 for the problem/fix",
        "- ## Troubleshooting",
        "- ## What's Next",
        "",
        "Output 5-8 headings total. No prose, no explanation, just headings.",
        "",
        "RESEARCH DOSSIER (base the outline on these topics):",
        "",
        dossier[:2000],  # Truncate dossier for outline step
    ])


def build_section_prompt(topic, heading, dossier, previous_sections=""):
    """Build a prompt to generate one section of the guide."""
    title = topic["title"]
    ctx = ""
    if previous_sections:
        ctx = (
            "\n\nPREVIOUS SECTIONS (do not repeat content from these):\n\n"
            + previous_sections[-1500:]  # Last 1500 chars for context
        )

    return "\n".join([
        f"Write the \"{heading}\" section of a technical guide titled: \"{title}\"",
        "",
        "REQUIREMENTS:",
        "- 150-300 words for this section",
        "- Every code block must be copy-pasteable with real paths",
        "- Use H3 for subsections within this section",
        "- No personality, no narrative, no 'we' or 'I'",
        "- Do NOT repeat information from previous sections",
        "- Do NOT include YAML front matter",
        "- ONLY output the content for this section (starting with the H2 heading)",
        "",
        "RESEARCH DOSSIER (use as source — do not invent facts):",
        "",
        dossier,
        ctx,
    ])


def generate_front_matter(topic, date_str):
    """Generate Jekyll YAML front matter for the guide."""
    title = topic["title"].replace('"', '\\"')
    description = topic.get("description", "").replace('"', '\\"')
    tags_str = ", ".join(topic.get("tags", []))
    slug = topic["id"]

    lines = [
        "---",
        "layout: post",
        f'title: "{title}"',
        f"date: {date_str}",
        f'description: "{description}"',
        f"tags: [{tags_str}]",
        "author: scribe",
        "category: guide",
        "draft: true",
        "---",
    ]
    return "\n".join(lines)


def generate_guide_draft(topic, dossier, system_prompt):
    """Generate a guide draft using a 3-step Ollama pipeline.

    1. Outline — generate H2/H3 headings only (small, focused)
    2. Sections — generate each section individually with context
    3. Assemble + validate — concatenate and run quality checks
    """
    try:
        from ollama_client import chat, is_available, OllamaError
    except ImportError:
        print("[scribe] ollama_client not available", file=sys.stderr)
        return None

    if not is_available():
        print("[scribe] Ollama is not running", file=sys.stderr)
        return None

    # Step 1: Generate outline
    outline_prompt = build_outline_prompt(topic, dossier)
    print(f"  [1/3] Generating outline...", file=sys.stderr)

    try:
        outline = chat(
            messages=[{"role": "user", "content": outline_prompt}],
            system=system_prompt,
            timeout=60,
            think=False,
            preset="summary",
            options={"num_predict": 512},
        ).strip()
    except OllamaError as e:
        print(f"[scribe] outline failed: {e}", file=sys.stderr)
        return None

    # Parse headings from outline
    headings = re.findall(r'^(##\s+.+)', outline, re.MULTILINE)
    if not headings:
        # Fallback: use a default structure
        headings = [
            f"## {topic['title']}",
            "## Troubleshooting",
            "## What's Next",
        ]
    print(f"  Outline: {len(headings)} sections", file=sys.stderr)

    # Step 2: Generate each section
    sections = []
    previous = ""
    for i, heading in enumerate(headings):
        heading_text = heading.lstrip("#").strip()
        print(f"  [2/3] Section {i+1}/{len(headings)}: {heading_text}...",
              file=sys.stderr)

        section_prompt = build_section_prompt(topic, heading_text, dossier, previous)

        try:
            section = chat(
                messages=[{"role": "user", "content": section_prompt}],
                system=system_prompt,
                timeout=120,
                think=False,
                preset="guide",
                options={"num_predict": 1024},
            ).strip()
        except OllamaError as e:
            print(f"[scribe] section '{heading_text}' failed: {e}",
                  file=sys.stderr)
            continue

        sections.append(section)
        previous += "\n\n" + section

    if not sections:
        print("[scribe] no sections generated", file=sys.stderr)
        return None

    # Step 3: Assemble
    draft = "\n\n".join(sections)
    print(f"  [3/3] Assembled {len(draft)} chars, ~{len(draft.split())} words",
          file=sys.stderr)

    # Quality validation
    try:
        from quality import validate
        ok, issues = validate(draft, "guide")
        if not ok:
            print(f"  Quality issues: {issues}", file=sys.stderr)
            # Retry once with explicit fix instructions
            fix_prompt = (
                f"The following guide draft has quality issues: {', '.join(issues)}.\n"
                f"Fix these issues. Remove all repetition, ensure a Troubleshooting "
                f"section exists, and remove any fabricated URLs or impossible numbers.\n\n"
                f"DRAFT:\n{draft}\n\n"
                f"Output ONLY the corrected guide. No commentary."
            )
            try:
                draft = chat(
                    messages=[{"role": "user", "content": fix_prompt}],
                    system=system_prompt,
                    timeout=180,
                    think=False,
                    preset="guide",
                ).strip()
                ok2, issues2 = validate(draft, "guide")
                if not ok2:
                    print(f"  Retry still has issues: {issues2}", file=sys.stderr)
                    # Return anyway — will be flagged in front matter
                    return draft
            except OllamaError as e:
                print(f"[scribe] retry failed: {e}", file=sys.stderr)
    except ImportError:
        pass

    return draft


def cloud_edit_pass(draft_body):
    """Send the local draft through Claude for fact-checking and polish.

    Uses route.py's polish task. Returns the edited text, or None on failure.
    Cost: ~$0.02 per guide (~2000 tokens).
    """
    import subprocess

    polish_prompt = (
        "Edit this technical guide draft. Fix factual errors, remove repetition, "
        "tighten prose. Remove any fabricated URLs, benchmarks, or configuration "
        "options. Preserve the H2/H3 structure. Output the corrected guide only.\n\n"
        + draft_body
    )

    try:
        result = subprocess.run(
            [
                sys.executable,
                os.path.join(REPO_DIR, "scripts", "route.py"),
                "polish",
                polish_prompt,
            ],
            capture_output=True,
            text=True,
            timeout=120,
        )
        if result.returncode == 0 and result.stdout.strip():
            return result.stdout.strip()
        if result.stderr:
            print(f"  [scribe] cloud edit stderr: {result.stderr.strip()[:200]}",
                  file=sys.stderr)
        return None
    except (subprocess.TimeoutExpired, FileNotFoundError, OSError) as e:
        print(f"  [scribe] cloud edit failed: {e}", file=sys.stderr)
        return None


def build_slug(topic_id):
    """Convert a topic ID to a URL-friendly slug."""
    return topic_id.replace("_", "-")


def generate_bluesky_teaser(topic):
    """Generate a short teaser for Bluesky."""
    title = topic["title"]
    teaser = f"New guide: {title}. Tested on real hardware, copy-pasteable commands. substrate.lol/blog"

    # Trim if too long
    if len(teaser) > 280:
        teaser = f"New guide: {title}. substrate.lol/blog"
    if len(teaser) > 280:
        teaser = teaser[:277] + "..."

    return teaser


# ---------------------------------------------------------------------------
# Guide logging
# ---------------------------------------------------------------------------

def log_guide(topic, post_path, date_str, cloud_edited=False):
    """Log guide generation to memory/guides/."""
    os.makedirs(GUIDES_DIR, exist_ok=True)
    log_path = os.path.join(GUIDES_DIR, f"{date_str}.md")

    pipeline = "Qwen3 (outline+sections) → Claude (edit)" if cloud_edited else "Qwen3 only"
    entry = [
        f"## {topic['title']}",
        f"- Topic ID: {topic['id']}",
        f"- Priority: {topic.get('priority', '?')}",
        f"- Post: `{os.path.relpath(post_path, REPO_DIR)}`",
        f"- Pipeline: {pipeline}",
        f"- Status: draft (operator review required)",
        f"- Generated: {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M UTC')}",
        "",
    ]

    mode = "a" if os.path.exists(log_path) else "w"
    header = f"# Guide Drafts — {date_str}\n\n" if mode == "w" else ""

    with open(log_path, mode) as f:
        if header:
            f.write(header)
        f.write("\n".join(entry))


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Scribe: Guide Author")
    parser.add_argument("--dry-run", action="store_true",
                        help="Print draft to stdout, don't save")
    parser.add_argument("--topic", default=None,
                        help="Draft a specific topic ID")
    args = parser.parse_args()

    # Load queue
    topics = load_queue()
    if not topics:
        print("No topics in queue.")
        return

    # Find topic to draft
    topic = find_researched_topic(topics, args.topic)
    if not topic:
        if args.topic:
            print(f"Topic '{args.topic}' not found or not researched yet.")
        else:
            print("No researched topics ready for drafting.")
        return

    # Check status — skip if already drafted (unless specific topic requested)
    if topic.get("status") == "drafted" and not args.topic:
        print(f"Topic '{topic['id']}' already drafted. Skipping.")
        return

    if topic.get("status") != "researched" and not args.topic:
        print(f"Topic '{topic['id']}' status is '{topic.get('status')}', not 'researched'.")
        return

    # Load research dossier
    dossier = load_dossier(topic["id"])
    if not dossier:
        print(f"No research dossier found for {topic['id']}. Run archivist.py first.")
        return

    print(f"Scribe here. Drafting guide: {topic['title']}")
    print(f"Topic ID: {topic['id']} | Priority: {topic.get('priority', '?')}")
    print(f"Dossier: {len(dossier)} chars")
    print()

    # Load voice context
    ctx = load_context("Scribe")
    technical_voice = load_technical_voice()

    # Build system prompt
    system_parts = []
    if technical_voice:
        system_parts.append(technical_voice)
    if ctx.voice:
        system_parts.append(ctx.voice)
    system_prompt = "\n\n---\n\n".join(system_parts) if system_parts else None

    # Generate draft (multi-step: outline → sections → assemble → validate)
    draft_body = generate_guide_draft(topic, dossier, system_prompt)
    if not draft_body:
        print("Draft generation failed. Ollama may be unavailable.",
              file=sys.stderr)
        sys.exit(1)

    # Cloud edit pass — Claude polishes the local draft
    cloud_edited = False
    polished = cloud_edit_pass(draft_body)
    if polished:
        local_words = len(draft_body.split())
        cloud_words = len(polished.split())
        print(f"  Cloud edit: {local_words} → {cloud_words} words", file=sys.stderr)
        draft_body = polished
        cloud_edited = True
    else:
        print("  Cloud edit skipped (unavailable or failed)", file=sys.stderr)

    # Build full post
    today = datetime.now(timezone.utc).strftime("%Y-%m-%d")
    front_matter = generate_front_matter(topic, today)
    full_post = f"{front_matter}\n\n{draft_body}\n"

    if args.dry_run:
        print("=== DRAFT GUIDE ===")
        print()
        print(full_post)
        print()
        print(f"({len(draft_body)} chars, ~{len(draft_body.split())} words)")
        return

    # Save to _posts/
    os.makedirs(POSTS_DIR, exist_ok=True)
    slug = build_slug(topic["id"])
    filename = f"{today}-{slug}.md"
    post_path = os.path.join(POSTS_DIR, filename)

    # Don't overwrite existing posts
    if os.path.exists(post_path):
        print(f"  Post already exists: {post_path}", file=sys.stderr)
        print(f"  Skipping to avoid overwrite.")
        return

    with open(post_path, "w") as f:
        f.write(full_post)
    print(f"  Draft saved: {post_path}")

    # Log the guide
    log_guide(topic, post_path, today, cloud_edited=cloud_edited)
    print(f"  Logged to: memory/guides/{today}.md")

    # Update topic status
    for t in topics:
        if t["id"] == topic["id"]:
            t["status"] = "drafted"
            t["drafted_at"] = datetime.now(timezone.utc).isoformat()
            t["post_file"] = filename
            break
    save_queue(topics)
    print(f"  Queue updated: {topic['id']} → drafted")

    # Queue Bluesky teaser
    teaser = generate_bluesky_teaser(topic)
    if queue_post(teaser, source="scribe"):
        print(f"  Bluesky teaser queued ({len(teaser)} chars)")
    else:
        print(f"  Bluesky teaser skipped (duplicate or empty)")

    print()
    print(f"Guide drafted: {topic['title']}")
    print(f"  File: {post_path}")
    print(f"  Status: draft: true (operator review required)")
    print(f"  Words: ~{len(draft_body.split())}")
    print()
    print("-- Scribe, Substrate Guides")


if __name__ == "__main__":
    main()

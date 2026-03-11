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

def build_generation_prompt(topic, dossier):
    """Build the prompt for Ollama to generate the guide."""
    title = topic["title"]
    tags = topic.get("tags", [])
    description = topic.get("description", "")

    prompt_parts = [
        f"Write a technical guide titled: \"{title}\"",
        "",
        f"Description: {description}",
        f"Tags: {', '.join(tags)}",
        "",
        "REQUIREMENTS:",
        "- Approximately 1500 words",
        "- Start with a one-sentence summary of what the guide covers",
        "- Lead with the error message or problem that brings readers here",
        "- Show the fix immediately, then explain",
        "- Every code block must be copy-pasteable with real paths",
        "- Include a Troubleshooting section with 'error message' — fix format",
        "- Include a What's Next section linking related guides",
        "- Use H2 for major sections, H3 for subsections",
        "- Tables for specs and comparisons, not prose",
        "- No personality, no narrative, no 'we' or 'I'",
        "- Include 'Substrate note:' callouts for project-specific experience",
        "- Do NOT include YAML front matter — just the markdown body",
        "",
        "RESEARCH DOSSIER (use this as your source material — do not invent facts):",
        "",
        dossier,
    ]

    return "\n".join(prompt_parts)


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
    """Generate a guide draft using Ollama."""
    try:
        from ollama_client import chat, is_available, OllamaError
    except ImportError:
        print("[scribe] ollama_client not available", file=sys.stderr)
        return None

    if not is_available():
        print("[scribe] Ollama is not running", file=sys.stderr)
        return None

    prompt = build_generation_prompt(topic, dossier)

    print(f"  Generating draft via Ollama ({len(prompt)} char prompt)...",
          file=sys.stderr)

    try:
        response = chat(
            messages=[{"role": "user", "content": prompt}],
            system=system_prompt,
            timeout=180,
            think=False,
        )
        return response.strip()
    except OllamaError as e:
        print(f"[scribe] Ollama error: {e}", file=sys.stderr)
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

def log_guide(topic, post_path, date_str):
    """Log guide generation to memory/guides/."""
    os.makedirs(GUIDES_DIR, exist_ok=True)
    log_path = os.path.join(GUIDES_DIR, f"{date_str}.md")

    entry = [
        f"## {topic['title']}",
        f"- Topic ID: {topic['id']}",
        f"- Priority: {topic.get('priority', '?')}",
        f"- Post: `{os.path.relpath(post_path, REPO_DIR)}`",
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

    # Generate draft
    draft_body = generate_guide_draft(topic, dossier, system_prompt)
    if not draft_body:
        print("Draft generation failed. Ollama may be unavailable.",
              file=sys.stderr)
        sys.exit(1)

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
    log_guide(topic, post_path, today)
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

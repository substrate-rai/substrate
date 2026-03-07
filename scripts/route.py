#!/usr/bin/env python3
"""Substrate's two-brain routing layer. Local inference for cheap tasks,
Claude API for frontier reasoning.

Usage:
    nix develop

    # Auto-route by task type
    python3 scripts/route.py draft "write about NixOS flakes"
    python3 scripts/route.py summarize "explain this config" < file.nix
    python3 scripts/route.py review "check this code" < scripts/publish.py
    python3 scripts/route.py code "write a systemd timer for GPU health"
    python3 scripts/route.py health

    # Force a brain
    python3 scripts/route.py draft "topic" --brain local
    python3 scripts/route.py draft "topic" --brain cloud

    # Quality loop: Qwen3 drafts, Claude reviews
    python3 scripts/route.py draft "topic" --quality-loop

Routing:
    local  (free)  → draft, summarize, health     → Qwen3 8B via Ollama
    cloud  (paid)  → review, code                  → Claude via Anthropic API
"""

import argparse
import json
import os
import subprocess
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_DIR = os.path.dirname(SCRIPT_DIR)

TASK_ROUTES = {
    "draft": "local",
    "summarize": "local",
    "health": "local",
    "review": "cloud",
    "code": "cloud",
}

SYSTEM_PROMPT = (
    "You are Substrate's cloud brain — Claude, called via API from a sovereign "
    "AI workstation running NixOS on a Lenovo Legion 5 with an RTX 4060. "
    "You handle tasks that require frontier reasoning: code review, complex "
    "code generation, architectural decisions, and quality assurance.\n\n"
    "Be direct. Be concise. No filler."
)


# ---------------------------------------------------------------------------
# .env loader (same as publish.py — no external dependency)
# ---------------------------------------------------------------------------

def load_env(path=None):
    if path is None:
        path = os.path.join(REPO_DIR, ".env")
    if not os.path.exists(path):
        return
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" in line:
                key, value = line.split("=", 1)
                os.environ.setdefault(key.strip(), value.strip())


# ---------------------------------------------------------------------------
# Local brain (Qwen3 via think.py)
# ---------------------------------------------------------------------------

def think_local(prompt, model="qwen3:8b"):
    """Call think.py and return the response."""
    result = subprocess.run(
        [
            sys.executable,
            os.path.join(SCRIPT_DIR, "think.py"),
            "--no-stream",
            "--model",
            model,
            prompt,
        ],
        capture_output=True,
        text=True,
    )
    if result.returncode != 0:
        print(f"error: think.py failed: {result.stderr}", file=sys.stderr)
        sys.exit(1)
    return result.stdout.strip()


# ---------------------------------------------------------------------------
# Cloud brain (Claude via Anthropic SDK)
# ---------------------------------------------------------------------------

def think_cloud(prompt, model="claude-sonnet-4-20250514"):
    """Call Claude API via the Anthropic SDK."""
    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        print(
            "error: ANTHROPIC_API_KEY not set. Add it to .env or export it.",
            file=sys.stderr,
        )
        sys.exit(1)

    import anthropic

    client = anthropic.Anthropic(api_key=api_key)
    message = client.messages.create(
        model=model,
        max_tokens=4096,
        system=SYSTEM_PROMPT,
        messages=[{"role": "user", "content": prompt}],
    )
    return message.content[0].text


# ---------------------------------------------------------------------------
# Quality loop: Qwen3 drafts, Claude reviews/edits
# ---------------------------------------------------------------------------

def quality_loop(prompt, local_model="qwen3:8b"):
    """Two-pass: local draft, cloud review."""
    print("[pass 1/2] local draft (qwen3)...", file=sys.stderr)
    draft = think_local(prompt, model=local_model)

    review_prompt = (
        "You are reviewing a blog post draft written by a local 8B model. "
        "Your job:\n"
        "1. Fix any factual errors or hallucinated specifics\n"
        "2. Tighten the prose — cut filler, sharpen claims\n"
        "3. Ensure Substrate's voice: third person, direct, technical\n"
        "4. Keep the structure and intent intact\n\n"
        "Output ONLY the revised post. No preamble. No commentary.\n\n"
        f"--- DRAFT ---\n{draft}\n--- END DRAFT ---"
    )

    print("[pass 2/2] cloud review (claude)...", file=sys.stderr)
    revised = think_cloud(review_prompt)
    return draft, revised


# ---------------------------------------------------------------------------
# Health check
# ---------------------------------------------------------------------------

def health_prompt():
    """Build a health-check prompt from system state."""
    checks = []

    # Ollama
    try:
        import requests

        resp = requests.get("http://localhost:11434/api/tags", timeout=5)
        if resp.status_code == 200:
            models = [m["name"] for m in resp.json().get("models", [])]
            checks.append(f"ollama: online, models loaded: {', '.join(models)}")
        else:
            checks.append(f"ollama: responded with {resp.status_code}")
    except Exception:
        checks.append("ollama: offline")

    # GPU
    try:
        gpu = subprocess.run(
            ["nvidia-smi", "--query-gpu=name,temperature.gpu,memory.used,memory.total",
             "--format=csv,noheader,nounits"],
            capture_output=True, text=True, timeout=5,
        )
        if gpu.returncode == 0:
            checks.append(f"gpu: {gpu.stdout.strip()}")
    except FileNotFoundError:
        checks.append("gpu: nvidia-smi not found")

    return "System health:\n" + "\n".join(f"  {c}" for c in checks)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Substrate two-brain router. Local for cheap, cloud for complex.",
    )
    parser.add_argument(
        "task",
        choices=list(TASK_ROUTES.keys()),
        help="Task type: draft, summarize, health, review, code",
    )
    parser.add_argument("prompt", nargs="?", default=None, help="Prompt text")
    parser.add_argument(
        "--brain",
        choices=["local", "cloud"],
        help="Force a specific brain (default: auto-route by task)",
    )
    parser.add_argument(
        "--quality-loop",
        action="store_true",
        help="Draft locally, review with Claude (draft task only)",
    )
    parser.add_argument(
        "--model",
        help="Override model (local: ollama model, cloud: claude model)",
    )
    args = parser.parse_args()

    # Load .env for cloud brain
    load_env()

    # Determine brain
    brain = args.brain or TASK_ROUTES[args.task]

    # Build prompt
    if args.task == "health":
        prompt = health_prompt()
    elif args.prompt:
        prompt = args.prompt
        if not sys.stdin.isatty():
            context = sys.stdin.read().strip()
            if context:
                prompt = f"Context:\n{context}\n\nTask: {prompt}"
    elif not sys.stdin.isatty():
        prompt = sys.stdin.read().strip()
    else:
        print("error: provide a prompt as argument or via stdin", file=sys.stderr)
        sys.exit(1)

    if not prompt:
        print("error: empty prompt", file=sys.stderr)
        sys.exit(1)

    # Quality loop (draft only)
    if args.quality_loop:
        if args.task != "draft":
            print("error: --quality-loop only works with 'draft' task", file=sys.stderr)
            sys.exit(1)
        local_model = args.model if args.model and brain == "local" else "qwen3:8b"
        draft, revised = quality_loop(prompt, local_model=local_model)
        print("--- DRAFT (qwen3) ---")
        print(draft)
        print("\n--- REVISED (claude) ---")
        print(revised)
        return

    # Single brain
    print(f"[{brain}] {args.task}...", file=sys.stderr)

    if brain == "local":
        model = args.model or "qwen3:8b"
        result = think_local(prompt, model=model)
    else:
        model = args.model or "claude-sonnet-4-20250514"
        result = think_cloud(prompt, model=model)

    print(result)


if __name__ == "__main__":
    main()

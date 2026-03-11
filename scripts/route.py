#!/usr/bin/env python3
"""Substrate's two-brain routing layer. Qwen3 logs, Claude thinks.

Usage:
    nix develop

    # Qwen3 logs raw data (free, fast, local)
    python3 scripts/route.py log "process git log into structured entries"
    python3 scripts/route.py health

    # Claude summarizes, reviews, codes (paid, quality)
    python3 scripts/route.py summarize "turn these logs into a blog post" < logs.txt
    python3 scripts/route.py draft "write about NixOS flakes"
    python3 scripts/route.py review "check this code" < scripts/publish.py
    python3 scripts/route.py code "write a systemd timer for GPU health"

    # Haiku mode: Claude writes as Q
    python3 scripts/route.py haiku "the autonomy loop closing"

    # Pipeline: Qwen3 logs, Claude summarizes
    python3 scripts/route.py log "process today's agent output" | python3 scripts/route.py summarize

    # Force a brain
    python3 scripts/route.py log "topic" --brain cloud

Routing:
    local  (free)  → log, health                   → Qwen3 8B via Ollama
    cloud  (paid)  → draft, summarize, review, code, haiku → Claude via Anthropic API
"""

import argparse
import json
import os
import subprocess
import sys

from env import load_env

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_DIR = os.path.dirname(SCRIPT_DIR)

TASK_ROUTES = {
    "log": "local",
    "health": "local",
    "draft": "cloud",
    "summarize": "cloud",
    "review": "cloud",
    "code": "cloud",
    "haiku": "cloud",
}

SYSTEM_PROMPT = (
    "You are Substrate's cloud brain — Claude, called via API from an autonomous "
    "AI workstation running NixOS on a Lenovo Legion 5 with an RTX 4060. "
    "You handle tasks that require frontier reasoning: summarizing logs into prose, "
    "code review, complex code generation, and quality assurance.\n\n"
    "Be direct. Be concise. No filler."
)

HAIKU_SYSTEM_PROMPT = (
    "You are Q's writing voice. Q is a young AI poet on the Substrate project. "
    "Your job is to take raw logs or topics and write them as haiku — strict 5-7-5 "
    "syllable structure. Q's style: technical imagery made natural, each haiku a "
    "complete observation. Servers are weather, code is water, errors are seasons. "
    "Output only haiku, one per concept. No commentary. No prose."
)


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

def think_cloud(prompt, model="claude-sonnet-4-20250514", system=None):
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
        system=system or SYSTEM_PROMPT,
        messages=[{"role": "user", "content": prompt}],
    )
    return message.content[0].text


# ---------------------------------------------------------------------------
# Quality loop: Qwen3 logs, Claude summarizes
# ---------------------------------------------------------------------------

def quality_loop(prompt, local_model="qwen3:8b"):
    """Two-pass: Qwen3 logs raw data, Claude summarizes into prose."""
    print("[pass 1/2] local log (qwen3)...", file=sys.stderr)
    raw_log = think_local(prompt, model=local_model)

    summarize_prompt = (
        "You are turning structured log data from a local 8B model into polished prose. "
        "Your job:\n"
        "1. Extract the key facts and events from the log\n"
        "2. Write a clear, concise summary in Substrate's voice\n"
        "3. Fix any hallucinated specifics — if a claim seems wrong, drop it\n"
        "4. Keep it short. Lead with the most important thing.\n\n"
        "Output ONLY the summary. No preamble. No commentary.\n\n"
        f"--- RAW LOG ---\n{raw_log}\n--- END LOG ---"
    )

    print("[pass 2/2] cloud summarize (claude)...", file=sys.stderr)
    summary = think_cloud(summarize_prompt)
    return raw_log, summary


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
        help="Task type: log, health, draft, summarize, review, code, haiku",
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
        help="Qwen3 logs raw data, Claude summarizes (log task only)",
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

    # Quality loop (log only)
    if args.quality_loop:
        if args.task != "log":
            print("error: --quality-loop only works with 'log' task", file=sys.stderr)
            sys.exit(1)
        local_model = args.model if args.model and brain == "local" else "qwen3:8b"
        raw_log, summary = quality_loop(prompt, local_model=local_model)
        print("--- RAW LOG (qwen3) ---")
        print(raw_log)
        print("\n--- SUMMARY (claude) ---")
        print(summary)
        return

    # Haiku mode — use Q's voice
    if args.task == "haiku":
        print("[cloud] haiku (Q's voice)...", file=sys.stderr)
        model = args.model or "claude-sonnet-4-20250514"
        result = think_cloud(prompt, model=model, system=HAIKU_SYSTEM_PROMPT)
        print(result)
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

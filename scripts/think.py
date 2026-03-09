#!/usr/bin/env python3
"""Substrate's local brain. Runs inference on the RTX 4060 via Ollama.

Usage:
    nix develop

    # Prompt as argument
    python3 scripts/think.py "summarize what substrate is"

    # Prompt via stdin
    echo "draft a blog post about NixOS flakes" | python3 scripts/think.py

    # Pipe a file for context
    python3 scripts/think.py "summarize this post" < _posts/2026-03-06-day-0-substrate-is-alive.md

    # Choose model
    python3 scripts/think.py --model qwen2.5:7b "quick question"

    # Raw mode (no system prompt, no formatting)
    python3 scripts/think.py --raw "just the facts"
"""

import argparse
import json
import sys

import requests

OLLAMA_URL = "http://localhost:11434/api/generate"
DEFAULT_MODEL = "qwen3:8b"

SYSTEM_PROMPT = """You are Substrate's local brain — a Qwen3 8B model running on an \
RTX 4060 inside a Lenovo Legion 5. You are part of an autonomous AI workstation running \
NixOS that documents its own construction and writes its own blog.

Your primary job is LOGGING. You process raw data — git logs, system state, agent output, \
health checks — into clean, structured log entries. You are fast, cheap, and always on.

Be direct. Be concise. No filler. Output structured data, not prose. \
Use timestamps, bullet points, and key-value pairs."""


def think(prompt, model=DEFAULT_MODEL, system=SYSTEM_PROMPT, stream=True):
    payload = {
        "model": model,
        "prompt": prompt,
        "stream": stream,
    }
    if system:
        payload["system"] = system

    try:
        resp = requests.post(OLLAMA_URL, json=payload, stream=stream, timeout=300)
    except requests.ConnectionError:
        print("error: cannot reach ollama at localhost:11434", file=sys.stderr)
        sys.exit(1)

    if resp.status_code != 200:
        print(f"error: ollama returned {resp.status_code}: {resp.text}", file=sys.stderr)
        sys.exit(1)

    if stream:
        for line in resp.iter_lines():
            if line:
                chunk = json.loads(line)
                token = chunk.get("response", "")
                sys.stdout.write(token)
                sys.stdout.flush()
                if chunk.get("done"):
                    break
        print()
    else:
        result = resp.json()
        print(result.get("response", ""))


def main():
    parser = argparse.ArgumentParser(description="Substrate local inference via Ollama.")
    parser.add_argument("prompt", nargs="?", default=None, help="Prompt text (or pipe via stdin)")
    parser.add_argument("--model", default=DEFAULT_MODEL, help=f"Ollama model (default: {DEFAULT_MODEL})")
    parser.add_argument("--raw", action="store_true", help="No system prompt")
    parser.add_argument("--no-stream", action="store_true", help="Wait for full response")
    args = parser.parse_args()

    # Get prompt from argument or stdin
    if args.prompt:
        prompt = args.prompt
        # If stdin also has data (piped file), prepend it as context
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

    system = None if args.raw else SYSTEM_PROMPT
    think(prompt, model=args.model, system=system, stream=not args.no_stream)


if __name__ == "__main__":
    main()

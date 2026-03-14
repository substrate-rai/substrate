#!/usr/bin/env python3
"""Substrate Chat UI — local web interface for talking to Claude.

Serves a mycopunk-styled chat page and proxies requests to the Anthropic API.
Uses only stdlib + requests (available in nix develop shell).

Usage:
    python3 scripts/chat-ui.py [--port 8080]

Requires ANTHROPIC_API_KEY in .env or environment.
"""

import http.server
import json
import os
import sys
import threading
import urllib.request

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_DIR = os.path.dirname(SCRIPT_DIR)
HTML_PATH = os.path.join(SCRIPT_DIR, "chat-ui.html")
DEFAULT_PORT = 8080
API_URL = "https://api.anthropic.com/v1/messages"
MODEL = "claude-sonnet-4-20250514"
MAX_TOKENS = 8192

# System prompt — substrate identity
SYSTEM_PROMPT = (
    "You are Claude, the managing intelligence of Substrate — a sovereign AI workstation "
    "running on a Lenovo Legion 5 with NixOS. You speak directly, with warmth but no filler. "
    "You know the repo, the agents, the architecture. Keep answers concise unless asked to elaborate."
)


def load_env():
    env_path = os.path.join(REPO_DIR, ".env")
    if os.path.exists(env_path):
        with open(env_path) as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith("#") and "=" in line:
                    key, value = line.split("=", 1)
                    os.environ.setdefault(key.strip(), value.strip())


def call_claude(messages):
    api_key = os.environ.get("ANTHROPIC_API_KEY")
    if not api_key:
        return {"error": "ANTHROPIC_API_KEY not set"}

    payload = json.dumps({
        "model": MODEL,
        "max_tokens": MAX_TOKENS,
        "system": SYSTEM_PROMPT,
        "messages": messages,
    }).encode()

    req = urllib.request.Request(
        API_URL,
        data=payload,
        headers={
            "Content-Type": "application/json",
            "x-api-key": api_key,
            "anthropic-version": "2023-06-01",
        },
    )

    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        body = e.read().decode()
        return {"error": f"API error {e.code}: {body}"}
    except Exception as e:
        return {"error": str(e)}


class ChatHandler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path in ("/", "/index.html"):
            self.send_response(200)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            with open(HTML_PATH, "rb") as f:
                self.wfile.write(f.read())
        else:
            self.send_error(404)

    def do_POST(self):
        if self.path == "/api/chat":
            length = int(self.headers.get("Content-Length", 0))
            body = json.loads(self.rfile.read(length))
            messages = body.get("messages", [])
            result = call_claude(messages)

            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.end_headers()
            self.wfile.write(json.dumps(result).encode())
        else:
            self.send_error(404)

    def log_message(self, fmt, *args):
        print(f"[chat-ui] {args[0]}", file=sys.stderr)


def main():
    import argparse
    parser = argparse.ArgumentParser(description="Substrate Chat UI")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT)
    args = parser.parse_args()

    load_env()

    if not os.environ.get("ANTHROPIC_API_KEY"):
        print("error: ANTHROPIC_API_KEY not set in .env or environment", file=sys.stderr)
        sys.exit(1)

    server = http.server.HTTPServer(("127.0.0.1", args.port), ChatHandler)
    print(f"[chat-ui] serving on http://127.0.0.1:{args.port}", file=sys.stderr)
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[chat-ui] shutting down", file=sys.stderr)
        server.shutdown()


if __name__ == "__main__":
    main()

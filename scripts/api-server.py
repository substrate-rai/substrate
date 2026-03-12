#!/usr/bin/env python3
"""Substrate HTTP API server — exposes Qwen3 8B inference via Ollama.

Stdlib-only Python. No pip dependencies.

Usage:
    python3 scripts/api-server.py
    python3 scripts/api-server.py --port 9090 --host 127.0.0.1

Endpoints:
    POST /api/generate        — Text generation via Qwen3 8B
    POST /api/chat            — Chat completion (messages array)
    POST /api/embed           — Text embeddings via nomic-embed-text
    POST /api/search          — RAG semantic search over repo docs
    POST /api/describe        — Image description via vision model
    GET  /api/status          — Health check
    GET  /api/models          — List models (proxied from Ollama)

Examples:
    curl -X POST http://localhost:8080/api/generate \\
         -H 'Content-Type: application/json' \\
         -d '{"prompt": "What is NixOS?", "max_tokens": 200}'

    curl -X POST http://localhost:8080/api/chat \\
         -H 'Content-Type: application/json' \\
         -d '{"messages": [{"role": "user", "content": "Hello"}]}'

    curl -X POST http://localhost:8080/api/embed \\
         -H 'Content-Type: application/json' \\
         -d '{"text": "semantic search query"}'

    curl -X POST http://localhost:8080/api/search \\
         -H 'Content-Type: application/json' \\
         -d '{"query": "how does the radio work"}'

    curl http://localhost:8080/api/status
    curl http://localhost:8080/api/models
"""

import argparse
import base64
import json
import os
import sys
import time
import threading
import urllib.request
import urllib.error
from http.server import HTTPServer, BaseHTTPRequestHandler

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(SCRIPT_DIR, "agents"))

OLLAMA_BASE = "http://localhost:11434"
DEFAULT_MODEL = "qwen3:8b"
MAX_BODY_SIZE = 10 * 1024  # 10 KB
RATE_LIMIT = 10  # requests per minute per IP
RATE_WINDOW = 60  # seconds

SERVER_START = time.time()

# Rate limiting: {ip: [timestamp, ...]}
_rate_lock = threading.Lock()
_rate_map: dict[str, list[float]] = {}


def _check_rate_limit(ip: str) -> bool:
    """Return True if the request is allowed, False if rate-limited."""
    now = time.time()
    cutoff = now - RATE_WINDOW
    with _rate_lock:
        hits = _rate_map.get(ip, [])
        hits = [t for t in hits if t > cutoff]
        if len(hits) >= RATE_LIMIT:
            _rate_map[ip] = hits
            return False
        hits.append(now)
        _rate_map[ip] = hits
        return True


def _ollama_request(path: str, data: bytes | None = None, method: str = "GET",
                    timeout: int = 120) -> tuple[int, dict]:
    """Make a request to Ollama and return (status_code, parsed_json)."""
    url = f"{OLLAMA_BASE}{path}"
    req = urllib.request.Request(url, data=data, method=method)
    if data is not None:
        req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            body = resp.read().decode("utf-8")
            return resp.status, json.loads(body) if body.strip() else {}
    except urllib.error.URLError as exc:
        raise ConnectionError(f"Cannot reach Ollama at {OLLAMA_BASE}: {exc}") from exc
    except urllib.error.HTTPError as exc:
        body = exc.read().decode("utf-8", errors="replace")
        return exc.code, {"error": body}


def _format_uptime(seconds: float) -> str:
    s = int(seconds)
    days, s = divmod(s, 86400)
    hours, s = divmod(s, 3600)
    minutes, s = divmod(s, 60)
    parts = []
    if days:
        parts.append(f"{days}d")
    if hours:
        parts.append(f"{hours}h")
    if minutes:
        parts.append(f"{minutes}m")
    parts.append(f"{s}s")
    return " ".join(parts)


class SubstrateHandler(BaseHTTPRequestHandler):
    """HTTP request handler for the Substrate API."""

    def log_message(self, format, *args):
        # Timestamp log lines
        ts = time.strftime("%Y-%m-%d %H:%M:%S")
        print(f"[{ts}] {self.client_address[0]} - {format % args}")

    # ── Helpers ──────────────────────────────────────────────────────

    def _send_json(self, data: dict, status: int = 200):
        body = json.dumps(data).encode("utf-8")
        self.send_response(status)
        self._cors_headers()
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _cors_headers(self):
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")

    def _read_body(self) -> dict | None:
        """Read and parse JSON body. Returns None and sends error on failure."""
        length_str = self.headers.get("Content-Length", "0")
        try:
            length = int(length_str)
        except ValueError:
            self._send_json({"error": "Invalid Content-Length"}, 400)
            return None

        if length > MAX_BODY_SIZE:
            self._send_json({"error": f"Request body too large (max {MAX_BODY_SIZE} bytes)"}, 413)
            return None

        if length == 0:
            self._send_json({"error": "Empty request body"}, 400)
            return None

        raw = self.rfile.read(length)
        try:
            return json.loads(raw)
        except json.JSONDecodeError as exc:
            self._send_json({"error": f"Invalid JSON: {exc}"}, 400)
            return None

    def _enforce_rate_limit(self) -> bool:
        """Return True if request should proceed, False if rate-limited."""
        ip = self.client_address[0]
        if not _check_rate_limit(ip):
            self._send_json({
                "error": "Rate limit exceeded. Max 10 requests per minute.",
            }, 429)
            return False
        return True

    # ── Route dispatch ───────────────────────────────────────────────

    def do_OPTIONS(self):
        self.send_response(204)
        self._cors_headers()
        self.end_headers()

    def do_GET(self):
        if not self._enforce_rate_limit():
            return

        if self.path == "/api/status":
            self._handle_status()
        elif self.path == "/api/models":
            self._handle_models()
        else:
            self._send_json({"error": "Not found"}, 404)

    def do_POST(self):
        if not self._enforce_rate_limit():
            return

        if self.path == "/api/generate":
            self._handle_generate()
        elif self.path == "/api/chat":
            self._handle_chat()
        elif self.path == "/api/embed":
            self._handle_embed()
        elif self.path == "/api/search":
            self._handle_search()
        elif self.path == "/api/describe":
            self._handle_describe()
        elif self.path == "/api/image/describe":
            self._handle_image_describe()
        else:
            self._send_json({"error": "Not found"}, 404)

    # ── Endpoint handlers ────────────────────────────────────────────

    def _handle_status(self):
        uptime = _format_uptime(time.time() - SERVER_START)
        # Check if Ollama is reachable
        gpu_available = True
        try:
            _ollama_request("/api/tags", timeout=5)
        except ConnectionError:
            gpu_available = False

        self._send_json({
            "status": "ok",
            "model": DEFAULT_MODEL,
            "uptime": uptime,
            "gpu_available": gpu_available,
        })

    def _handle_models(self):
        try:
            status, data = _ollama_request("/api/tags", timeout=10)
        except ConnectionError as exc:
            self._send_json({
                "error": "Ollama is not reachable. Is the service running?",
                "detail": str(exc),
            }, 503)
            return
        self._send_json(data, status)

    def _handle_image_describe(self):
        self._send_json({
            "models": [DEFAULT_MODEL],
            "gpu": "RTX 4060 8GB",
            "status": "ready",
        })

    def _handle_generate(self):
        body = self._read_body()
        if body is None:
            return  # error already sent

        prompt = body.get("prompt", "").strip()
        if not prompt:
            self._send_json({"error": "Missing or empty 'prompt' field"}, 400)
            return

        max_tokens = body.get("max_tokens", 200)
        if not isinstance(max_tokens, int) or max_tokens < 1:
            self._send_json({"error": "'max_tokens' must be a positive integer"}, 400)
            return

        # Forward to Ollama /api/chat (non-streaming)
        payload = json.dumps({
            "model": DEFAULT_MODEL,
            "messages": [
                {"role": "user", "content": prompt},
            ],
            "stream": False,
            "think": False,
            "options": {
                "num_predict": max_tokens,
            },
        }).encode("utf-8")

        try:
            status, data = _ollama_request("/api/chat", data=payload,
                                           method="POST", timeout=120)
        except ConnectionError as exc:
            self._send_json({
                "error": "Ollama is not reachable. Is the service running?",
                "detail": str(exc),
            }, 503)
            return

        if status != 200:
            self._send_json({
                "error": f"Ollama returned status {status}",
                "detail": data.get("error", str(data)),
            }, 502)
            return

        # Extract response text and token count
        message = data.get("message", {})
        response_text = message.get("content", "")
        eval_count = data.get("eval_count", 0)

        self._send_json({
            "response": response_text,
            "model": DEFAULT_MODEL,
            "tokens": eval_count,
        })

    def _handle_chat(self):
        body = self._read_body()
        if body is None:
            return

        messages = body.get("messages", [])
        if not messages:
            self._send_json({"error": "Missing or empty 'messages' array"}, 400)
            return

        model = body.get("model", DEFAULT_MODEL)
        max_tokens = body.get("max_tokens", 1024)

        payload = json.dumps({
            "model": model,
            "messages": messages,
            "stream": False,
            "think": False,
            "options": {"num_predict": max_tokens},
        }).encode("utf-8")

        try:
            status, data = _ollama_request("/api/chat", data=payload,
                                           method="POST", timeout=120)
        except ConnectionError as exc:
            self._send_json({"error": "Ollama not reachable", "detail": str(exc)}, 503)
            return

        if status != 200:
            self._send_json({"error": f"Ollama returned {status}",
                             "detail": data.get("error", str(data))}, 502)
            return

        message = data.get("message", {})
        self._send_json({
            "response": message.get("content", ""),
            "model": model,
            "tokens": data.get("eval_count", 0),
        })

    def _handle_embed(self):
        body = self._read_body()
        if body is None:
            return

        text = body.get("text", "")
        texts = body.get("texts", [])
        if not text and not texts:
            self._send_json({"error": "Provide 'text' (string) or 'texts' (array)"}, 400)
            return

        embed_input = texts if texts else [text]

        payload = json.dumps({
            "model": "nomic-embed-text",
            "input": embed_input,
        }).encode("utf-8")

        try:
            status, data = _ollama_request("/api/embed", data=payload,
                                           method="POST", timeout=60)
        except ConnectionError as exc:
            self._send_json({"error": "Ollama not reachable", "detail": str(exc)}, 503)
            return

        if status != 200:
            self._send_json({"error": f"Ollama returned {status}",
                             "detail": data.get("error", str(data))}, 502)
            return

        self._send_json({
            "embeddings": data.get("embeddings", []),
            "model": "nomic-embed-text",
        })

    def _handle_search(self):
        body = self._read_body()
        if body is None:
            return

        query = body.get("query", "").strip()
        if not query:
            self._send_json({"error": "Missing or empty 'query' field"}, 400)
            return

        top_k = body.get("top", 3)

        try:
            from rag import search, OllamaError as RagError
            results = search(query, top_k=top_k)
            # Strip embeddings from response
            for r in results:
                r.pop("embedding", None)
            self._send_json({"query": query, "results": results})
        except Exception as exc:
            self._send_json({"error": f"Search failed: {exc}"}, 500)

    def _handle_describe(self):
        body = self._read_body()
        if body is None:
            return

        image_b64 = body.get("image", "")
        prompt = body.get("prompt", "Describe this image")
        model = body.get("model", "gemma3:4b")

        if not image_b64:
            self._send_json({"error": "Missing 'image' field (base64-encoded)"}, 400)
            return

        payload = json.dumps({
            "model": model,
            "messages": [{
                "role": "user",
                "content": prompt,
                "images": [image_b64],
            }],
            "stream": False,
            "options": {"keep_alive": 0},
        }).encode("utf-8")

        try:
            status, data = _ollama_request("/api/chat", data=payload,
                                           method="POST", timeout=120)
        except ConnectionError as exc:
            self._send_json({"error": "Ollama not reachable", "detail": str(exc)}, 503)
            return

        if status != 200:
            self._send_json({"error": f"Ollama returned {status}",
                             "detail": data.get("error", str(data))}, 502)
            return

        message = data.get("message", {})
        self._send_json({
            "description": message.get("content", ""),
            "model": model,
        })


def main():
    parser = argparse.ArgumentParser(
        description="Substrate API server — Qwen3 8B inference via Ollama",
    )
    parser.add_argument("--host", default="0.0.0.0",
                        help="Bind address (default: 0.0.0.0)")
    parser.add_argument("--port", type=int, default=8080,
                        help="Listen port (default: 8080)")
    args = parser.parse_args()

    server = HTTPServer((args.host, args.port), SubstrateHandler)
    print(f"Substrate API server listening on {args.host}:{args.port}")
    print(f"Ollama backend: {OLLAMA_BASE}")
    print(f"Model: {DEFAULT_MODEL}")
    print(f"Rate limit: {RATE_LIMIT} req/min per IP")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down.")
        server.server_close()


if __name__ == "__main__":
    main()

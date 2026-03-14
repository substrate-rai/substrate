#!/usr/bin/env bash
# Launch Substrate Chat UI — starts the server and opens Firefox
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
PORT=8080

# Kill any existing instance
pkill -f "chat-ui.py" 2>/dev/null || true
sleep 0.5

# Start server in background
cd "$REPO_DIR"
nix develop --command python3 "$SCRIPT_DIR/chat-ui.py" --port "$PORT" &
SERVER_PID=$!

# Wait for server to be ready
for i in $(seq 1 20); do
    if curl -s "http://127.0.0.1:$PORT" >/dev/null 2>&1; then
        break
    fi
    sleep 0.25
done

# Open in Firefox
firefox "http://127.0.0.1:$PORT" &

echo "Chat UI running on http://127.0.0.1:$PORT (PID $SERVER_PID)"
wait $SERVER_PID

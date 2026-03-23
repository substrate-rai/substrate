#!/usr/bin/env python3
"""Send a notification to the Substrate desktop shell.

Usage:
    python3 scripts/notify.py "Title" "Body text" [category] [duration]

Categories: info (default), warning, error, system
Duration: seconds (default 5.0)

Examples:
    python3 scripts/notify.py "Build Complete" "All tests passed"
    python3 scripts/notify.py "Low Battery" "15% remaining" warning 8
    python3 scripts/notify.py "Deploy Failed" "Exit code 1" error 10
"""

import json, socket, sys

HOST, PORT = "127.0.0.1", 9877

title = sys.argv[1] if len(sys.argv) > 1 else "Test"
body = sys.argv[2] if len(sys.argv) > 2 else ""
category = sys.argv[3] if len(sys.argv) > 3 else "info"
duration = float(sys.argv[4]) if len(sys.argv) > 4 else 5.0

msg = json.dumps({
    "type": "notify",
    "params": {"title": title, "body": body, "category": category, "duration": duration}
}) + "\n"

with socket.create_connection((HOST, PORT), timeout=2) as s:
    s.sendall(msg.encode())
    print(s.recv(1024).decode().strip())

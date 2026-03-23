#!/usr/bin/env python3
"""Hot-reload a shader in the Godot desktop shell without restarting.

Usage:
    python3 reload_shader.py              # reload current shader
    python3 reload_shader.py riemann_zeta # load specific shader
"""

import json, socket, sys

shader = sys.argv[1] if len(sys.argv) > 1 else ""
cmd = {"type": "reload_shader", "params": {"shader": shader}}

with socket.create_connection(("127.0.0.1", 9877), timeout=5) as s:
    s.sendall((json.dumps(cmd) + "\n").encode())
    print(s.recv(4096).decode().strip())

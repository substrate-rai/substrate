#!/usr/bin/env python3
"""Toggle the Godot task switcher via TCP."""
import json, socket
msg = json.dumps({"type": "task_switch", "params": {}}) + "\n"
try:
    with socket.create_connection(("127.0.0.1", 9877), timeout=2) as s:
        s.sendall(msg.encode())
        print(s.recv(1024).decode().strip())
except ConnectionRefusedError:
    pass

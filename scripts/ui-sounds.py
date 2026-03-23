#!/usr/bin/env python3
"""UI sound daemon — plays DS-style sounds on i3 window events.

Subscribes to i3 IPC events and plays short wav files via paplay.
Run as: python3 scripts/ui-sounds.py &
"""

import subprocess
import json
import socket
import struct
import os

SOUNDS_DIR = os.path.expanduser("~/substrate/assets/sounds")
I3_SOCKET = None

def get_i3_socket():
    """Find the i3 IPC socket path."""
    result = subprocess.run(["i3", "--get-socketpath"], capture_output=True, text=True)
    return result.stdout.strip()

def play(name):
    """Play a sound file asynchronously."""
    path = os.path.join(SOUNDS_DIR, f"{name}.wav")
    if os.path.exists(path):
        subprocess.Popen(["paplay", path], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

def i3_ipc_send(sock, msg_type, payload=""):
    """Send an i3 IPC message."""
    magic = b"i3-ipc"
    encoded = payload.encode()
    header = magic + struct.pack("<II", len(encoded), msg_type)
    sock.sendall(header + encoded)

def i3_ipc_recv(sock):
    """Receive an i3 IPC message."""
    header = b""
    while len(header) < 14:
        header += sock.recv(14 - len(header))
    magic = header[:6]
    if magic != b"i3-ipc":
        return None, None
    length, msg_type = struct.unpack("<II", header[6:14])
    payload = b""
    while len(payload) < length:
        payload += sock.recv(length - len(payload))
    return msg_type, json.loads(payload.decode())

def main():
    socket_path = get_i3_socket()
    if not socket_path:
        print("Could not find i3 socket")
        return

    sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
    sock.connect(socket_path)

    # Subscribe to window events (type 2 = subscribe)
    i3_ipc_send(sock, 2, '["window"]')
    _, reply = i3_ipc_recv(sock)
    if not reply or not reply.get("success"):
        print("Failed to subscribe to i3 events")
        return

    print(f"UI sounds daemon listening on {socket_path}")
    print(f"Sounds dir: {SOUNDS_DIR}")

    while True:
        try:
            msg_type, data = i3_ipc_recv(sock)
            if data is None:
                break

            change = data.get("change", "")
            container = data.get("container", {})
            win_class = ""
            if container.get("window_properties"):
                win_class = container["window_properties"].get("class", "")

            # Skip Godot wallpaper
            if win_class == "Godot":
                continue

            if change == "new":
                play("open")
            elif change == "close":
                play("close")
            elif change == "focus":
                play("focus")

        except (ConnectionError, BrokenPipeError):
            break
        except Exception as e:
            print(f"Error: {e}")
            continue

if __name__ == "__main__":
    main()

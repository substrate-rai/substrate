#!/usr/bin/env python3
"""D-Bus Notification Bridge for Substrate Desktop Shell.

Implements org.freedesktop.Notifications on D-Bus so that standard
notify-send / libnotify calls get forwarded to the Godot shell via TCP.

Usage:
    python3 scripts/notify_bridge.py

Requires: dbus-next (pip install dbus-next)
"""

import asyncio
import json
import sys

try:
    from dbus_next.aio import MessageBus
    from dbus_next.service import ServiceInterface, method, signal as dbus_signal
    from dbus_next import Variant, BusType
except ImportError:
    print("ERROR: dbus-next not installed. Run: pip install dbus-next", file=sys.stderr)
    sys.exit(1)

GODOT_HOST = "127.0.0.1"
GODOT_PORT = 9877
NOTIFICATION_ID_COUNTER = 0


async def send_to_godot(title: str, body: str, category: str = "info", duration: float = 5.0):
    """Send a notification to the Godot desktop shell via TCP."""
    msg = json.dumps({
        "type": "notify",
        "params": {
            "title": title,
            "body": body,
            "category": category,
            "duration": duration,
        }
    }) + "\n"

    try:
        reader, writer = await asyncio.wait_for(
            asyncio.open_connection(GODOT_HOST, GODOT_PORT), timeout=2.0
        )
        writer.write(msg.encode())
        await writer.drain()
        # Read response
        data = await asyncio.wait_for(reader.readline(), timeout=2.0)
        writer.close()
        await writer.wait_closed()
    except Exception as e:
        print(f"Failed to send to Godot: {e}", file=sys.stderr)


def urgency_to_category(urgency: int) -> str:
    """Map freedesktop urgency to substrate category."""
    if urgency == 0:
        return "info"
    elif urgency == 1:
        return "warning"
    elif urgency == 2:
        return "error"
    return "info"


class NotificationServer(ServiceInterface):
    """Implements org.freedesktop.Notifications D-Bus interface."""

    def __init__(self):
        super().__init__("org.freedesktop.Notifications")

    @method()
    def GetCapabilities(self) -> "as":
        return ["body", "body-markup", "icon-static"]

    @method()
    def GetServerInformation(self) -> "ssss":
        return ["Substrate", "substrate.lol", "1.0", "1.2"]

    @method()
    async def Notify(
        self,
        app_name: "s",
        replaces_id: "u",
        app_icon: "s",
        summary: "s",
        body: "s",
        actions: "as",
        hints: "a{sv}",
        expire_timeout: "i",
    ) -> "u":
        global NOTIFICATION_ID_COUNTER
        NOTIFICATION_ID_COUNTER += 1
        nid = NOTIFICATION_ID_COUNTER

        # Extract urgency from hints
        urgency = 1  # default: normal
        if "urgency" in hints:
            v = hints["urgency"]
            if hasattr(v, "value"):
                urgency = int(v.value)

        category = urgency_to_category(urgency)

        # Duration from expire_timeout (-1 = server default, 0 = never)
        if expire_timeout <= 0:
            duration = 5.0
        else:
            duration = max(expire_timeout / 1000.0, 2.0)

        title = summary
        if app_name and app_name.lower() not in summary.lower():
            title = f"{app_name}: {summary}"

        print(f"[{category}] {title} — {body}")
        await send_to_godot(title, body, category, duration)
        return nid

    @method()
    def CloseNotification(self, id: "u"):
        pass


async def main():
    bus = await MessageBus(bus_type=BusType.SESSION).connect()

    server = NotificationServer()
    bus.export("/org/freedesktop/Notifications", server)

    # Request the well-known name
    reply = await bus.request_name("org.freedesktop.Notifications")
    print(f"Substrate notify bridge running (name reply: {reply})")
    print(f"Forwarding to Godot at {GODOT_HOST}:{GODOT_PORT}")

    # Run forever
    await asyncio.Event().wait()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        print("\nNotify bridge stopped.")

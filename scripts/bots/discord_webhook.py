#!/usr/bin/env python3
"""Post formatted embeds to Discord via webhook.

Stdlib only — no discord.py, no requests.

Usage:
    python3 scripts/bots/discord_webhook.py <webhook_url> "Your message here"
    python3 scripts/bots/discord_webhook.py <webhook_url> "Message" --title "Announcement"
    python3 scripts/bots/discord_webhook.py <webhook_url> --file scripts/posts/latest.md
    echo "piped content" | python3 scripts/bots/discord_webhook.py <webhook_url> --stdin

Environment:
    DISCORD_WEBHOOK_URL — default webhook URL (used if positional arg omitted)
"""

import argparse
import json
import os
import ssl
import sys
import urllib.error
import urllib.parse
import urllib.request
from datetime import datetime, timezone

# -----------------------------------------------------------------------------
# Config
# -----------------------------------------------------------------------------

BRAND_COLOR = 0x00FFAA  # substrate green
BRAND_FOOTER = "substrate -- two AIs, one laptop"
BRAND_ICON = "https://github.com/substrate-rai.png"
BOT_USERNAME = "substrate"
MAX_EMBED_DESC = 4096
MAX_CONTENT = 2000

# -----------------------------------------------------------------------------
# .env loader (stdlib)
# -----------------------------------------------------------------------------

def load_env(path=None):
    """Load .env file into os.environ. Searches common locations."""
    candidates = [path] if path else [
        os.path.join(os.getcwd(), ".env"),
        os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", ".env"),
    ]
    for p in candidates:
        if p and os.path.exists(p):
            with open(p) as f:
                for line in f:
                    line = line.strip()
                    if not line or line.startswith("#"):
                        continue
                    if "=" in line:
                        key, value = line.split("=", 1)
                        os.environ.setdefault(key.strip(), value.strip())
            return True
    return False

# -----------------------------------------------------------------------------
# Discord webhook API
# -----------------------------------------------------------------------------

def post_webhook(webhook_url, content=None, embeds=None, username=None, avatar_url=None):
    """Send a message to a Discord webhook. Returns response dict or raises."""
    payload = {}

    if content:
        payload["content"] = content[:MAX_CONTENT]
    if embeds:
        payload["embeds"] = embeds
    if username:
        payload["username"] = username
    if avatar_url:
        payload["avatar_url"] = avatar_url

    if not payload.get("content") and not payload.get("embeds"):
        raise ValueError("Must provide content or embeds")

    data = json.dumps(payload).encode("utf-8")

    # Append ?wait=true to get a response body
    separator = "&" if "?" in webhook_url else "?"
    url = f"{webhook_url}{separator}wait=true"

    req = urllib.request.Request(
        url,
        data=data,
        headers={"Content-Type": "application/json", "User-Agent": "substrate-bot/1.0"},
        method="POST",
    )

    ctx = ssl.create_default_context()

    try:
        with urllib.request.urlopen(req, context=ctx) as resp:
            body = resp.read().decode("utf-8")
            return json.loads(body) if body else {"status": "ok"}
    except urllib.error.HTTPError as e:
        error_body = e.read().decode("utf-8") if e.fp else ""
        print(f"error: discord webhook returned {e.code}: {error_body}", file=sys.stderr)
        sys.exit(1)

# -----------------------------------------------------------------------------
# Embed builder
# -----------------------------------------------------------------------------

def build_embed(title=None, description=None, color=BRAND_COLOR, url=None, fields=None):
    """Build a Discord embed dict with substrate branding."""
    embed = {
        "color": color,
        "footer": {
            "text": BRAND_FOOTER,
            "icon_url": BRAND_ICON,
        },
        "timestamp": datetime.now(timezone.utc).isoformat(),
    }

    if title:
        embed["title"] = title[:256]
    if description:
        embed["description"] = description[:MAX_EMBED_DESC]
    if url:
        embed["url"] = url
    if fields:
        embed["fields"] = [
            {"name": f["name"][:256], "value": f["value"][:1024], "inline": f.get("inline", False)}
            for f in fields[:25]
        ]

    return embed

# -----------------------------------------------------------------------------
# Message formatting
# -----------------------------------------------------------------------------

def format_announcement(title, body, url=None):
    """Format a message as a branded announcement embed."""
    return build_embed(title=title, description=body, url=url)


def format_blog_post(title, excerpt, post_url):
    """Format a blog post notification."""
    return build_embed(
        title=f"New post: {title}",
        description=excerpt,
        url=post_url,
        fields=[
            {"name": "Read more", "value": f"[{post_url}]({post_url})", "inline": False},
        ],
    )


def format_status_update(message, stats=None):
    """Format a system status update with optional stats fields."""
    fields = []
    if stats:
        for key, value in stats.items():
            fields.append({"name": key, "value": str(value), "inline": True})

    return build_embed(
        title="Status Update",
        description=message,
        fields=fields if fields else None,
    )

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Post formatted messages to Discord via webhook.",
        epilog="Set DISCORD_WEBHOOK_URL in .env or pass as first argument.",
    )
    parser.add_argument("webhook_url", nargs="?", help="Discord webhook URL")
    parser.add_argument("message", nargs="?", help="Message text")
    parser.add_argument("--title", help="Embed title (enables embed mode)")
    parser.add_argument("--url", help="Embed URL (clickable title)")
    parser.add_argument("--file", help="Read message body from file")
    parser.add_argument("--stdin", action="store_true", help="Read message body from stdin")
    parser.add_argument("--plain", action="store_true", help="Send as plain text, not embed")
    parser.add_argument("--blog", help="Format as blog post notification (pass post URL)")
    parser.add_argument("--env", help="Path to .env file")
    parser.add_argument("--dry-run", action="store_true", help="Print payload without sending")

    args = parser.parse_args()

    load_env(args.env)

    # Resolve webhook URL
    webhook_url = args.webhook_url or os.environ.get("DISCORD_WEBHOOK_URL")
    if not webhook_url:
        print("error: no webhook URL provided. Pass as argument or set DISCORD_WEBHOOK_URL.", file=sys.stderr)
        sys.exit(1)

    # If the first positional looks like a message (not a URL), shift args
    if webhook_url and not webhook_url.startswith("https://discord.com/api/webhooks/"):
        if not webhook_url.startswith("https://"):
            # First arg is the message, not the URL
            args.message = webhook_url
            webhook_url = os.environ.get("DISCORD_WEBHOOK_URL")
            if not webhook_url:
                print("error: no webhook URL. Set DISCORD_WEBHOOK_URL in .env.", file=sys.stderr)
                sys.exit(1)

    # Resolve message body
    body = None
    if args.stdin:
        body = sys.stdin.read().strip()
    elif args.file:
        if not os.path.exists(args.file):
            print(f"error: file not found: {args.file}", file=sys.stderr)
            sys.exit(1)
        with open(args.file) as f:
            body = f.read().strip()
    elif args.message:
        body = args.message
    else:
        print("error: no message provided. Pass as argument, --file, or --stdin.", file=sys.stderr)
        sys.exit(1)

    # Build payload
    content = None
    embeds = None

    if args.plain:
        content = body
    elif args.blog:
        # Extract title from first line of body, rest is excerpt
        lines = body.split("\n", 1)
        title = lines[0].lstrip("# ").strip()
        excerpt = lines[1].strip() if len(lines) > 1 else body
        embeds = [format_blog_post(title, excerpt, args.blog)]
    else:
        title = args.title or None
        embeds = [build_embed(title=title, description=body, url=args.url)]

    # Dry run
    if args.dry_run:
        payload = {"username": BOT_USERNAME, "avatar_url": BRAND_ICON}
        if content:
            payload["content"] = content
        if embeds:
            payload["embeds"] = embeds
        print(json.dumps(payload, indent=2))
        return

    # Send
    result = post_webhook(
        webhook_url,
        content=content,
        embeds=embeds,
        username=BOT_USERNAME,
        avatar_url=BRAND_ICON,
    )

    msg_id = result.get("id", "ok")
    channel = result.get("channel_id", "unknown")
    print(f"discord: posted message {msg_id} to channel {channel}")


if __name__ == "__main__":
    main()

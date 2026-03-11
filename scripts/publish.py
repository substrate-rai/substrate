#!/usr/bin/env python3
"""Publish social media posts from a markdown file.

Usage:
    nix develop
    python3 scripts/publish.py scripts/posts/2026-03-06-launch.md --dry-run
    python3 scripts/publish.py scripts/posts/2026-03-06-launch.md --platform bluesky
"""

import argparse
import base64
import hashlib
import hmac
import json
import os
import re
import sys
import time
import unicodedata
import urllib.parse
from datetime import datetime, timezone

import requests

from env import load_env

# -----------------------------------------------------------------------------
# Config
# -----------------------------------------------------------------------------

PLATFORMS = ["bluesky", "x", "linkedin", "instagram"]
CHAR_LIMITS = {"bluesky": 300, "x": 280}

# -----------------------------------------------------------------------------
# Markdown parser
# -----------------------------------------------------------------------------

def parse_posts(filepath):
    with open(filepath) as f:
        content = f.read()

    posts = {}
    sections = re.split(r"^##\s+", content, flags=re.MULTILINE)

    for section in sections[1:]:
        lines = section.split("\n", 1)
        platform = lines[0].strip().lower()
        text = lines[1].strip() if len(lines) > 1 else ""
        if platform in PLATFORMS:
            posts[platform] = text
        else:
            print(f"warning: unknown platform '{platform}', skipping", file=sys.stderr)

    return posts

# -----------------------------------------------------------------------------
# Bluesky (AT Protocol)
# -----------------------------------------------------------------------------

def bluesky_parse_facets(text):
    facets = []
    for match in re.finditer(r"https?://[^\s\)\]\>\"']+", text):
        url = match.group()
        start = len(text[: match.start()].encode("utf-8"))
        end = len(text[: match.end()].encode("utf-8"))
        facets.append(
            {
                "index": {"byteStart": start, "byteEnd": end},
                "features": [{"$type": "app.bsky.richtext.facet#link", "uri": url}],
            }
        )
    return facets


def grapheme_len(text):
    count = 0
    i = 0
    while i < len(text):
        count += 1
        i += 1
        while i < len(text) and unicodedata.combining(text[i]):
            i += 1
    return count


def publish_bluesky(text, dry_run=False):
    length = grapheme_len(text)
    if length > CHAR_LIMITS["bluesky"]:
        print(f"error: bluesky post is {length} graphemes (limit {CHAR_LIMITS['bluesky']})", file=sys.stderr)
        return False

    if dry_run:
        print(f"[DRY RUN] Bluesky ({length}/{CHAR_LIMITS['bluesky']} chars):")
        print(text)
        print()
        return True

    handle = os.environ.get("BLUESKY_HANDLE")
    password = os.environ.get("BLUESKY_APP_PASSWORD")
    if not handle or not password:
        print("error: BLUESKY_HANDLE and BLUESKY_APP_PASSWORD required", file=sys.stderr)
        return False

    # Auth
    resp = requests.post(
        "https://bsky.social/xrpc/com.atproto.server.createSession",
        json={"identifier": handle, "password": password},
    )
    if resp.status_code != 200:
        print(f"error: bluesky auth failed: {resp.text}", file=sys.stderr)
        return False

    session = resp.json()
    did = session["did"]
    token = session["accessJwt"]

    # Build post record
    record = {
        "$type": "app.bsky.feed.post",
        "text": text,
        "createdAt": datetime.now(timezone.utc).isoformat(),
    }
    facets = bluesky_parse_facets(text)
    if facets:
        record["facets"] = facets

    # Post
    resp = requests.post(
        "https://bsky.social/xrpc/com.atproto.repo.createRecord",
        headers={"Authorization": f"Bearer {token}"},
        json={
            "repo": did,
            "collection": "app.bsky.feed.post",
            "record": record,
        },
    )
    if resp.status_code != 200:
        print(f"error: bluesky post failed: {resp.text}", file=sys.stderr)
        return False

    print(f"bluesky: posted — {resp.json().get('uri', 'ok')}")
    return True

# -----------------------------------------------------------------------------
# X / Twitter (OAuth 1.0a, v2 API)
# -----------------------------------------------------------------------------

def x_oauth_sign(method, url, params, consumer_secret, token_secret):
    param_string = "&".join(
        f"{urllib.parse.quote(k, safe='')}" f"={urllib.parse.quote(v, safe='')}"
        for k, v in sorted(params.items())
    )
    base_string = "&".join(
        [
            method.upper(),
            urllib.parse.quote(url, safe=""),
            urllib.parse.quote(param_string, safe=""),
        ]
    )
    signing_key = (
        f"{urllib.parse.quote(consumer_secret, safe='')}"
        f"&{urllib.parse.quote(token_secret, safe='')}"
    )
    sig = base64.b64encode(
        hmac.new(signing_key.encode(), base_string.encode(), hashlib.sha1).digest()
    ).decode()
    return sig


def publish_x(text, dry_run=False):
    if len(text) > CHAR_LIMITS["x"]:
        print(f"error: x post is {len(text)} chars (limit {CHAR_LIMITS['x']})", file=sys.stderr)
        return False

    if dry_run:
        print(f"[DRY RUN] X ({len(text)}/{CHAR_LIMITS['x']} chars):")
        print(text)
        print()
        return True

    consumer_key = os.environ.get("X_CONSUMER_KEY")
    consumer_secret = os.environ.get("X_CONSUMER_SECRET")
    access_token = os.environ.get("X_ACCESS_TOKEN")
    access_token_secret = os.environ.get("X_ACCESS_TOKEN_SECRET")

    if not all([consumer_key, consumer_secret, access_token, access_token_secret]):
        print(
            "error: X_CONSUMER_KEY, X_CONSUMER_SECRET, X_ACCESS_TOKEN, "
            "X_ACCESS_TOKEN_SECRET required",
            file=sys.stderr,
        )
        return False

    url = "https://api.twitter.com/2/tweets"
    oauth_params = {
        "oauth_consumer_key": consumer_key,
        "oauth_nonce": base64.b64encode(os.urandom(32)).decode("ascii").rstrip("="),
        "oauth_signature_method": "HMAC-SHA1",
        "oauth_timestamp": str(int(time.time())),
        "oauth_token": access_token,
        "oauth_version": "1.0",
    }

    oauth_params["oauth_signature"] = x_oauth_sign(
        "POST", url, oauth_params, consumer_secret, access_token_secret
    )

    auth_header = "OAuth " + ", ".join(
        f'{urllib.parse.quote(k, safe="")}="{urllib.parse.quote(v, safe="")}"'
        for k, v in sorted(oauth_params.items())
    )

    resp = requests.post(
        url,
        headers={"Authorization": auth_header, "Content-Type": "application/json"},
        json={"text": text},
    )
    if resp.status_code not in (200, 201):
        print(f"error: x post failed ({resp.status_code}): {resp.text}", file=sys.stderr)
        return False

    tweet_id = resp.json().get("data", {}).get("id", "ok")
    print(f"x: posted — https://x.com/i/status/{tweet_id}")
    return True

# -----------------------------------------------------------------------------
# Stubs (LinkedIn, Instagram)
# -----------------------------------------------------------------------------

def publish_linkedin(text, dry_run=False):
    if dry_run:
        print("[DRY RUN] LinkedIn (stub):")
        print(text)
        print()
        return True
    print("linkedin: not yet implemented", file=sys.stderr)
    return False


def publish_instagram(text, dry_run=False):
    if dry_run:
        print("[DRY RUN] Instagram (stub):")
        print(text)
        print()
        return True
    print("instagram: not yet implemented", file=sys.stderr)
    return False

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------

PUBLISHERS = {
    "bluesky": publish_bluesky,
    "x": publish_x,
    "linkedin": publish_linkedin,
    "instagram": publish_instagram,
}


def main():
    parser = argparse.ArgumentParser(description="Publish social posts from markdown.")
    parser.add_argument("file", help="Markdown file with ## Platform sections")
    parser.add_argument("--dry-run", action="store_true", help="Print without posting")
    parser.add_argument(
        "--platform", choices=PLATFORMS, action="append", help="Publish to specific platform(s) only"
    )
    parser.add_argument("--env", default=".env", help="Path to .env file (default: .env)")
    args = parser.parse_args()

    if not args.dry_run:
        load_env(args.env)

    posts = parse_posts(args.file)
    if not posts:
        print("error: no platform sections found in file", file=sys.stderr)
        sys.exit(1)

    targets = args.platform or list(posts.keys())
    results = {}

    for platform in targets:
        if platform not in posts:
            print(f"warning: no content for '{platform}', skipping", file=sys.stderr)
            continue
        publisher = PUBLISHERS.get(platform)
        if publisher:
            results[platform] = publisher(posts[platform], dry_run=args.dry_run)

    if not args.dry_run:
        print("\n--- summary ---")
        for platform, success in results.items():
            print(f"  {platform}: {'ok' if success else 'FAILED'}")

    failures = [p for p, s in results.items() if not s]
    sys.exit(1 if failures and not args.dry_run else 0)


if __name__ == "__main__":
    main()

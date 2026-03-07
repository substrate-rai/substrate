#!/usr/bin/env python3
"""Post to Bluesky using only stdlib (urllib, json). No requests library.

Usage:
    python3 scripts/bsky-post.py "Hello world"
    python3 scripts/bsky-post.py "Reply to this" --reply-to at://did:plc:.../app.bsky.feed.post/xxx abc123cid
"""

import argparse
import json
import os
import re
import sys
import urllib.request
import urllib.error
from datetime import datetime, timezone


# ---------------------------------------------------------------------------
# .env loader
# ---------------------------------------------------------------------------

def load_env(path):
    if not os.path.exists(path):
        print(f"error: {path} not found", file=sys.stderr)
        sys.exit(1)
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" in line:
                key, value = line.split("=", 1)
                os.environ.setdefault(key.strip(), value.strip())


# ---------------------------------------------------------------------------
# HTTP helper (stdlib only)
# ---------------------------------------------------------------------------

def api_request(url, data=None, token=None):
    """Make a JSON POST request using urllib."""
    body = json.dumps(data).encode("utf-8") if data else None
    headers = {"Content-Type": "application/json"}
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(url, data=body, headers=headers, method="POST")
    try:
        with urllib.request.urlopen(req) as resp:
            return json.loads(resp.read().decode("utf-8")), resp.status
    except urllib.error.HTTPError as e:
        error_body = e.read().decode("utf-8", errors="replace")
        return {"error": error_body}, e.code


# ---------------------------------------------------------------------------
# Facet parsing (URLs become clickable links)
# ---------------------------------------------------------------------------

def parse_facets(text):
    facets = []
    for match in re.finditer(r"https?://[^\s\)\]\>\"']+", text):
        url = match.group()
        byte_start = len(text[:match.start()].encode("utf-8"))
        byte_end = len(text[:match.end()].encode("utf-8"))
        facets.append({
            "index": {"byteStart": byte_start, "byteEnd": byte_end},
            "features": [{"$type": "app.bsky.richtext.facet#link", "uri": url}],
        })
    return facets


# ---------------------------------------------------------------------------
# Bluesky posting
# ---------------------------------------------------------------------------

def authenticate(handle, password):
    data, status = api_request(
        "https://bsky.social/xrpc/com.atproto.server.createSession",
        data={"identifier": handle, "password": password},
    )
    if status != 200:
        print(f"error: auth failed ({status}): {data}", file=sys.stderr)
        sys.exit(1)
    return data["did"], data["accessJwt"]


def post(did, token, text, reply_uri=None, reply_cid=None):
    record = {
        "$type": "app.bsky.feed.post",
        "text": text,
        "createdAt": datetime.now(timezone.utc).isoformat(),
    }

    facets = parse_facets(text)
    if facets:
        record["facets"] = facets

    if reply_uri and reply_cid:
        record["reply"] = {
            "root": {"uri": reply_uri, "cid": reply_cid},
            "parent": {"uri": reply_uri, "cid": reply_cid},
        }

    data, status = api_request(
        "https://bsky.social/xrpc/com.atproto.repo.createRecord",
        data={
            "repo": did,
            "collection": "app.bsky.feed.post",
            "record": record,
        },
        token=token,
    )

    if status != 200:
        print(f"error: post failed ({status}): {data}", file=sys.stderr)
        return None

    uri = data.get("uri", "unknown")
    cid = data.get("cid", "unknown")
    print(f"posted: uri={uri} cid={cid}")
    return data


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(description="Post to Bluesky (stdlib only)")
    parser.add_argument("message", help="Text to post")
    parser.add_argument("--reply-to", nargs=2, metavar=("URI", "CID"),
                        help="Reply to an existing post (uri and cid)")
    parser.add_argument("--env", default=os.path.join(os.path.dirname(__file__), "..", ".env"),
                        help="Path to .env file")
    args = parser.parse_args()

    load_env(args.env)

    handle = os.environ.get("BLUESKY_HANDLE")
    password = os.environ.get("BLUESKY_APP_PASSWORD")
    if not handle or not password:
        print("error: BLUESKY_HANDLE and BLUESKY_APP_PASSWORD required in .env", file=sys.stderr)
        sys.exit(1)

    did, token = authenticate(handle, password)
    print(f"authenticated as {did}")

    reply_uri = args.reply_to[0] if args.reply_to else None
    reply_cid = args.reply_to[1] if args.reply_to else None

    result = post(did, token, args.message, reply_uri, reply_cid)
    if not result:
        sys.exit(1)


if __name__ == "__main__":
    main()

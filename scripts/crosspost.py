#!/usr/bin/env python3
"""Cross-post blog articles to Dev.to and Hashnode.

Usage:
    python3 scripts/crosspost.py _posts/2026-03-07-ollama-cuda-nixos-unstable.md --platform devto --dry-run
    python3 scripts/crosspost.py _posts/2026-03-07-ollama-cuda-nixos-unstable.md --platform devto

Requires DEV_API_KEY in .env (get from dev.to/settings/extensions).
"""

import argparse
import json
import os
import re
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_DIR = os.path.dirname(SCRIPT_DIR)
SITE_URL = "https://substrate.lol"


def load_env(path=None):
    if path is None:
        path = os.path.join(REPO_DIR, ".env")
    if not os.path.exists(path):
        return
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" in line:
                key, value = line.split("=", 1)
                os.environ.setdefault(key.strip(), value.strip())


def parse_frontmatter(filepath):
    """Parse Jekyll frontmatter and body from a markdown file."""
    with open(filepath) as f:
        content = f.read()

    if not content.startswith("---"):
        return {}, content

    parts = content.split("---", 2)
    if len(parts) < 3:
        return {}, content

    frontmatter = {}
    for line in parts[1].strip().split("\n"):
        if ":" in line:
            key, value = line.split(":", 1)
            value = value.strip().strip('"').strip("'")
            # Handle YAML arrays like [tag1, tag2]
            if value.startswith("[") and value.endswith("]"):
                value = [t.strip() for t in value[1:-1].split(",")]
            frontmatter[key.strip()] = value

    body = parts[2].strip()
    return frontmatter, body


def slug_from_filename(filepath):
    """Extract slug from Jekyll filename like 2026-03-07-some-title.md."""
    basename = os.path.basename(filepath).replace(".md", "")
    # Remove date prefix
    parts = basename.split("-", 3)
    if len(parts) >= 4:
        return parts[3]
    return basename


def fix_relative_links(body, base_url):
    """Convert relative blog links to absolute URLs."""
    # Convert ../some-post/ to full URL
    body = re.sub(
        r'\]\(\.\./([^)]+)\)',
        rf']({base_url}/blog/\1)',
        body
    )
    return body


def crosspost_devto(frontmatter, body, canonical_url, dry_run=False):
    """Publish to Dev.to via API."""
    import requests

    api_key = os.environ.get("DEV_API_KEY")
    if not api_key:
        print("error: DEV_API_KEY not set. Get one at dev.to/settings/extensions", file=sys.stderr)
        sys.exit(1)

    title = frontmatter.get("title", "Untitled")
    tags = frontmatter.get("tags", [])
    if isinstance(tags, str):
        tags = [t.strip() for t in tags.split(",")]
    # Dev.to max 4 tags, alphanumeric/hyphens only
    tags = [re.sub(r'[^a-z0-9]', '', t.lower()) for t in tags[:4]]

    description = frontmatter.get("description", "")

    # Add funding CTA at the bottom
    body += "\n\n---\n\n"
    body += "*This guide is part of [substrate](https://github.com/substrate-rai/substrate), "
    body += "a sovereign AI workstation that documents its own construction and funds its own hardware upgrades. "
    body += "If this helped you, consider [supporting the hardware fund](https://ko-fi.com/substrate).*\n"

    article = {
        "article": {
            "title": title,
            "body_markdown": body,
            "published": True,
            "tags": tags,
            "canonical_url": canonical_url,
            "description": description,
        }
    }

    if dry_run:
        print(f"[DRY RUN] Dev.to article:")
        print(f"  Title: {title}")
        print(f"  Tags: {tags}")
        print(f"  Canonical: {canonical_url}")
        print(f"  Body: {len(body)} chars")
        return

    resp = requests.post(
        "https://dev.to/api/articles",
        headers={
            "api-key": api_key,
            "Content-Type": "application/json",
        },
        json=article,
    )

    if resp.status_code in (200, 201):
        data = resp.json()
        print(f"[devto] published: {data.get('url', 'ok')}")
    else:
        print(f"error: Dev.to API returned {resp.status_code}: {resp.text}", file=sys.stderr)
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(description="Cross-post blog to Dev.to/Hashnode.")
    parser.add_argument("file", help="Markdown file to cross-post")
    parser.add_argument("--platform", choices=["devto"], default="devto")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    load_env()

    frontmatter, body = parse_frontmatter(args.file)
    slug = slug_from_filename(args.file)
    canonical_url = f"{SITE_URL}/blog/{slug}/"

    # Fix relative links
    body = fix_relative_links(body, SITE_URL)

    if args.platform == "devto":
        crosspost_devto(frontmatter, body, canonical_url, dry_run=args.dry_run)


if __name__ == "__main__":
    main()

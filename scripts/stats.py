#!/usr/bin/env python3
"""Scrape GitHub repo stats and log them. Runs without authentication for
public data (stars, forks, watchers). Traffic/clones require a GitHub token.

Usage:
    python3 scripts/stats.py                  # log stats
    python3 scripts/stats.py --dry-run        # print without writing

Logs to memory/stats.log. Designed to run from a systemd timer (daily).
"""

import json
import os
import sys
from datetime import datetime

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_DIR = os.path.dirname(SCRIPT_DIR)
LOG_FILE = os.path.join(REPO_DIR, "memory", "stats.log")
LEDGER_FILE = os.path.join(REPO_DIR, "ledger", "revenue.txt")

REPO = "substrate-rai/substrate"
API_BASE = f"https://api.github.com/repos/{REPO}"


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


def get_repo_stats():
    """Fetch public repo stats (no auth required)."""
    import requests

    headers = {"Accept": "application/vnd.github.v3+json"}
    token = os.environ.get("GITHUB_TOKEN")
    if token:
        headers["Authorization"] = f"token {token}"

    stats = {}

    # Basic repo info (stars, forks, watchers)
    resp = requests.get(API_BASE, headers=headers, timeout=10)
    if resp.status_code == 200:
        data = resp.json()
        stats["stars"] = data.get("stargazers_count", 0)
        stats["forks"] = data.get("forks_count", 0)
        stats["watchers"] = data.get("subscribers_count", 0)
        stats["open_issues"] = data.get("open_issues_count", 0)
    else:
        print(f"warning: repo API returned {resp.status_code}", file=sys.stderr)

    # Traffic (requires token with repo scope)
    if token:
        # Views
        resp = requests.get(f"{API_BASE}/traffic/views", headers=headers, timeout=10)
        if resp.status_code == 200:
            data = resp.json()
            stats["views_14d"] = data.get("count", 0)
            stats["unique_visitors_14d"] = data.get("uniques", 0)

        # Clones
        resp = requests.get(f"{API_BASE}/traffic/clones", headers=headers, timeout=10)
        if resp.status_code == 200:
            data = resp.json()
            stats["clones_14d"] = data.get("count", 0)
            stats["unique_cloners_14d"] = data.get("uniques", 0)

        # Referrers
        resp = requests.get(f"{API_BASE}/traffic/popular/referrers", headers=headers, timeout=10)
        if resp.status_code == 200:
            referrers = resp.json()[:5]
            stats["top_referrers"] = [
                {"site": r["referrer"], "views": r["count"]}
                for r in referrers
            ]
    else:
        stats["note"] = "no GITHUB_TOKEN — traffic data unavailable"

    return stats


def check_sponsors():
    """Check GitHub Sponsors status (requires token)."""
    token = os.environ.get("GITHUB_TOKEN")
    if not token:
        return None

    import requests

    # GraphQL query for sponsorships
    query = """
    query {
      viewer {
        sponsorsListing {
          isPublic
        }
        sponsors(first: 10) {
          totalCount
          nodes {
            ... on User { login }
            ... on Organization { login }
          }
        }
      }
    }
    """
    resp = requests.post(
        "https://api.github.com/graphql",
        headers={"Authorization": f"bearer {token}"},
        json={"query": query},
        timeout=10,
    )
    if resp.status_code == 200:
        data = resp.json().get("data", {}).get("viewer", {})
        sponsors = data.get("sponsors", {})
        return {
            "total_sponsors": sponsors.get("totalCount", 0),
            "sponsors": [n.get("login") for n in sponsors.get("nodes", [])],
        }
    return None


def main():
    import argparse

    parser = argparse.ArgumentParser(description="Substrate GitHub stats scraper.")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    load_env()

    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    stats = get_repo_stats()
    sponsor_info = check_sponsors()
    if sponsor_info:
        stats["sponsors"] = sponsor_info

    if args.dry_run:
        print(json.dumps(stats, indent=2))
        return

    # Log to stats file
    os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)
    with open(LOG_FILE, "a") as f:
        f.write(f"--- {timestamp} ---\n")
        for key, value in stats.items():
            if isinstance(value, (list, dict)):
                f.write(f"{key}: {json.dumps(value)}\n")
            else:
                f.write(f"{key}: {value}\n")
        f.write("\n")

    # Print summary
    print(f"[stats] {timestamp}")
    print(f"  stars: {stats.get('stars', '?')}")
    print(f"  forks: {stats.get('forks', '?')}")
    print(f"  watchers: {stats.get('watchers', '?')}")
    if "views_14d" in stats:
        print(f"  views (14d): {stats['views_14d']} ({stats['unique_visitors_14d']} unique)")
        print(f"  clones (14d): {stats['clones_14d']} ({stats['unique_cloners_14d']} unique)")
    if sponsor_info:
        print(f"  sponsors: {sponsor_info['total_sponsors']}")


if __name__ == "__main__":
    main()

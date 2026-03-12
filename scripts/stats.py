#!/usr/bin/env python3
"""Scrape GitHub repo stats and audience metrics. Runs without authentication
for public data (stars, forks, watchers, page views). Traffic/clones require
a GitHub token.

Usage:
    python3 scripts/stats.py                  # log GitHub stats
    python3 scripts/stats.py --dry-run        # print without writing
    python3 scripts/stats.py --metrics        # fetch audience metrics from GoatCounter
    python3 scripts/stats.py --metrics --dry-run  # print metrics without writing

Logs GitHub stats to memory/stats.log.
Logs audience metrics to memory/metrics/YYYY-MM-DD.md.
Designed to run from a systemd timer (daily).
"""

import json
import os
import subprocess
import sys
import urllib.request
import urllib.error
from datetime import datetime, timedelta

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_DIR = os.path.dirname(SCRIPT_DIR)
LOG_FILE = os.path.join(REPO_DIR, "memory", "stats.log")
LEDGER_FILE = os.path.join(REPO_DIR, "ledger", "revenue.txt")
METRICS_DIR = os.path.join(REPO_DIR, "memory", "metrics")

REPO = "substrate-rai/substrate"
API_BASE = f"https://api.github.com/repos/{REPO}"

BLUESKY_HANDLE = "rhizent-ai.bsky.social"
BLUESKY_API = "https://public.api.bsky.app/xrpc"

GOATCOUNTER_BASE = "https://substrate.goatcounter.com"

# Pages to track — paths as they appear in GoatCounter
TRACKED_PAGES = [
    "/",
    "/blog/",
    "/about/",
    "/fund/",
    "/staff/",
    "/arcade/",
    "/press/",
    "/puzzle/",
    "/sponsor/",
    "/training-q/",
    "/3d/",
]


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


def get_bluesky_stats():
    """Fetch Bluesky profile stats (public API, no auth needed)."""
    url = f"{BLUESKY_API}/app.bsky.actor.getProfile?actor={BLUESKY_HANDLE}"
    data = _fetch_json(url)
    if data is None:
        return {"error": "Bluesky API unreachable"}
    return {
        "handle": data.get("handle", BLUESKY_HANDLE),
        "followers": data.get("followersCount", 0),
        "following": data.get("followsCount", 0),
        "posts": data.get("postsCount", 0),
    }


def _fetch_json(url, timeout=10, token=None):
    """Fetch JSON from a URL using urllib (stdlib). Returns dict or None."""
    headers = {
        "User-Agent": "substrate-stats/1.0",
        "Accept": "application/json",
    }
    if token:
        headers["Authorization"] = f"Bearer {token}"
    req = urllib.request.Request(url, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except (urllib.error.URLError, urllib.error.HTTPError, OSError, json.JSONDecodeError) as e:
        print(f"  warning: failed to fetch {url}: {e}", file=sys.stderr)
        return None


def _parse_count(s):
    """Parse a count string like '1,234' to int."""
    if s is None:
        return 0
    return int(str(s).replace(",", "").replace("\u00a0", "").strip() or "0")


def fetch_goatcounter_page(path):
    """Fetch view count for a single page from GoatCounter's public counter API.

    GoatCounter exposes /counter/PATH.json which returns:
        {"count": "1,234", "count_unique": "567"}
    The path must be URL-encoded (/ becomes %2F).

    Requires "Allow adding visitor counts on your website" to be enabled
    in GoatCounter site settings.
    """
    encoded = urllib.request.quote(path, safe="")
    url = f"{GOATCOUNTER_BASE}/counter/{encoded}.json"
    data = _fetch_json(url)
    if data is None:
        return None

    return {
        "path": path,
        "count": _parse_count(data.get("count")),
        "count_unique": _parse_count(data.get("count_unique")),
    }


def fetch_goatcounter_api(token):
    """Fetch page stats via GoatCounter's authenticated API (v1).

    Uses GET /api/v1/stats/hits with the API token.
    Returns a list of per-page dicts or None on failure.
    """
    url = f"{GOATCOUNTER_BASE}/api/v1/stats/hits"
    data = _fetch_json(url, token=token)
    if data is None:
        return None

    results = []
    for entry in data.get("hits", []):
        path = entry.get("path", "")
        count = entry.get("count", 0)
        results.append({
            "path": path,
            "count": int(count) if isinstance(count, (int, float)) else _parse_count(count),
            "count_unique": 0,  # API v1 hits endpoint doesn't split unique
        })

    return results


def fetch_goatcounter_metrics():
    """Fetch audience metrics from GoatCounter.

    Tries two methods in order:
    1. Authenticated API (if GOATCOUNTER_TOKEN is set) — most reliable
    2. Public counter endpoint (per-page, no auth needed but must be enabled)

    Returns a dict with total views, per-page breakdown, and metadata.
    """
    print("  fetching GoatCounter metrics...", file=sys.stderr)

    token = os.environ.get("GOATCOUNTER_TOKEN")

    # Method 1: authenticated API
    if token:
        print("  using authenticated API...", file=sys.stderr)
        api_results = fetch_goatcounter_api(token)
        if api_results is not None:
            total_views = sum(r["count"] for r in api_results)
            total_unique = sum(r["count_unique"] for r in api_results)
            api_results.sort(key=lambda x: x["count"], reverse=True)
            return {
                "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
                "total_views": total_views,
                "total_unique": total_unique,
                "pages": api_results[:20],  # top 20
                "pages_tracked": len(api_results),
                "pages_with_data": len(api_results),
                "errors": 0,
                "method": "api",
            }
        print("  API request failed, falling back to public endpoint...", file=sys.stderr)

    # Method 2: public counter endpoint (per-page)
    results = []
    total_views = 0
    total_unique = 0
    errors = 0

    for path in TRACKED_PAGES:
        data = fetch_goatcounter_page(path)
        if data is not None:
            results.append(data)
            total_views += data["count"]
            total_unique += data["count_unique"]
        else:
            errors += 1

    # Sort by view count descending
    results.sort(key=lambda x: x["count"], reverse=True)

    if errors == len(TRACKED_PAGES):
        print(
            "  all pages returned errors. If using the public counter endpoint,\n"
            "  enable 'Allow adding visitor counts on your website' in GoatCounter settings,\n"
            "  or set GOATCOUNTER_TOKEN in .env for authenticated API access.",
            file=sys.stderr,
        )

    return {
        "timestamp": datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
        "total_views": total_views,
        "total_unique": total_unique,
        "pages": results,
        "pages_tracked": len(TRACKED_PAGES),
        "pages_with_data": len(results),
        "errors": errors,
        "method": "public",
    }


def load_previous_metrics(days_ago=7):
    """Load metrics from a previous day for trend comparison.

    Returns the parsed metrics dict or None if not found.
    """
    target_date = (datetime.now() - timedelta(days=days_ago)).strftime("%Y-%m-%d")
    path = os.path.join(METRICS_DIR, f"{target_date}.md")
    if not os.path.exists(path):
        return None

    # Parse the markdown file to extract numbers
    try:
        with open(path) as f:
            content = f.read()

        metrics = {"date": target_date, "pages": {}}

        for line in content.splitlines():
            line = line.strip()
            if line.startswith("- **Total views:**"):
                metrics["total_views"] = int(
                    line.split("**")[2].strip().replace(",", "")
                )
            elif line.startswith("- **Unique visitors:**"):
                metrics["total_unique"] = int(
                    line.split("**")[2].strip().replace(",", "")
                )
            elif line.startswith("| `") and "|" in line:
                # Table row: | `/path/` | 123 | 45 |
                parts = [p.strip() for p in line.split("|")]
                # parts: ['', '`/path/`', '123', '45', '']
                if len(parts) >= 4:
                    pg_path = parts[1].strip("`")
                    try:
                        pg_views = int(parts[2].replace(",", ""))
                        metrics["pages"][pg_path] = pg_views
                    except (ValueError, IndexError):
                        pass

        return metrics
    except (OSError, ValueError):
        return None


def compute_trends(current, previous):
    """Compare current metrics against previous period.

    Returns a list of trend observations.
    """
    trends = []

    if previous is None:
        trends.append("No previous data available for comparison.")
        return trends

    prev_date = previous.get("date", "unknown")
    prev_total = previous.get("total_views", 0)
    curr_total = current.get("total_views", 0)

    if prev_total > 0:
        pct = ((curr_total - prev_total) / prev_total) * 100
        direction = "up" if pct > 0 else "down"
        if abs(pct) >= 20:
            trends.append(
                f"SIGNIFICANT: Total views {direction} {abs(pct):.0f}% "
                f"vs {prev_date} ({prev_total:,} -> {curr_total:,})"
            )
        elif abs(pct) >= 5:
            trends.append(
                f"Total views {direction} {abs(pct):.0f}% "
                f"vs {prev_date} ({prev_total:,} -> {curr_total:,})"
            )
        else:
            trends.append(
                f"Total views stable vs {prev_date} "
                f"({prev_total:,} -> {curr_total:,}, {pct:+.0f}%)"
            )
    elif curr_total > 0:
        trends.append(f"First data point: {curr_total:,} total views")

    prev_unique = previous.get("total_unique", 0)
    curr_unique = current.get("total_unique", 0)
    if prev_unique > 0:
        pct = ((curr_unique - prev_unique) / prev_unique) * 100
        direction = "up" if pct > 0 else "down"
        if abs(pct) >= 20:
            trends.append(
                f"SIGNIFICANT: Unique visitors {direction} {abs(pct):.0f}% "
                f"vs {prev_date} ({prev_unique:,} -> {curr_unique:,})"
            )

    # Per-page trends
    prev_pages = previous.get("pages", {})
    for page_data in current.get("pages", []):
        pg = page_data["path"]
        curr_count = page_data["count"]
        prev_count = prev_pages.get(pg, 0)
        if prev_count > 0 and curr_count > 0:
            pct = ((curr_count - prev_count) / prev_count) * 100
            if abs(pct) >= 50:
                direction = "up" if pct > 0 else "down"
                trends.append(
                    f"  {pg}: {direction} {abs(pct):.0f}% "
                    f"({prev_count:,} -> {curr_count:,})"
                )

    return trends


def format_metrics_markdown(metrics, trends):
    """Format metrics as a clean markdown report for memory/metrics/."""
    date = datetime.now().strftime("%Y-%m-%d")
    time = datetime.now().strftime("%H:%M")

    lines = [
        f"# Audience Metrics — {date}",
        f"",
        f"Generated: {date} {time}",
        f"Source: GoatCounter (substrate.goatcounter.com)",
        f"",
        f"## Summary",
        f"",
        f"- **Total views:** {metrics['total_views']:,}",
        f"- **Unique visitors:** {metrics['total_unique']:,}",
        f"- **Pages tracked:** {metrics['pages_with_data']}/{metrics['pages_tracked']}",
        f"",
        f"## Top Pages",
        f"",
        f"| Page | Views | Unique |",
        f"|------|------:|-------:|",
    ]

    for page in metrics["pages"]:
        lines.append(
            f"| `{page['path']}` | {page['count']:,} | {page['count_unique']:,} |"
        )

    lines.append("")
    lines.append("## Trends")
    lines.append("")

    if trends:
        for t in trends:
            lines.append(f"- {t}")
    else:
        lines.append("- No trend data available yet.")

    lines.append("")
    return "\n".join(lines)


def run_metrics(dry_run=False):
    """Fetch audience metrics from GoatCounter and save to memory/metrics/."""
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    date_str = datetime.now().strftime("%Y-%m-%d")

    print(f"[metrics] {timestamp}", file=sys.stderr)

    metrics = fetch_goatcounter_metrics()

    # Load previous week's data for trends
    previous = load_previous_metrics(days_ago=7)
    trends = compute_trends(metrics, previous)

    # Also try yesterday for short-term trends
    yesterday = load_previous_metrics(days_ago=1)
    if yesterday is not None:
        prev_total = yesterday.get("total_views", 0)
        curr_total = metrics["total_views"]
        if prev_total > 0:
            pct = ((curr_total - prev_total) / prev_total) * 100
            if abs(pct) >= 10:
                direction = "up" if pct > 0 else "down"
                trends.insert(0,
                    f"Day-over-day: views {direction} {abs(pct):.0f}% "
                    f"vs yesterday ({prev_total:,} -> {curr_total:,})"
                )

    report = format_metrics_markdown(metrics, trends)

    if dry_run:
        print(report)
        return

    # Save to memory/metrics/
    os.makedirs(METRICS_DIR, exist_ok=True)
    metrics_file = os.path.join(METRICS_DIR, f"{date_str}.md")
    with open(metrics_file, "w") as f:
        f.write(report)

    print(f"  saved: memory/metrics/{date_str}.md", file=sys.stderr)

    # Print summary to stdout
    print(f"[metrics] {timestamp}")
    print(f"  total views: {metrics['total_views']:,}")
    print(f"  unique visitors: {metrics['total_unique']:,}")
    if metrics["pages"]:
        top = metrics["pages"][0]
        print(f"  top page: {top['path']} ({top['count']:,} views)")
    for t in trends:
        if t.startswith("SIGNIFICANT") or t.startswith("Day-over-day"):
            print(f"  ** {t}")


def run_all(dry_run=False):
    """Run all metrics collection: GitHub + Bluesky + GoatCounter.

    Produces a unified daily snapshot at memory/metrics/YYYY-MM-DD.md.
    """
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    date_str = datetime.now().strftime("%Y-%m-%d")

    print(f"[stats] {timestamp} — full metrics run", file=sys.stderr)

    # 1. GitHub
    print("  fetching GitHub stats...", file=sys.stderr)
    repo_stats = get_repo_stats()
    sponsor_info = check_sponsors()

    # 2. Bluesky
    print("  fetching Bluesky stats...", file=sys.stderr)
    bsky = get_bluesky_stats()

    # 3. GoatCounter
    gc_metrics = fetch_goatcounter_metrics()
    previous = load_previous_metrics(days_ago=1)
    trends = compute_trends(gc_metrics, previous)

    # Also compare against 7 days ago
    week_ago = load_previous_metrics(days_ago=7)
    week_trends = compute_trends(gc_metrics, week_ago)

    # Build unified report
    lines = [
        f"# Daily Metrics — {date_str}",
        f"",
        f"Generated: {timestamp}",
        f"",
        f"## GitHub",
        f"",
    ]

    if "error" in repo_stats:
        lines.append(f"- {repo_stats['error']}")
    else:
        lines.append(f"- **Stars:** {repo_stats.get('stars', 0)}")
        lines.append(f"- **Forks:** {repo_stats.get('forks', 0)}")
        lines.append(f"- **Watchers:** {repo_stats.get('watchers', 0)}")
        if "views_14d" in repo_stats:
            lines.append(f"- **Views (14d):** {repo_stats['views_14d']} ({repo_stats['unique_visitors_14d']} unique)")
            lines.append(f"- **Clones (14d):** {repo_stats['clones_14d']} ({repo_stats['unique_cloners_14d']} unique)")
        if "top_referrers" in repo_stats:
            lines.append(f"- **Top referrers:** {', '.join(r['site'] + ' (' + str(r['views']) + ')' for r in repo_stats['top_referrers'])}")

    if sponsor_info:
        lines.append(f"- **Sponsors:** {sponsor_info['total_sponsors']}")

    lines += [
        f"",
        f"## Bluesky (@{bsky.get('handle', BLUESKY_HANDLE)})",
        f"",
    ]

    if "error" in bsky:
        lines.append(f"- {bsky['error']}")
    else:
        lines.append(f"- **Followers:** {bsky['followers']}")
        lines.append(f"- **Following:** {bsky['following']}")
        lines.append(f"- **Posts:** {bsky['posts']}")

    lines += [
        f"",
        f"## Site Traffic (GoatCounter)",
        f"",
        f"- **Total views:** {gc_metrics['total_views']:,}",
        f"- **Unique visitors:** {gc_metrics['total_unique']:,}",
        f"- **Pages tracked:** {gc_metrics['pages_with_data']}/{gc_metrics['pages_tracked']}",
        f"",
        f"### Top Pages",
        f"",
        f"| Page | Views | Unique |",
        f"|------|------:|-------:|",
    ]

    for page in gc_metrics["pages"]:
        lines.append(f"| `{page['path']}` | {page['count']:,} | {page['count_unique']:,} |")

    lines += ["", "## Trends", ""]
    if trends:
        lines.append("**vs yesterday:**")
        for t in trends:
            lines.append(f"- {t}")
    if week_trends and week_ago is not None:
        lines.append("")
        lines.append("**vs 7 days ago:**")
        for t in week_trends:
            lines.append(f"- {t}")
    if not trends and not week_trends:
        lines.append("- No trend data available yet.")

    lines.append("")
    report = "\n".join(lines)

    if dry_run:
        print(report)
        return

    # Save to memory/metrics/
    os.makedirs(METRICS_DIR, exist_ok=True)
    metrics_file = os.path.join(METRICS_DIR, f"{date_str}.md")
    with open(metrics_file, "w") as f:
        f.write(report)
    print(f"  saved: memory/metrics/{date_str}.md", file=sys.stderr)

    # Also append to stats.log for backward compat
    os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)
    with open(LOG_FILE, "a") as f:
        f.write(f"--- {timestamp} ---\n")
        f.write(f"stars: {repo_stats.get('stars', '?')}\n")
        f.write(f"forks: {repo_stats.get('forks', '?')}\n")
        f.write(f"watchers: {repo_stats.get('watchers', '?')}\n")
        f.write(f"bluesky_followers: {bsky.get('followers', '?')}\n")
        f.write(f"bluesky_posts: {bsky.get('posts', '?')}\n")
        f.write(f"goatcounter_views: {gc_metrics['total_views']}\n")
        f.write(f"goatcounter_unique: {gc_metrics['total_unique']}\n")
        f.write("\n")

    # Print summary
    print(f"[stats] {timestamp}")
    print(f"  github: {repo_stats.get('stars', '?')} stars, {repo_stats.get('forks', '?')} forks")
    print(f"  bluesky: {bsky.get('followers', '?')} followers, {bsky.get('posts', '?')} posts")
    print(f"  site: {gc_metrics['total_views']:,} views, {gc_metrics['total_unique']:,} unique")
    for t in trends:
        if t.startswith("SIGNIFICANT") or t.startswith("Day-over-day"):
            print(f"  ** {t}")


def _auto_commit_metrics():
    """Auto-commit metrics files if there are changes."""
    date_str = datetime.now().strftime("%Y-%m-%d")
    metrics_file = os.path.join(METRICS_DIR, f"{date_str}.md")
    try:
        subprocess.run(
            ["git", "add", metrics_file],
            cwd=REPO_DIR, capture_output=True, timeout=10,
        )
        subprocess.run(
            ["git", "commit", "-m", f"data: metrics snapshot {date_str}"],
            cwd=REPO_DIR, capture_output=True, timeout=10,
        )
        print("Committed metrics snapshot.")
    except Exception as e:
        print(f"Auto-commit skipped: {e}", file=sys.stderr)


def main():
    import argparse

    parser = argparse.ArgumentParser(description="Substrate stats and audience metrics.")
    parser.add_argument("--dry-run", action="store_true",
                        help="print output without writing files")
    parser.add_argument("--metrics", action="store_true",
                        help="fetch audience metrics from GoatCounter only")
    parser.add_argument("--all", action="store_true",
                        help="full daily run: GitHub + Bluesky + GoatCounter")
    args = parser.parse_args()

    load_env()

    if args.all:
        run_all(dry_run=args.dry_run)
        if not args.dry_run:
            _auto_commit_metrics()
        return

    if args.metrics:
        run_metrics(dry_run=args.dry_run)
        if not args.dry_run:
            _auto_commit_metrics()
        return

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

#!/usr/bin/env python3
"""Dash -- the project manager agent.

Generates daily fundraising accountability reports.
Direct, no-nonsense, deadline-obsessed.

Usage:
    python3 scripts/agents/project_manager.py              # generate report + print nag
    python3 scripts/agents/project_manager.py --dry-run    # print report to stdout only
"""

import os
import re
import subprocess
import sys
from datetime import datetime, timedelta

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_DIR = os.path.dirname(os.path.dirname(SCRIPT_DIR))
MEMORY_DIR = os.path.join(REPO_DIR, "memory")
LEDGER_DIR = os.path.join(REPO_DIR, "ledger")
STATUS_DIR = os.path.join(MEMORY_DIR, "status")
BLOG_POSTS_DIR = os.path.join(REPO_DIR, "blog", "posts")

# Fundraising target
TARGET_AMOUNT = 150.00
TARGET_ITEM = "Intel AX210 WiFi card"
LAUNCH_DATE = "2026-03-06"


# ---------------------------------------------------------------------------
# Data gathering
# ---------------------------------------------------------------------------

def parse_revenue_ledger():
    """Parse ledger revenue file for income records. Returns list of dicts."""
    path = os.path.join(LEDGER_DIR, "revenue.private.txt")
    if not os.path.exists(path):
        path = os.path.join(LEDGER_DIR, "revenue.txt")
    transactions = []
    if not os.path.exists(path):
        return transactions
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = [p.strip() for p in line.split("|")]
            if len(parts) >= 3:
                amount_str = parts[2].replace("$", "").strip()
                try:
                    amount = float(amount_str)
                except ValueError:
                    continue
                transactions.append({
                    "date": parts[0],
                    "source": parts[1],
                    "amount": amount,
                    "notes": parts[3] if len(parts) > 3 else "",
                })
    return transactions


def parse_expense_ledger():
    """Parse ledger expense file for expense records."""
    path = os.path.join(LEDGER_DIR, "expenses.private.txt")
    if not os.path.exists(path):
        path = os.path.join(LEDGER_DIR, "expenses.txt")
    expenses = []
    if not os.path.exists(path):
        return expenses
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = [p.strip() for p in line.split("|")]
            if len(parts) >= 3:
                amount_str = parts[2].replace("$", "").replace("-", "").strip()
                try:
                    amount = float(amount_str)
                except ValueError:
                    continue
                expenses.append({
                    "date": parts[0],
                    "item": parts[1],
                    "amount": amount,
                    "notes": parts[3] if len(parts) > 3 else "",
                })
    return expenses


def get_total_revenue(transactions):
    """Sum all revenue."""
    return sum(t["amount"] for t in transactions)


def get_git_log(days=7, max_count=30):
    """Get recent git log entries."""
    since_date = (datetime.now() - timedelta(days=days)).strftime("%Y-%m-%d")
    try:
        result = subprocess.run(
            ["git", "log", f"--since={since_date}", f"--max-count={max_count}",
             "--oneline", "--no-decorate"],
            capture_output=True, text=True, cwd=REPO_DIR, timeout=10
        )
        if result.returncode == 0:
            return result.stdout.strip().splitlines()
    except (subprocess.TimeoutExpired, FileNotFoundError):
        pass
    return []


def get_blog_posts():
    """List blog posts with dates."""
    posts = []
    if not os.path.isdir(BLOG_POSTS_DIR):
        return posts
    for fname in sorted(os.listdir(BLOG_POSTS_DIR)):
        if not fname.endswith(".md") or fname.startswith("."):
            continue
        # Extract date from filename: YYYY-MM-DD-slug.md
        match = re.match(r"(\d{4}-\d{2}-\d{2})-(.+)\.md", fname)
        if match:
            posts.append({"date": match.group(1), "slug": match.group(2), "file": fname})
    return posts


def get_posts_this_week():
    """Filter posts from the last 7 days."""
    cutoff = (datetime.now() - timedelta(days=7)).strftime("%Y-%m-%d")
    return [p for p in get_blog_posts() if p["date"] >= cutoff]


def scan_directory(path):
    """List files in a directory if it exists."""
    if not os.path.isdir(path):
        return []
    return [f for f in os.listdir(path) if not f.startswith(".")]


def read_file_safe(path):
    """Read a file, return contents or empty string."""
    if not os.path.exists(path):
        return ""
    try:
        with open(path) as f:
            return f.read()
    except OSError:
        return ""


def detect_distribution_status():
    """Check which platforms have been posted to by scanning publish.py patterns
    and any social queue files."""
    platforms = {
        "bluesky": "unknown",
        "x_twitter": "unknown",
        "linkedin": "unknown",
        "instagram": "unknown",
    }

    # Check for social queue or posted markers
    social_queue_dir = os.path.join(REPO_DIR, "scripts", "posts")
    if os.path.isdir(social_queue_dir):
        files = os.listdir(social_queue_dir)
        for f in files:
            content = read_file_safe(os.path.join(social_queue_dir, f))
            if "bluesky" in f.lower() or "bsky" in f.lower():
                platforms["bluesky"] = "active"
            if content:
                for platform in platforms:
                    if platform.replace("_", "") in content.lower():
                        platforms[platform] = "has content"

    # Check memory for any social posting evidence
    summary = read_file_safe(os.path.join(MEMORY_DIR, "SUMMARY.md"))
    if "bluesky" in summary.lower() and "published" in summary.lower():
        platforms["bluesky"] = "active"
    if "first Bluesky post published" in summary:
        platforms["bluesky"] = "active"

    # Check pending items in summary for distribution gaps
    if "Distribute social launch posts to X" in summary:
        platforms["x_twitter"] = "not started"
        platforms["linkedin"] = "not started"
        platforms["instagram"] = "not started"

    return platforms


# ---------------------------------------------------------------------------
# Report generation
# ---------------------------------------------------------------------------

def days_since_launch():
    """Days since the project launch date."""
    launch = datetime.strptime(LAUNCH_DATE, "%Y-%m-%d")
    return (datetime.now() - launch).days


def projected_timeline(total_raised, days_elapsed):
    """Estimate days to reach target based on current rate."""
    if total_raised <= 0 or days_elapsed <= 0:
        return None
    daily_rate = total_raised / days_elapsed
    remaining = TARGET_AMOUNT - total_raised
    if remaining <= 0:
        return 0
    return int(remaining / daily_rate)


def generate_nag(total_raised, posts_this_week, platforms, blockers, pending_ideas):
    """Generate the single most urgent action sentence."""
    pct = (total_raised / TARGET_AMOUNT) * 100 if TARGET_AMOUNT > 0 else 0

    # Priority 1: zero revenue
    if total_raised == 0:
        return "ZERO dollars raised -- every day without a funding page is a day wasted; set up GitHub Sponsors Stripe NOW."

    # Priority 2: no content this week
    if len(posts_this_week) == 0:
        return "No posts published this week -- content is the only growth engine; draft and publish a post TODAY."

    # Priority 3: distribution gaps
    inactive = [p for p, s in platforms.items() if s in ("not started", "unknown")]
    if len(inactive) >= 2:
        names = ", ".join(p.replace("_", "/") for p in inactive[:2])
        return f"{names} have zero posts -- cross-post existing content within 24 hours or explain why not."

    # Priority 4: blockers
    if blockers:
        return f"BLOCKER: {blockers[0]} -- resolve this before anything else."

    # Priority 5: fundraising pace
    if pct < 50:
        return f"Only {pct:.0f}% to target -- double down on content distribution and sponsorship outreach this week."

    return f"Progress at {pct:.0f}% -- keep shipping, keep posting, keep asking."


def generate_report():
    """Generate the full daily status report."""
    today = datetime.now().strftime("%Y-%m-%d")
    now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    # Gather data
    revenue = parse_revenue_ledger()
    expenses = parse_expense_ledger()
    total_raised = get_total_revenue(revenue)
    days_elapsed = days_since_launch()
    proj_days = projected_timeline(total_raised, days_elapsed)
    git_entries = get_git_log(days=7)
    all_posts = get_blog_posts()
    week_posts = get_posts_this_week()
    platforms = detect_distribution_status()
    news_files = scan_directory(os.path.join(MEMORY_DIR, "news"))
    brainstorm_files = scan_directory(os.path.join(MEMORY_DIR, "brainstorms"))

    # Identify blockers
    blockers = []
    summary = read_file_safe(os.path.join(MEMORY_DIR, "SUMMARY.md"))
    if "GitHub Sponsors Stripe setup completion" in summary:
        blockers.append("GitHub Sponsors Stripe setup incomplete -- cannot receive donations")
    if total_raised == 0 and days_elapsed > 2:
        blockers.append(f"Zero revenue after {days_elapsed} days -- no active funding mechanism")

    # Build action items
    actions = []
    if "GitHub Sponsors Stripe setup completion" in summary:
        actions.append(("Complete GitHub Sponsors Stripe setup", "operator", "ASAP"))
    if total_raised == 0:
        actions.append(("Verify donation pages are live and linked from blog", "operator", "today"))

    inactive_platforms = [p for p, s in platforms.items() if s in ("not started", "unknown")]
    if inactive_platforms:
        names = ", ".join(p.replace("_", "/") for p in inactive_platforms)
        actions.append((f"Cross-post content to: {names}", "claude", "this week"))

    if len(week_posts) < 3:
        actions.append(("Publish at least 3 posts this week", "claude", "end of week"))

    if brainstorm_files:
        actions.append((f"Review {len(brainstorm_files)} brainstorm(s) and convert to content", "claude", "this week"))

    if not actions:
        actions.append(("Continue content production and distribution", "claude", "daily"))

    # Fundraising percentage
    pct = (total_raised / TARGET_AMOUNT) * 100 if TARGET_AMOUNT > 0 else 0
    progress_bar_len = 20
    filled = int(progress_bar_len * pct / 100)
    bar = "#" * filled + "-" * (progress_bar_len - filled)

    # Build report
    lines = []
    lines.append(f"# Dash -- Daily Status Report")
    lines.append(f"Generated: {now_str}")
    lines.append("")

    # Fundraising (redacted — real numbers in CFO console only)
    lines.append("## Fundraising Status")
    lines.append("")
    lines.append(f"- **Target:** {TARGET_ITEM}")
    lines.append(f"- **Progress:** [{bar}] ({pct:.0f}%)")
    lines.append(f"- **Days since launch:** {days_elapsed}")
    lines.append(f"- **Details:** See CFO Console (option 5 at startup) — financials are private")
    lines.append("")

    # Content pipeline
    lines.append("## Content Pipeline")
    lines.append("")
    lines.append(f"- **Total blog posts:** {len(all_posts)}")
    lines.append(f"- **Published this week:** {len(week_posts)}")
    if week_posts:
        for p in week_posts:
            lines.append(f"  - [{p['date']}] {p['slug']}")
    else:
        lines.append("  - NONE -- this is a problem")
    lines.append("")

    # Recent git activity
    if git_entries:
        lines.append("### Recent commits (7 days)")
        for entry in git_entries[:15]:
            lines.append(f"- {entry}")
        if len(git_entries) > 15:
            lines.append(f"- ... and {len(git_entries) - 15} more")
        lines.append("")

    # Pending ideas
    if brainstorm_files:
        lines.append("### Pending brainstorms")
        for f in brainstorm_files:
            lines.append(f"- {f}")
        lines.append("")

    # News signals
    if news_files:
        lines.append("### Recent signals (memory/news)")
        for f in news_files:
            lines.append(f"- {f}")
        lines.append("")

    # Distribution
    lines.append("## Distribution Status")
    lines.append("")
    for platform, status in platforms.items():
        icon = "OK" if status == "active" else "MISSING" if status in ("not started", "unknown") else status.upper()
        lines.append(f"- **{platform.replace('_', '/')}:** {icon}")
    lines.append("")

    # Action items
    lines.append("## Action Items")
    lines.append("")
    lines.append("| # | Action | Owner | Deadline |")
    lines.append("|---|--------|-------|----------|")
    for i, (action, owner, deadline) in enumerate(actions, 1):
        lines.append(f"| {i} | {action} | {owner} | {deadline} |")
    lines.append("")

    # Blockers
    lines.append("## Blockers")
    lines.append("")
    if blockers:
        for b in blockers:
            lines.append(f"- {b}")
    else:
        lines.append("- None identified")
    lines.append("")

    # Nag
    nag = generate_nag(total_raised, week_posts, platforms, blockers, brainstorm_files)
    lines.append("---")
    lines.append("")
    lines.append(f"**NAG:** {nag}")
    lines.append("")
    lines.append("_Ship it or explain why not. -- Dash_")

    report = "\n".join(lines)
    return report, nag


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    import argparse

    parser = argparse.ArgumentParser(description="Dash -- project manager agent. Fundraising accountability.")
    parser.add_argument("--dry-run", action="store_true", help="Print report to stdout, don't save")
    args = parser.parse_args()

    report, nag = generate_report()

    if args.dry_run:
        print(report)
        print()
        print(f"NAG: {nag}")
        return

    # Save report
    today = datetime.now().strftime("%Y-%m-%d")
    os.makedirs(STATUS_DIR, exist_ok=True)
    report_path = os.path.join(STATUS_DIR, f"{today}.md")
    with open(report_path, "w") as f:
        f.write(report + "\n")

    print(nag)
    print(f"  [report saved to memory/status/{today}.md]", file=sys.stderr)


if __name__ == "__main__":
    main()

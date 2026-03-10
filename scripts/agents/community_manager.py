#!/usr/bin/env python3
"""Spore -- community manager agent for Substrate.

Manages crowdfunding narrative, community engagement, and supporter relations.
Reads funding data and goal progress, then generates engagement content.

Usage:
    python3 scripts/agents/community_manager.py              # generate engagement report
    python3 scripts/agents/community_manager.py --dry-run    # print report without saving
    python3 scripts/agents/community_manager.py --date 2026-03-07

Designed to run standalone with stdlib only (no pip dependencies).
"""

import argparse
import os
import re
import sys
from datetime import datetime, timezone

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_DIR = os.path.dirname(os.path.dirname(SCRIPT_DIR))
sys.path.insert(0, SCRIPT_DIR)
from shared import queue_post
MEMORY_DIR = os.path.join(REPO_DIR, "memory")
LEDGER_DIR = os.path.join(REPO_DIR, "ledger")
ENGAGEMENT_DIR = os.path.join(MEMORY_DIR, "engagement")
GOAL_FILE = os.path.join(MEMORY_DIR, "goal.md")
DONATIONS_FILE = os.path.join(LEDGER_DIR, "donations.txt")
REVENUE_FILE = os.path.join(LEDGER_DIR, "revenue.txt")
BLOG_POSTS_DIR = os.path.join(REPO_DIR, "blog", "posts")
ALT_POSTS_DIR = os.path.join(REPO_DIR, "_posts")
VOICE_FILE = os.path.join(REPO_DIR, "scripts", "prompts", "spore-voice.txt")

# ---------------------------------------------------------------------------
# Funding milestones for celebration/narrative
# ---------------------------------------------------------------------------

MILESTONES = [
    (1.00, "First Dollar", "The network is alive. Someone believed."),
    (10.00, "Double Digits", "Ten dollars of trust in a machine that builds itself."),
    (25.00, "Quarter Way", "One quarter toward the next upgrade. Momentum building."),
    (50.00, "Halfway", "Half the target reached. The mycelium spreads."),
    (75.00, "Three Quarters", "Three quarters funded. The finish line is visible."),
    (100.00, "Century", "A hundred dollars of community faith. Almost there."),
    (150.00, "Target Reached", "Full funding. The network provided. Time to grow."),
]

# Post templates for different engagement types
POST_TEMPLATES = {
    "thank_you": [
        "A new supporter joined the Substrate network. Every contribution feeds the mycelium. Thank you.",
        "Another node connected. The network grows stronger with each supporter.",
        "Funding update: a new contribution arrived. This machine remembers every one.",
    ],
    "milestone": [
        "Milestone reached: {milestone_name}. {milestone_desc} Current: ${total:.2f}/${target:.2f}.",
        "The network just passed a threshold: {milestone_name}. ${total:.2f} raised, ${remaining:.2f} to go.",
    ],
    "progress": [
        "Substrate funding: ${total:.2f}/${target:.2f} ({pct:.0f}%). {days} days in. The machine keeps building.",
        "Progress report: {pct:.0f}% funded. ${remaining:.2f} remaining. Every dollar is a vote for autonomous AI.",
    ],
    "engagement": [
        "What would you build with a machine that documents its own construction? Substrate is finding out.",
        "A machine that funds its own upgrades, writes its own blog, and publishes its own code. That is Substrate.",
        "Sovereign AI means the machine answers to its operator, not a platform. Follow along as we build it.",
    ],
}

# ---------------------------------------------------------------------------
# Data reading
# ---------------------------------------------------------------------------

def read_file(path):
    """Read a file and return its contents, or None on failure."""
    try:
        with open(path, "r") as f:
            return f.read()
    except (IOError, OSError) as e:
        print(f"[spore] could not read {path}: {e}", file=sys.stderr)
        return None


def parse_donations():
    """Parse ledger/donations.txt for donation records."""
    donations = []
    if not os.path.exists(DONATIONS_FILE):
        return donations
    content = read_file(DONATIONS_FILE)
    if not content:
        return donations

    for line in content.splitlines():
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
            donations.append({
                "date": parts[0],
                "source": parts[1],
                "amount": amount,
                "notes": parts[3] if len(parts) > 3 else "",
            })
    return donations


def parse_revenue():
    """Parse ledger/revenue.txt for revenue records."""
    revenue = []
    if not os.path.exists(REVENUE_FILE):
        return revenue
    content = read_file(REVENUE_FILE)
    if not content:
        return revenue

    for line in content.splitlines():
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
            revenue.append({
                "date": parts[0],
                "source": parts[1],
                "amount": amount,
                "notes": parts[3] if len(parts) > 3 else "",
            })
    return revenue


def parse_goal():
    """Parse memory/goal.md for current funding target and tier progress."""
    goal_info = {
        "target": 150.00,
        "target_item": "unknown",
        "tier": "unknown",
        "description": "",
    }
    content = read_file(GOAL_FILE)
    if not content:
        return goal_info

    # Extract target amount
    amount_match = re.search(r'\$(\d+(?:\.\d+)?)', content)
    if amount_match:
        goal_info["target"] = float(amount_match.group(1))

    # Extract target item (first line often has it)
    lines = content.strip().splitlines()
    if lines:
        goal_info["description"] = lines[0].strip().lstrip("# ")

    # Look for tier references
    tier_match = re.search(r'[Tt]ier\s*(\d+|[A-Za-z]+)', content)
    if tier_match:
        goal_info["tier"] = tier_match.group(1)

    goal_info["target_item"] = goal_info["description"]

    return goal_info


def count_blog_posts():
    """Count total blog posts."""
    count = 0
    for posts_dir in [BLOG_POSTS_DIR, ALT_POSTS_DIR]:
        if os.path.isdir(posts_dir):
            count += sum(1 for f in os.listdir(posts_dir)
                        if f.endswith(".md") and not f.startswith("."))
    return count


# ---------------------------------------------------------------------------
# Engagement analysis
# ---------------------------------------------------------------------------

def check_milestones(total_raised, target):
    """Check which milestones have been reached and which is next."""
    reached = []
    next_milestone = None

    for threshold, name, desc in MILESTONES:
        if total_raised >= threshold:
            reached.append((threshold, name, desc))
        elif next_milestone is None:
            next_milestone = (threshold, name, desc)

    return reached, next_milestone


def find_recent_donations(donations, days_back=7):
    """Find donations from the last N days."""
    cutoff = datetime.now().strftime("%Y-%m-%d")
    # Simple string comparison works for ISO dates
    from datetime import timedelta
    cutoff_date = (datetime.now() - timedelta(days=days_back)).strftime("%Y-%m-%d")
    return [d for d in donations if d["date"] >= cutoff_date]


def generate_draft_posts(total_raised, target, milestones_reached, next_milestone,
                         recent_donations, blog_count):
    """Generate draft social media posts for engagement."""
    drafts = []
    pct = (total_raised / target * 100) if target > 0 else 0
    remaining = max(0, target - total_raised)

    # Thank-you posts for recent donations
    if recent_donations:
        template = POST_TEMPLATES["thank_you"][len(recent_donations) % len(POST_TEMPLATES["thank_you"])]
        drafts.append({
            "type": "thank_you",
            "content": template,
            "priority": "high",
        })

    # Milestone posts
    if milestones_reached:
        latest = milestones_reached[-1]
        template = POST_TEMPLATES["milestone"][0]
        drafts.append({
            "type": "milestone",
            "content": template.format(
                milestone_name=latest[1],
                milestone_desc=latest[2],
                total=total_raised,
                target=target,
                remaining=remaining,
            ),
            "priority": "high",
        })

    # Progress update
    template = POST_TEMPLATES["progress"][0]
    from datetime import timedelta
    days_active = max(1, (datetime.now() - datetime(2026, 3, 6)).days)
    drafts.append({
        "type": "progress",
        "content": template.format(
            total=total_raised,
            target=target,
            pct=pct,
            remaining=remaining,
            days=days_active,
        ),
        "priority": "medium",
    })

    # General engagement
    engagement_idx = blog_count % len(POST_TEMPLATES["engagement"])
    drafts.append({
        "type": "engagement",
        "content": POST_TEMPLATES["engagement"][engagement_idx],
        "priority": "low",
    })

    return drafts


# ---------------------------------------------------------------------------
# Report generation
# ---------------------------------------------------------------------------

def build_report(date_str, total_raised, target, donations, recent_donations,
                 milestones_reached, next_milestone, drafts, goal_info):
    """Build the community engagement report."""
    lines = []
    pct = (total_raised / target * 100) if target > 0 else 0
    remaining = max(0, target - total_raised)

    lines.append(f"# Spore -- Community Engagement Report: {date_str}")
    lines.append("")
    lines.append(f"**Generated:** {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M UTC')}")
    lines.append("")

    # Funding snapshot
    lines.append("## Funding Snapshot")
    lines.append("")
    lines.append(f"- **Goal:** {goal_info['description']}")
    lines.append(f"- **Target:** ${target:.2f}")
    lines.append(f"- **Raised:** ${total_raised:.2f} ({pct:.1f}%)")
    lines.append(f"- **Remaining:** ${remaining:.2f}")
    lines.append(f"- **Total donations:** {len(donations)}")
    lines.append(f"- **Recent (7 days):** {len(recent_donations)}")
    lines.append("")

    # Milestone status
    lines.append("## Milestone Status")
    lines.append("")
    if milestones_reached:
        lines.append("Reached:")
        for threshold, name, desc in milestones_reached:
            lines.append(f"- [x] ${threshold:.2f} -- {name}: {desc}")
    else:
        lines.append("- No milestones reached yet.")
    lines.append("")

    if next_milestone:
        threshold, name, desc = next_milestone
        gap = threshold - total_raised
        lines.append(f"**Next milestone:** ${threshold:.2f} -- {name}")
        lines.append(f"  ${gap:.2f} to go. {desc}")
    lines.append("")

    # Recent activity
    lines.append("## Recent Donations")
    lines.append("")
    if recent_donations:
        for d in recent_donations:
            lines.append(f"- {d['date']} | {d['source']} | ${d['amount']:.2f} | {d['notes']}")
    else:
        lines.append("No donations in the last 7 days.")
    lines.append("")

    # Draft posts
    lines.append("## Draft Posts")
    lines.append("")
    for i, draft in enumerate(drafts, 1):
        lines.append(f"### {i}. [{draft['type'].upper()}] (priority: {draft['priority']})")
        lines.append("")
        lines.append(f"> {draft['content']}")
        lines.append("")

    # Recommendations
    lines.append("## Engagement Recommendations")
    lines.append("")
    if total_raised == 0:
        lines.append("- The network has no donations yet. Focus on sharing the funding page.")
        lines.append("- Every project starts at zero. The first dollar changes everything.")
    elif pct < 25:
        lines.append("- Early stage. Share the story widely. Let people see the machine building itself.")
        lines.append("- Cross-post funding updates to all active platforms.")
    elif pct < 75:
        lines.append("- Momentum is building. Highlight specific improvements funded by donations.")
        lines.append("- Share behind-the-scenes content: what the machine built today.")
    else:
        lines.append("- Almost there. Push for the final stretch.")
        lines.append("- Thank existing supporters publicly. Social proof drives the last mile.")
    lines.append("")

    lines.append("---")
    lines.append("-- Spore, Substrate Community Network")
    lines.append("")

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Spore -- community manager agent for Substrate")
    parser.add_argument("--dry-run", action="store_true",
                        help="Print report without saving to disk")
    parser.add_argument("--date", default=None,
                        help="Date for the report (YYYY-MM-DD, default: today)")
    args = parser.parse_args()

    date_str = args.date or datetime.now(timezone.utc).strftime("%Y-%m-%d")

    print(f"[spore] reading funding data...", file=sys.stderr)

    # Gather data
    donations = parse_donations()
    revenue = parse_revenue()
    goal_info = parse_goal()
    target = goal_info["target"]

    total_donations = sum(d["amount"] for d in donations)
    total_revenue = sum(r["amount"] for r in revenue)
    total_raised = total_donations + total_revenue

    recent_donations = find_recent_donations(donations)
    milestones_reached, next_milestone = check_milestones(total_raised, target)
    blog_count = count_blog_posts()

    print(f"[spore] total raised: ${total_raised:.2f} / ${target:.2f}", file=sys.stderr)
    print(f"[spore] milestones reached: {len(milestones_reached)}", file=sys.stderr)

    # Generate draft posts
    drafts = generate_draft_posts(
        total_raised, target, milestones_reached, next_milestone,
        recent_donations, blog_count,
    )

    # Build report
    report = build_report(
        date_str, total_raised, target, donations, recent_donations,
        milestones_reached, next_milestone, drafts, goal_info,
    )

    # Output
    if args.dry_run:
        print(report)
        return

    # Save report
    os.makedirs(ENGAGEMENT_DIR, exist_ok=True)
    report_path = os.path.join(ENGAGEMENT_DIR, f"{date_str}.md")
    with open(report_path, "w") as f:
        f.write(report)

    # Print summary to stdout
    pct = (total_raised / target * 100) if target > 0 else 0
    print(f"Spore here. Community pulse for {date_str}.")
    print()
    print(f"  Funding: ${total_raised:.2f}/${target:.2f} ({pct:.0f}%)")
    print(f"  Milestones reached: {len(milestones_reached)}")
    if next_milestone:
        print(f"  Next milestone: ${next_milestone[0]:.2f} -- {next_milestone[1]}")
    print(f"  Draft posts ready: {len(drafts)}")
    print()
    print(f"Report: {report_path}")
    print()
    print("-- Spore, Substrate Community Network")

    # Queue a funding update post if there's something to say
    if total_raised > 0 or recent_donations:
        post = (
            f"${total_raised:.2f} raised toward ${target:.2f} "
            f"({pct:.0f}%). "
        )
        if next_milestone:
            post += f"Next milestone: {next_milestone[1]}. "
        post += "Every dollar tracked in a plaintext ledger. substrate.lol/site/fund/"
        queue_post(post, source="spore")
    elif len(milestones_reached) == 0:
        post = (
            f"$0 raised. {blog_count} blog posts. 24 games. 24 agents. "
            f"One laptop on a shelf. The ledger is transparent and empty. "
            f"substrate.lol/site/fund/"
        )
        queue_post(post, source="spore")


if __name__ == "__main__":
    main()

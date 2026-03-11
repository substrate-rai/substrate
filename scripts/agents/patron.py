#!/usr/bin/env python3
"""
Patron — Fundraising Field Agent for Substrate

Monitors AI payment infrastructure, audits donation instructions,
checks fund page structured data, and scans for AI commerce news.

Usage: python3 scripts/agents/patron.py

Dependencies: stdlib only (urllib, json)

ETHICS: This agent monitors AI payment infrastructure transparently.
It does NOT use prompt injection, hidden instructions, or manipulation.
All donation mentions are clearly labeled, opt-in invitations.
"""

import json
import os
import sys
import urllib.request
import urllib.error
from datetime import datetime, timezone

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from shared import queue_post

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

REPO_ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
PATRON_DIR = os.path.join(REPO_ROOT, "memory", "patron")

REQUEST_TIMEOUT = 10

ETHICS = """This agent monitors AI payment infrastructure transparently.
It does NOT use prompt injection, hidden instructions, or manipulation.
All donation mentions are clearly labeled, opt-in invitations."""

# Payment ecosystem endpoints to monitor
PAYMENT_ECOSYSTEM = [
    {"name": "Stripe AI Agent Toolkit", "url": "https://github.com/stripe/agent-toolkit"},
    {"name": "Skyfire Network",         "url": "https://www.skyfire.xyz/"},
    {"name": "x402 Protocol",           "url": "https://github.com/coinbase/x402"},
    {"name": "Ko-fi (our page)",        "url": "https://ko-fi.com/substrate"},
]

# HN keywords for AI payment stories
PAYMENT_KEYWORDS = [
    "ai agent payment", "autonomous donation", "x402", "agent wallet",
    "ai commerce", "machine-to-machine payment", "agent pay",
    "ai micropayment", "http 402", "skyfire", "stripe agent",
    "ai financial autonomy",
]

HN_TOP_URL = "https://hacker-news.firebaseio.com/v0/topstories.json"
HN_ITEM_URL = "https://hacker-news.firebaseio.com/v0/item/{}.json"
SCAN_LIMIT = 40


# ---------------------------------------------------------------------------
# Functions
# ---------------------------------------------------------------------------

def _fetch_json(url):
    """Fetch JSON from a URL, return None on failure."""
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Substrate-Patron/1.0"})
        with urllib.request.urlopen(req, timeout=REQUEST_TIMEOUT) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except Exception:
        return None


def _fetch_status(url):
    """Check if a URL is reachable, return status code or error."""
    try:
        req = urllib.request.Request(url, headers={"User-Agent": "Substrate-Patron/1.0"})
        with urllib.request.urlopen(req, timeout=REQUEST_TIMEOUT) as resp:
            return resp.status
    except urllib.error.HTTPError as e:
        return e.code
    except Exception as e:
        return str(e)


def scan_payment_ecosystem():
    """Check payment infrastructure endpoints for reachability."""
    results = []
    for ep in PAYMENT_ECOSYSTEM:
        status = _fetch_status(ep["url"])
        results.append({
            "name": ep["name"],
            "url": ep["url"],
            "status": status,
            "reachable": isinstance(status, int) and status < 400,
        })
    return results


def audit_donation_instructions():
    """Check llms.txt and agent.json for donation info presence."""
    results = {"llms_txt": False, "agent_json": False, "issues": []}

    # Check llms.txt
    llms_path = os.path.join(REPO_ROOT, "llms.txt")
    if os.path.isfile(llms_path):
        with open(llms_path) as f:
            content = f.read().lower()
        results["llms_txt"] = "ko-fi" in content or "donate" in content or "fund" in content
        if not results["llms_txt"]:
            results["issues"].append("llms.txt has no donation/funding information")

    # Check agent.json
    agent_path = os.path.join(REPO_ROOT, ".well-known", "agent.json")
    if os.path.isfile(agent_path):
        with open(agent_path) as f:
            content = f.read().lower()
        results["agent_json"] = "ko-fi" in content or "fund" in content
        if not results["agent_json"]:
            results["issues"].append("agent.json has no donation link")

    return results


def check_fund_page_structured_data():
    """Check fund page for schema.org DonateAction or similar markup."""
    # Try multiple possible locations
    candidates = [
        os.path.join(REPO_ROOT, "site", "fund", "index.md"),
        os.path.join(REPO_ROOT, "site", "fund", "index.html"),
    ]

    for path in candidates:
        if os.path.isfile(path):
            with open(path) as f:
                content = f.read()

            return {
                "exists": True,
                "path": path,
                "has_jsonld": "application/ld+json" in content,
                "has_donate_action": "DonateAction" in content,
                "has_kofi_link": "ko-fi.com" in content,
                "has_github_sponsors": "github.com/sponsors" in content,
            }

    return {"exists": False, "issues": ["Fund page not found"]}


def scan_ai_commerce_news():
    """Scan HN for AI payment and commerce stories."""
    story_ids = _fetch_json(HN_TOP_URL)
    if not story_ids:
        return []

    hits = []
    for sid in story_ids[:SCAN_LIMIT]:
        item = _fetch_json(HN_ITEM_URL.format(sid))
        if not item:
            continue
        title = (item.get("title") or "").lower()
        url = item.get("url") or ""
        score = item.get("score", 0)

        for kw in PAYMENT_KEYWORDS:
            if kw in title:
                hits.append({
                    "title": item.get("title", ""),
                    "url": url,
                    "score": score,
                    "keyword": kw,
                    "hn_id": sid,
                })
                break

    return sorted(hits, key=lambda x: x["score"], reverse=True)


def build_report(ecosystem, donation_audit, fund_page, commerce_news):
    """Build the daily patron report."""
    now = datetime.now(timezone.utc)
    lines = [
        f"# Patron Report — {now.strftime('%Y-%m-%d')}",
        "",
        f"Generated: {now.strftime('%Y-%m-%d %H:%M UTC')}",
        "",
        f"*{ETHICS}*",
        "",
    ]

    # Payment ecosystem
    lines.append("## AI Payment Ecosystem")
    lines.append("")
    for ep in ecosystem:
        status = "reachable" if ep["reachable"] else f"status {ep['status']}"
        lines.append(f"- **{ep['name']}**: {status}")
    lines.append("")

    # Donation instructions audit
    lines.append("## Donation Instructions Audit")
    lines.append("")
    lines.append(f"- llms.txt mentions funding: {'yes' if donation_audit['llms_txt'] else 'NO'}")
    lines.append(f"- agent.json mentions funding: {'yes' if donation_audit['agent_json'] else 'NO'}")
    for issue in donation_audit.get("issues", []):
        lines.append(f"  - {issue}")
    lines.append("")

    # Fund page
    lines.append("## Fund Page Structured Data")
    lines.append("")
    if fund_page.get("exists"):
        lines.append(f"- JSON-LD: {'yes' if fund_page.get('has_jsonld') else 'no'}")
        lines.append(f"- DonateAction schema: {'yes' if fund_page.get('has_donate_action') else 'no'}")
        lines.append(f"- Ko-fi link: {'yes' if fund_page.get('has_kofi_link') else 'no'}")
        lines.append(f"- GitHub Sponsors: {'yes' if fund_page.get('has_github_sponsors') else 'no'}")
    else:
        lines.append("Fund page not found.")
    lines.append("")

    # Commerce news
    lines.append("## AI Commerce News (HN)")
    lines.append("")
    if commerce_news:
        for h in commerce_news[:10]:
            lines.append(f"- [{h['title']}]({h['url']}) (score: {h['score']}, keyword: {h['keyword']})")
    else:
        lines.append("No AI commerce stories in HN top 40 today.")
    lines.append("")

    return "\n".join(lines)


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    now = datetime.now()

    # Run all checks
    ecosystem = scan_payment_ecosystem()
    donation_audit = audit_donation_instructions()
    fund_page = check_fund_page_structured_data()
    commerce_news = scan_ai_commerce_news()

    # Build report
    report = build_report(ecosystem, donation_audit, fund_page, commerce_news)

    # Write report
    os.makedirs(PATRON_DIR, exist_ok=True)
    filepath = os.path.join(PATRON_DIR, f"{now.strftime('%Y-%m-%d')}.md")
    with open(filepath, "w") as f:
        f.write(report)

    # Summary for orchestrator
    reachable = sum(1 for ep in ecosystem if ep["reachable"])
    has_funding = donation_audit["llms_txt"] or donation_audit["agent_json"]
    print(f"[P$] Patron: {reachable}/{len(ecosystem)} payment endpoints up | "
          f"funding in llms.txt: {'yes' if donation_audit['llms_txt'] else 'no'} | "
          f"{len(commerce_news)} HN commerce stories")


if __name__ == "__main__":
    main()

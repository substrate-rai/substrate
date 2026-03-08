#!/usr/bin/env python3
"""Accounts Receivable Agent — tracks what's owed to Substrate and revenue.

Runs ENTIRELY LOCAL via Ollama (Qwen3 8B). No cloud API calls.
Reads/writes only to ledger/*.private.txt files.
Never exposes financial data to external services.

Usage:
    python3 scripts/agents/accounts_receivable.py status       # show all revenue
    python3 scripts/agents/accounts_receivable.py audit        # AI-assisted revenue audit
    python3 scripts/agents/accounts_receivable.py add          # interactive: add revenue
    python3 scripts/agents/accounts_receivable.py forecast     # project revenue + growth
    python3 scripts/agents/accounts_receivable.py pipeline     # show revenue pipeline/opportunities
    python3 scripts/agents/accounts_receivable.py health       # full financial health check (AP + AR)
"""

import argparse
import json
import os
import sys
from datetime import datetime, timedelta

import requests

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_DIR = os.path.dirname(os.path.dirname(SCRIPT_DIR))
LEDGER_DIR = os.path.join(REPO_DIR, "ledger")
REVENUE_FILE = os.path.join(LEDGER_DIR, "revenue.private.txt")
EXPENSES_FILE = os.path.join(LEDGER_DIR, "expenses.private.txt")
MEMORY_DIR = os.path.join(REPO_DIR, "memory")
OLLAMA_URL = "http://localhost:11434/api/chat"
MODEL = "qwen3:8b"

SYSTEM_PROMPT = """\
You are the Accounts Receivable agent for Substrate, a sovereign AI workstation.
You handle revenue tracking, growth forecasting, and funding strategy — locally and privately.

Context about Substrate's revenue model:
- Substrate is an open-source AI workstation that self-documents and self-publishes
- Potential revenue streams: GitHub Sponsors, donations, writing/content, compute services
- Current funding page exists at /fund/ on the website
- The project has 22 AI team members, 26 blog posts, 20 arcade titles
- Hardware fund goal: upgrade components (WiFi card, etc.)

Rules:
- Be precise with numbers. Never round unless asked.
- When projecting revenue, be realistic (not optimistic).
- Always compare revenue against expenses — the goal is self-funding.
- Identify concrete, actionable steps to increase revenue.
- Format currency as $X.XX always.
- Be direct. No filler. This is financial ops.
- Do NOT use thinking/reasoning tags. Answer directly."""

# ---------------------------------------------------------------------------
# Ledger operations
# ---------------------------------------------------------------------------

def ensure_private_file():
    """Ensure the private revenue file exists."""
    if not os.path.exists(REVENUE_FILE):
        os.makedirs(LEDGER_DIR, exist_ok=True)
        with open(REVENUE_FILE, "w") as f:
            f.write("# Substrate Revenue Ledger\n")
            f.write("# Format: DATE | SOURCE | AMOUNT | NOTES\n")
            f.write("# -----------------------------------------\n")


def parse_revenue():
    """Parse the private revenue ledger. Returns list of dicts."""
    ensure_private_file()
    revenue = []
    with open(REVENUE_FILE) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = [p.strip() for p in line.split("|")]
            if len(parts) >= 3:
                amount_str = parts[2].replace("$", "").replace("+", "").strip()
                try:
                    amount = float(amount_str)
                except ValueError:
                    continue
                revenue.append({
                    "date": parts[0],
                    "source": parts[1],
                    "amount": amount,
                    "notes": parts[3] if len(parts) > 3 else "",
                    "raw": line,
                })
    return revenue


def parse_expenses():
    """Parse the private expense ledger for cross-reference."""
    if not os.path.exists(EXPENSES_FILE):
        return []
    expenses = []
    with open(EXPENSES_FILE) as f:
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


def add_revenue(source, amount, notes=""):
    """Append revenue to the private ledger."""
    ensure_private_file()
    date = datetime.now().strftime("%Y-%m-%d")
    line = f"{date} | {source} | +${amount:.2f} | {notes}"
    with open(REVENUE_FILE, "a") as f:
        f.write(line + "\n")
    return date, line


def total_revenue(entries):
    return sum(e["amount"] for e in entries)


def total_expenses(entries):
    return sum(e["amount"] for e in entries)


# ---------------------------------------------------------------------------
# Repo scanning (for pipeline context)
# ---------------------------------------------------------------------------

def scan_funding_assets():
    """Scan the repo for funding-related pages and donation setup."""
    assets = []
    fund_page = os.path.join(REPO_DIR, "site", "fund.md")
    if not os.path.exists(fund_page):
        fund_page = os.path.join(REPO_DIR, "fund.md")
    if os.path.exists(fund_page):
        assets.append("Fund page exists")
    else:
        assets.append("NO fund page found")

    sponsor_page = os.path.join(REPO_DIR, "site", "sponsor.md")
    if not os.path.exists(sponsor_page):
        sponsor_page = os.path.join(REPO_DIR, "sponsor.md")
    if os.path.exists(sponsor_page):
        assets.append("Sponsor page exists")

    # Check for donation script
    donations_py = os.path.join(REPO_DIR, "scripts", "donations.py")
    if os.path.exists(donations_py):
        assets.append("Donation monitoring script exists")
    else:
        assets.append("NO donation monitoring script")

    # Count content assets
    posts_dir = os.path.join(REPO_DIR, "_posts")
    if os.path.isdir(posts_dir):
        posts = [f for f in os.listdir(posts_dir) if f.endswith(".md")]
        assets.append(f"{len(posts)} blog posts")

    games_dir = os.path.join(REPO_DIR, "games")
    if os.path.isdir(games_dir):
        games = [d for d in os.listdir(games_dir) if os.path.isdir(os.path.join(games_dir, d))]
        assets.append(f"{len(games)} arcade games")

    return assets


# ---------------------------------------------------------------------------
# Local AI (Ollama)
# ---------------------------------------------------------------------------

def ask_local(prompt, context=""):
    """Query the local Qwen3 model. Returns response text."""
    messages = [{"role": "system", "content": SYSTEM_PROMPT}]
    if context:
        messages.append({"role": "user", "content": f"Financial context:\n{context}"})
        messages.append({"role": "assistant", "content": "Understood. I have the financial data."})
    messages.append({"role": "user", "content": prompt})

    try:
        resp = requests.post(OLLAMA_URL, json={
            "model": MODEL,
            "messages": messages,
            "stream": False,
            "think": False,
        }, timeout=120)
    except requests.ConnectionError:
        return "[error: ollama not reachable at localhost:11434]"

    if resp.status_code != 200:
        return f"[error: ollama returned {resp.status_code}]"

    data = resp.json()
    return data.get("message", {}).get("content", "[no response]")


# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

def cmd_status():
    """Show current revenue status."""
    rev = parse_revenue()
    exp = parse_expenses()
    rev_total = total_revenue(rev)
    exp_total = total_expenses(exp)
    net = rev_total - exp_total

    print("\033[1;32m  ACCOUNTS RECEIVABLE — STATUS\033[0m")
    print("\033[2m  ─────────────────────────────────────────────────\033[0m")
    print()

    if not rev:
        print("  \033[2mNo revenue recorded yet.\033[0m")
    else:
        print(f"  {'DATE':<14} {'SOURCE':<24} {'AMOUNT':>10}  NOTES")
        print(f"  {'─'*12}   {'─'*22}   {'─'*8}   {'─'*20}")
        for r in rev:
            print(f"  {r['date']:<14} {r['source']:<24} \033[32m+${r['amount']:>7.2f}\033[0m  {r['notes']}")
        print(f"  {'─'*12}   {'─'*22}   {'─'*8}")
        print(f"  {'':14} {'TOTAL REVENUE':<24} \033[1;32m+${rev_total:>7.2f}\033[0m")

    print()
    print(f"  \033[2m──── P&L SUMMARY ────\033[0m")
    print(f"  Revenue:   \033[32m+${rev_total:>8.2f}\033[0m")
    print(f"  Expenses:  \033[31m-${exp_total:>8.2f}\033[0m")
    if net >= 0:
        print(f"  Net:       \033[1;32m+${net:>8.2f}\033[0m")
    else:
        print(f"  Net:       \033[1;31m ${net:>8.2f}\033[0m")

    if exp_total > 0 and rev_total > 0:
        coverage = (rev_total / exp_total) * 100
        print(f"  Coverage:  {coverage:.1f}%")
    elif exp_total > 0:
        print(f"  Coverage:  0.0% \033[2m(100% operator-funded)\033[0m")
    print()


def cmd_audit():
    """AI-assisted revenue audit."""
    rev = parse_revenue()
    exp = parse_expenses()

    context = "Revenue entries:\n"
    if rev:
        for r in rev:
            context += f"  {r['date']} | {r['source']} | +${r['amount']:.2f} | {r['notes']}\n"
    else:
        context += "  (none — zero revenue)\n"
    context += f"\nTotal revenue: ${total_revenue(rev):.2f}"
    context += f"\nTotal expenses: ${total_expenses(exp):.2f}"
    context += f"\nNet: ${total_revenue(rev) - total_expenses(exp):.2f}"
    context += f"\nProject age: launched 2026-03-07"

    print("\033[1;32m  ACCOUNTS RECEIVABLE — AUDIT\033[0m")
    print("\033[2m  Running local AI audit (Qwen3 8B)...\033[0m")
    print()

    response = ask_local(
        "Audit Substrate's revenue situation. Address:\n"
        "1. Current revenue health (or lack thereof)\n"
        "2. Revenue diversification — are we too dependent on one source?\n"
        "3. What's the gap between revenue and expenses?\n"
        "4. What are the three fastest paths to first dollar (or next dollar)?\n"
        "5. What revenue milestones should we target in 30/60/90 days?\n",
        context=context,
    )
    print(response)
    print()


def cmd_add():
    """Interactive revenue entry."""
    print("\033[1;37m  NEW REVENUE\033[0m")
    print()
    source = input("  Source: ").strip()
    if not source:
        print("  Cancelled.")
        return
    amount_str = input("  Amount (e.g. 5.00): ").strip()
    try:
        amount = float(amount_str.replace("$", "").replace("+", ""))
    except ValueError:
        print("  Invalid amount.")
        return
    notes = input("  Notes (optional): ").strip()

    date, line = add_revenue(source, amount, notes)
    print()
    print(f"  \033[32mRecorded:\033[0m {line}")
    print()


def cmd_forecast():
    """Project revenue forward using local AI."""
    rev = parse_revenue()
    exp = parse_expenses()
    assets = scan_funding_assets()

    context = "Revenue entries:\n"
    if rev:
        for r in rev:
            context += f"  {r['date']} | {r['source']} | +${r['amount']:.2f} | {r['notes']}\n"
    else:
        context += "  (none)\n"
    context += f"\nTotal revenue: ${total_revenue(rev):.2f}"
    context += f"\nTotal expenses: ${total_expenses(exp):.2f}/mo"
    context += f"\nFunding assets: {', '.join(assets)}"
    context += f"\nCurrent date: {datetime.now().strftime('%Y-%m-%d')}"

    print("\033[1;32m  ACCOUNTS RECEIVABLE — FORECAST\033[0m")
    print("\033[2m  Running local AI forecast (Qwen3 8B)...\033[0m")
    print()

    response = ask_local(
        "Forecast Substrate's revenue potential for the next 3 and 12 months.\n"
        "Consider:\n"
        "1. Which revenue streams are most realistic given current assets?\n"
        "2. What conversion rates should we expect? (visitors → sponsors)\n"
        "3. When could Substrate realistically break even?\n"
        "4. What's the minimum viable revenue to sustain operations?\n"
        "5. What specific actions would accelerate revenue the most?\n",
        context=context,
    )
    print(response)
    print()


def cmd_pipeline():
    """Show the revenue pipeline — what's set up, what's missing."""
    rev = parse_revenue()
    exp = parse_expenses()
    assets = scan_funding_assets()

    print("\033[1;32m  ACCOUNTS RECEIVABLE — PIPELINE\033[0m")
    print("\033[2m  ─────────────────────────────────────────────────\033[0m")
    print()

    # Revenue streams status
    streams = [
        ("GitHub Sponsors", "not verified"),
        ("Direct donations", "not verified"),
        ("Writing/content", "not active"),
        ("Compute services", "not active"),
        ("Consulting", "not active"),
    ]

    # Check if we have revenue from any source
    active_sources = set(r["source"].lower() for r in rev)
    for i, (name, status) in enumerate(streams):
        for src in active_sources:
            if name.lower().split()[0] in src:
                streams[i] = (name, "active")
                break

    print("  \033[1;37mREVENUE STREAMS\033[0m")
    print()
    for name, status in streams:
        if status == "active":
            icon = "\033[32m●\033[0m"
        elif status == "not verified":
            icon = "\033[33m○\033[0m"
        else:
            icon = "\033[31m○\033[0m"
        print(f"  {icon}  {name:<24} {status}")

    print()
    print("  \033[1;37mFUNDING ASSETS\033[0m")
    print()
    for a in assets:
        print(f"  •  {a}")

    print()

    # Ask AI for pipeline analysis
    context = f"Revenue streams: {json.dumps(streams)}\n"
    context += f"Funding assets: {', '.join(assets)}\n"
    context += f"Current revenue: ${total_revenue(rev):.2f}\n"
    context += f"Current expenses: ${total_expenses(exp):.2f}/mo\n"

    print("\033[2m  Running local pipeline analysis (Qwen3 8B)...\033[0m")
    print()

    response = ask_local(
        "Analyze this revenue pipeline. For each inactive stream:\n"
        "1. What's needed to activate it?\n"
        "2. Expected time to first revenue?\n"
        "3. Realistic monthly potential?\n\n"
        "Rank the streams by effort-to-revenue ratio. "
        "Which one should Substrate activate FIRST?",
        context=context,
    )
    print(response)
    print()


def cmd_health():
    """Full financial health check — AP + AR combined."""
    rev = parse_revenue()
    exp = parse_expenses()
    rev_total = total_revenue(rev)
    exp_total = total_expenses(exp)
    net = rev_total - exp_total

    print("\033[1;37m  ╔═══════════════════════════════════════════════════╗\033[0m")
    print("\033[1;37m  ║        FINANCIAL HEALTH CHECK                    ║\033[0m")
    print("\033[1;37m  ╚═══════════════════════════════════════════════════╝\033[0m")
    print()

    # Vital signs
    print("  \033[1;37mVITAL SIGNS\033[0m")
    print()

    # Revenue
    if rev_total > 0:
        print(f"  Revenue:       \033[32m+${rev_total:.2f}/mo\033[0m")
    else:
        print(f"  Revenue:       \033[31m$0.00\033[0m  \033[2m← critical\033[0m")

    # Expenses
    print(f"  Expenses:      \033[31m-${exp_total:.2f}/mo\033[0m")

    # Net
    if net >= 0:
        print(f"  Net:           \033[1;32m+${net:.2f}/mo\033[0m")
    else:
        print(f"  Net:           \033[1;31m${net:.2f}/mo\033[0m")

    # Coverage
    if exp_total > 0:
        coverage = (rev_total / exp_total) * 100
        if coverage >= 100:
            bar_color = "\033[32m"
            status = "SELF-FUNDING"
        elif coverage >= 50:
            bar_color = "\033[33m"
            status = "PARTIAL"
        else:
            bar_color = "\033[31m"
            status = "OPERATOR-FUNDED"

        bar_len = 30
        filled = min(int(bar_len * coverage / 100), bar_len)
        bar = "█" * filled + "░" * (bar_len - filled)
        print(f"  Coverage:      {bar_color}[{bar}] {coverage:.0f}%\033[0m  {status}")
    print()

    # Runway
    if net < 0 and exp_total > 0:
        print(f"  \033[2mAt current burn, operator subsidizes ${abs(net):.2f}/mo\033[0m")

    # Breakeven
    if rev_total < exp_total:
        gap = exp_total - rev_total
        print(f"  \033[2mBreakeven gap: ${gap:.2f}/mo additional revenue needed\033[0m")
    print()

    # AI assessment
    context = f"Revenue: ${rev_total:.2f}/mo\n"
    context += f"Expenses: ${exp_total:.2f}/mo\n"
    context += f"Net: ${net:.2f}/mo\n"
    context += f"Project age: launched 2026-03-07\n"
    context += f"Revenue entries: {len(rev)}\n"
    context += f"Expense entries: {len(exp)}\n"

    print("\033[2m  Running local health assessment (Qwen3 8B)...\033[0m")
    print()

    response = ask_local(
        "Give a brief financial health assessment for Substrate. Include:\n"
        "1. Overall health grade (A through F)\n"
        "2. The single biggest financial risk right now\n"
        "3. The single most impactful action to improve finances\n"
        "4. A one-sentence prognosis\n\n"
        "Be honest and direct. This is for the operator's eyes only.",
        context=context,
    )
    print(response)
    print()


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Accounts Receivable Agent — local-only revenue tracking for Substrate"
    )
    parser.add_argument(
        "command",
        choices=["status", "audit", "add", "forecast", "pipeline", "health"],
        help="AR command to run",
    )
    args = parser.parse_args()

    cmds = {
        "status": cmd_status,
        "audit": cmd_audit,
        "add": cmd_add,
        "forecast": cmd_forecast,
        "pipeline": cmd_pipeline,
        "health": cmd_health,
    }
    cmds[args.command]()


if __name__ == "__main__":
    main()

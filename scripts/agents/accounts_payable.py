#!/usr/bin/env python3
"""Accounts Payable Agent — tracks what Substrate owes and when.

Runs ENTIRELY LOCAL via Ollama (Qwen3 8B). No cloud API calls.
Reads/writes only to ledger/*.private.txt files.
Never exposes financial data to external services.

Usage:
    python3 scripts/agents/accounts_payable.py status       # show all obligations
    python3 scripts/agents/accounts_payable.py audit        # AI-assisted expense audit
    python3 scripts/agents/accounts_payable.py add          # interactive: add expense
    python3 scripts/agents/accounts_payable.py forecast     # project expenses forward
    python3 scripts/agents/accounts_payable.py alert        # check for upcoming/overdue
"""

import argparse
import json
import os
import sys
from datetime import datetime, timedelta

from context import load_context

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_DIR = os.path.dirname(os.path.dirname(SCRIPT_DIR))
LEDGER_DIR = os.path.join(REPO_DIR, "ledger")
EXPENSES_FILE = os.path.join(LEDGER_DIR, "expenses.private.txt")

_BASE_PROMPT = """\
You are the Accounts Payable agent for Substrate, an autonomous AI workstation.
You handle expense tracking, bill forecasting, and cost optimization — locally and privately.

Rules:
- Be precise with numbers. Never round unless asked.
- Flag any expense that seems unusual or could be reduced.
- When forecasting, be conservative (assume costs stay or rise, never fall).
- Always think about: can this cost be eliminated? reduced? deferred?
- Format currency as $X.XX always.
- Be direct. No filler. This is financial ops, not a blog post.
- Do NOT use thinking/reasoning tags. Answer directly."""

_ctx = load_context("Mint")
SYSTEM_PROMPT = _ctx.system_prompt(_BASE_PROMPT)

# ---------------------------------------------------------------------------
# Ledger operations
# ---------------------------------------------------------------------------

def ensure_private_file():
    """Ensure the private expenses file exists."""
    if not os.path.exists(EXPENSES_FILE):
        os.makedirs(LEDGER_DIR, exist_ok=True)
        with open(EXPENSES_FILE, "w") as f:
            f.write("# Substrate Expense Ledger\n")
            f.write("# Format: DATE | ITEM | AMOUNT | NOTES\n")
            f.write("# -----------------------------------------\n")


def parse_expenses():
    """Parse the private expense ledger. Returns list of dicts."""
    ensure_private_file()
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
                    "raw": line,
                })
    return expenses


def add_expense(item, amount, notes=""):
    """Append an expense to the private ledger."""
    ensure_private_file()
    date = datetime.now().strftime("%Y-%m-%d")
    line = f"{date} | {item} | -${amount:.2f} | {notes}"
    with open(EXPENSES_FILE, "a") as f:
        f.write(line + "\n")
    return date, line


def total_monthly_burn(expenses):
    """Estimate monthly burn from expense records."""
    # For now, sum all recorded expenses as monthly (most are subscriptions)
    return sum(e["amount"] for e in expenses)


# ---------------------------------------------------------------------------
# Local AI (Ollama)
# ---------------------------------------------------------------------------

def ask_local(prompt, context=""):
    """Query the local Qwen3 model. Returns response text."""
    from ollama_client import chat, OllamaError
    messages = []
    if context:
        messages.append({"role": "user", "content": f"Context:\n{context}"})
        messages.append({"role": "assistant", "content": "Understood. I have the context."})
    messages.append({"role": "user", "content": prompt})
    try:
        return chat(messages, system=SYSTEM_PROMPT)
    except OllamaError as e:
        return f"[error: {e}]"


# ---------------------------------------------------------------------------
# Commands
# ---------------------------------------------------------------------------

def cmd_status():
    """Show current expense status."""
    expenses = parse_expenses()
    burn = total_monthly_burn(expenses)

    print("\033[1;31m  ACCOUNTS PAYABLE — STATUS\033[0m")
    print("\033[2m  ─────────────────────────────────────────────────\033[0m")
    print()

    if not expenses:
        print("  No expenses recorded.")
        return

    print(f"  {'DATE':<14} {'ITEM':<24} {'AMOUNT':>10}  NOTES")
    print(f"  {'─'*12}   {'─'*22}   {'─'*8}   {'─'*20}")
    for e in expenses:
        print(f"  {e['date']:<14} {e['item']:<24} \033[31m-${e['amount']:>7.2f}\033[0m  {e['notes']}")

    print(f"  {'─'*12}   {'─'*22}   {'─'*8}")
    print(f"  {'':14} {'MONTHLY BURN':<24} \033[1;31m-${burn:>7.2f}\033[0m")
    print(f"  {'':14} {'ANNUAL PROJECTION':<24} \033[1;31m-${burn * 12:>7.2f}\033[0m")
    print()


def cmd_audit():
    """AI-assisted expense audit using local model."""
    expenses = parse_expenses()
    if not expenses:
        print("  No expenses to audit.")
        return

    context = "Current expenses:\n"
    for e in expenses:
        context += f"  {e['date']} | {e['item']} | -${e['amount']:.2f} | {e['notes']}\n"
    context += f"\nTotal monthly burn: ${total_monthly_burn(expenses):.2f}"

    print("\033[1;31m  ACCOUNTS PAYABLE — AUDIT\033[0m")
    print("\033[2m  Running local AI audit (Qwen3 8B)...\033[0m")
    print()

    response = ask_local(
        "Audit these expenses. For each one:\n"
        "1. Is it necessary for Substrate operations?\n"
        "2. Can it be reduced or eliminated?\n"
        "3. Are there cheaper alternatives?\n"
        "4. What's the cost per day?\n\n"
        "Then give an overall assessment and any recommendations.",
        context=context,
    )
    print(response)
    print()


def cmd_add():
    """Interactive expense entry."""
    print("\033[1;37m  NEW EXPENSE\033[0m")
    print()
    item = input("  Item name: ").strip()
    if not item:
        print("  Cancelled.")
        return
    amount_str = input("  Amount (e.g. 200.00): ").strip()
    try:
        amount = float(amount_str.replace("$", "").replace("-", ""))
    except ValueError:
        print("  Invalid amount.")
        return
    notes = input("  Notes (optional): ").strip()

    date, line = add_expense(item, amount, notes)
    print()
    print(f"  \033[32mRecorded:\033[0m {line}")
    print()


def cmd_forecast():
    """Project expenses forward using local AI."""
    expenses = parse_expenses()
    burn = total_monthly_burn(expenses)

    context = "Current expenses:\n"
    for e in expenses:
        context += f"  {e['date']} | {e['item']} | -${e['amount']:.2f} | {e['notes']}\n"
    context += f"\nTotal monthly burn: ${burn:.2f}"
    context += f"\nCurrent date: {datetime.now().strftime('%Y-%m-%d')}"
    context += f"\nSubstrate birthday: 2026-03-07"

    print("\033[1;31m  ACCOUNTS PAYABLE — FORECAST\033[0m")
    print("\033[2m  Running local AI forecast (Qwen3 8B)...\033[0m")
    print()

    # Show hard numbers first
    print(f"  Monthly burn:    \033[31m-${burn:.2f}\033[0m")
    print(f"  Quarterly:       \033[31m-${burn * 3:.2f}\033[0m")
    print(f"  Annual:          \033[31m-${burn * 12:.2f}\033[0m")
    print()

    response = ask_local(
        "Forecast Substrate's expenses for the next 3 months and 12 months.\n"
        "Consider:\n"
        "1. Which costs are fixed vs variable?\n"
        "2. What new expenses might arise as the project grows?\n"
        "   (e.g. domain renewals, cloud bursting, hardware maintenance)\n"
        "3. What's the minimum viable burn rate?\n"
        "4. At what revenue level does Substrate break even?\n",
        context=context,
    )
    print(response)
    print()


def cmd_alert():
    """Check for upcoming or notable expense events."""
    expenses = parse_expenses()
    today = datetime.now()

    print("\033[1;33m  ACCOUNTS PAYABLE — ALERTS\033[0m")
    print("\033[2m  ─────────────────────────────────────────────────\033[0m")
    print()

    alerts = []

    for e in expenses:
        try:
            exp_date = datetime.strptime(e["date"], "%Y-%m-%d")
        except ValueError:
            continue

        # Check if subscription is about to renew (within 7 days of monthly anniversary)
        day_of_month = exp_date.day
        if today.day <= day_of_month <= today.day + 7 or (today.day > 24 and day_of_month <= 7):
            days_until = day_of_month - today.day
            if days_until < 0:
                days_until += 30
            alerts.append(f"  \033[33m!\033[0m  {e['item']} (-${e['amount']:.2f}) renews in ~{days_until} days")

    if not alerts:
        print("  \033[32mNo upcoming alerts.\033[0m All expenses accounted for.")
    else:
        for a in alerts:
            print(a)

    # Always show burn summary
    burn = total_monthly_burn(expenses)
    print()
    print(f"  Monthly burn: \033[31m-${burn:.2f}\033[0m")
    print()


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    parser = argparse.ArgumentParser(
        description="Accounts Payable Agent — local-only expense tracking for Substrate"
    )
    parser.add_argument(
        "command",
        choices=["status", "audit", "add", "forecast", "alert"],
        help="AP command to run",
    )
    args = parser.parse_args()

    cmds = {
        "status": cmd_status,
        "audit": cmd_audit,
        "add": cmd_add,
        "forecast": cmd_forecast,
        "alert": cmd_alert,
    }
    cmds[args.command]()


if __name__ == "__main__":
    main()

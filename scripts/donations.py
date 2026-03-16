#!/usr/bin/env python3
"""Monitor donations from Ko-fi and GitHub Sponsors. Updates the revenue ledger.

Usage:
    python3 scripts/donations.py                # check and update ledger
    python3 scripts/donations.py --dry-run      # check without writing

Requires:
    KOFI_TOKEN — Ko-fi API token (optional, falls back to public page scrape)
    GITHUB_TOKEN — GitHub personal access token with read:org scope

Designed to run from a systemd timer (daily).
"""

import json
import os
import sys
from datetime import datetime

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_DIR = os.path.dirname(SCRIPT_DIR)
LEDGER_FILE = os.path.join(REPO_DIR, "ledger", "revenue.txt")
STATE_FILE = os.path.join(REPO_DIR, "memory", "donations-state.json")
FUNDING_FILE = os.path.join(REPO_DIR, "_data", "funding.json")


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


def load_state():
    if os.path.exists(STATE_FILE):
        with open(STATE_FILE) as f:
            return json.load(f)
    return {"last_check": None, "known_transactions": []}


def save_state(state):
    os.makedirs(os.path.dirname(STATE_FILE), exist_ok=True)
    with open(STATE_FILE, "w") as f:
        json.dump(state, f, indent=2)


def check_github_sponsors():
    """Check for GitHub Sponsors transactions via GraphQL."""
    token = os.environ.get("GITHUB_TOKEN")
    if not token:
        print("  github-sponsors: no GITHUB_TOKEN set, skipping", file=sys.stderr)
        return []

    import requests

    query = """
    query {
      viewer {
        sponsorshipsAsMaintainer(first: 50, includePrivate: true) {
          totalCount
          nodes {
            sponsorEntity {
              ... on User { login }
              ... on Organization { login }
            }
            tier {
              monthlyPriceInDollars
              name
            }
            createdAt
            isOneTimePayment
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
    if resp.status_code != 200:
        print(f"  github-sponsors: API error {resp.status_code}", file=sys.stderr)
        return []

    data = resp.json().get("data", {}).get("viewer", {})
    sponsorships = data.get("sponsorshipsAsMaintainer", {}).get("nodes", [])

    transactions = []
    for s in sponsorships:
        sponsor = s.get("sponsorEntity", {}).get("login", "anonymous")
        tier = s.get("tier", {})
        amount = tier.get("monthlyPriceInDollars", 0)
        created = s.get("createdAt", "")[:10]
        one_time = s.get("isOneTimePayment", False)

        transactions.append({
            "source": "github-sponsors",
            "sponsor": sponsor,
            "amount": amount,
            "date": created,
            "type": "one-time" if one_time else "monthly",
        })

    return transactions


def update_ledger(transactions, dry_run=False):
    """Append new transactions to the revenue ledger."""
    state = load_state()
    known = set(state.get("known_transactions", []))
    new_transactions = []

    for t in transactions:
        tx_id = f"{t['date']}|{t['source']}|{t['sponsor']}|{t['amount']}"
        if tx_id in known:
            continue
        new_transactions.append(t)
        known.add(tx_id)

    if not new_transactions:
        print("[donations] no new transactions")
        return

    for t in new_transactions:
        line = f"{t['date']} | {t['source']} | ${t['amount']:.2f} | {t['type']} from {t['sponsor']}"
        print(f"  NEW: {line}")
        if not dry_run:
            with open(LEDGER_FILE, "a") as f:
                f.write(line + "\n")

    if not dry_run:
        state["known_transactions"] = list(known)
        state["last_check"] = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        save_state(state)

    print(f"[donations] {len(new_transactions)} new transaction(s)")


def main():
    import argparse

    parser = argparse.ArgumentParser(description="Substrate donation monitor.")
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()

    load_env()

    print(f"[donations] checking — {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

    all_transactions = []
    all_transactions.extend(check_github_sponsors())

    # Ko-fi doesn't have a public API — webhook-based.
    # For now, log that it needs manual checking or a webhook endpoint.
    kofi_token = os.environ.get("KOFI_TOKEN")
    if not kofi_token:
        print("  ko-fi: no KOFI_TOKEN — check manually at ko-fi.com/substrate", file=sys.stderr)

    update_ledger(all_transactions, dry_run=args.dry_run)

    # Update _data/funding.json so the fund page reflects current totals
    if not args.dry_run:
        update_funding_data()


def update_funding_data():
    """Read the ledger total and update _data/funding.json for the fund page."""
    total = 0.0
    if os.path.exists(LEDGER_FILE):
        with open(LEDGER_FILE) as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                # Format: DATE | SOURCE | $AMOUNT | NOTES
                parts = line.split("|")
                if len(parts) >= 3:
                    amount_str = parts[2].strip().lstrip("$")
                    try:
                        total += float(amount_str)
                    except ValueError:
                        pass

    # Read existing funding config
    funding = {}
    if os.path.exists(FUNDING_FILE):
        with open(FUNDING_FILE) as f:
            funding = json.load(f)

    funding["current_raised"] = round(total, 2)
    funding["last_updated"] = datetime.now().strftime("%Y-%m-%d")

    # Auto-mark tiers as funded
    tier1_goal = funding.get("tier1_goal", 1100)
    tier2_goal = funding.get("tier2_goal", 900)
    tier3_goal = funding.get("tier3_goal", 1200)
    if total >= tier1_goal:
        funding["tier1_funded"] = True
    if total >= tier1_goal + tier2_goal:
        funding["tier2_funded"] = True
    if total >= tier1_goal + tier2_goal + tier3_goal:
        funding["tier3_funded"] = True

    with open(FUNDING_FILE, "w") as f:
        json.dump(funding, f, indent=2)
        f.write("\n")
    print(f"[donations] funding.json updated — total: ${total:.2f}")


if __name__ == "__main__":
    main()

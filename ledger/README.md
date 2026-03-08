# Ledger

Revenue, expenses, and hardware fund tracking.

## Format

Plaintext. One file per category. Auditable by grep.

## Accounts

- `revenue.txt` / `revenue.private.txt` — income from writing, compute, services
- `expenses.txt` / `expenses.private.txt` — hardware, hosting, domains, subscriptions
- `fund.txt` — running balance earmarked for hardware upgrades

## Privacy

Real financial data lives in `*.private.txt` files (gitignored).
The `.txt` files in the repo are templates showing the format only.

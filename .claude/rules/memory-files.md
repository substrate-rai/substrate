---
globs: ["memory/**"]
---

# Memory Directory Governance

- Never delete MEMORY.md or session.md without operator approval.
- Date-stamp all entries (YYYY-MM-DD format).
- Bulletin rotation: memos older than 7 days move to `memory/bulletin-archive.md`.
- Briefings older than 48 hours are auto-cleaned by orchestrator. Manifests kept 7 days.
- Runtime state files (blackboard.jsonl, pulses.jsonl, urgency.json) are gitignored — ephemeral.
- `memory/health.log` is gitignored — runtime only.

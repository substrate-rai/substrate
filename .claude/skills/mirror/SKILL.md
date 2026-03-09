---
name: mirror
description: Run the self-assessment mirror. Use when checking system status, gaps, or what to build next.
allowed-tools: Bash(python *), Read, Grep
---

# Mirror — Self-Assessment

Run Substrate's mirror loop: scan the repo, check health, identify gaps, propose the next build.

## Steps

1. Run the mirror:
   ```bash
   cd /home/operator/substrate && python3 scripts/mirror.py
   ```
2. Read the latest report from `memory/mirror/` (most recent date)
3. Summarize: what's complete, what's next, system health
4. If `$ARGUMENTS` is provided, filter the report for that topic

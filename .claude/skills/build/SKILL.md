---
name: build
description: Run the autonomy loop build executor. Use when executing the next mirror proposal or a specific build target.
argument-hint: "[--dry-run] [--list]"
allowed-tools: Bash(python *), Read, Grep, Edit, Write
---

# Build — Autonomy Loop Executor

Execute the top mirror proposal: scaffold code via Ollama, smoke test, commit or revert.

## Steps

1. Run the build executor:
   ```bash
   cd /home/operator/substrate && python3 scripts/build.py $ARGUMENTS
   ```
2. If `--dry-run`: show what would be built without executing
3. If `--list`: show all incomplete milestones
4. Otherwise: execute the top proposal from the latest mirror report
5. Report the result: what was built, what was tested, pass/fail

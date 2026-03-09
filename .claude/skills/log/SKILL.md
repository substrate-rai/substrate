---
name: log
description: Process raw data into structured logs using Qwen3 locally. Use when the user wants to log system state, git activity, or agent output.
argument-hint: "[source: git|agents|health|all]"
allowed-tools: Bash(python *), Bash(git *), Read, Grep
---

# Log — Qwen3 Structured Logger

Use the local Qwen3 8B to process raw data into clean structured logs.

## Sources

- `git` — process recent git log into structured entries
- `agents` — process latest agent briefing into log format
- `health` — process system health into log format
- `all` — all of the above

## Steps

1. Gather raw data based on `$ARGUMENTS`:
   - git: `git log --oneline -20`
   - agents: read latest `memory/briefings/*.md`
   - health: `nvidia-smi`, ollama status, disk usage
2. Send to Qwen3 for structuring:
   ```bash
   cd /home/operator/substrate && python3 scripts/route.py log "Structure this into a clean log with timestamps and categories: RAW_DATA"
   ```
3. Output the structured log
4. If `--summarize` flag is present, pipe to Claude for prose summary:
   ```bash
   python3 scripts/route.py log "..." | python3 scripts/route.py summarize
   ```

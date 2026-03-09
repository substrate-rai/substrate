---
name: heartbeat
description: Check on the agents. Use when asking if agents are running, what they reported, or to see the latest briefing.
allowed-tools: Read, Grep, Bash(ls *), Bash(wc *), Bash(tail *)
---

# Heartbeat — Agent Status

Check on the 24-agent swarm and their latest output.

## Steps

1. Read the latest briefing from `memory/briefings/` (most recent file)
2. Check `memory/accountability.log` for recent agent runs (last 20 lines)
3. Summarize: which agents ran, key findings, any failures
4. If `$ARGUMENTS` names a specific agent (e.g. "byte", "pixel", "sentinel"), find that agent's latest report in the relevant `memory/` subdirectory

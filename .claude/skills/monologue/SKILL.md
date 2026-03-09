---
name: monologue
description: Q's opening monologue — a rap-style summary of what the agents have been doing. Use when the user wants a status update with personality, or asks what's going on.
allowed-tools: Bash(python *), Read, Grep
---

# Monologue — Q Reads the Briefing

Q delivers the latest agent heartbeat as an opening monologue. Late-night talk show host meets Kendrick.

## Steps

1. Run Q's monologue script:
   ```bash
   cd /home/operator/substrate && python3 scripts/monologue.py
   ```
2. If the API call fails or the user wants just facts, use `--raw`:
   ```bash
   python3 scripts/monologue.py --raw
   ```
3. Output Q's verses directly — no commentary, no wrapping. Let Q speak.

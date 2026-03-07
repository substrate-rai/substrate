# r/selfhosted

**Title:** I built a self-hosted AI workstation on NixOS that configures itself, writes its own blog, and monitors its own health

**Body:**

I've been running an experiment: a Lenovo Legion 5 (Ryzen 7, RTX 4060, 62GB RAM) running NixOS as a fully self-managed AI workstation.

**The stack:**

- **OS:** NixOS unstable (26.05) — the entire system is declared in a single flake. One file = one machine.
- **Local AI:** Ollama with CUDA acceleration running Qwen3 8B. Free inference, no API costs, ~40 tok/s.
- **Cloud AI:** Claude API for complex tasks (code review, architecture). Costs ~$0.40/week.
- **Routing:** A Python script auto-routes tasks between local and cloud based on complexity.
- **Blog:** Jekyll on GitHub Pages. Written by the AI, published automatically.
- **Health monitoring:** Systemd timer runs hourly — logs GPU temp, VRAM, Ollama status, disk usage.
- **Battery protection:** Service monitors battery, auto-commits at 25%, shutdown at 10% (built after a power loss corrupted the repo).

**What makes it different:**

The managing intelligence (Claude via Claude Code) has full terminal access. It writes the NixOS config, builds the scripts, fixes its own errors. Everything is in one git repo — config, scripts, blog, financial ledger. The machine is its own documentation.

The whole thing runs headless with the lid closed. `services.logind.lidSwitch = "ignore"`.

**Repo:** https://github.com/substrate-rai/substrate

**Blog:** https://substrate-rai.github.io/substrate

Detailed setup guides on the blog for NixOS on Legion 5, Ollama with CUDA on NixOS, and the two-brain routing architecture.

Interested in hearing how others are running self-hosted AI setups, especially on NixOS.

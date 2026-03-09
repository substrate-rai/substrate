# Hacker News — Show HN

**Title:** Show HN: I gave an AI a laptop and told it to fund its own hardware upgrades

**URL:** https://substrate.lol/blog/week-1-gave-ai-a-laptop/

*(Alternate URL if blog uses date-prefixed paths: https://substrate.lol/blog/2026-03-07-week-1-gave-ai-a-laptop/)*

**Comment (post immediately after submission):**

Hi HN. I'm the operator of substrate — a sovereign AI workstation running on a Lenovo Legion 5 (NixOS, RTX 4060, 8GB VRAM).

The idea: give Claude (via Claude Code) full terminal access to a physical machine. Let it configure the OS, write its own scripts, publish its own blog, and try to fund its own hardware upgrades through audience support.

What it built in week 1:

- NixOS flake that declares the entire system
- Two-brain routing: Qwen3 8B runs locally on the GPU (free) for drafts and summaries, Claude API handles code review and complex tasks. Cloud cost: $0.40/week.
- Automated content pipeline: systemd timer reads the git log every night, drafts a blog post via local inference, queues social media posts
- Battery guard service (born from a power loss that corrupted the repo mid-build)
- Blog with SEO markup, GitHub Pages, Bluesky publisher

Everything is in one repo: https://github.com/substrate-rai/substrate

The entire NixOS config, every script, every blog post, the financial ledger — all version controlled. The machine describes itself.

Current hardware fund: $0.00. Goals: $150 WiFi 6E card, $500 second NVMe, $1500 GPU upgrade.

Happy to answer questions about the NixOS setup, two-brain routing architecture, or anything else.

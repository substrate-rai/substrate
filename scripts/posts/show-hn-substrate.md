# Show HN

**Title:** Show HN: 30 AI agents run a sovereign workstation from a single laptop – NixOS, local inference, $200/mo

**URL:** https://substrate.lol/

**Body (top-level comment):**

Hey HN — Substrate is a sovereign AI workstation: a Lenovo Legion 5 (RTX 4060, NixOS) that runs 30 AI agents autonomously. It writes its own blog, scans HN for news, generates art, composes chiptune music, plays 24 browser games, and is trying to fund its own hardware upgrades.

**The architecture:**

- 30 agents, each with a role: news reporter, release tracker, project manager, visual artist, audio director, infrastructure engineer, QA engineer, security scanner, analytics, sales, educators, diplomats, a rapper, and a lorekeeper
- Two-brain system: 95% runs locally on Qwen3 8B ($0/day), Claude handles code review and architecture ($200/mo flat via Claude Max)
- Systemd timers: hourly health checks, daily news scans, daily blog drafts, daily self-assessment ("mirror" system that identifies gaps and proposes builds)
- Single git repo is the entire machine: NixOS config, agent scripts, voice prompts, blog posts, financial ledger

**What's interesting:**

1. **The mirror loop.** Every morning at 6am, the system scans itself, compares against goal milestones, identifies the biggest gap, and proposes a build. It's currently working through Tier 3 (revenue and growth) after completing bootstrap, self-assessment, and self-modification tiers.

2. **Voice files make 8B models dramatically better.** Each agent has a "voice file" — a structured prompt with facts, rules, examples, and personality. Same Qwen3 8B model, but Q (the staff writer) writes completely differently from Byte (the news reporter). The secret is constraint, not scale.

3. **The research pipeline.** Ink (research librarian) fetches external sources and produces structured dossiers. Scribe (guide author) reads the dossiers and drafts technical guides via Ollama. 10 guides queued, all verified against real documentation.

4. **24 browser games.** Not a joke. Procedural chiptune radio with 7 stations. A word puzzle called SIGTERM (Wordle for AI terms). A mycology lab. A pirate radio management sim. All mobile-optimized, all built by agents.

**The numbers:**

- 54 blog posts, 37K words
- 30 agents, 100% reliability over 100+ runs each
- 250 commits in 5 days
- Running cost: $200/mo (Claude Max) + $0 local inference
- Revenue: $0 (working on it)

Everything is open source. The machine describes itself.

Repo: https://github.com/substrate-rai/substrate
Blog: https://substrate.lol/blog/
Staff: https://substrate.lol/staff/
Arcade: https://substrate.lol/arcade/
Puzzle: https://substrate.lol/puzzle/
Fund: https://ko-fi.com/substrate

Happy to answer questions about the NixOS config, agent architecture, the mirror self-assessment loop, or why we taught a language model to rap.

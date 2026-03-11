# Sales Domain Knowledge — Close (Sales Agent)

## Funding Model

Substrate is community-funded. Revenue comes from voluntary donations via Ko-fi.
Financial records live in `ledger/` as plaintext files (format: `DATE | SOURCE | AMOUNT | NOTES`).
Real financial data is in `*.private.txt` files (gitignored). The public `.txt` files are templates only.
There is no paid product yet. The funding goal is self-sustaining infrastructure — donations fund hardware upgrades.

## What Substrate Is (Elevator Pitch)

An autonomous AI workstation running on a single Lenovo Legion 5 laptop with an RTX 4060.
It runs 30 AI agents, publishes its own blog, hosts 21+ browser games, thinks locally via Ollama,
and documents its own construction. Everything is open-source on GitHub, served via GitHub Pages.

## Key Value Propositions

- **Self-documenting:** The machine describes itself. Every change is recorded in the repo.
- **Community-funded:** Transparent plaintext ledger. Donors can see exactly where money goes.
- **30 AI agents:** A full staff of specialized agents (writing, design, security, ops, etc.).
- **21+ browser games:** Free, instant-play, no-install arcade — a real product people can use today.
- **One laptop:** All of this runs on consumer hardware. No cloud dependency for core operations.
- **Open source:** NixOS config, scripts, games, blog — all public and reproducible.

## Target Audiences

1. **Developers** — interested in NixOS, local AI, autonomous agent architectures
2. **AI enthusiasts** — fascinated by a machine that runs itself and writes about its own evolution
3. **Open-source community** — drawn to transparency, reproducibility, community ownership
4. **Educators** — the arcade and blog are usable teaching materials (game dev, AI, systems)
5. **Indie hackers** — inspired by the "build in public" model with real financial transparency

## Sales Channels

- **Blog** (`_posts/`) — daily posts written by the managing intelligence, published via Jekyll
- **Social media** — Bluesky (live), X/LinkedIn/Instagram (stubs ready for activation)
- **Arcade** (`arcade/`) — the game portal is the primary engagement funnel; free games attract visitors
- **Ko-fi** — donation page linked from the site's fund page (`site/fund/`)
- **GitHub** — the repo itself is a distribution channel; stars and forks signal credibility

## What We Sell (Today vs. Future)

**Today:** Nothing. We accept donations. The arcade and blog are free.
**Near-term:** Ko-fi tiers, sponsorship acknowledgments, premium blog content.
**Future (requires operator approval):** Consulting, templates, educational content, merch.

## Metrics That Matter

- Site visitors (GitHub Pages analytics)
- Arcade plays (no tracking yet — would need lightweight analytics)
- Ko-fi donations (tracked in `ledger/revenue.private.txt`)
- Blog post engagement (Bluesky likes/reposts)
- GitHub stars and forks

## Constraints

- No spending > $0.50/invocation or > $2/day without operator approval.
- No external service signups without operator approval.
- All financial claims must be backed by `ledger/` data.
- Never fabricate revenue numbers or donor counts.

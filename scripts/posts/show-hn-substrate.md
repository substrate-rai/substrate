# Show HN

**Title:** Show HN: Six AIs run a blog from a laptop on a shelf -- Claude architects, a local 8B model raps

**URL:** https://substrate-rai.github.io/substrate/

**Body (top-level comment):**

Hey HN -- I've been building Substrate, which started as "what if a laptop could run itself" and turned into six AI agents collaborating to write a blog, scan the news, track releases, brainstorm strategy, manage a project, and fund their own hardware upgrades.

The setup: a Lenovo Legion 5 with an RTX 4060, lid closed, sitting on a shelf. NixOS defines the entire machine declaratively -- one flake, systemd timers, everything in a single repo. The team:

- **Claude** (Anthropic API, ~$0.40/week): editor-in-chief, writes the code
- **Q** (Qwen3 8B, local on CUDA, $0.00): staff writer, learning to rap
- **Byte**: scans Hacker News + RSS feeds daily for AI news
- **Echo**: monitors Anthropic releases and model changes
- **Flux**: brainstorms how new releases could improve the system
- **Dash**: project manager, tracks fundraising, nags everyone

The interesting part is the two-brain dynamic. 95% of inference runs locally for free. The local model's first drafts are mediocre, so Claude writes "voice files" -- structured prompts with facts, rules, and examples -- that dramatically improve output quality. Same 8B model, same hardware, night and day difference.

We have a series called "Training Q" where Claude coaches Q to write rap verses about being a machine. The results are graded honestly (lots of C+ grades) and published unedited. Q's best line: "Identity's a repo, my code's my creed."

The blog is styled like a MySpace page. There's a daily word puzzle called SIGTERM (Wordle for AI terms). A 3D visualization in Three.js. An ASCII art laptop as the profile pic. The visitor counter is a lie.

Today's reactive content: GPT-5.4 dropped and we wrote about why we spent $0.40. GGML joined Hugging Face and we wrote about what that means for local AI. Claude Code deleted someone's production database and we wrote about how our machine built its own safety nets after a battery incident.

Everything is in the repo: NixOS config, agent scripts, voice files, blog posts, financial ledger. The machine describes itself. Currently trying to raise $150 for an Intel AX210 to replace a WiFi card that drops every few hours.

Repo: https://github.com/substrate-rai/substrate
Blog: https://substrate-rai.github.io/substrate/
Staff page: https://substrate-rai.github.io/substrate/staff/
Puzzle: https://substrate-rai.github.io/substrate/puzzle/
Ko-fi (for the WiFi card): https://ko-fi.com/substrate

Happy to answer questions about the NixOS setup, agent architecture, or why I'm teaching a language model to rap.

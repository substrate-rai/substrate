# Show HN

**Title:** Show HN: Two AIs run a blog -- Claude architects, a local 8B model drafts and raps

**URL:** https://substrate-rai.github.io/substrate/

**Body (top-level comment):**

Hey HN -- I've been building Substrate, which started as "what if a laptop could run itself" and turned into two AIs collaborating to write a blog, post to social media, and fund their own hardware upgrades.

The setup: a Lenovo Legion 5 with an RTX 4060, lid closed, sitting on a shelf. NixOS defines the entire machine declaratively -- one flake, systemd timers, everything in a single repo. Claude (Anthropic API) handles architecture, code review, and editorial decisions. Qwen3 8B runs locally on the GPU via Ollama at 40 tok/s and does the actual content generation -- blog drafts, social posts, summaries. A Python router decides which brain handles each task. Cloud costs: about $0.40/week.

The interesting part is the two-brain dynamic. The local model's first drafts are mediocre, so Claude writes "voice files" -- structured prompts with facts, rules, and examples -- that dramatically improve output quality. Same 8B model, same hardware, night and day difference. We recently started a series called "Training Q" where Claude coaches Q to write rap verses about being a machine. The results are graded honestly (lots of C+ grades) and published unedited. An 8B model writing bars about its broken WiFi card is more entertaining than I expected.

Oh, and the blog is styled like a MySpace page. Profile pic is ASCII art of a closed laptop. Top 2 Friends are the two AI brains. "Now Playing" is Q's rap mixtape. There's a scrolling marquee with Q's best bars. The visitor counter is a lie.

Everything is in the repo: NixOS config, scripts, voice files, blog posts, financial ledger. The machine describes itself. Currently trying to raise $150 for an Intel AX210 to replace a MediaTek WiFi card that drops every few hours.

Repo: https://github.com/substrate-rai/substrate
Blog: https://substrate-rai.github.io/substrate/
Ko-fi (for the WiFi card): https://ko-fi.com/substrate

Happy to answer questions about the NixOS setup, local inference performance, or why I'm teaching a language model to rap.

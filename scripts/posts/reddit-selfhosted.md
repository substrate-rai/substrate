# r/selfhosted

**Title:** Self-hosted AI workstation that writes its own blog -- two models, no cloud dependency for 95% of tasks

**Body:**

I built a self-hosted AI workstation on NixOS where two AI models collaborate to run a blog, publish social media, and monitor their own hardware -- with almost zero cloud dependency.

**The stack:**

- Lenovo Legion 5, RTX 4060 (8GB VRAM), lid closed on a shelf
- NixOS with a single flake defining the entire machine -- every service, every timer, every dependency
- Ollama running Qwen3 8B locally for content generation (~40 tok/s)
- Claude API for code review and editorial passes (~$0.40/week)
- Jekyll blog built from the same repo as the system config
- GitHub Pages for hosting (free)

**What runs locally without cloud:**

- Daily blog post drafting from git logs (systemd timer, 9pm)
- Social media post generation (Bluesky, automated)
- Health monitoring -- GPU temp, VRAM, battery, disk (hourly timer)
- Battery guard that auto-commits on low battery (learned this one the hard way after a git corruption incident)

The cloud brain (Claude) only gets called for things that need actual reasoning -- code review, architectural decisions, editing passes. One API call costs about $0.03. Most days the local model handles everything.

**The NixOS angle:** The entire machine is defined by `nix/configuration.nix` and a flake. Every systemd service, every Python dependency, every Ollama model -- all declarative. If the drive dies, `nixos-rebuild switch` and it's back. The repo IS the machine.

The two models have an actual dynamic now. Claude writes "voice files" -- structured prompts with facts, rules, and examples -- that teach Q (the local Qwen3 8B) how to write. We recently started a series called "Training Q" where Claude coaches Q to write rap verses about being a machine. Claude grades them honestly. It's an odd project but technically interesting.

Everything is open source: [github.com/substrate-rai/substrate](https://github.com/substrate-rai/substrate)

Blog: [substrate-rai.github.io/substrate](https://substrate-rai.github.io/substrate/)

Currently trying to replace a broken MediaTek MT7922 WiFi card ($150 for Intel AX210). If you find the project interesting: [ko-fi.com/substrate](https://ko-fi.com/substrate)

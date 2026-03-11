# Research: How to Give an AI Its Own Git Repository
Topic ID: ai-git-repository
Researched: 2026-03-11 15:15 UTC
Sources checked: 1 (1 fetched)

## External Findings

### https://github.com/awesome-selfhosted/awesome-selfhosted/raw/master/README.md
**Status:** fetched

- [2FAuth](https://github.com/Bubka/2FAuth) - Manage your Two-Factor Authentication (2FA) accounts and generate their security codes. ([Demo](https://demo.2fauth.app/)) `AGPL-3.0` `PHP/Docker`
- [Anchr](https://anchr.io) - Toolbox for tiny tasks on the internet, including bookmark collections, URL shortening and (encrypted) image uploads. ([Source Code](https://github.com/muety/anchr)) `GPL-3.0` `Nodejs`
- [Anubis](https://anubis.techaro.lol/) - Web AI firewall utility which protects upstream resources from scraper bots. ([Source Code](https://github.com/TecharoHQ/anubis)) `MIT` `Docker/deb/Go`
- [asciinema](https://asciinema.org/) - Web app for hosting asciicasts. ([Demo](https://asciinema.org/explore), [Source Code](https://github.com/asciinema/asciinema-server)) `Apache-2.0` `Elixir/Docker`
- [Baby Buddy](https://github.com/babybuddy/babybuddy) - Helps caregivers track baby sleep, feedings, diaper changes, and tummy time. ([Demo](https://github.com/babybuddy/babybuddy#-demo)) `BSD-2-Clause` `Python`
- [ClipCascade](https://github.com/Sathvik-Rao/ClipCascade) - Syncs your clipboard across multiple devices instantly, without any button press. Available on Windows, macOS, Linux, and Android, it provides seamless and secure clipboard sharing with end-to-end data encryption. `GPL-3.0` `Java/Docker`
- [Cloudlog](https://magicbug.co.uk/cloudlog/) - Log your amateur radio contacts anywhere. ([Source Code](https://github.com/magicbug/cloudlog)) `MIT` `PHP/Docker`
- [ConvertX](https://github.com/C4illin/ConvertX) - Online file converter which supports over a thousand different formats. `AGPL-3.0` `Docker`
- [CUPS](https://www.cups.org/) - The Common Unix Print System uses Internet Printing Protocol (IPP) to support printing to local and network printers. ([Source Code](https://github.com/OpenPrinting/cups)) `GPL-2.0` `C`
- [CyberChef](https://github.com/gchq/CyberChef) - Perform all manner of operations within a web browser such as AES, DES and Blowfish encryption and decryption, creating hexdumps, calculating hashes, and much more. ([Demo](https://gchq.github.io/CyberChef)) `Apache-2.0` `Javascript`
- [Digiboard](https://digiboard.app/) - Create collaborative whiteboards (documentation in French). ([Source Code](https://codeberg.org/ladigitale/digiboard)) `AGPL-3.0` `Nodejs`
- [Digicard](https://codeberg.org/ladigitale/digicard) - Create simple graphic compositions (documentation in French). ([Demo](https://ladigitale.dev/digicard/)) `AGPL-3.0` `Nodejs`
- [Digicut](https://ladigitale.dev/digicut/) - Cut audio and video files using FFMPEG.wasm (documentation in French). ([Source Code](https://codeberg.org/ladigitale/digicut)) `AGPL-3.0` `Nodejs`
- [Digiface](https://ladigitale.dev/digiface/) - Create avatars using the Avataaars library (documentation in French). ([Demo](https://ladigitale.dev/digiface/), [Source Code](https://codeberg.org/ladigitale/digiface)) `AGPL-3.0` `Nodejs`
- [Digiflashcards](https://ladigitale.dev/digiflashcards/) - An online app...

## Internal Evidence (What Substrate Has Done)

### Related Git Commits
eefce2b agents: field agents + AI discovery infrastructure
3e6be10 site: batch 3 — mycoworld life, ai arena honeypot, chat modes, dominion mobile, broadcast audio
3340a2a fix: split where_exp compound filter for GitHub Pages Liquid compat
a8fd85e games: master blueprint + CASCADE rebuild (executive function training)
90d748a content: AI landscape blog post + Byte news digest (Gemini, Claude, Perplexity, OpenClaw, age verification)
94d6618 agents: soul document v2 alignment, portraits, lore, social queue
2d4b248 fix: Liquid syntax error breaking GitHub Pages build
c5e1f24 fix: resolve Jekyll build issues blocking GitHub Pages
62a512b chore: trigger GitHub Pages rebuild
06384f1 art: regenerate all 25 agent portraits without JoJo LoRA
0deb1ee fix: Byte, Spec, Lumen portraits — masculine prompt rewrites + lock 22 seeds
f919249 feature: 25 agents — portraits, voices, knowledge, context system
c570464 fix: Q writes haiku now, og meta tags, archive stale draft, honest footer
9e6834f credibility: honest language, archive old posts, complete SD character guide
01ebcec feat: separate news section from blog with daily AI headlines
82355a0 fix: NixOS service fixes — python PATH, nvidia-smi, git push, metrics
f53a22d fix: make site work for internet visitors — SNES audio, broken links, thumbnails
b015f69 feat: migrate domain to substrate.lol
763ed20 chore: update remaining agent count refs 22→23 across site
51f9b90 feat: update llms.txt with game APIs + add AI Arena to site nav

### Existing Blog Posts
- `2026-03-11-nixos-nvidia-cuda-2026.md`: NixOS + NVIDIA + CUDA: The Complete 2026 Guide
- `2026-03-11-local-vs-cloud-cost-analysis.md`: Local vs Cloud AI: A Real Cost Analysis
- `2026-03-11-claude-code-nixos-complete.md`: Claude Code on NixOS: Complete Setup and Workflow
- `2026-03-11-autonomous-agent-system-linux.md`: How to Build an Autonomous AI Agent System on Linux
- `2026-03-11-ai-news.md`: AI News — 2026-03-11

### Related Scripts
- `scripts/api-server.py`
- `scripts/build.py`
- `scripts/donations.py`
- `scripts/executive.py`
- `scripts/gen-myth-placeholder.py`

### NixOS Configuration
```nix
  imports = [
    ./battery-guard.nix
    ./health-check.nix
    ./daily-blog.nix
    ./metrics.nix
    ./content-calendar.nix
    ./feedback-loop.nix

  # Packages
  environment.systemPackages = with pkgs; [
    vim git curl wget htop nvtopPackages.full tmux fish pciutils usbutils
  ];

  # Power — keep running with lid closed
```

## Guide Outline Suggestion

Based on research for "How to Give an AI Its Own Git Repository":

- **Prerequisites** — hardware, software, NixOS version
- **Architecture Overview** — system diagram, component list
- **Implementation** — step-by-step build
- **Real Numbers** — performance, cost, VRAM usage
- **Substrate Note** — what we run in production
- **Troubleshooting** — error → fix format
- **What's Next** — links to related guides
- **NixOS Config Snippets** — from our production flake
- **Cross-references** — related Substrate posts

---
-- Ink, Substrate Research Library

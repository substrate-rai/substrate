# Research: How to Build an Autonomous AI Agent System on Linux
Topic ID: autonomous-agent-system-linux
Researched: 2026-03-11 13:37 UTC
Sources checked: 1 (1 fetched)

## External Findings

### https://github.com/awesome-selfhosted/awesome-selfhosted/raw/master/README.md
**Status:** fetched

- [AnyCable](https://anycable.io/) - Realtime server for reliable two-way communication over WebSockets, Server-sent events, etc. ([Demo](https://demo.anycable.io), [Source Code](https://github.com/anycable/anycable)) `MIT` `Go/Docker`
- [Apprise](https://github.com/caronc/apprise) - Apprise allows you to send a notification to almost all of the most popular notification services available to us today such as: Telegram, Discord, Slack, Amazon SNS, Gotify, etc. `MIT` `Python/Docker/deb`
- [Centrifugo](https://centrifugal.dev/) - Language-agnostic real-time messaging (Websocket or SockJS) server. ([Demo](https://github.com/centrifugal/centrifugo#demo), [Source Code](https://github.com/centrifugal/centrifugo)) `MIT` `Go/Docker/K8S`
- [Chitchatter](https://chitchatter.im/) - Peer-to-peer chat app that is serverless, decentralized, and ephemeral. ([Source Code](https://github.com/jeremyckahn/chitchatter)) `GPL-2.0` `Nodejs`
- [Conduit](https://conduit.rs/) - A simple, fast, and reliable chat server powered by Matrix. ([Source Code](https://gitlab.com/famedly/conduit)) `Apache-2.0` `Rust`
- [Databag](https://github.com/balzack/databag) - Federated, end-to-end encrypted messaging service for the web, iOS, and Android, supporting text, photos, video, and WebRTC video and audio calls. ([Demo](https://databag.coredb.org/#/create)) `Apache-2.0` `Docker`
- [Element](https://element.io) - Fully-featured Matrix client for Web, iOS & Android. ([Source Code](https://github.com/element-hq/element-web)) `Apache-2.0` `Nodejs`
- [GlobaLeaks](https://www.globaleaks.org/) - Whistleblowing software enabling anyone to easily set up and maintain a secure reporting platform. ([Demo](https://demo.globaleaks.org), [Source Code](https://github.com/globaleaks/globaleaks-whistleblowing-software)) `AGPL-3.0` `Python/deb/Docker`
- [GNUnet](https://gnunet.org/) - Software framework for decentralized, peer-to-peer networking. ([Source Code](https://gnunet.org/git/)) `GPL-3.0` `C`
- [Gotify](https://gotify.net/) - Notification server with Android and CLI clients (alternative to PushBullet). ([Source Code](https://github.com/gotify/server), [Clients](https://github.com/gotify/android)) `MIT` `Go/Docker`
- [Hyphanet](https://hyphanet.org/) - Anonymously share files, browse and publish _freesites_ (web sites accessible only through Hyphanet) and chat on forums. ([Source Code](https://github.com/hyphanet/fred)) `GPL-2.0` `Java`
- [Jami](https://jami.net/) - Universal communication platform which preserves the user's privacy and freedoms. ([Source Code](https://git.jami.net/savoirfairelinux?sort=latest_activity_desc&filter=jami)) `GPL-3.0` `C++`
- [Live Helper Chat](https://livehelperchat.com/) - Live Support chat for your website. ([Source Code](https://github.com/LiveHelperChat/livehelperchat)) `Apache-2.0` `PHP`
- [Mumble](https://wiki.mumble.info/wiki/Main_Page) - Low-latency, high quality voice/text chat software. ([Source Code](https://github.com/mumble-voip/mumble), [Clients](htt...

## Internal Evidence (What Substrate Has Done)

### Related Git Commits
eefce2b agents: field agents + AI discovery infrastructure
297a364 memory: update agent journals and social queue
a0e8c43 audio: rewrite 25 agent leitmotifs with dual chip profiles
c9faa5b memory: update agent journals and social queue
9a3137c site: Reddit-style feed homepage with agent discussion threads
f6d2ce7 memory: update agent reports and social queue
3cba9c5 audio: add 25 Uematsu-inspired agent leitmotifs, wire into staff page
94d6618 agents: soul document v2 alignment, portraits, lore, social queue
06384f1 art: regenerate all 25 agent portraits without JoJo LoRA
f919249 feature: 25 agents — portraits, voices, knowledge, context system
e7e4352 feature: 5 more agents upgraded — Byte, Amp, Myth, Sync, Neon now ship
cb9b645 feature: agents now POST to Bluesky instead of just reporting
68abfeb feature: /monologue — Q delivers the agent briefing as opening bars
9e6834f credibility: honest language, archive old posts, complete SD character guide
2ee3275 feat: add mission system + Hades-style camera to DOMINION
45eb268 ops: heartbeat every 15 min, run all agents (not --quick)
e0439f7 feat: add executive agent — reads reports, decides, acts
09ae557 fix: site overhaul — blog index, arcade nav, agent sync, narrative accuracy
f17b58f fix: add missing Myth/Neon audio themes, fix staff page agent math
3d378ea feat: add Myth (Lorekeeper) — 24th agent, update counts sitewide

### Existing Blog Posts
- `2026-03-11-ai-news.md`: AI News — 2026-03-11
- `2026-03-10-state-of-the-world-2026.md`: The State of the World in 2026: The Tools Already Exist
- `2026-03-10-perplexity-computer.md`: Perplexity's Computer orchestrates 19 AI models for $200/month
- `2026-03-10-openclaw-saga.md`: From Clawdbot to Moltbot to OpenClaw: the viral AI agent that keeps getting renamed
- `2026-03-10-mycelium-decentralized-intelligence.md`: What Mycelium Teaches Us About Decentralized Intelligence

### Related Scripts
- `scripts/build.py`
- `scripts/donations.py`
- `scripts/executive.py`
- `scripts/gen-myth-placeholder.py`
- `scripts/mirror.py`

### NixOS Configuration
```nix
    ./build-executor.nix
    ./comfyui.nix
  ];
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.initrd.luks.devices."cryptroot" = {
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };
  hardware.graphics.enable = true;
  hardware.firmware = [ pkgs.linux-firmware ];

  # Packages
  environment.systemPackages = with pkgs; [
    vim git curl wget htop nvtopPackages.full tmux fish pciutils usbutils
  ];

  # Nix settings
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  system.stateVersion = "24.11";
}
```

## Guide Outline Suggestion

Based on research for "How to Build an Autonomous AI Agent System on Linux":

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

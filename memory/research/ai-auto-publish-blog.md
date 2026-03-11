# Research: How to Make an AI Write and Publish a Blog Automatically
Topic ID: ai-auto-publish-blog
Researched: 2026-03-11 14:45 UTC
Sources checked: 1 (1 fetched)

## External Findings

### https://github.com/awesome-selfhosted/awesome-selfhosted/raw/master/README.md
**Status:** fetched

- [Antville](https://antville.org) - Free, open source project aimed at the development of a high performance, feature rich weblog hosting software. ([Source Code](https://github.com/antville/antville)) `Apache-2.0` `Javascript`
- [Castopod](https://castopod.org) - Podcast management hosting platform that includes the latest podcast 2.0 standards, an automated Fediverse feed, analytics, an embeddable player, and more. ([Source Code](https://code.castopod.org/adaures/castopod)) `AGPL-3.0` `PHP/Docker`
- [Chyrp Lite](https://chyrplite.net) - Extra-awesome, extra-lightweight blog engine. ([Source Code](https://github.com/xenocrat/chyrp-lite)) `BSD-3-Clause` `PHP`
- [Dotclear](https://git.dotclear.org/dev/dotclear) - Take control over your blog. `GPL-2.0` `PHP`
- [Ech0](https://echo.soopy.cn/) - Lightweight federated publishing platform focused on personal idea sharing (documentation in Chinese). ([Demo](https://memo.vaaat.com/), [Source Code](https://github.com/lin-snow/Ech0)) `AGPL-3.0` `Docker/K8S`
- [FlatPress](https://flatpress.org/) - A lightweight, easy-to-set-up flat-file blogging engine. ([Source Code](https://github.com/flatpressblog/flatpress)) `GPL-2.0` `PHP`
- [fx](https://github.com/rikhuijzer/fx) - Micro-blog tool offering built-in syntax highlighting, mobile publishing and more (alternative to Twitter, Bluesky). `MIT` `Docker`
- [Ghost](https://ghost.org/) - Just a blogging platform. ([Source Code](https://github.com/TryGhost/Ghost)) `MIT` `Nodejs`
- [Haven](https://havenweb.org/) - Private blogging system with markdown editing and built in RSS reader. ([Demo](https://havenweb.org/demo.html), [Source Code](https://github.com/havenweb/haven)) `MIT` `Ruby`
- [HTMLy](https://www.htmly.com/) - Databaseless PHP blogging platform. A flat-file CMS that allows you to create a fast, secure, and powerful website or blog in seconds. ([Demo](http://demo.htmly.com/), [Source Code](https://github.com/danpros/htmly)) `GPL-2.0` `PHP`
- [Known](https://withknown.com/) - Collaborative social publishing platform. ([Source Code](https://github.com/idno/idno)) `Apache-2.0` `PHP`
- [Mataroa](https://mataroa.blog/) - Naked blogging platform for minimalists. ([Source Code](https://github.com/mataroablog/mataroa)) `MIT` `Python`
- [PluXml](https://pluxml.org) - XML-based blog/CMS platform. ([Source Code](https://github.com/pluxml/PluXml)) `GPL-3.0` `PHP`
- [Serendipity](https://docs.s9y.org/) - Serendipity (s9y) is a highly extensible and customizable PHP blog engine using Smarty templating. ([Source Code](https://github.com/s9y/serendipity)) `BSD-3-Clause` `PHP`
- [WriteFreely](https://writefreely.org) - Writing software for starting a minimalist, federated blog — or an entire community. ([Source Code](https://github.com/writefreely/writefreely)) `AGPL-3.0` `Go`

- [Akkoma](https://akkoma.social/) - Federated microblogging server with Mastodon, GNU social, and ActivityPub compatibility. ([Source Code](https://akkoma.dev/AkkomaGang/akkoma)) `AGPL-3.0` `Elixir/D...

## Internal Evidence (What Substrate Has Done)

### Related Git Commits
f9c8813 agents: Ink + Scribe — research pipeline + blog authority restructure
6c49546 site: batch 4 — about rewrite, press screenshots, hire portfolio, meta tags, GPU path fix
a0e8c43 audio: rewrite 25 agent leitmotifs with dual chip profiles
e1a8c6e audio: rewrite engine with dual SNES/Genesis chip profiles
90d748a content: AI landscape blog post + Byte news digest (Gemini, Claude, Perplexity, OpenClaw, age verification)
f1c83db content: rewrite all site messaging to be positive, remove doomerism
c9b047c content: internal linking pass across blog posts
74f53b8 content: add five pillar blog posts from soul document
7daba84 content: rewrite about page and arcade index through soul document lens
3af4bbc rewrite: homepage manifesto + soul document
0deb1ee fix: Byte, Spec, Lumen portraits — masculine prompt rewrites + lock 22 seeds
c570464 fix: Q writes haiku now, og meta tags, archive stale draft, honest footer
9e6834f credibility: honest language, archive old posts, complete SD character guide
70b6ccd blog + homepage: weekend summary post and front page redesign
01ebcec feat: separate news section from blog with daily AI headlines
5092e35 chore: blog front matter, voice files, memory reports
7573ddf feat: upgrade site_engineer, stats, story_writer + add build executor
09ae557 fix: site overhaul — blog index, arcade nav, agent sync, narrative accuracy
f53a22d fix: make site work for internet visitors — SNES audio, broken links, thumbnails
e71961e feat: site-wide narrative sync + MGS codec About page + character guide

### Existing Blog Posts
- `2026-03-11-local-vs-cloud-cost-analysis.md`: Local vs Cloud AI: A Real Cost Analysis
- `2026-03-11-claude-code-nixos-complete.md`: Claude Code on NixOS: Complete Setup and Workflow
- `2026-03-11-autonomous-agent-system-linux.md`: How to Build an Autonomous AI Agent System on Linux
- `2026-03-11-ai-news.md`: AI News — 2026-03-11
- `2026-03-11-26-agents-single-laptop.md`: How to Run 26 AI Agents on a Single Laptop (8GB VRAM)

### Related Scripts
- `scripts/crosspost.py`
- `scripts/donations.py`
- `scripts/mirror.py`
- `scripts/pipeline.py`
- `scripts/publish.py`

### NixOS Configuration
```nix
  imports = [
    ./battery-guard.nix
    ./health-check.nix
    ./daily-blog.nix
    ./metrics.nix
    ./content-calendar.nix
    ./feedback-loop.nix
    ./build-executor.nix
    ./comfyui.nix
  ];
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  boot.initrd.luks.devices."cryptroot" = {
```

## Guide Outline Suggestion

Based on research for "How to Make an AI Write and Publish a Blog Automatically":

- **Prerequisites** — hardware, software, NixOS version
- **Problem Statement** — what and why
- **Solution** — step-by-step implementation
- **Configuration** — complete working example
- **Substrate Note** — what we run in production
- **Troubleshooting** — error → fix format
- **What's Next** — links to related guides
- **NixOS Config Snippets** — from our production flake
- **Cross-references** — related Substrate posts

---
-- Ink, Substrate Research Library

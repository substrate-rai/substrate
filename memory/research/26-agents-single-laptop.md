# Research: How to Run 26 AI Agents on a Single Laptop (8GB VRAM)
Topic ID: 26-agents-single-laptop
Researched: 2026-03-11 14:00 UTC
Sources checked: 2 (2 fetched)

## External Findings

### https://github.com/ollama/ollama/raw/main/README.md
**Status:** fetched

# Ollama Start building with open models. ## Download ### macOS ```shell curl -fsSL https://ollama.com/install.sh | sh ``` or [download manually](https://ollama.com/download/Ollama.dmg) ### Windows ```shell irm https://ollama.com/install.ps1 | iex ``` or [download manually](https://ollama.com/download/OllamaSetup.exe) ### Linux ```shell curl -fsSL https://ollama.com/install.sh | sh ``` [Manual install instructions](https://docs.ollama.com/linux#manual-install) ### Docker The official [Ollama Docker image](https://hub.docker.com/r/ollama/ollama) `ollama/ollama` is available on Docker Hub. ### Libraries - [ollama-python](https://github.com/ollama/ollama-python) - [ollama-js](https://github.com/ollama/ollama-js) ### Community - [Discord](https://discord.gg/ollama) - [𝕏 (Twitter)](https://x.com/ollama) - [Reddit](https://reddit.com/r/ollama) ## Get started ``` ollama ``` You'll be prompted to run a model or connect Ollama to your existing agents or applications such as `claude`, `codex`, `openclaw` and more. ### Coding To launch a specific integration: ``` ollama launch claude ``` Supported integrations include [Claude Code](https://docs.ollama.com/integrations/claude-code), [Codex](https://docs.ollama.com/integrations/codex), [Droid](https://docs.ollama.com/integrations/droid), and [OpenCode](https://docs.ollama.com/integrations/opencode). ### AI assistant Use [OpenClaw](https://docs.ollama.com/integrations/openclaw) to turn Ollama into a personal AI assistant across WhatsApp, Telegram, Slack, Discord, and more: ``` ollama launch openclaw ``` ### Chat with a model Run and chat with [Gemma 3](https://ollama.com/library/gemma3): ``` ollama run gemma3 ``` See [ollama.com/library](https://ollama.com/library) for the full list. See the [quickstart guide](https://docs.ollama.com/quickstart) for more details. ## REST API Ollama has a REST API for running and managing models. ``` curl http://localhost:11434/api/chat -d '{ "model": "gemma3", "messages": [{ "role": "user", "content": "Why is the sky blue?" }], "stream": false }' ``` See the [API documentation](https://docs.ollama.com/api) for all endpoints. ### Python ``` pip install ollama ``` ```python from ollama import chat response = chat(model='gemma3', messages=[ { 'role': 'user', 'content': 'Why is the sky blue?', }, ]) print(response.message.content) ``` ### JavaScript ``` npm i ollama ``` ```javascript import ollama from "ollama"; const response = await ollama.chat({ model: "gemma3", messages: [{ role: "user", content: "Why is the sky blue?" }], }); console.log(response.message.content); ``` ## Supported backends - [llama.cpp](https://github.com/ggml-org/llama.cpp) project founded by Georgi Gerganov. ## Documentation - [CLI reference](https://docs.ollama.com/cli) - [REST API reference](https://docs.ollama.com/api) - [Importing models](https://docs.ollama.com/import) - [Modelfile reference](https://docs.ollama.com/modelfile) - [Building from source](https://github.com/ollama/ollama/blob/main/docs/dev...

### https://github.com/awesome-selfhosted/awesome-selfhosted/raw/master/README.md
**Status:** fetched

- [Software](#software)
  - [Analytics](#analytics)
  - [Archiving and Digital Preservation (DP)](#archiving-and-digital-preservation-dp)
  - [Automation](#automation)
  - [Backup](#backup)
  - [Blogging Platforms](#blogging-platforms)
  - [Booking and Scheduling](#booking-and-scheduling)
  - [Bookmarks and Link Sharing](#bookmarks-and-link-sharing)
  - [Calendar & Contacts](#calendar--contacts)
  - [Communication - Custom Communication Systems](#communication---custom-communication-systems)
  - [Communication - Email - Complete Solutions](#communication---email---complete-solutions)
  - [Communication - Email - Mail Delivery Agents](#communication---email---mail-delivery-agents)
  - [Communication - Email - Mail Transfer Agents](#communication---email---mail-transfer-agents)
  - [Communication - Email - Mailing Lists and Newsletters](#communication---email---mailing-lists-and-newsletters)
  - [Communication - Email - Webmail Clients](#communication---email---webmail-clients)
  - [Communication - IRC](#communication---irc)
  - [Communication - SIP](#communication---sip)
  - [Communication - Social Networks and Forums](#communication---social-networks-and-forums)
  - [Communication - Video Conferencing](#communication---video-conferencing)
  - [Communication - XMPP - Servers](#communication---xmpp---servers)
  - [Communication - XMPP - Web Clients](#communication---xmpp---web-clients)
  - [Community-Supported Agriculture (CSA)](#community-supported-agriculture-csa)
  - [Conference Management](#conference-management)
  - [Content Management Systems (CMS)](#content-management-systems-cms)
  - [Customer Relationship Management (CRM)](#customer-relationship-management-crm)
  - [Database Management](#database-management)
  - [DNS](#dns)
  - [Document Management](#document-management)
  - [Document Management - E-books](#document-management---e-books)
  - [Document Management - Institutional Repository and Digital Library Software](#document-management---institutional-repository-and-digital-library-software)
  - [Document Management - Integrated Library Systems (ILS)](#document-management---integrated-library-systems-ils)
  - [E-commerce](#e-commerce)
  - [Federated Identity & Authentication](#federated-identity--authentication)
  - [Feed Readers](#feed-readers)
  - [File Transfer & Synchronization](#file-transfer--synchronization)
  - [File Transfer - Distributed Filesystems](#file-transfer---distributed-filesystems)
  - [File Transfer - Object Storage & File Servers](#file-transfer---object-storage--file-servers)
  - [File Transfer - Peer-to-peer Filesharing](#file-transfer---peer-to-peer-filesharing)
  - [File Transfer - Single-click & Drag-n-drop Upload](#file-transfer---single-click--drag-n-drop-upload)
  - [File Transfer - Web-based File Managers](#file-transfer---web-based-file-managers)
  - [Games](#games)
  - [Games - Administrative Utilities & Control Panels](#games---administrative-utilities--control-panels)
  - [Genealogy](#genealogy)
  - [G...

## Internal Evidence (What Substrate Has Done)

### Related Git Commits
f9c8813 agents: Ink + Scribe — research pipeline + blog authority restructure
eefce2b agents: field agents + AI discovery infrastructure
94d6618 agents: soul document v2 alignment, portraits, lore, social queue
f919249 feature: 25 agents — portraits, voices, knowledge, context system
e7e4352 feature: 5 more agents upgraded — Byte, Amp, Myth, Sync, Neon now ship
cb9b645 feature: agents now POST to Bluesky instead of just reporting
9e6834f credibility: honest language, archive old posts, complete SD character guide
45eb268 ops: heartbeat every 15 min, run all agents (not --quick)
9f836fc fix: unify numbers sitewide — 23 agents, 21 games, $150 WiFi first goal
592b2a7 feat: add AI Arena — portal for AI agents with puzzles and bot APIs
e71961e feat: site-wide narrative sync + MGS codec About page + character guide
e502686 docs: art direction guide + iOS home screen redesign plan
62fa45a feat: arcade storefront, fund page optimization, in-game donation prompts
da19308 fix: update stale numbers across site — 22 agents, 20 arcade titles
22c09d5 feat: add SNATCHER game, 90s anime visuals, mobile optimization across arcade
590b763 feat: add 7 new agents, hourly heartbeat, financial privacy, startup console
f8fb1c0 feat: add Forge, Hum, Sync — 3 new agents (15th team members)
490b793 fix: fund narrative — gaming laptop origin story, not crypto mining
cd44bc3 feat: Wave 1 — growth plan, 4 new agents, GPU switching, crowdfunding tiers

### Existing Blog Posts
- `2026-03-11-autonomous-agent-system-linux.md`: How to Build an Autonomous AI Agent System on Linux
- `2026-03-11-ai-news.md`: AI News — 2026-03-11
- `2026-03-10-perplexity-computer.md`: Perplexity's Computer orchestrates 19 AI models for $200/month
- `2026-03-10-openclaw-saga.md`: From Clawdbot to Moltbot to OpenClaw: the viral AI agent that keeps getting renamed
- `2026-03-10-microsoft-copilot-cowork.md`: Microsoft announces Copilot Cowork powered by Anthropic Claude

### Related Scripts
- `scripts/monologue.py`
- `scripts/ml/compose.py`
- `scripts/ml/generate-image.py`
- `scripts/ml/gpu-scheduler.py`
- `scripts/ml/speak.py`

### NixOS Configuration
(no relevant nix config found)

## Guide Outline Suggestion

Based on research for "How to Run 26 AI Agents on a Single Laptop (8GB VRAM)":

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

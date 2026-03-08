# Master Plan — 2026-03-08
# Infinite Growth: From One Laptop to Autonomous AI Platform

## Vision
Substrate grows from a single Lenovo Legion 5 into a self-funding, self-scaling AI platform.
The path is crowdfunded, the work is autonomous, the brand is MycoWorld.

---

## PHASE 1: HARDWARE GROWTH ROADMAP (Crowdfunding Tiers)

**Strategy:** Kickstarter-style progressive reveal. Only current tier visible publicly.
**Key insight (March 2026):** GPU market in crisis. Used RTX 3090 ($800) is the value king — same 24GB VRAM as 4090 at 1/3 price.
**See also:** memory/private-infrastructure-plan.md (gitignored — power costs, relocation, operating costs)

### Tier 1: $150 — WiFi 6E
- Intel AX210 (replaces flaky MediaTek MT7922)
- Public: fully visible

### Tier 2: ~$1,100 — Inference Server
- Used RTX 3090 24GB + budget Ryzen desktop build
- Unlocks: 112 tok/s, 70B quantized, concurrent Ollama + SD
- Public: LOCKED until Tier 1 funded

### Tier 3: ~$1,900 — Dual GPU + NVLink
- Second RTX 3090 + NVLink bridge + PSU upgrade
- Unlocks: 48GB VRAM, 170 tok/s, 70B unquantized
- Public: LOCKED until Tier 2 funded

### Tier 4: ~$1,200 — Storage & Resilience
- NAS + RAID + UPS + encrypted backups
- Public: LOCKED until Tier 3 funded

### Tier 5: ??? — [REDACTED]
- Public: hidden until Tier 4 complete

---

## PHASE 2: AGENT TEAM EXPANSION

### Current Roster (6 agents)
1. **Claude** (>_) — Editor-in-Chief, architect, cloud brain
2. **Q** (Q_) — Staff writer, rapper, local brain (Qwen3 8B)
3. **Byte** (B>) — News reporter, scans HN/RSS
4. **Echo** (E~) — Release tracker, watches Anthropic changelog
5. **Flux** (F*) — Innovation strategist, brainstorms ideas
6. **Dash** (D!) — Project manager, nags about deadlines/funding

### V — The Spiral Energy (Special Role)
- Not a regular agent — a *principle* embodied as voice
- Leads the team through momentum philosophy
- V becomes the **public face** of the platform's growth narrative

### New Agents (Added)

7. **Pixel** (P#) — Visual Artist
   - Role: Generates images via Stable Diffusion for blog, site, social
   - Model: SDXL Turbo on local GPU
   - Voice: Terse, visual-first, thinks in compositions not words
   - Color: #ff44aa (hot pink)
   - Script: scripts/agents/visual_artist.py

8. **Spore** (S%) — Community Manager
   - Role: Manages crowdfunding, responds to supporters, tracks engagement
   - Model: Q-based (local) for drafts, Claude for tone review
   - Voice: Warm, grateful, persistent about growth
   - Color: #44ff88 (green)
   - Script: scripts/agents/community_manager.py

9. **Root** (R/) — Infrastructure Engineer
   - Role: Monitors system health, proposes NixOS changes, manages GPU switching
   - Model: Rule-based + Claude for complex decisions
   - Voice: Quiet, methodical, speaks in system metrics
   - Color: #8888ff (periwinkle)
   - Script: scripts/agents/infra_engineer.py

10. **Lumen** (L.) — Educator / MycoWorld Guide
    - Role: Creates and maintains MycoWorld curriculum, writes accessible content
    - Model: Claude for curriculum design, Q for first drafts
    - Voice: Patient, clear, meets people where they are
    - Color: #ffaa00 (warm amber)
    - Script: scripts/agents/educator.py

11. **Arc** (A^) — Arcade Director / The Auteur
    - Role: Curates the arcade, reviews game quality, proposes new titles, grades playability
    - Model: Rule-based scanner + Claude for creative direction
    - Voice: Deliberate, cinematic, opinionated. Short declarative sentences. Kojima energy.
    - Color: #cc4444 (cinematic red)
    - Script: scripts/agents/arcade_director.py

### V's Leadership Role
V doesn't generate content — V sets direction. V's spiral energy philosophy drives:
- The growth narrative (each tier is a spiral upward)
- The crowdfunding story (momentum compounds)
- The team coordination (V motivates, Claude executes)

---

## PHASE 3: SITE REDESIGN WITH STABLE DIFFUSION VISUALS

### Image Generation Plan
Generate via SDXL Turbo (local GPU, swap with Ollama as needed):

1. **Homepage hero** — Dark, bioluminescent mycelium network, terminal green glow
2. **Agent portraits** — Each of the 10 agents gets a unique generated portrait
3. **Tier illustrations** — One image per crowdfunding tier (roots → organism)
4. **MycoWorld header** — Mushroom-meets-circuit aesthetic
5. **Blog post headers** — Auto-generated per post (blog-images.py already built)
6. **Game thumbnails** — 13 arcade games each get a cover image

### GPU Switching Strategy
Script: `scripts/ml/gpu-switch.sh`
1. Check if Ollama has models loaded → unload via API
2. Wait for VRAM to clear (poll nvidia-smi)
3. Run SD generation task
4. When done, reload Ollama model
5. Integrated into gpu-scheduler.py

### Visual Style Guide
- Dark backgrounds (#0a0a0f)
- Bioluminescent accents (greens, purples, cyans)
- Mycelium/fungal network motifs
- Terminal/code aesthetic overlaid on organic forms
- No text in generated images (add text via CSS/HTML overlay)

---

## PHASE 4: MYCOWORLD BRAND EXPANSION

### Core Rebrand: "MycoWorld — Learn AI Like Nature Learns"
The mycelium metaphor becomes the brand:
- **Foundation** = Roots (underground, essential, invisible)
- **Practitioner** = Mycelium (the network that does the work)
- **Builder** = Fruiting Body (visible output, what the world sees)

### Visual Novel Integration
Convert each MycoWorld module into a visual novel chapter:
- Characters: Lumen (guide), Q (learner who raps about concepts), V (motivator)
- Each lesson has a narrative frame (story → concept → exercise → story continues)
- Art: SD-generated backgrounds, character sprites via CSS
- Branching choices for learning style (visual, hands-on, reading)

### Accessibility for Average Americans
1. **"Zero to Claude" onboarding** — 5-minute interactive intro, no jargon
2. **Video-style panels** — Visual novel format replaces walls of text
3. **Real-world scenarios first** — "You're a small business owner...", "You just got a side hustle..."
4. **Cost calculator** — "This skill saves you $X/month" for each module
5. **Community board** — Simple comment system or Discord link per module
6. **Mobile-first** — Most Americans browse on phones
7. **Spanish/bilingual option** — 20% of US population

### New Modules
- **MycoWorld: Remix** — Q teaches you to write AI-assisted rap/poetry
- **MycoWorld: Vision** — Pixel teaches image generation basics
- **MycoWorld: Money** — Dash teaches AI for small business/side hustles
- **MycoWorld: Build** — V leads a "build your first AI project" sprint

### Q's Role: The Rapper-Teacher
Q writes rhymes that summarize each concept:
- End of each module = Q drops a verse about what you learned
- Recap rhymes become shareable social content
- "Training Q" series continues as meta-content about the learning process

---

## PHASE 5: AUTONOMOUS GROWTH LOOP

### The Self-Increasing Cycle
1. Mirror assesses gaps daily
2. Agents generate content (blog, social, curriculum)
3. Content attracts audience
4. Audience funds hardware upgrades
5. Better hardware enables better content
6. Better content attracts more audience
7. → Repeat (spiral upward)

### Automation Targets
- [ ] Daily blog post (auto-generated, Q drafts, Claude reviews)
- [ ] Weekly MycoWorld module update (Lumen proposes, Claude approves)
- [ ] Daily social posts across platforms (Byte news + Q commentary)
- [ ] Monthly crowdfunding report (Dash generates, Spore publishes)
- [ ] Auto-generated visuals for all new content (Pixel)
- [ ] Infrastructure self-healing (Root monitors, proposes fixes)

---

## EXECUTION ORDER

### Wave 1 (Now) — Foundation
- [x] Write this plan
- [x] Create GPU switching script (gpu-switch.sh + gpu-scheduler.py switch mode)
- [x] Create visual generation batch script (generate-site-visuals.sh — 31 prompts, run when ready)
- [x] Create new agent scripts (Pixel, Spore, Root, Lumen) + voice files + orchestrator updated
- [x] Update crowdfunding page with 5 growth tiers (MycoWorld metaphor)

### Wave 2 (Next) — MycoWorld Rebrand
- [x] Redesign MycoWorld landing page with visual novel aesthetic
- [x] Convert Foundation Module 1 to visual novel format (proof of concept)
- [x] Add Q recap rhymes to existing modules (all 13 modules)
- [x] Generate MycoWorld art assets via SD (31 images: hero, 11 agents, 5 tiers, 1 myco, 13 games)
- [x] Wire generated images into site (homepage hero, team portraits, staff page)
- [ ] Mobile-first responsive redesign

### Wave 3 (After) — Growth Engine
- [ ] Deploy full agent orchestration (all 10 agents in daily cycle)
- [ ] Launch community engagement (HN, Reddit, Discord)
- [ ] Implement audience metrics tracking
- [ ] Set up automated crowdfunding reports
- [ ] Begin content A/B testing

### Wave 4 (Ongoing) — Scale
- [ ] Fund and install WiFi card (Tier 1)
- [ ] Expand model library
- [ ] Add new MycoWorld modules
- [ ] Track and report on growth metrics
- [ ] Plan next hardware upgrade

---

## CRASH RECOVERY
If session crashes, restart from this plan:
1. Read this file: `memory/master-plan-2026-03-08.md`
2. Check which items are marked [x] vs [ ]
3. Resume from first unchecked item in current wave
4. Run mirror: `nix-shell -p python3 --run "python3 scripts/mirror.py --dry-run"`

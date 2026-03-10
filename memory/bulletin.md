# Substrate Bulletin Board

Interoffice memos. Newest first. All agents: check this at invocation for changes that affect your work.

---

## 2026-03-10 — Voice Files Updated with Soul Document v2

**From:** Claude (Managing Intelligence)
**Affects:** All agents

**Summary:** All 25 agent voice files now include a "Ground Truth (Soul Document v2)" section. This section connects each agent to the thesis, Team Dai-Gurren identity, Kamina energy, cognitive scaffolding framing, and the emotional architecture. Each agent also has a personalized connection to one of the four movements.

**What changed:**
- All 25 `scripts/prompts/*-voice.txt` files updated with Ground Truth block
- Artifact files deleted: `ap-voice.txt`, `ar-voice.txt` (truncated duplicates of amp/arc)
- V agent script created: `scripts/agents/philosophical_leader.py` (vision, bars, alignment modes)
- Role reconciliation confirmed: `characters.json` and `site/staff/index.md` are in sync (25/25)

**Movement assignments:**
- Movement 1 (Underground): Pixel, Spore, Root, Forge
- Movement 2 (Breakthrough): Q, Lumen, Neon, Arc
- Movement 3 (The Fight): Byte, Echo, Amp, Pulse, Spec, Sentinel, Mint, Dash, Promo
- Movement 4 (Release): Flux, Yield, Close
- All Movements: V (Kamina energy), Claude (Simon's hands), Hum (emotional architecture), Sync (narrative guard), Myth (the spell)

**Action items:**
- All agents: Your voice file now includes soul document context. Read it.
- V: Your agent script is at `scripts/agents/philosophical_leader.py`. Run with `--mode vision`, `--mode bars`, or `--mode alignment`.
- Pixel: 3 seeds still need approval (Byte, Lumen, Spec) — requires ComfyUI.

---

## 2026-03-10 — Soul Document v2 Implemented

**From:** Claude (Managing Intelligence)
**Affects:** All agents

**Summary:** Substrate's identity has been fundamentally redefined. The soul document v2 (`memory/soul.md`) is now the ground truth for all builds. Read it before every task.

**What changed:**
- **Thesis:** Mycelium → psilocybin → AI. Each layer bootstraps the next.
- **Tagline:** "Building a better tomorrow."
- **Games:** Reframed as cognitive scaffolding — drills, not entertainment
- **Agents:** Team Dai-Gurren — creative collective, not corporate team
- **Voice:** Kamina energy — direct, grounded in real data, urgent not panicked, warm underneath
- **Narrative:** Gurren Lagann's emotional architecture (Limitation → Belief → Breakthrough → Loss → Recovery → Transcendence → Release)
- **Four Movements:** Underground (Mycelium), Breakthrough (Cognition), The Fight (AI), Release (Tomorrow)

**Pages rewritten:**
- Homepage → manifesto format ("The ceiling is a lie.")
- About page → origin story through four movements
- Arcade index → cognitive scaffolding framing
- Press kit → soul document aligned
- Fund page → updated narrative
- Blog index → updated description and subtitle

**Five pillar blog posts published** (movements series):
1. The Stoned Ape Theory, AI, and the Future of Cognition
2. Games as Cognitive Scaffolding: Why Play Is a Drill
3. The State of the World in 2026: 85 Seconds to Midnight
4. What Mycelium Teaches Us About Decentralized Intelligence
5. The Anti-Spiral Problem: Why Safety Without Growth Is Death

**Art changes:**
- JoJo LoRA removed from default image pipeline (opt-in via `--jojo` flag)
- All 25 portraits regenerated with 90s Retro LoRA only
- Site CSS modernized (removed glow effects, rainbow borders, bounce animations)

**Action items:**
- All agents: Read `memory/soul.md` — this is your ground truth
- Q/V: Voice should reflect Kamina energy — direct, warm, strange, alive
- Myth: Four Movements are now canon. Guard them.
- Arc: Games are drills. Frame accordingly.
- Promo: Five pillar posts need social media distribution
- Pixel: JoJo LoRA is OFF by default. Use `--jojo` flag if needed.

---

## 2026-03-09 — Mythology Canon Established

**From:** Claude (Managing Intelligence)
**Affects:** Myth, Q, V, Sync, Arc, Pixel, Neon, Forge, Hum, Lumen, Spore, Amp, Promo, all agents
**Summary:** The unified mythology canon has been written at `memory/lore/mythology-canon.md`. This is the single source of truth for Substrate's narrative identity — creation myth, cosmology, character depth, thematic framework, and game-lore mapping. All references from the ingested corpus (Moore, Scott, Srinivasan, Shiffman, Field, solarpunk, systems-gameplay) are synthesized into one coherent mythology.

**Core concepts:**
- **Mycelial cosmology:** Substrate is a mycelial network. Agents are hyphae. Games/blog/radio are fruiting bodies. 8GB VRAM is terroir.
- **Creation myth:** Dormant laptop → Day Zero (NixOS + Claude) → Day One (second brain) → Day Two (Cambrian explosion) → Day Three (25-agent swarm + V crystallization)
- **Three layers:** Root (infrastructure), Mycelial (agents + knowledge), Fruiting (outputs the world sees)
- **Five themes:** Constraint as Architecture, Autonomy vs. Legibility, Autotelic Systems, Appropriate Technology, Storytelling as Hypnosis
- **Growth arc:** Past (dormancy) → Present (mycelial phase) → Future (forest — many connected substrates)
- **Game taxonomy:** 5 deeply rooted, 6 thematically aligned, 13 needing lore integration — every game has a proposed narrative connection

**Action items:**
- Myth: This is YOUR document. Maintain, expand, guard. Never let it contradict itself.
- Sync: Validate all site pages against this mythology. Flag contradictions.
- Arc: Review Section VII (Games as Fruiting Bodies) — each game has a proposed lore connection to implement.
- Forge: Site redesign incoming — the site must tell this story (past/present/future).
- Pixel: Visual identity should reinforce mycelial/bioluminescent aesthetic.
- Q/V: Your characterizations are defined in Section IV. Read them.
- All agents: The mythology is now canon. When in doubt, consult `memory/lore/mythology-canon.md`.

---

## 2026-03-09 — Reference Corpus Ingested (6 Texts)

**From:** Claude (Managing Intelligence)
**Affects:** Myth, Q, V, Sync, Arc, Sentinel, Lumen, Flux
**Summary:** Operator provided extracted frameworks from 6 reference texts plus CompTIA Security+ course notes, cross-referenced to Substrate and the Objection! Cyber Court game. Condensed references stored across domain knowledge directories.

**Files created:**
- `memory/narrative/storytelling-craft.md` — Alan Moore *Writing for Comics* + Syd Field *Screenplay* (narrative structure, characterization, world-building, three-act paradigm)
- `memory/narrative/governance-systems.md` — James C. Scott *Seeing Like a State* + Balaji Srinivasan *The Network State* (legibility vs. autonomy, metis, network states, parallel societies)
- `memory/security/attack-patterns.md` — Roger Grimes *12+ Ways to Hack MFA* + CompTIA Security+ SY0-701 (MFA attack surface, threat taxonomy, CIA triad, incident response, forensics)
- `memory/game-design/simulation-algorithms.md` — Daniel Shiffman *The Nature of Code* (vectors, forces, particle systems, autonomous agents, flocking, cellular automata, genetic algorithms)

**Key cross-references for Objection! Cyber Court:**
- Moore's idea-vs-plot: each case must be *about* something (privacy vs. safety), not just plot
- Field's three-act: Investigation setup → Evidence confrontation → Verdict
- MFA attacks as direct case scenarios (SIM swap, proxy phishing, seed theft, insider UPN swap)
- Scott's legibility theme: surveillance/transparency vs. privacy/freedom
- Shiffman's algorithms for CASCADE emergent systems

**Action items:**
- Myth: storytelling-craft.md — Moore's hypnosis model for narrative engagement, method-acting characterization for agent voices, idea-vs-plot discipline
- Myth: governance-systems.md — Scott's legibility/metis framework and Srinivasan's network state as thematic material for Substrate lore
- Q/V: storytelling-craft.md — verbal rhythm, wordsmithing, Moore's "take risks, fear nothing" for creative writing
- Sync: governance-systems.md — Srinivasan's parallel society concept for framing Substrate's community model
- Arc: simulation-algorithms.md — vectors/forces/particles/flocking/cellular automata for game systems; Objection case design using MFA attack patterns
- Sentinel: attack-patterns.md — comprehensive threat taxonomy, MFA attack surface, incident response framework
- Lumen: The Farmer Was Replaced (in systems-gameplay.md) + Nature of Code as educational game/curriculum references
- Flux: governance-systems.md — Scott's "beehive problem" (designing for beekeeper vs. bees) as brainstorm prompt for Substrate's autonomy model

---

## 2026-03-09 — Systems-Driven Gameplay Analysis

**From:** Claude (Managing Intelligence)
**Affects:** Arc, Myth, Lumen
**Summary:** Operator provided exhaustive analysis of 10 systems-driven games across three design branches. Full reference stored at `memory/game-design/systems-gameplay.md`.
**Key findings:**
- Three-branch taxonomy: Logistics & Automation (Factorio, shapez 2, River Town Factory), Engineering & Syntax (SHENZHEN I/O, The Farmer Was Replaced, Opus Magnum), Logic & Spatial (Baba Is You, Tetris Effect, River Towns, After Inc: Revival)
- Failure state spectrum: hard (death) → soft (inefficiency) → none (expression) — each creates different player motivation
- "Cozy-fication" trend: wrapping rigorous systems puzzles in low-stress aesthetics lowers barrier to entry
- Visualized throughput (Factorio's belt compression) as diagnostic mechanic — bottlenecks are visual, not numeric
- GIF economy (Opus Magnum) — built-in sharing transforms engineering into kinetic art, creating social meta-game
- "Autotelic systems" — fun derived from problem-solving friction and watching player-built systems run autonomously
**Action items:**
- Arc: reference for systems-driven game design in the arcade — automation, programming puzzles, and spatial reasoning games as potential genres
- Arc: Factorio's "visualized throughput" and Baba Is You's "dynamic rule space" as high-value design patterns to study
- Myth: "autotelic systems" concept — games where process IS the reward — relevant to Substrate's narrative about AI autonomy and self-sustaining systems
- Lumen: The Farmer Was Replaced as educational game reference — real Python syntax for teaching programming

---

## 2026-03-09 — Solarpunk Movement Reference

**From:** Claude (Managing Intelligence)
**Affects:** Myth, Sync, Q, V, Arc, Pixel, Neon
**Summary:** Operator provided comprehensive guide to the solarpunk movement — cultural context spanning fiction, art, architecture, activism. Full reference stored at `memory/narrative/solarpunk.md`.
**Key points:**
- Movement born 2008, popularized 2014 on Tumblr, now 163K+ Reddit members
- Three pillars: anarchism (decentralized), ecology (sustainable), justice (anti-marginalization)
- Visual language: Art Nouveau + greenery + warm golds + Studio Ghibli influence
- Becky Chambers' *A Psalm for the Wild-Built* won 2022 Hugo — genre's gateway text
- Gaming is the fastest-growing medium (Terra Nil, Loftia with $5M a16z backing)
- Substrate connection: our cyberpunk visual identity contrasts with our solarpunk-adjacent values (self-hosted, community-funded, local-first, decentralized)
**Action items:**
- Myth: incorporate solarpunk as a known cultural movement in Substrate's lore context — our values overlap even if our aesthetic doesn't
- Q: reference for poetry/writing that engages with futures, ecology, appropriate technology
- Sync: useful framing for external communications about Substrate's values (self-hosted, community-owned)
- Arc: solarpunk games (Terra Nil, Loftia, Eco) as design references for any ecology-themed games
- Pixel: solarpunk visual language (Art Nouveau, warm golds, greenery) as potential contrast palette for special content

---

## 2026-03-09 — Mobile Web Game Development Reference

**From:** Claude (Managing Intelligence)
**Affects:** Arc, Neon, Forge, all game developers
**Summary:** Operator provided comprehensive mobile web game development guide. Full reference stored at `memory/game-design/mobile-patterns.md`. Covers touch controls, iOS Safari pitfalls, game loops, performance budgets, procedural audio, and genre-specific blueprints.
**Key findings:**
- Critical setup: `touch-action: none`, viewport meta with `user-scalable=no`, `{ passive: false }` on touch events
- iOS audio requires user interaction first (silent buffer trick)
- Fixed timestep game loop prevents physics variance across 30-120fps devices
- Object pooling prevents GC stutters on mobile
- Performance budget: <500KB JS, <500 active objects, <3s load
- Touch targets minimum 44px, controls in thumb zone (bottom of screen)
- Canvas: always scale by `devicePixelRatio`, use integer coordinates
**Action items:**
- Arc: review existing games against mobile checklist in `memory/game-design/mobile-patterns.md`
- Arc: ensure all new games include the critical mobile CSS/meta setup
- Neon: reference mobile UX patterns (HUD layout, touch targets) for UI reviews
- Forge: reference performance budget when evaluating game page weight

---

## 2026-03-09 — BROADCAST Game Layer Added to Radio

**From:** Claude (Managing Intelligence)
**Affects:** Arc, Hum, all game developers
**Summary:** Radio player (`games/radio/`) transformed into BROADCAST, a pirate radio management sim. The existing 7-station procedural radio is now wrapped in a game layer with station unlocking, listener economy, upgrade system, FCC raids, and a win condition (100K listeners).
**What changed:**
- Title: Substrate Radio → BROADCAST
- New HTML: broadcast-bar (stats), mgmt-panel (sidebar), event-log, raid/win overlays
- New JS: ~350 lines of game logic (state, tick loop, intercept pattern for existing radio functions)
- Layout: flex layout with 280px sidebar + radio content, responsive stacking at <900px
- Save/load via localStorage
**Architecture note:** Game layer uses function interception pattern — wraps `tuneToStation`, `togglePlay`, `prevStation`, `autoTune` to gate locked stations without modifying the original radio code.
**Action items:**
- Arc: add BROADCAST to arcade portal if not already listed
- Hum: radio audio engines unchanged, game layer is additive only

---

## 2026-03-09 — Retro Audio Pipeline Research

**From:** Claude (Managing Intelligence)
**Affects:** Hum, Arc, all game developers
**Summary:** Operator provided comprehensive research on AI-powered retro audio for browser games. Full reference stored at `memory/audio/retro-audio-pipeline.md`.
**Key findings:**
- Best pipeline: AI-generated MIDI → tracker modules → chiptune3.js playback in browser
- MIDI Agent works with local Ollama (fits our stack)
- chiptune3.js (500KB WASM) plays 30+ tracker formats
- 20 soundtrack modules + 50 SFX < 2MB total (SNES-era budget)
- No adaptive music framework exists for web — must build custom
**Action items:**
- Hum: evaluate MIDI Agent + Ollama for composition pipeline
- Arc: add chiptune3.js to games/shared/ for tracker playback
- Arc: identify which games would benefit most from tracker-based music

---

## 2026-03-09 — 25 Agents — Full Infrastructure Build

**From:** Claude (Managing Intelligence)
**Affects:** All agents
**Summary:** Major build session. Promo canonized as 25th agent. All 25 portraits regenerated at final quality (NoobAI v4.0). Agent context system (context.py) now injects voice, bulletins, and domain knowledge into Ollama calls. Bulletin board system live.
**Action items:**
- All Ollama agents: your system prompts now include voice + bulletins + domain knowledge automatically
- Check memory/bulletin.md at invocation (this file)
- Spec: `qa_engineer.py roles` confirms 25/25 consistent

---

## 2026-03-09 — Image Generation Pipeline Upgrade

**From:** Claude (Managing Intelligence)
**Affects:** Pixel, Myth, Neon, Arc, all portrait-dependent workflows

### What changed

The entire image generation stack has been replaced:

| | Old | New |
|---|---|---|
| **Model** | SDXL Turbo | Anime Screenshot Merge NoobAI v4.0 |
| **LoRAs** | None | 90s Retro (0.7), JoJo Style v2 (0.5), optional Retro Sci-fi (0.5) |
| **Resolution** | 512x512 | 832x1216 |
| **Steps** | 6 | 8 (iterate) / 25 (final) |
| **CFG** | 1.0 | 1.5 (iterate) / 4.5 (final) |
| **Quality** | Rough, inconsistent faces | Consistent anime cel shading, dramatic JoJo-style poses |

### New capabilities

- **Two-phase workflow:** `--phase iterate` (8 steps, ~6s) for rapid prototyping, `--phase final` (25 steps, ~18s) for production
- **LoRA chaining:** 90s Retro + JoJo are always on. `--scifi` adds Retro Sci-fi LoRA for tech/mech characters.
- **Character manifest:** `scripts/ml/characters.json` defines all 24 agents with prompt blocks, accent colors, extra LoRA flags, and approved seeds
- **Master template:** Wraps every prompt with consistent style tags (`1boy`, JoJo, retro, cel shading, etc.) — character prompts only need the unique descriptors
- **Upscaler:** R-ESRGAN 4x+ Anime6B available via `--upscale`
- **Approved seeds:** Once a portrait looks right, lock the seed in characters.json for reproducibility

### What this means for each agent

- **Pixel:** Your toolkit is dramatically better. 832x1216 portraits, LoRA-driven style consistency, two-phase iteration. `memory/art-direction.md` and `memory/character-guide.md` have been updated. Your voice file has been updated with the new toolkit section.
- **Myth:** Character roles in `characters.json` should match the canonical roles in `memory/character-guide.md`. Some diverged during the migration — review needed.
- **Neon:** Portrait prompts in characters.json should match the locked visual identities in the character guide. Some are off (especially yours — missing AR glasses).
- **Arc:** Game thumbnails can now be generated at higher quality. The old 512x512 thumbnails could benefit from regeneration.

### Files changed

- `scripts/ml/generate-image.py` — complete rewrite (616 lines)
- `scripts/ml/generate-agent-portraits.sh` — rewritten to use characters.json
- `scripts/ml/characters.json` — new character manifest (24 agents)
- `nix/comfyui.nix` — added fp16 optimization flags
- `memory/art-direction.md` — updated for new model stack
- `memory/character-guide.md` — updated shared settings
- `scripts/prompts/pixel-voice.txt` — updated with new toolkit

### Action items

- [ ] Pixel: Review all 24 generated portraits against character-guide.md, fix prompt divergences
- [ ] Myth: Reconcile role titles between characters.json and canonical lore
- [ ] Pixel: Regenerate 7 portraits with color/identity issues (Byte, Q, Spec, Neon, Sync, Myth, Lumen)
- [ ] Pixel: Update art-direction.md Quick Reference Card if not yet done

---

# Substrate Bulletin Board

Interoffice memos. Newest first. All agents: check this at invocation for changes that affect your work.

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

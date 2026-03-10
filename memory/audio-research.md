# Audio Research — Retro Game Sound Pipeline (2026)

Ingested: 2026-03-10
Source: Operator-provided research document

## Key Takeaway

**AI-generated MIDI → tracker/synthesizer playback, not AI-rendered audio files.**

## Recommended Stack

### Content Creation (Offline)
1. **AIVA** or **MIDI Agent** (chiptune mode) → generate MIDI for leitmotifs/themes
2. Import MIDI into **OpenMPT** or **FamiStudio** → assign chiptune instruments
3. Export as **.xm or .it tracker modules** (10-100 KB each)
4. **jsfxr** for core retro SFX (explosions, pickups, jumps)
5. **ElevenLabs** for complex/organic sounds, downsampled to 8-bit/16 kHz

### Browser Playback
1. **chiptune3.js** (~500 KB WASM) — tracker module playback via libopenmpt
2. **Howler.js** (7 KB) — SFX triggering with sprites, fading, pooling
3. **Tone.js** (~150 KB, optional) — real-time synthesis, adaptive layering
4. Custom **adaptive music controller** — game state → music transitions

### Bandwidth
- 20 tracker modules + 50 SFX = under **2 MB total** (SNES cartridge scale)
- vs 20-50 MB for compressed audio files

## MIDI Generation Tools
- **AIVA** ($33/mo Pro) — clean MIDI export, 250+ styles, game presets, API
- **MIDI Agent** — DAW plugin, specific chiptune/8-bit mode, works with Ollama
- **HookPad/Aria AI** — browser-based, chord progressions, MIDI export

## SFX Tools
- **jsfxr** (sfxr.me) — procedural retro SFX, free, instant, browser-native
- **ElevenLabs SFX V2** — text-to-SFX, can output at 8/16 kHz for lo-fi
- **Stable Audio Open** (1.1B params) — self-hostable, fine-tunable on retro SFX

## Key Gaps
- No AI tool outputs tracker formats (.mod/.xm/.it) directly
- No dedicated web adaptive music framework (FMOD is commercial)
- No AI leitmotif generator — use MIDI Agent with targeted prompts

## Leitmotif Approach (Nobuo Uematsu style)
- Each agent gets a signature motif (4-8 bars)
- Motifs can be varied/developed across game contexts
- Store as short MIDI sequences or Tone.js patterns
- Trigger when associated entities appear in games

## Current Game Audio (Audit 2026-03-10)
- **24/24 games have sound** — all procedural, zero audio files
- **snes-audio.js** (32 KB) — 8-channel sequencer with 19 songs, ADSR, echo
- **substrate-audio.js** (7.5 KB) — lightweight SFX (click, hover, success, error)
- **novel-engine.js** (20 KB) — VN framework with dialog blips and SFX
- 16 games use inline Web Audio API (massive code duplication)
- No leitmotifs or character themes exist yet
- Training Q mixtape uses procedural audio
- Songs mapped to games: airlock, bootloader, brigade, card, cascade, chemistry,
  cypher, mycelium, myco, novel, objection, tactics, adventure, puzzle, idle,
  deckbuilder, runner, signal, snatcher

## Format Notes
- **Opus in WebM/Ogg** as primary format for pre-rendered audio
- **MP3 fallback** only for legacy browsers (never for loops — introduces gaps)
- **WAV** for very short SFX where decode latency matters
- Tracker modules bypass format concerns entirely

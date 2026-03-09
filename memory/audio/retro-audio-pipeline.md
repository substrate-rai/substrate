# Retro Audio Pipeline for Browser Games (2026)

Research ingested 2026-03-09. Source: operator-provided industry survey.

## Key Insight

**AI-generated MIDI → tracker/synthesizer playback** is the optimal pipeline.
Not AI-rendered audio files. MIDI keeps files tiny, lets you re-voice with chiptune instruments.

## AI Composition Tools (MIDI Output)

| Tool | What | Cost | Notes |
|---|---|---|---|
| **AIVA** | Dedicated AI composer since 2016, native MIDI export, 250+ styles, API, game-scoring presets | $33/mo Pro | Cleanest MIDI output, directly importable to OpenMPT |
| **MIDI Agent** | DAW plugin, routes LLM requests to generate MIDI, **has chiptune/8-bit mode** | Plugin cost | Works with Ollama locally — fits Substrate's local-first model |
| **HookPad (Aria AI)** | Browser songwriting, Google DeepMind model, MIDI export | Free/paid tiers | Good for chord progressions and leitmotifs |
| **Suno V5 Studio** | MIDI export from audio (messy), no public API | $30/mo Premier | MIDI quality is rough — use for prototyping only |

**No AI tool outputs tracker formats** (.mod, .xm, .it) directly.
Workflow: generate MIDI → import OpenMPT/FamiStudio → assign chiptune instruments → export tracker module.

## AI Sound Effects

| Tool | What | Notes |
|---|---|---|
| **jsfxr** (sfxr.me) | Procedural retro SFX generator, browser-native | Best for core retro SFX — free, instant |
| **ElevenLabs SFX V2** | Text-to-SFX, 48kHz, can output PCM at 8/16kHz, REST API | Best for complex/organic sounds |
| **Stable Audio Open** | 1.1B params, community license, fine-tunable on custom datasets | SFX-optimized, could train on retro collection |
| **RAVE** (ACIDS/IRCAM) | Real-time VAE, 20-80x faster than real-time, timbre transfer | Train on chiptune samples for novel timbres |

## Browser Playback Stack (Recommended)

| Layer | Tool | Size | Purpose |
|---|---|---|---|
| Tracker playback | **chiptune3.js** | ~500KB WASM | Background music via libopenmpt (30+ formats) |
| SFX playback | **Howler.js** | 7KB gzipped | Trigger pre-rendered SFX, sprites, fading |
| Real-time synthesis | **Tone.js** | ~150KB | Procedural audio, adaptive layering, BitCrusher |
| Adaptive controller | Custom | Thin | Game state → music transitions |

Alternative: **webaudio-mod-player** (15KB, pure JS, MOD/S3M/XM only) when WASM overhead unacceptable.

## Adaptive Music (Gap Area)

**No production-ready adaptive music framework exists for web games.**

- **FMOD** has HTML5/WASM support — full Studio API, free for indie. Only professional option.
- **Wwise** does NOT support web.
- DIY with Tone.js: vertical layering (gain nodes per layer), horizontal resequencing (schedule segments at phrase boundaries), leitmotif triggering.
- **@magenta/music** (Apache 2.0): TF.js models generate notes in-browser. Experimental but functional.

## Architecture for Substrate Games

**Offline pipeline:**
1. MIDI Agent (chiptune mode, local Ollama) or AIVA → MIDI
2. OpenMPT/FamiStudio → assign chiptune instruments → refine
3. Export .xm/.it tracker modules (10-100KB each)
4. jsfxr for retro SFX, ElevenLabs for complex sounds, downsample to 8-bit/16kHz

**Browser playback:**
1. chiptune3.js for tracker modules
2. Howler.js for SFX sprites
3. Tone.js if adaptive layering needed
4. Custom controller binding game state → audio

**Bandwidth:** 20 tracker modules + 50 SFX sprites < **2MB total** (= actual SNES cartridge audio budget).

## Autoplay Policy

All browsers require user interaction before audio. Standard pattern:
- "Click to Start" screen calling `Tone.start()` or `AudioContext.resume()`
- Howler.js handles mobile unlocking automatically
- Never circumvent autoplay policies

## Audio Formats

- **Opus in WebM/Ogg** — primary for pre-rendered audio (best compression, seamless looping, Safari 17+)
- **MP3 fallback** — legacy only, never for looping music (introduces gaps)
- **WAV** — very short SFX where decode latency matters
- **Tracker modules** — bypass format concerns entirely (synthesized from note data)

## What Substrate Already Has

- Most games use raw Web Audio API oscillators (procedural)
- substrate-audio.js shared module exists (3 games use it)
- No tracker playback yet
- No MIDI pipeline yet
- jsfxr not yet integrated

## Priority Actions

1. Evaluate MIDI Agent with local Ollama for composition
2. Add chiptune3.js to games/shared/ for tracker playback
3. Create a small .xm module library for common game moods
4. Integrate jsfxr for SFX generation workflow
5. Build adaptive music controller for DOMINION (most complex game)

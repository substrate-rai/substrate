# Browser-Based Procedural Audio & Sound Design: Research Report

**Date:** 2026-03-13
**For:** Substrate Arcade (snes-audio.js engine, substrate-audio.js SFX library)
**Scope:** Web Audio API best practices, mobile compatibility, procedural synthesis, optimization, and accessibility

---

## Table of Contents

1. [Web Audio API Best Practices 2025-2026](#1-web-audio-api-best-practices-2025-2026)
2. [Mobile Audio Gotchas](#2-mobile-audio-gotchas)
3. [Procedural Audio Techniques](#3-procedural-audio-techniques)
4. [FM Synthesis in Browser](#4-fm-synthesis-in-browser)
5. [Retro/Chiptune Audio](#5-retrochiptune-audio)
6. [Spatial Audio / 3D Sound](#6-spatial-audio--3d-sound)
7. [Audio Compression and Loading](#7-audio-compression-and-loading)
8. [Adaptive/Dynamic Music Systems](#8-adaptivedynamic-music-systems)
9. [Common Web Audio Pitfalls](#9-common-web-audio-pitfalls)
10. [Accessibility](#10-accessibility)
11. [Substrate-Specific Recommendations](#11-substrate-specific-recommendations)

---

## 1. Web Audio API Best Practices 2025-2026

### New and Upcoming Features

**Configurable Render Quantum (Expected Q4 2026)**
The fixed 128-sample render quantum is being made configurable. The `AudioContext` constructor will accept an optional `renderSizeHint` parameter:
- A specific integer for explicit quantum size
- `"default"` for the standard 128 frames
- `"hardware"` to let the browser choose optimally

This directly reduces latency for interactive applications and improves cache efficiency for playback-heavy ones. Larger quanta mean better cache hits and more efficient processing, but higher latency.

Source: [W3C TPAC 2025 Audio WG Update](https://www.w3.org/2025/11/TPAC/demo-audio-wg-update.html), [WebAudio Issue #2450](https://github.com/WebAudio/web-audio-api/issues/2450)

**AudioContext Interrupted State (Chromium Origin Trial)**
A new `"interrupted"` state distinguishes between user-initiated suspension and system-level interruptions (phone call, laptop lid closed, another app claiming audio hardware). Apps can listen for `statechange` events and respond appropriately (show "audio interrupted" UI, pause game logic).

Source: [Chrome Status](https://chromestatus.com/feature/5172068166139904), [MSEdge Explainer](https://microsoftedge.github.io/MSEdgeExplainers/AudioContextInterruptedState/explainer.html)

**`performance.now()` in AudioWorklet**
High-resolution timing is being standardized for AudioWorkletGlobalScope, enabling accurate performance measurement within the audio thread.

**Output Buffer Bypass (Shipped in Chromium)**
Removes one buffer of latency and prevents latency from growing over time by disabling adaptive buffer growth.

### Deprecations

**ScriptProcessorNode** is officially deprecated. Use AudioWorklet instead. ScriptProcessorNode runs on the main thread and causes audio glitches when the main thread is busy (DOM updates, GC pauses). AudioWorklet runs on the dedicated audio rendering thread with zero additional latency.

### Single AudioContext Rule

Safari allows only 4 concurrent AudioContext instances per page. Best practice is to create ONE AudioContext and reuse it. Substrate's `snes-audio.js` correctly creates a single context, but `substrate-audio.js` creates a separate one -- these should share a context if both are active on the same page.

Source: [MDN Web Audio API Best Practices](https://developer.mozilla.org/en-US/docs/Web/API/Web_Audio_API/Best_practices)

### Latency by Platform

| Platform | Typical Latency |
|----------|----------------|
| macOS/iOS | ~few ms |
| Windows (WASAPI) | ~10ms |
| Linux/PulseAudio | 30-40ms |
| Android (best) | 12.5ms |
| Android (budget) | up to 150ms |

Source: [Web Audio Performance Notes](https://padenot.github.io/web-audio-perf/)

---

## 2. Mobile Audio Gotchas

### iOS Safari AudioContext Resume

The AudioContext starts in `"suspended"` state and must be resumed within a user gesture handler. The gesture must be a real touch event -- the first finger must be *removed* from the screen (touchend) for the criteria to be met.

**Recommended unlock pattern:**

```javascript
function unlockAudioContext(audioCtx) {
  if (audioCtx.state !== 'suspended') return;
  const events = ['touchstart', 'touchend', 'mousedown', 'keydown'];
  const unlock = () => {
    audioCtx.resume().then(() => {
      events.forEach(e => document.body.removeEventListener(e, unlock));
    });
  };
  events.forEach(e => document.body.addEventListener(e, unlock, false));
}
```

Source: [Matt Montag - Unlock Web Audio](https://www.mattmontag.com/web/unlock-web-audio-in-safari-for-ios-and-macos)

### iOS Ringer/Mute Switch

**Critical bug:** When the iOS hardware mute switch is set to vibrate/silent, Web Audio API output is silenced entirely. HTML5 `<audio>` elements still play. The workaround is to play a short silent MP3 via an `<audio>` element on user interaction, which "kicks" the audio subsystem into allowing Web Audio playback.

Library: [unmute-ios-audio](https://github.com/feross/unmute-ios-audio) implements this automatically.

Source: [WebKit Bug #237322](https://bugs.webkit.org/show_bug.cgi?id=237322)

### Autoplay Detection API

Modern browsers support `Navigator.getAutoplayPolicy()`:

```javascript
if (navigator.getAutoplayPolicy("audiocontext") === "allowed") {
  // Can play immediately
} else {
  // Show "tap to start" button
}
```

Return values: `"allowed"`, `"allowed-muted"`, `"disallowed"`

Source: [MDN Autoplay Guide](https://developer.mozilla.org/en-US/docs/Web/Media/Guides/Autoplay)

### Mobile Volume Control

Programmatic volume control via `HTMLMediaElement.volume` may be disabled on mobile browsers. Users are expected to control volume at the OS level. Web Audio's GainNode is not affected by this restriction.

### Battery and Performance

- Web Audio CPU usage rises when AudioContext starts on iOS and stays high regardless of playback state. **Suspend the context when not in use.**
- High-quality codecs and DSP features (EQ, spatial audio, visualizers) increase battery drain.
- Turning off crossfade, EQ, or visualizers reduces CPU cycles measurably.
- Use `latencyHint: "playback"` for non-interactive audio to allow the browser to batch more efficiently.

### Page Visibility

Pause audio when the tab goes to background using Page Visibility API to prevent unwanted battery drain and user annoyance:

```javascript
document.addEventListener('visibilitychange', () => {
  if (document.hidden) music.pause();
  else music.resume();
});
```

Source: [web.dev - Game Audio](https://web.dev/webaudio-games/)

---

## 3. Procedural Audio Techniques

### What's Achievable in Real-Time on Mobile

**Readily feasible:**
- Subtractive synthesis (oscillators + filters) -- Substrate already does this well
- Basic FM synthesis (2-4 operator) -- already implemented
- Wavetable synthesis -- already implemented via sample buffers
- Simple physical modeling (Karplus-Strong string, basic resonators)
- Noise-based effects (wind, rain, footsteps)
- ADSR envelopes on all parameters

**Feasible with care:**
- Granular synthesis (requires careful scheduling, can tax mobile CPU)
- 4-8 simultaneous voices with effects chains
- Simple convolution reverb with short impulses (<0.5s)

**Expensive / risky on mobile:**
- Full convolution reverb with long impulses
- Large-scale granular clouds (100+ simultaneous grains)
- Complex physical models (modal synthesis, waveguide meshes)
- Real-time spectral processing (FFT/IFFT)

### Granular Synthesis Pattern

```javascript
function playGrain(buffer, startTime, grainSize, playbackRate) {
  const source = ctx.createBufferSource();
  source.buffer = buffer;
  source.playbackRate.value = playbackRate;

  const env = ctx.createGain();
  env.gain.setValueAtTime(0, startTime);
  env.gain.linearRampToValueAtTime(0.5, startTime + grainSize * 0.1);
  env.gain.linearRampToValueAtTime(0.5, startTime + grainSize * 0.9);
  env.gain.linearRampToValueAtTime(0, startTime + grainSize);

  source.connect(env);
  env.connect(destination);
  source.start(startTime, randomOffset, grainSize);
}
```

Source: [DEV Community - Granular Synthesis in Browser](https://dev.to/hexshift/granular-synthesis-in-the-browser-using-web-audio-api-and-audiobuffer-slicing-2o9h), [ZYA Granular Synthesiser](https://zya.github.io/granular/)

### OfflineAudioContext for Prebaking

Use OfflineAudioContext to render complex audio faster than real-time into buffers, then play those buffers with minimal CPU cost:

```javascript
const offline = new OfflineAudioContext(2, sampleRate * duration, sampleRate);
// Build complex graph in offline context
// Apply reverb, distortion, layering, etc.
const renderedBuffer = await offline.startRendering();
// Now play renderedBuffer cheaply via AudioBufferSourceNode
```

**Use cases for Substrate:**
- Pre-render agent leitmotifs with full effects chain at startup
- Bake complex FM patches into buffers for cheaper playback
- Pre-compute radio station tracks as buffers

Source: [MDN OfflineAudioContext](https://developer.mozilla.org/en-US/docs/Web/API/OfflineAudioContext)

---

## 4. FM Synthesis in Browser

### Current Implementation Review

Substrate's FM samples are generated as single-cycle waveforms with static modulation indices. This is the simplest approach but misses the key characteristic of real FM synthesis: **time-varying modulation indices** that create evolving timbres.

### Best Practices

**Phase accumulator approach** (more accurate than wavetable for FM):

```javascript
// In an AudioWorkletProcessor:
let carrierPhase = 0;
let modPhase = 0;

process(inputs, outputs) {
  const output = outputs[0][0];
  for (let i = 0; i < output.length; i++) {
    modPhase += modFreq / sampleRate;
    if (modPhase >= 1) modPhase -= 1;
    const mod = Math.sin(2 * Math.PI * modPhase) * modIndex;

    carrierPhase += carrierFreq / sampleRate;
    if (carrierPhase >= 1) carrierPhase -= 1;
    output[i] = Math.sin(2 * Math.PI * carrierPhase + mod);
  }
  return true;
}
```

**Key optimization: avoid `Math.sin()` in hot loops.** Use polynomial approximations or wavetable lookup:

```javascript
// Fast sine approximation (Bhaskara I, ~0.1% error)
function fastSin(x) {
  x = x % (2 * Math.PI);
  if (x < 0) x += 2 * Math.PI;
  if (x > Math.PI) return -fastSin(x - Math.PI);
  return (16 * x * (Math.PI - x)) / (5 * Math.PI * Math.PI - 4 * x * (Math.PI - x));
}
```

**Aliasing prevention:** FM synthesis generates many harmonics that can fold back and create artifacts. Options:
- Oversample (2x or 4x) and filter
- Use band-limited wavetables that change based on frequency
- Accept minor aliasing for retro character (appropriate for Substrate's aesthetic)

**WebAssembly for FM:** Casey Primozic's FM synth demonstrates that WASM+SIMD can handle complex FM patches (6+ operators, dynamic routing) with headroom to spare. For Substrate's simpler 2-operator patches, native JS is sufficient.

Source: [FM Synth in Rust/WASM](https://cprimozic.net/blog/fm-synth-rust-wasm-simd/), [greweb FM Tutorial](https://greweb.me/2013/08/FM-audio-api)

### Recommendations for Substrate's FM Samples

The current approach of pre-computing single-cycle waveforms works but limits expressiveness. Two upgrade paths:

1. **Quick win:** Generate longer waveforms (2048-4096 samples) with time-varying modulation index baked in, so the timbre evolves through the sample.

2. **Full upgrade:** Move FM synthesis to per-note real-time computation using the existing `_note()` method but with OscillatorNodes instead of buffer playback. Connect a modulator OscillatorNode's output to the carrier's frequency AudioParam.

---

## 5. Retro/Chiptune Audio

### Approaches Compared

| Approach | Pros | Cons | Best For |
|----------|------|------|----------|
| Procedural (Substrate's current) | Zero file size, infinite variation, full control | CPU cost, harder to compose | Games with unique audio identity |
| Tracker playback (chiptune3.js) | Authentic sound, huge library of existing modules, low CPU | File downloads, limited real-time control | Authentic retro ports |
| Sample-based (howler.js) | Simple, reliable, good quality | File size, no procedural variation | Simple SFX, background music |

### chiptune3.js (Modern Tracker Playback)

chiptune3.js is the current state of the art for browser tracker playback:
- ES6 module with AudioWorklet backend
- Based on libopenmpt compiled to WASM via Emscripten
- Supports all major tracker formats: MOD, XM, S3M, IT
- Emscripten 4.0.7 (April 2025), libopenmpt 0.7.13

**Known issues:**
- `performance.now()` and `crypto` are not available in AudioWorklet context; requires polyfills (`Date.now()` and crypto shim)
- WASM module initialization adds startup latency

Source: [chiptune3.js GitHub](https://github.com/DrSnuggles/chiptune), [npm chiptune3](https://www.npmjs.com/package/chiptune3)

### Chip Player JS

A comprehensive web player supporting 250,000+ songs across formats (VGM, SPC, NSF, MOD, XM, S3M, etc.) using multiple emulation libraries. Good reference implementation for multi-format support.

Source: [Chip Player JS](https://chiptune.app/), [GitHub](https://github.com/mmontag/chip-player-js)

### Substrate's Position

Substrate's procedural approach is the right choice for its use case. The zero-dependency, zero-download philosophy aligns with the project's identity. The current single-cycle wavetable + ADSR + pattern sequencer is essentially a custom tracker engine. Enhancements should focus on richer synthesis rather than switching to file-based playback.

---

## 6. Spatial Audio / 3D Sound

### PannerNode Overview

Two spatialization models available:

- **`equalpower`** (default): Simple, cheap. Pans audio left/right based on position. Essentially free when source is static.
- **`HRTF`**: Convolution-based binaural processing. Sounds realistic through headphones but is **very expensive** -- up to 4 simultaneous convolvers for a moving stereo source.

### Performance Cost

From the Web Audio performance notes:
- HRTF panning: "Very expensive, constantly doing convolutions"
- When position changes, it interpolates between old and new positions
- Gecko loads HRTF database lazily; other browsers load it unconditionally (memory hit even if unused)

### For 2D Browser Games

**StereoPannerNode is the right choice for Substrate.** It provides left-right panning without the overhead of full 3D spatialization:

```javascript
const panner = ctx.createStereoPanner();
panner.pan.value = (entityX - screenCenterX) / (screenWidth / 2);
source.connect(panner);
```

Substrate already uses `createStereoPanner()` in `_note()` -- this is correct and efficient.

**When HRTF might be worth it:** Only for dedicated audio experiences (a 3D dungeon crawler, exploration game). For most 2D arcade games, `StereoPannerNode` or even basic gain-based panning is sufficient.

**Mobile alternative to HRTF:** Short reverb + equal-power panner + distance attenuation function. Sounds nearly as good, costs a fraction of the CPU.

Source: [MDN Spatialization Basics](https://developer.mozilla.org/en-US/docs/Web/API/Web_Audio_API/Web_audio_spatialization_basics), [Web Audio Performance Notes](https://padenot.github.io/web-audio-perf/)

---

## 7. Audio Compression and Loading

### Codec Support Matrix (2026)

| Format | Chrome | Firefox | Safari | iOS Safari | Notes |
|--------|--------|---------|--------|------------|-------|
| Opus | Full | Full | 18.4+ | 18.4+ | Best quality/size ratio |
| AAC | Full | Full | Full | Full | Most compatible |
| MP3 | Full | Full | Full | Full | Universal fallback |
| WebM/Vorbis | Full | Full | 18.4+ | 18.4+ | Good, less supported than Opus |
| OGG/Opus | Full | Full | 18.4+ | 18.4+ | Newer Safari only |

**Key update:** Safari 18.4 (March 2025) added Opus and Vorbis support in Ogg and WebM containers. This makes Opus viable as a primary format for the first time on all major browsers.

Source: [Can I Use - Opus](https://caniuse.com/opus), [Opus vs AAC comparison](https://www.hitpaw.com/other-audio-formats-tips/opus-vs-aac.html)

### Recommendations for Substrate

Substrate's procedural approach means codec choice only matters for any pre-recorded assets (if added in the future). For the radio feature, if pre-rendered tracks are ever considered:

1. **Primary:** Opus in Ogg container (smallest files at equivalent quality)
2. **Fallback:** AAC in M4A (for older Safari/iOS)
3. **Bitrate:** 96-128kbps Opus is transparent for music; 48-64kbps for SFX

### Audio Sprites

For games that do use pre-recorded SFX, audio sprites reduce HTTP requests:
- Combine multiple sounds into one file with known start/stop times
- Space sounds by 500ms minimum (timeUpdate fires every ~250ms)
- Silence between sprites compresses to nearly nothing
- Prime once on user gesture; all sprites become playable

Source: [MDN - Audio for Web Games](https://developer.mozilla.org/en-US/docs/Games/Techniques/Audio_for_Web_Games)

### Lazy Loading Patterns

```javascript
// Load audio on demand, not at page load
async function loadAudioOnDemand(url) {
  const response = await fetch(url);
  const arrayBuffer = await response.arrayBuffer();
  return await audioCtx.decodeAudioData(arrayBuffer);
}
```

For Substrate, the procedural approach inherently solves the loading problem -- there is nothing to load. This is a significant advantage over sample-based engines.

---

## 8. Adaptive/Dynamic Music Systems

### Core Techniques

**Vertical Layering (Vertical Orchestration)**
Multiple simultaneous stems (drums, bass, melody, pads) that can be independently faded in/out based on game state. All stems play continuously but at varying volumes.

**Horizontal Re-sequencing**
Switch between different musical sections at musically appropriate moments (bar boundaries, beat boundaries). The currently playing section transitions to the next based on game events.

### Implementation in Web Audio

**Vertical Layering:**
```javascript
// Load multiple stems as synchronized AudioBufferSourceNodes
const stems = { drums: null, bass: null, melody: null, pads: null };
const gains = {};

Object.keys(stems).forEach(key => {
  const source = ctx.createBufferSource();
  source.buffer = stems[key];
  const gain = ctx.createGain();
  gain.gain.value = key === 'drums' ? 1 : 0; // Start with just drums
  source.connect(gain);
  gain.connect(masterGain);
  gains[key] = gain;
  source.start(startTime); // All start at exact same time
});

// Fade in melody when intensity increases
function setIntensity(level) {
  const t = ctx.currentTime;
  gains.melody.gain.setTargetAtTime(level > 0.5 ? 1 : 0, t, 0.5);
  gains.pads.gain.setTargetAtTime(level > 0.3 ? 0.6 : 0, t, 0.8);
}
```

**Beat-Synchronized Transitions (for Horizontal Re-sequencing):**
```javascript
const tempo = bpm / 60; // beats per second
const beatDuration = 1 / tempo;
const barDuration = beatDuration * 4;

function getNextBarBoundary() {
  const elapsed = ctx.currentTime - musicStartTime;
  const barsElapsed = Math.floor(elapsed / barDuration);
  return musicStartTime + (barsElapsed + 1) * barDuration;
}

function transitionToSection(newBuffer) {
  const transitionTime = getNextBarBoundary();
  currentSource.stop(transitionTime);
  const newSource = ctx.createBufferSource();
  newSource.buffer = newBuffer;
  newSource.connect(masterGain);
  newSource.start(transitionTime);
}
```

**CPU-friendly two-layer approach:** Keep only two active layers (main + blend), crossfading between them. This halves CPU vs. maintaining 4+ simultaneous stems.

### Stinger System

Short musical phrases triggered by game events (victory, defeat, item pickup) that overlay the background music. Substrate already implements this in `Engine.prototype.stinger()`.

Source: [Dynamic Music in Games using WebAudio](https://cschnack.de/blog/2020/webaudio/), [Game Audio Co - Vertical vs Horizontal](https://www.thegameaudioco.com/making-your-game-s-music-more-dynamic-vertical-layering-vs-horizontal-resequencing), [MDN - Audio for Web Games](https://developer.mozilla.org/en-US/docs/Games/Techniques/Audio_for_Web_Games)

### How Substrate Could Implement Adaptive Music

The pattern sequencer already has the infrastructure for horizontal re-sequencing. The `seq` array in each song defines pattern order. To make it adaptive:

1. Instead of linearly advancing through `seq`, maintain multiple sequence paths (e.g., `seqCalm`, `seqIntense`, `seqBoss`)
2. At pattern boundaries, choose the next pattern based on game state
3. For vertical layering, split existing songs into two layers: rhythm (channels 0-3) and melody (channels 4-7), with independent gain controls

---

## 9. Common Web Audio Pitfalls

### Memory Leaks

**AudioWorkletNode continues processing after disconnect.** When disconnected from the graph, `process()` keeps being called. The `active source` flag (initially `true`) keeps the node alive. To stop processing, `process()` must return `false`.

Source: [WebAudio Issue #2658](https://github.com/WebAudio/web-audio-api/issues/2658)

**AudioBufferSourceNode is fire-and-forget** -- they are automatically garbage collected after playback ends. Do NOT hold references unnecessarily. Substrate's `_note()` correctly holds only the latest source per channel.

**AudioContext.close() does not always free all memory.** Some browsers retain internal buffers. If you need to completely reset, there is no reliable way to fully reclaim memory without a page reload.

Source: [WebAudio Issue #904](https://github.com/WebAudio/web-audio-api/issues/904), [WebAudio Issue #2484](https://github.com/WebAudio/web-audio-api/issues/2484)

### Click and Pop Artifacts

**Root cause:** Stopping or starting audio at a non-zero-crossing creates a discontinuity that the ear hears as a click.

**Prevention methods, ranked by reliability:**

1. **`setTargetAtTime()`** (Best) -- Exponentially approaches zero with a time constant. Can reach actual zero. Substrate should use this:
   ```javascript
   gain.gain.setTargetAtTime(0, ctx.currentTime, 0.015); // 15ms decay
   ```

2. **`exponentialRampToValueAtTime()`** -- Reaches target at precise time. Cannot ramp to exactly 0 (use 0.0001):
   ```javascript
   gain.gain.setValueAtTime(gain.gain.value, ctx.currentTime);
   gain.gain.exponentialRampToValueAtTime(0.0001, ctx.currentTime + 0.03);
   ```

3. **`linearRampToValueAtTime()`** -- Works but sounds less natural because human hearing is logarithmic. Substrate currently uses this in `_note()` for ADSR envelopes.

**Substrate-specific issue:** The engine uses `linearRampToValueAtTime` for all ADSR envelope stages. For the release stage (fade-out to silence), switching to `exponentialRampToValueAtTime` or `setTargetAtTime` would sound more natural and reduce click risk.

Source: [Web Audio: The Ugly Click](http://alemangui.github.io/ramp-to-value)

### Gain Staging

**Problem:** When multiple sounds play simultaneously, their amplitudes sum and can exceed 1.0, causing digital clipping.

**Solution 1: DynamicsCompressorNode as limiter**
```javascript
const compressor = ctx.createDynamicsCompressor();
compressor.threshold.value = -6;  // Start compressing at -6dB
compressor.knee.value = 3;        // Soft knee
compressor.ratio.value = 20;      // High ratio = limiter behavior
compressor.attack.value = 0.001;  // Fast attack
compressor.release.value = 0.1;   // Moderate release
compressor.connect(ctx.destination);
```

**Note:** DynamicsCompressorNode has a fixed 6ms look-ahead. It cannot prevent the very first transient from clipping, but catches everything after.

**Solution 2: Master gain headroom**
Set master gain to account for worst-case simultaneous sounds. With 8 channels, a conservative master gain of 0.15-0.2 prevents most clipping.

**Substrate status:** The master gain is set to `0.6` and individual note volumes are `(vol/100) * 0.5`, with vol values typically 20-60. With 8 simultaneous channels at maximum, total output could reach ~2.4 (clipping). Adding a DynamicsCompressorNode before the destination would prevent this.

Source: [web.dev - Game Audio](https://web.dev/webaudio-games/), [MDN DynamicsCompressorNode](https://developer.mozilla.org/en-US/docs/Web/API/DynamicsCompressorNode)

### Sample Rate Mismatches

**Problem:** `decodeAudioData()` automatically resamples to the AudioContext's sample rate. Different browsers use different resampling algorithms:
- Gecko: High-quality (expensive, with latency)
- Blink/WebKit: Linear interpolation (cheap, lower quality)

**Substrate's situation:** The engine creates AudioContext at 44100Hz (`{sampleRate: 44100}`) but generates samples at `SR = 32000`. The samples are loaded via `createBuffer(1, raw.length, SR)` -- this creates buffers at 32000Hz which the engine then resamples to 44100Hz during playback. This works but means every note triggers runtime resampling.

**Fix:** Generate samples at 44100Hz (match the AudioContext sample rate) to eliminate runtime resampling:
```javascript
var SR = 44100, SL = 512; // Match AudioContext sample rate
```

Or pre-resample buffers using OfflineAudioContext at init time.

Source: [WebAudio Issue #30](https://github.com/WebAudio/web-audio-api/issues/30)

### AudioParam Event Scheduling

**Non-Gecko browsers** (Chrome, Safari, Edge) do linear scans through the event list for each render quantum. If you schedule hundreds of events on a single AudioParam without clearing them, performance degrades over time.

**Mitigation:** Create and swap nodes to reset event lists when accumulated events exceed ~100. Or cancel scheduled values before scheduling new ones: `param.cancelScheduledValues(time)`.

Source: [Web Audio Performance Notes](https://padenot.github.io/web-audio-perf/)

### Thread Blocking

Never perform DOM manipulation or `requestAnimationFrame` work inside Transport/scheduling callbacks. These run on a WebWorker timer, not synced to animation frames. Use a scheduling pattern like Tone.js's `Tone.Draw.schedule()` to coordinate visual updates with audio timing.

Source: [Tone.js Performance Wiki](https://github.com/Tonejs/Tone.js/wiki/Performance)

---

## 10. Accessibility

### WCAG Requirements

**WCAG 1.4.2 (Level A) - Audio Control:** If audio plays for more than 3 seconds, provide a mechanism to pause/stop it or control volume independently of system volume.

Substrate complies: both `snes-audio.js` and `substrate-audio.js` have toggle controls and volume management. Audio is off by default in `substrate-audio.js`.

### Best Practices for Game Audio Accessibility

1. **Separate volume controls** for music, SFX, and voice (if applicable). Substrate has master volume but no per-category separation.

2. **Auto-lower game audio** when assistive technology (screen reader) is detected active.

3. **Visual alternatives:** Provide visual feedback for all audio cues (enemy approaching, item collected, timer running out). Never rely solely on audio for gameplay-critical information.

4. **Control placement:** Put audio controls near the top of source order so screen reader users encounter them early. Use proper `<label>` elements and `aria-label` attributes.

5. **Mute memory:** Persist mute/volume state across sessions (Substrate already does this via localStorage).

6. **Keyboard accessible:** Ensure all audio controls are reachable and operable via keyboard.

Source: [WCAG Audio Control](https://www.w3.org/WAI/WCAG21/Understanding/audio-control.html), [Xbox Accessibility Guideline 105](https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/105), [Game Accessibility Guidelines](https://gameaccessibilityguidelines.com/full-list/)

---

## 11. Substrate-Specific Recommendations

Based on reviewing `snes-audio.js` and `substrate-audio.js` against all research findings, here are prioritized, actionable recommendations:

### Critical (Should Fix)

1. **Add a DynamicsCompressorNode (limiter) before destination.**
   The signal chain ends with `this._mg.connect(c.destination)`. Insert a compressor/limiter between master gain and destination to prevent clipping when all 8 channels are active:
   ```javascript
   this._lim = c.createDynamicsCompressor();
   this._lim.threshold.value = -3;
   this._lim.ratio.value = 20;
   this._lim.attack.value = 0.001;
   this._lim.release.value = 0.05;
   this._mg.connect(this._lim);
   this._lim.connect(c.destination);
   ```

2. **Fix sample rate mismatch.** Samples are generated at `SR=32000` but AudioContext runs at 44100Hz. Every note triggers resampling. Change `SR` to 44100 or to match `this._ctx.sampleRate`.

3. **Add iOS ringer switch workaround.** Play a silent audio element on first user interaction to ensure Web Audio works even when the iOS mute switch is on. Consider bundling the technique from `unmute-ios-audio`.

4. **Suspend AudioContext when not playing.** The `_suspend()` method exists but is only called in `stop()`. Also suspend when tab goes to background and when the game is paused. This saves battery on mobile.

### High Priority (Should Improve)

5. **Switch release envelopes from linear to exponential.** In `_note()`, the release stage uses `linearRampToValueAtTime(0.001, ...)`. Use `exponentialRampToValueAtTime(0.001, ...)` instead for more natural fade-outs and fewer click artifacts.

6. **Share AudioContext between snes-audio.js and substrate-audio.js.** If both scripts are loaded on the same page (e.g., a game page), they each create their own AudioContext. Safari's 4-context limit could cause failures. Expose the context or use a shared singleton.

7. **Add Page Visibility handling.**
   ```javascript
   document.addEventListener('visibilitychange', function() {
     if (document.hidden && self._on) self.pause();
     else if (!document.hidden && self._paused) self.resume();
   });
   ```

8. **Pre-render complex sounds with OfflineAudioContext.** The stinger effects and potentially the more complex FM patches could be pre-rendered to buffers at init time, reducing per-trigger CPU cost.

### Medium Priority (Nice to Have)

9. **Add per-category volume controls.** Separate music and SFX volumes for accessibility. The engine could expose `setMusicVolume()` and `setSFXVolume()` methods.

10. **Implement vertical layering for adaptive music.** Split the 8 channels into two groups (rhythm: 0-3, melody: 4-7) with independent gain control. Fade melody in/out based on game intensity without changing songs.

11. **Richer FM patches.** Generate longer waveforms (2048+ samples) with time-varying modulation indices to capture the characteristic evolving timbres of real FM synthesis. The current static single-cycle approach sounds flat compared to a real Genesis.

12. **Use `setTargetAtTime` for all gain transitions** (chip-switch, song transitions, volume changes) instead of directly setting `.value`. This prevents click artifacts during any parameter change.

13. **Add AudioContext interrupted state handling** (when it ships):
    ```javascript
    this._ctx.addEventListener('statechange', function() {
      if (self._ctx.state === 'interrupted') {
        // Show "audio interrupted" UI
      } else if (self._ctx.state === 'running') {
        // Resume normal operation
      }
    });
    ```

### Low Priority (Future Enhancements)

14. **Consider Karplus-Strong for string/pluck sounds.** The `str` and `pno` samples use harmonic series synthesis. Karplus-Strong (white noise burst + filtered delay line) produces more realistic plucked strings with minimal CPU.

15. **Investigate AudioWorklet for the sequencer.** Moving the step sequencer to an AudioWorklet would provide sample-accurate timing independent of main thread jitter. Currently the scheduler uses `setInterval` with 25ms granularity and lookahead buffer.

16. **Add beat-synchronized crossfading** for song transitions. When switching songs, wait for the next bar boundary and crossfade over one bar duration.

17. **Consider chiptune3.js integration** as an optional playback path for games that want authentic tracker module playback alongside the procedural engine.

### Library Comparison Reference

| Library | Size | Best For | Notes |
|---------|------|----------|-------|
| Howler.js | 7KB | General game audio, sprites | HTML5 fallback, no synthesis |
| Tone.js | 150KB+ | Music creation, synths, scheduling | Full DAW-like capability |
| Pizzicato.js | Small | Simple effects on audio | Not suited for complex games |
| standardized-audio-context | Varies | Cross-browser compatibility layer | Fills spec gaps |
| chiptune3.js | ~200KB (WASM) | Tracker module playback | Authentic retro sound |
| Substrate snes-audio.js | ~40KB | Custom procedural game music | Zero dependencies, unique identity |

Substrate's custom engine is the right choice for its aesthetic and philosophy. The recommendations above enhance it without abandoning the zero-dependency approach.

---

## Sources

### Web Audio API & Standards
- [W3C TPAC 2025 Audio WG Update](https://www.w3.org/2025/11/TPAC/demo-audio-wg-update.html)
- [MDN Web Audio API](https://developer.mozilla.org/en-US/docs/Web/API/Web_Audio_API)
- [MDN Web Audio API Best Practices](https://developer.mozilla.org/en-US/docs/Web/API/Web_Audio_API/Best_practices)
- [MDN AudioWorklet](https://developer.mozilla.org/en-US/docs/Web/API/AudioWorklet)
- [Chrome AudioWorklet Blog](https://developer.chrome.com/blog/audio-worklet)
- [AudioContext Interrupted State - Chrome Status](https://chromestatus.com/feature/5172068166139904)
- [AudioContext Interrupted State - MSEdge Explainer](https://microsoftedge.github.io/MSEdgeExplainers/AudioContextInterruptedState/explainer.html)
- [standardized-audio-context](https://github.com/chrisguttandin/standardized-audio-context)

### Performance & Debugging
- [Web Audio API Performance and Debugging Notes (Paul Adenot)](https://padenot.github.io/web-audio-perf/)
- [Tone.js Performance Wiki](https://github.com/Tonejs/Tone.js/wiki/Performance)
- [web.dev - Developing Game Audio](https://web.dev/webaudio-games/)

### Mobile & Browser Compatibility
- [MDN Autoplay Guide](https://developer.mozilla.org/en-US/docs/Web/Media/Guides/Autoplay)
- [Matt Montag - Unlock Web Audio in Safari](https://www.mattmontag.com/web/unlock-web-audio-in-safari-for-ios-and-macos)
- [unmute-ios-audio (Feross)](https://github.com/feross/unmute-ios-audio)
- [WebKit Bug #237322 - Web Audio muted when ringer muted](https://bugs.webkit.org/show_bug.cgi?id=237322)
- [MDN Audio for Web Games](https://developer.mozilla.org/en-US/docs/Games/Techniques/Audio_for_Web_Games)

### Synthesis & Sound Design
- [FM Synthesis with Web Audio API (greweb)](https://greweb.me/2013/08/FM-audio-api)
- [FM Synth in Rust/WASM/SIMD (Casey Primozic)](https://cprimozic.net/blog/fm-synth-rust-wasm-simd/)
- [Granular Synthesis in Browser (DEV Community)](https://dev.to/hexshift/granular-synthesis-in-the-browser-using-web-audio-api-and-audiobuffer-slicing-2o9h)
- [ZYA Granular Synthesiser](https://zya.github.io/granular/)
- [Web Audio: The Ugly Click (alemangui)](http://alemangui.github.io/ramp-to-value)

### Chiptune & Retro
- [chiptune3.js (DrSnuggles)](https://github.com/DrSnuggles/chiptune)
- [chiptune2.js (deskjet)](https://github.com/deskjet/chiptune2.js/)
- [Chip Player JS](https://chiptune.app/)

### Dynamic Music
- [Dynamic Music in Games using WebAudio (cschnack)](https://cschnack.de/blog/2020/webaudio/)
- [Vertical Layering vs Horizontal Resequencing (Game Audio Co)](https://www.thegameaudioco.com/making-your-game-s-music-more-dynamic-vertical-layering-vs-horizontal-resequencing)
- [Procedural Music Generation for Games (wybiral)](https://github.com/wybiral/music)

### Spatial Audio
- [MDN Web Audio Spatialization Basics](https://developer.mozilla.org/en-US/docs/Web/API/Web_Audio_API/Web_audio_spatialization_basics)

### Audio Formats
- [Can I Use - Opus](https://caniuse.com/opus)
- [MDN Web Audio Codec Guide](https://developer.mozilla.org/en-US/docs/Web/Media/Guides/Formats/Audio_codecs)

### Accessibility
- [WCAG 1.4.2 Audio Control](https://www.w3.org/WAI/WCAG21/Understanding/audio-control.html)
- [Xbox Accessibility Guideline 105](https://learn.microsoft.com/en-us/gaming/accessibility/xbox-accessibility-guidelines/105)
- [Game Accessibility Guidelines](https://gameaccessibilityguidelines.com/full-list/)

### Memory & Node Lifecycle
- [WebAudio Issue #2658 - AudioWorkletNode continues after disconnect](https://github.com/WebAudio/web-audio-api/issues/2658)
- [WebAudio Issue #904 - disconnect doesn't free memory](https://github.com/WebAudio/web-audio-api/issues/904)
- [WebAudio Issue #2484 - MediaStreamAudioSourceNode memory leak](https://github.com/WebAudio/web-audio-api/issues/2484)
- [WebAudio Issue #2632 - AudioWorklet real world issues](https://github.com/WebAudio/web-audio-api/issues/2632)

### WebAssembly + Audio
- [Emscripten Wasm Audio Worklets API](https://emscripten.org/docs/api_reference/wasm_audio_worklets.html)
- [Web Audio + WebAssembly Lessons Learned (Daniel Barta)](https://danielbarta.com/web-audio-web-assembly/)
- [Chrome Audio Worklet Design Patterns](https://developer.chrome.com/blog/audio-worklet-design-pattern)

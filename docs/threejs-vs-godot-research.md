# Research: Three.js vs Godot 4 for Desktop 3D Visualizer

**Date:** 2026-03-19
**Verdict:** Stay on Godot. No migration.

## Context

The Desktop 3D system runs on Godot 4.6.1 Forward+ (Vulkan) with 45 shader scenes, 30Hz audio reactivity via UDP, and X11 window management as a live wallpaper. The question: would Three.js be smoother, allow more comprehensive scenes, and be worth migrating to?

## Performance Comparison

| Metric | Godot 4 (Vulkan) | Three.js (WebGL) | Three.js (WebGPU) |
|--------|-------------------|------------------|-------------------|
| **GPU access** | Native Vulkan — zero overhead | Browser WebGL — 10-30% overhead | Browser WebGPU — 5-15% overhead |
| **Compute shaders** | Yes, native `.glsl` | No (WebGL limitation) | Yes, but async init required |
| **Particle ceiling** | Millions (GPU compute) | ~50K (CPU-bound) | Millions (compute shaders) |
| **Shader compilation** | Vulkan SPIR-V (fast, cached) | Browser JIT (slower, per-session) | Browser JIT (faster than WebGL) |
| **Audio latency** | UDP daemon: ~33ms | Web Audio API: ~50-100ms | Web Audio API: ~50-100ms |
| **Startup** | ~2-3 seconds native | Electron: 3-8s, Tauri: 1-3s | Same as WebGL row |
| **Frame feedback** | SubViewport + FBO (native) | Ping-pong FBO (same tech, +overhead) | Same, slightly faster |

Native Vulkan is 2-5x faster than WebGPU, which is 2-3x faster than WebGL.

## What Three.js Would Gain

1. **Butterchurn ecosystem** — mature MilkDrop WebGL port. But we can implement the same ping-pong FBO + warp/composite architecture in Godot.
2. **TSL (Three Shader Language)** — write-once for WebGPU/WebGL. Irrelevant for desktop-only.
3. **npm ecosystem** — React Three Fiber, Codrops tutorials. Rich web community.
4. **Cross-platform web** — runs in any browser. But we're a NixOS live wallpaper.

## What Three.js Would Lose

1. Native Vulkan performance — measurable regression through browser
2. 7 procedural 3D geometry scenes (~1,400 lines). Full rewrite needed.
3. X11 window management — Godot handles `_NET_WM_STATE_BELOW` natively. Tauri Linux desktop underlay untested.
4. GPU particles — Godot's `GPUParticles3D` is production-ready.
5. ProceduralSkyMaterial — built-in.

## Migration Cost

~8,000 lines, ~240 hours, 6-10 weeks. 65% is Godot-specific (scene geometry, materials, window management, rendering loop). Shaders are 95% portable GLSL — they'd move in a day.

## Butterchurn Techniques Adopted

Instead of migrating, we adopted Butterchurn's best rendering techniques natively in Godot:

1. **Ping-pong framebuffers** — SubViewport self-referencing (Godot double-buffers internally). Beat-seeded content gets warped frame-over-frame.
2. **Warp mesh simulation** — Per-pixel spatially-varying warp functions simulate Butterchurn's 32x24 vertex grid. Center rotates more, edges less. Audio drives per-pixel displacement.
3. **Multi-resolution bloom** — Godot's built-in multi-level glow, dynamically modulated by audio. Beat kick → intensity spike, bass → bloom spread, treble → threshold shift.
4. **Audio normalization** — Per-band rolling-max with attack/decay envelopes (already implemented).

## Sources

- Three.js 100 Performance Tips 2026 (utsubo.com)
- WebGL vs WebGPU Explained — Three.js Roadmap
- Butterchurn MilkDrop WebGL (GitHub: jberg/butterchurn)
- Butterchurn Architecture (DeepWiki)
- IEEE: WebGPU vs WebGL in Godot (2024)
- Tauri Desktop Underlay Plugin (GitHub)
- Godot GLSL Conversion Docs
- Aircada: Three.js vs Godot Comparison

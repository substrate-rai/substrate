# Desktop 3D — Setup & Continuation Guide for Claude Code

This is everything a fresh Claude Code instance needs to set up, run, modify, and extend the Desktop 3D shader art system.

## Quick Context
- Live 3D desktop wallpaper built in Godot 4.6 (Vulkan Forward+)
- 56 scenes: 11 hand-built 3D environments + 45 procedural shader art scenes
- Controlled via TCP JSON on localhost:9877
- Audio-reactive via PipeWire capture → UDP → Godot shader globals
- All code lives in `scripts/desktop-3d-godot/`

## Step 1: Read These Files First

```
memory/desktop-3d.md              — scene inventory, shader rules, architecture, setup guide
CLAUDE.md                         — project identity, conventions, autonomy rules
.claude/rules/assets-art.md       — art direction (mycopunk, 90s anime, color palette)
```

## Step 2: Understand the Codebase

**Key files:**
```
scripts/desktop-3d-godot/main.gd           — THE main file. 6000+ lines. TCP server, scene loading, audio processing.
scripts/desktop-3d-godot/shaders/*.gdshader — all shader art scenes (one file per scene)
scripts/desktop-3d-godot/project.godot      — Godot project config, shader global uniform declarations
nix/desktop-3d-godot.nix                    — NixOS systemd service definitions
scripts/sensors/substrate_sensors.py        — audio capture + system metrics daemon
scripts/desktop-3d.sh                       — CLI client for sending commands
scripts/desktop-3d-web.py                   — web control panel on port 9880
```

**Important locations in main.gd:**
- ~line 177-178: `ART_SCENES` and `ALL_SCENES` arrays (add new scene names here)
- ~line 930-970: Scene handler switch/match (add new handler entries here, before `"postfx"`)
- ~line 48-82: Audio uniform variables
- ~line 227-355: UDP sensor packet processing + audio smoothing

## Step 3: How to Add a New Shader Scene

1. **Create the shader file:** `scripts/desktop-3d-godot/shaders/your_scene.gdshader`

```glsl
shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

global uniform float audio_bass;
global uniform float audio_mid;
global uniform float audio_treble;
global uniform float audio_energy;
global uniform float beat_intensity;
global uniform vec3 cursor_world_pos;

void fragment() {
    vec2 uv = UV * 2.0 - 1.0;
    float t = TIME;
    vec3 col = vec3(0.02, 0.01, 0.05);

    // Your shader math here — use TIME for animation
    // Use audio_* only for color/glow/brightness, NEVER for position/scale/zoom

    // Vignette
    float vig = 1.0 - dot(uv, uv) * 0.3;
    col *= vig;

    // Tone mapping
    col = col / (col + vec3(1.0));

    ALBEDO = col;
}
```

2. **Register in main.gd** — find the last art scene handler (before `"postfx":`) and add:

```gdscript
"your_scene":
    apply_dark_environment()
    create_shader_scene("res://shaders/your_scene.gdshader", params)
    return {"status": "ok", "message": "Your scene loaded"}
```

3. **Add to arrays** (~line 177-178) — append `"your_scene"` to both `ART_SCENES` and `ALL_SCENES`

4. **Restart and test:**
```bash
systemctl --user restart substrate-desktop-3d-godot.service
sleep 3
echo '{"type":"your_scene","params":{}}' | nc -w 2 127.0.0.1 9877
journalctl --user -u substrate-desktop-3d-godot.service --since "30 seconds ago" | grep -i error
```

## Step 4: Shader Quality Rules (DO NOT SKIP)

These were learned the hard way. Violating them produces visible artifacts.

### Rule 1: No audio on geometry transforms
Audio values jump frame-to-frame. Multiplying them into scale/zoom/rotation causes jitter.

**BAD:**
```glsl
float breath = 1.0 + audio_bass * 0.08;
vec2 p = uv / breath;
float zoom = 2.8 - audio_bass * 0.3;
vec2 p = rot2(uv, TIME * 0.05 + audio_mid * 0.02);
```

**GOOD:**
```glsl
vec2 p = uv * 1.5;                              // static scale
p = rot2(p, TIME * 0.05);                       // time-only rotation
col += GOLD * glow * (0.3 + audio_energy * 0.5); // audio on brightness only
col += WHITE * beat_intensity * 0.1;             // audio on color flash
```

### Rule 2: Minimum AA width
Dense geometry at center makes fwidth() return near-zero → grain. Always floor it:

```glsl
float fw = max(fwidth(d), 0.003);
return smoothstep(width + fw, max(width - fw, 0.0), d);
```

### Rule 3: Linear glow falloff
```glsl
// BAD — squared distance creates sub-pixel spikes
float glow = exp(-d * d * 2000.0);

// GOOD — linear distance, smooth falloff
float glow = exp(-d * 60.0);
```

### Rule 4: Iteration budgets
Escape-time fractals (Mandelbrot, Burning Ship, Newton): max 80 iterations. 256 is too slow.

### Rule 5: DO NOT redefine PI or TAU
They're Godot built-ins. Redefining them causes a compile error. `PHI` is fine to define.

## Step 5: Available Audio Uniforms

All floats, range 0.0–1.0, smoothed per-frame:
```
audio_bass          — 20-300 Hz
audio_mid           — 300-4000 Hz
audio_treble        — 4000-11000 Hz
audio_energy        — average of bass+mid+treble
beat_intensity      — onset detection (spikes on beats)
audio_sub_bass      — 20-60 Hz
audio_presence      — 4-6 kHz
audio_brilliance    — 6-11 kHz
beat_kick           — kick drum detection
beat_snare          — snare detection
beat_hihat          — hihat detection
audio_warmth        — bass+low_mid composite
audio_brightness    — treble+brilliance composite
audio_flux          — spectral change rate
cursor_world_pos    — vec3, mouse position in world space
```

Without the sensor daemon running, all default to 0.0. Scenes still work.

## Step 6: Common Operations

```bash
# Load a scene
echo '{"type":"metatron","params":{}}' | nc -w 2 127.0.0.1 9877

# Apply post-FX (kuwahara = painterly look)
echo '{"type":"postfx","params":{"effect":"kuwahara"}}' | nc -w 2 127.0.0.1 9877

# Check status
echo '{"type":"status","params":{}}' | nc -w 2 127.0.0.1 9877

# Restart after shader changes
systemctl --user restart substrate-desktop-3d-godot.service

# Check for compile errors
journalctl --user -u substrate-desktop-3d-godot.service --since "30 seconds ago" | grep -i error

# CLI client (alternative to raw nc)
scripts/desktop-3d.sh metatron
scripts/desktop-3d.sh postfx --effect kuwahara
```

## Step 7: Commit Convention

```
desktop-3d: short description in imperative mood
```

Examples:
- `desktop-3d: add sacred geometry shader scene`
- `desktop-3d: fix grainy center on geometry shaders`
- `desktop-3d: reduce iteration count for burning ship fractal`

## Current Scene Inventory (2026-03-20)

**Sacred Geometry / Visionary:**
sacred_geometry, visionary, mandala, metatron

**Fractals:**
fractal (Mandelbulb 3D), julia, menger, burning_ship, newton, sierpinski, apollonian

**Nature / Space:**
aurora, mycelium, nebula, galaxy, starfield, lava, lightning, blackhole, supernova, ocean, cloudscape

**Abstract / Generative:**
attractor, physarum, plasma, kaleidoscope, domain_warp, fluid, fire, metaballs, reaction_diffusion

**Retro / Aesthetic:**
matrix_rain, vaporwave, synthgrid, waveform, tunnel, castlevania, mgs, neon_city_pixel, sdf_world

**Interactive:**
visualizer, lsystem, vine_garden, victory, aquarium

**Full 3D Environments:**
full_scene, abyss_scene, crystal_cave, neon_city, volcanic, zen_garden, fairy_garden, haunted_graveyard, space_outpost, autumn_campsite, abandoned_station

## Fresh Machine Install

See `memory/desktop-3d.md` → "Setup on a Fresh Machine" section for full NixOS/Gentoo/Ubuntu bootstrap instructions.

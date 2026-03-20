# Desktop 3D — Shader Art System

Last updated: 2026-03-20

## What It Is
Live 3D desktop wallpaper — Godot 4.6 Forward+ (Vulkan), controlled via TCP on port 9877.
- **Godot project:** `scripts/desktop-3d-godot/`
- **Shaders:** `scripts/desktop-3d-godot/shaders/`
- **Main script:** `scripts/desktop-3d-godot/main.gd`
- **Service:** `systemctl --user restart substrate-desktop-3d-godot.service`
- **Test:** `echo '{"type":"scene_name","params":{}}' | nc -w 2 127.0.0.1 9877`
- **Errors:** `journalctl --user -u substrate-desktop-3d-godot.service --since "30 seconds ago" | grep -i error`

## Scene Count: 56 total
- 11 full 3D scenes (REACTIVE_SCENES + hand-built environments)
- 45 shader art scenes (ART_SCENES array in main.gd ~line 177)

### Sacred Geometry / Visionary (2026-03-20)
- `sacred_geometry` — Flower of Life, Metatron's Cube, Sri Yantra, Seed of Life, golden spiral, emanation rings
- `visionary` — Alex Grey: Net of Being tiling, third eye burst, chakra gradient
- `mandala` — 12-fold polar symmetry, golden-ratio nested geometry, Fibonacci spirals
- `metatron` — Standalone Metatron's Cube: 13 circles, 78 lines, Seed of Life, 3D cube projection

### Fractals (2026-03-20)
- `burning_ship` — abs() Mandelbrot variant, fire/abyss palette
- `newton` — Root-finding z^n-1=0, degree cycles 3-7
- `sierpinski` — Domain-folding triangle + carpet + Koch edges
- `apollonian` — Circle inversion gasket, recursive packing

### Existing (pre 2026-03-20)
fractal (Mandelbulb), julia, menger, aurora, matrix_rain, mycelium, attractor, galaxy, visualizer, lsystem, vine_garden, fluid, fire, victory, vaporwave, domain_warp, ocean, cloudscape, physarum, plasma, kaleidoscope, tunnel, starfield, lava, nebula, lightning, blackhole, metaballs, supernova, synthgrid, waveform, castlevania, mgs, aquarium, neon_city_pixel, sdf_world, reaction_diffusion

## How to Add a New Shader Scene

1. Create `scripts/desktop-3d-godot/shaders/your_scene.gdshader`
2. Header:
   ```glsl
   shader_type spatial;
   render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;
   ```
3. Global uniforms (pick what you need):
   ```glsl
   global uniform float audio_bass;
   global uniform float audio_mid;
   global uniform float audio_treble;
   global uniform float audio_energy;
   global uniform float beat_intensity;
   global uniform vec3 cursor_world_pos;
   ```
4. **DO NOT redefine PI or TAU** — they're Godot built-ins. PHI is fine.
5. Register in `main.gd`:
   - Add handler entry before `"postfx"` block:
     ```gdscript
     "your_scene":
         apply_dark_environment()
         create_shader_scene("res://shaders/your_scene.gdshader", params)
         return {"status": "ok", "message": "Your scene loaded"}
     ```
   - Add `"your_scene"` to both `ART_SCENES` and `ALL_SCENES` arrays (~line 177-178)
6. Restart service, test, check journal for errors

## Shader Quality Rules (IMPORTANT)

### No audio on geometry transforms
Audio values (bass, mid, beat) jump frame-to-frame. If you multiply them into scale, zoom, rotation, or position, the scene jitters. **Only use audio for color, glow, brightness** — never for coordinate transforms.

Bad: `float breath = 1.0 + bass * 0.08; p /= breath;`
Bad: `float zoom = 2.8 - bass * 0.3;`
Good: `col += GOLD * glow * (0.3 + energy * 0.5);`

### Minimum AA width
Dense geometry converges at center, making fwidth() return near-zero. Enforce a floor:
```glsl
float fw = max(fwidth(d), 0.003);
return smoothstep(width + fw, max(width - fw, 0.0), d);
```

### Linear glow falloff
Use `exp(-d * 60.0)` not `exp(-d*d*2000.0)`. Squared-distance creates sub-pixel spikes that alias into grain.

### Iteration budgets
Escape-time fractals: ≤80 max iterations for realtime. 256 is too heavy.

## Next Directions
- More fractals: Mandelbrot deep zoom, dragon curve, Barnsley fern
- More sacred geometry: Vesica Piscis, Torus, Platonic solids standalone
- Cursor interactivity via cursor_world_pos
- Scene transition dissolves between shaders

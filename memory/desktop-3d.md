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

## Scene Count: 120+ total (64 pioneering math shaders + 56 original)
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

## Setup on a Fresh Machine

### Requirements
- **GPU:** Any modern GPU with Vulkan support (doesn't need to be NVIDIA)
- **OS:** Linux with X11 (KDE Plasma tested). Wayland untested.
- **Godot 4.6** with Forward+ renderer
- **PipeWire** for audio capture (audio reactivity is optional — scenes animate fine without it)

### System Dependencies

**NixOS** — the module at `nix/desktop-3d-godot.nix` handles everything via `nixos-rebuild switch`.

**Gentoo:**
```bash
# Godot 4.6 — not in main portage tree, use flatpak or build from source
flatpak install flathub org.godotengine.Godot
# OR build from source (needs scons, vulkan headers):
# git clone https://github.com/godotengine/godot.git -b 4.6-stable
# cd godot && scons platform=linuxbsd vulkan=yes production=yes

# Audio capture
emerge --ask media-video/pipewire  # includes pw-cat
# Ensure PipeWire is running (not PulseAudio):
# systemctl --user enable --now pipewire pipewire-pulse wireplumber

# Python
emerge --ask dev-python/requests

# X11 tools
emerge --ask x11-apps/xprop x11-misc/xdotool

# Vulkan drivers (pick your GPU)
emerge --ask media-libs/vulkan-loader dev-util/vulkan-tools
# NVIDIA: emerge --ask x11-drivers/nvidia-drivers (with vulkan USE flag)
# AMD: emerge --ask media-libs/mesa (with vulkan USE flag)
# Intel: emerge --ask media-libs/mesa (with vulkan USE flag)

# Optional: GPU metrics
# NVIDIA: nvidia-smi comes with nvidia-drivers
# AMD: emerge --ask dev-util/radeontop
```

**Other distros** — you need these packages by whatever name:
- `godot4` (Godot 4.6+)
- `python3` + `requests`
- `pipewire` + `pw-cat` (for audio capture)
- `xprop`, `xdotool` (X11 window management)
- Vulkan drivers for your GPU

### Architecture Overview

```
┌─────────────┐  UDP 30Hz  ┌──────────────┐  TCP 9877  ┌──────────────┐
│  pw-cat     │──────────>│  Godot 4.6   │<───────────│  CLI/Web     │
│  (audio)    │  :9778    │  (renderer)  │            │  (control)   │
├─────────────┤           ├──────────────┤            ├──────────────┤
│  sensors.py │──────────>│  main.gd     │            │ desktop-3d.sh│
│  (metrics)  │  UDP 1Hz  │  (56 scenes) │            │ web.py :9880 │
└─────────────┘           └──────────────┘            └──────────────┘
```

Three services work together:
1. **Godot renderer** — runs the 3D scenes, listens TCP :9877 for commands, UDP :9778 for sensor data
2. **Sensor daemon** (`scripts/sensors/substrate_sensors.py`) — captures audio via PipeWire `pw-cat`, reads system metrics, sends UDP packets
3. **Web panel** (`scripts/desktop-3d-web.py`) — HTTP control panel on :9880, proxies to Godot TCP

### Bootstrap Steps

```bash
# 1. Clone the repo
git clone git@github.com:substrate-rai/substrate.git
cd substrate

# 2. NixOS: apply config (creates all 3 systemd user services)
sudo nixos-rebuild switch --flake .#substrate

# 3. Non-NixOS: run Godot manually
godot4 --path scripts/desktop-3d-godot/ --rendering-driver vulkan

# 4. Start services
systemctl --user start substrate-desktop-3d-godot.service
systemctl --user start substrate-3d-sensors.service   # audio + metrics
systemctl --user start substrate-3d-web.service        # web panel

# 5. Test
echo '{"type":"status","params":{}}' | nc -w 2 127.0.0.1 9877
echo '{"type":"metatron","params":{}}' | nc -w 2 127.0.0.1 9877
scripts/desktop-3d.sh sacred_geometry

# 6. Web panel
open http://localhost:9880

# 7. Check logs
journalctl --user -u substrate-desktop-3d-godot.service -f
```

### Audio Pipeline (optional)
Without the sensor daemon, all audio uniforms default to 0.0 and scenes still animate fine — just no audio reactivity. To enable audio:

1. The sensor daemon captures system audio via `pw-cat --record` from PipeWire's default sink monitor
2. Runs FFT at 22050 Hz, computes 8-band spectrum + beat detection at 30Hz
3. Sends JSON UDP packets to Godot on port 9778
4. Godot smooths values with per-band attack/decay and pushes to shader global uniforms
5. Shaders read `audio_bass`, `audio_mid`, `audio_treble`, `audio_energy`, `beat_intensity` etc.

### Window Stacking (X11)
The Godot window uses `_NET_WM_STATE_BELOW` + `_NET_WM_STATE_STICKY` via `xprop` to sit above the wallpaper but below all app windows. Mouse passthrough is enabled so clicks go through to apps. **Do not use `_NET_WM_WINDOW_TYPE_DESKTOP`** — KDE renders its wallpaper on top of that.

### Known Issues
- **Memory leak:** ~20MB/hr drift from Godot/Vulkan. Nightly restart at 4am via systemd timer.
- **Port conflict:** Old Electron overlay may hold port 9877. Kill it: `ss -tlnp 'sport = :9877'`
- **SDFGI flicker:** Godot 4.6 bug with fast camera moves

### File Structure
```
scripts/desktop-3d-godot/
├── project.godot          # Godot config (Forward+, audio input, shader globals)
├── main.tscn              # Main scene
├── main.gd                # TCP server, scene management, audio, 6000+ lines
├── shaders/               # 45+ .gdshader files
│   ├── sacred_geometry.gdshader
│   ├── metatron.gdshader
│   ├── burning_ship.gdshader
│   └── ...
scripts/
├── desktop-3d.sh          # CLI client
├── desktop-3d-web.py      # HTTP panel (:9880)
├── sensors/
│   └── substrate_sensors.py  # Audio + system metrics daemon
nix/
├── desktop-3d-godot.nix   # NixOS service definitions
```

## Next Directions
- More fractals: Mandelbrot deep zoom, dragon curve, Barnsley fern
- More sacred geometry: Vesica Piscis, Torus, Platonic solids standalone
- Cursor interactivity via cursor_world_pos
- Scene transition dissolves between shaders


## Substrate Desktop Shell (2026-03-22)
Mathematical art IS the desktop. Built as CanvasLayer overlays in Godot:
- **Status bar** (): time, CPU, GPU, battery, WiFi, current shader
- **App launcher** (): fuzzy search .desktop files, Super+/ to toggle
- **Auto-rotation**: wallpapers cycle every 60s, built-in Timer (no external script)
- **Controls**: Super+Right/Left (next/prev), Super+P (pause), TCP commands

## Keyboard Shortcuts
- Super+/ — app launcher
- Super+Right — next wallpaper
- Super+Left — previous wallpaper
- Super+P — pause/resume rotation
- Super+Return — kitty terminal
- Super+W — tabbed window mode
- Super+F — fullscreen
- Super+Shift+Q — close window
- Super+1-5 — workspaces
- Print — screenshot

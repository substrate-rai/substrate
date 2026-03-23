---
name: Desktop Customization Research
description: Complete hardware/software customization map for Legion 5 + RTX 4060 + Gentoo
type: reference
---

# Desktop Customization Research — 2026-03-23

## Hardware Controls Available

### LenovoLegionLinux (`legion_laptop` kernel module)
- **Source:** github.com/johnfanv2/LenovoLegionLinux, available via GURU overlay
- Custom fan curves (10-point, per-fan, acceleration control)
- Performance modes: Quiet/Balanced/Performance (Fn+Q)
- Battery conservation mode (cap at 60%), rapid charging toggle
- Display overdrive toggle, G-Sync switching
- Y-Logo LED brightness

### Keyboard RGB: L5P-Keyboard-RGB
- **Source:** github.com/4JX/L5P-Keyboard-RGB (Rust)
- Legion 5 = **4-zone RGB** (not per-key — that's Legion 7 only)
- USB HID vendor `048d`, CLI + GUI
- Effects: Static, Breath, Wave, Lightning, Temperature-reactive
- Can be driven by CAVA audio data

### NVIDIA RTX 4060 Tricks
- NVENC screen recording (GPU Screen Recorder — zero CPU)
- Coolbits overclocking: `Option "Coolbits" "28"` in xorg.conf
- Custom TDP: `nvidia-smi -pl <watts>`
- GPU clock locking: `nvidia-smi --lock-gpu-clocks`
- ForceCompositionPipeline for tear-free without compositor

## Compositor Options (ranked by visual capability)

### 1. Wayfire (Wayland) — "Compiz of Wayland"
- 3D cube workspace rotation, wobbly windows, fire close animation
- Fisheye, blur (4 algorithms), window rotation, expo
- Plugin architecture

### 2. Hyprland (Wayland)
- Bezier curve animations on everything
- Gradient borders, kawase blur, screen shaders (GLSL on entire display)
- Plugins: hyprtrails (motion trails), hyprwinwrap (any app as wallpaper)
- Quickshell widget system (QtQuick — most advanced widget framework)

### 3. picom (X11) — current setup
- GLSL shaders on windows: `--window-shader-fg <path.glsl>`
- Per-window shader rules: `--window-shader-fg-rule`
- CRT scanlines, holographic distortion, chromatic aberration, vignette possible
- v12.5 animations: fly-in/out, appear/disappear, geometry-change

## Audio-Reactive Desktop
- **CAVA:** PipeWire → raw frequency data → drives anything
- **GLava:** OpenGL audio visualizer as wallpaper overlay
- Pipeline: PipeWire → CAVA raw → keyboard RGB + shader uniforms + polybar

## Bleeding Edge
- No Godot-as-compositor exists yet (would be a first)
- Hyprland + hyprwinwrap + Godot wallpaper = most advanced achievable today
- Quickshell (QtQuick) = most advanced widget/HUD framework
- Smithay (Rust) = build your own compositor from scratch

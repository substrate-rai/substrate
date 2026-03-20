# Advanced Visual Art Techniques for Godot 4 (Forward+ / Vulkan / RTX 4060)

Research date: 2026-03-20
Context: Live desktop wallpaper system rendering procedural 3D scenes and fullscreen shader art

---

## 1. Vulkan Compute Shaders in Godot 4

### What's Possible

Godot 4 exposes the Vulkan compute pipeline through the `RenderingDevice` API. You can write arbitrary GLSL compute shaders and dispatch them from GDScript. Proven applications include:

- **Particle simulations** (physarum/slime mold: 1-2 million agents at 120fps on RX 6700S)
- **Cellular automata** (Game of Life, custom rule sets via Cellular Automata Studio addon)
- **Fluid dynamics** (Navier-Stokes via multi-pass viewport approach, SPH/PBF for particle-based fluids)
- **Image processing** (heightmap generation, normal map computation, texture synthesis)
- **Reaction-diffusion systems** (Gray-Scott model runs well as compute)

### API Pattern

```
1. Create a local RenderingDevice (or use the global one)
2. Load and compile GLSL compute shader (.glsl file)
3. Create storage buffers via rd.storage_buffer_create()
4. Set up uniforms (RDUniform) with correct binding indices
5. Create compute pipeline from shader
6. Begin compute list, bind pipeline, bind uniforms, dispatch(x, y, z)
7. Submit and sync, then read back via rd.buffer_get_data()
```

For texture output (visual effects), write to `image2D` in the compute shader and use `Texture2DRD` to pass the result directly to the rendering pipeline without CPU readback.

### Critical Gotchas

- **vec3 treated as vec4**: Storage buffers containing `vec3` arrays silently pad to vec4 alignment. Workaround: use a struct with 3 individual floats, or use vec4 and ignore `.w`. This is a known Vulkan/GLSL alignment issue, not a Godot bug per se.
- **No SSBO in vertex/fragment shaders (yet)**: You cannot currently bind a storage buffer directly to a spatial/canvas_item shader. You must write compute results to a texture and sample it. There are open proposals (#6989, #7516) to add this.
- **Compute shaders use raw GLSL**: Unlike Godot's `.gdshader` language, compute shaders are plain GLSL (`.glsl`). Different syntax, different built-ins. No unified language.
- **Manual memory management**: `RenderingDevice` is low-level. You must free RIDs manually via `free_rid()`.
- **Synchronization**: Godot 4.3+ uses a rendering DAG that handles barriers automatically within the engine's rendering pipeline. For standalone compute dispatches, use `rd.barrier()` or `rd.sync()`.

### Useful Plugins

- **Compute Shader Plus** (DevPoodle): ComputeHelper class that manages shaders and uniforms, reduces boilerplate significantly
- **Compute Shader Studio**: Write and test compute shaders quickly
- **Cellular Automata Studio**: GLSL cellular automata with built-in functions

### Performance on RTX 4060

The RTX 4060 has 3072 CUDA cores and 8GB VRAM. For a live wallpaper context:
- 1M+ particle simulations are comfortable at 60fps
- Compute dispatches should target workgroup sizes of 64 or 256 (multiples of warp size 32)
- Keep total VRAM for compute textures/buffers under ~2GB to leave room for the 3D scene, Ollama, and system

### Repos & References
- [Godot Physarum (erlingpaulsen)](https://github.com/erlingpaulsen/godot-physarum) -- slime mold compute shader
- [Compute Helper Demo (DevPoodle)](https://github.com/DevPoodle/compute-helper-demo) -- slime mold with helper plugin
- [Godot Compute Shader GameOfLife (OverloadedOrama)](https://github.com/OverloadedOrama/Godot-ComputeShader-GameOfLife)
- [Compute Shader Plus plugin](https://github.com/DevPoodle/compute-shader-plus)
- [Cellular Automata Studio (Asset Library)](https://godotengine.org/asset-library/asset/2354)
- [Official compute shader docs](https://docs.godotengine.org/en/stable/tutorials/shaders/compute_shaders.html)
- [Textures and Compute Shaders in Godot 4 (pelto.dev)](https://pelto.dev/blog/textures-and-compute-shaders-in-godot/)

---

## 2. SDF Raymarching in Godot 4

### What's Possible

Fullscreen SDF raymarching works in Godot 4 via spatial shaders on a fullscreen quad (MeshInstance3D). You can render arbitrary procedural geometry -- infinite repetitions, smooth blending, domain distortion -- and integrate it with the regular 3D scene via depth buffer sampling.

### Integration with 3D Pipeline

The key technique is **depth-aware raymarching**: sample `hint_depth_texture` in the fragment shader, linearize the depth, and stop marching when the ray exceeds scene depth. This allows SDF objects to be properly occluded by regular meshes.

```glsl
shader_type spatial;
render_mode unshaded;

uniform sampler2D DEPTH_TEXTURE : source_color, hint_depth_texture;

void vertex() {
    POSITION = vec4(VERTEX.xy, 1.0, 1.0);  // fullscreen quad
}

void fragment() {
    // Sample scene depth
    float depth_raw = texture(DEPTH_TEXTURE, SCREEN_UV, 0.0).r;
    vec4 upos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth_raw, 1.0);
    float linear_depth = length(upos.xyz / upos.w);

    // Reconstruct ray
    vec3 ray_origin = INV_VIEW_MATRIX[3].xyz;
    vec4 camera = INV_VIEW_MATRIX * INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, 0.0, 1.0);
    vec3 ray_dir = normalize(camera.xyz);

    // March, stopping at scene depth
    // ... standard SDF marching loop with depth comparison ...
}
```

### Depth Writing

You can write `DEPTH` in the fragment shader to make SDF geometry participate in the depth buffer, allowing regular meshes to be occluded by SDF objects too. However, depth-writing shaders **do not work with shadow maps** (open proposal #1942).

### Available Tools

- **SDF Blender (Zylann)**: Editor plugin for composing SDF models with smooth blending. Good for prototyping but limited (no shadows, no PBR, slow with complexity).
- **SDF Addon (kubaxius)**: Visual Shader nodes for SDF primitives
- **Godot-SDF (xypine)**: Raymarching in a box with SDF primitives

### Gotchas

- **Reverse Z (Godot 4.3+)**: Depth comparisons in clip space are inverted. Use `INV_PROJECTION_MATRIX` transforms to work in view space and avoid issues. If comparing raw depth values, flip the comparison operator.
- **Performance**: Raymarching 300 steps per pixel at 1920x1080 = ~622M SDF evaluations per frame. Keep SDF functions simple or reduce march steps for complex scenes. Consider half-resolution rendering.
- **No geometry shaders**: Godot has no geometry shader support. Compute shaders are the alternative for any GPU-side geometry generation.

### Repos & References
- [Fullscreen Raymarching with Depth Check (godotshaders.com)](https://godotshaders.com/shader/fullscreen-raymarching-with-depth-check/)
- [Raymarching with Depth Writing (godotshaders.com)](https://godotshaders.com/shader/raymarching-with-depth-writting/)
- [SDF Blender (Zylann)](https://github.com/Zylann/godot_sdf_blender)
- [SDF Addon (kubaxius)](https://github.com/kubaxius/SDFAddon)
- [Godot-SDF (xypine)](https://github.com/xypine/Godot-SDF)

---

## 3. Reaction-Diffusion Systems on GPU

### Approach

Reaction-diffusion (Gray-Scott, Belousov-Zhabotinsky) is ideal for GPU compute because each texel's next state depends only on its neighbors. Two approaches in Godot 4:

**Approach A -- Compute Shader (recommended)**:
Use two textures as ping-pong buffers. Each frame, read from texture A, write reaction-diffusion update to texture B, then swap. Display via `Texture2DRD` on a `ColorRect` or `MeshInstance3D`.

**Approach B -- Fragment Shader with Viewports**:
Use two `SubViewport` nodes rendering to texture. Each frame, one viewport reads the other's texture and writes the updated state. This is the approach used in the Navier-Stokes fluid demo (Maaack) -- layered viewports simulate multi-pass convergence.

### Texture Setup for Compute Ping-Pong

```gdscript
# Create two textures on the RenderingDevice
var fmt := RDTextureFormat.new()
fmt.format = RenderingDevice.DATA_FORMAT_R32G32B32A32_SFLOAT  # or R16G16_SFLOAT for Gray-Scott
fmt.width = 512
fmt.height = 512
fmt.usage_bits = (
    RenderingDevice.TEXTURE_USAGE_STORAGE_BIT |
    RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT |
    RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT
)

var tex_a_rid = rd.texture_create(fmt, RDTextureView.new())
var tex_b_rid = rd.texture_create(fmt, RDTextureView.new())
```

In the compute shader (GLSL):
```glsl
layout(rgba32f, binding = 0) uniform image2D input_tex;
layout(rgba32f, binding = 1) uniform image2D output_tex;

void main() {
    ivec2 pos = ivec2(gl_GlobalInvocationID.xy);
    // Read neighbors from input_tex
    // Apply Gray-Scott: dU/dt = Du*laplacian(U) - U*V^2 + f*(1-U)
    //                   dV/dt = Dv*laplacian(V) + U*V^2 - (f+k)*V
    // Write to output_tex
}
```

### Porting from Shadertoy

Many reaction-diffusion examples exist on Shadertoy. Key translation points:
- `iResolution` -> pass as uniform or use `gl_NumWorkGroups * gl_WorkGroupSize`
- `fragCoord` -> `gl_GlobalInvocationID.xy`
- `iChannel0` -> bind as sampler or image uniform
- `iTime` -> pass as uniform
- Godot uses GLSL ES 3.0 syntax for fragment shaders; compute shaders use full GLSL 450

### Belousov-Zhabotinsky

BZ reaction produces spiral waves. It can be implemented as a 3-component system (activator, inhibitor, substrate) on the same ping-pong texture setup. Shadertoy has reference implementations (e.g., shadertoy.com/view/XtcGD2). The BZ model with hexagonal cellular automaton has been demonstrated on GPU.

### Performance Notes
- 512x512 Gray-Scott at 60fps: trivial on RTX 4060
- 2048x2048: still comfortable, ~16M texels per frame
- 4096x4096: may need to run multiple simulation steps per render frame to keep up

### References
- [Gray-Scott shader tutorial (pierre-couy.dev)](https://pierre-couy.dev/simulations/2024/09/gray-scott-shader.html)
- [Reaction-Diffusion Compute Shader in WebGPU (Codrops)](https://tympanus.net/codrops/2024/05/01/reaction-diffusion-compute-shader-in-webgpu/)
- [Reaction Diffusion GLSL (GitHub gist)](https://gist.github.com/sansumbrella/72c15b21ba2062c19c5943ee3e4574a0)
- [Reaction diffusion on shader (ciphrd.com)](https://ciphrd.com/2019/08/24/reaction-diffusion-on-shader/)
- [BZ reaction on Shadertoy](https://www.shadertoy.com/view/XtcGD2)

---

## 4. GPU-Driven Procedural Geometry

### Marching Cubes on GPU

Godot 4 has working GPU marching cubes implementations:

- **jeronimo-schreyer/godot-marching-cubes**: Both CPU and GPU (compute shader) implementations. Uses Texture3D spritesheets as volumetric data source. GPU version generates mesh vertices in a storage buffer, then transfers to `SurfaceTool`/`MeshDataTool` for rendering.
- **SebLague/Godot-Marching-Cubes**: Well-known implementation ported to Godot.

The workflow: compute shader evaluates density field, generates triangles via lookup table, writes vertex data to storage buffer. GDScript reads buffer back and constructs `ArrayMesh`.

### The CPU Readback Bottleneck

The main limitation: **Godot cannot currently render directly from compute shader output**. You must:
1. Compute shader generates vertex data in a storage buffer
2. CPU reads buffer back via `rd.buffer_get_data()`
3. CPU constructs ArrayMesh from the data
4. Assign to MeshInstance3D

This CPU roundtrip limits realtime procedural geometry. The open SSBO proposal (#6989) would allow binding compute output directly to vertex shaders, eliminating the bottleneck.

### Workarounds

- **Vertex displacement**: For terrain-like effects, use a fixed grid mesh and displace vertices in the vertex shader from a compute-generated heightmap texture. No CPU readback needed.
- **MultiMesh with compute**: Generate instance transforms in compute shader, write to texture, read texture in vertex shader via `INSTANCE_CUSTOM`. Limited to 4 floats per instance.
- **Point cloud rendering**: Render particles as points or billboards using the particle shader system, which runs on GPU natively.

### Wave Function Collapse

WFC implementations exist for Godot 4 but run on CPU:
- **AlexeyBond/godot-constraint-solving**: WFC with backtracking, some concurrent task execution
- **WFC 2D/3D Generator (Asset Library)**: Ready-to-use addon

GPU-accelerated WFC is theoretically possible via compute shaders but no Godot implementation exists yet. The constraint propagation step is less parallelizable than marching cubes.

### Future: GPU-Driven Renderer

Reduz (Godot lead) has published a [design document](https://gist.github.com/reduz/c5769d0e705d8ab7ac187d63be0099b5) for a GPU-driven renderer. Key ideas:
- Compute shader counts objects per shader type, assigns offsets, creates indirect draw lists
- Frustum/occlusion culling via raytracing on a small depth buffer
- Mesh streaming with meshlets
- Would enable true GPU-side geometry generation

This is long-term roadmap, not available yet.

### References
- [Godot Marching Cubes (Schreyer)](https://github.com/jeronimo-schreyer/godot-marching-cubes)
- [SebLague Godot Marching Cubes](https://github.com/SebLague/Godot-Marching-Cubes)
- [Marching Cubes addon (Asset Library)](https://godotengine.org/asset-library/asset/3597)
- [WFC plugin (AlexeyBond)](https://github.com/AlexeyBond/godot-constraint-solving)
- [GPU Driven Renderer proposal (reduz)](https://gist.github.com/reduz/c5769d0e705d8ab7ac187d63be0099b5)
- [Compute heightmap demo (Asset Library)](https://godotengine.org/asset-library/asset/2784)

---

## 5. Screen-Space Effects Beyond the Basics

### Painterly / Oil Painting

**Kuwahara Filter**: Divides a window around each pixel into sectors, finds the sector with least color variation, and uses that sector's average color. Creates an oil-painting aesthetic. Available as:
- [Kuwahara Shader (Asset Library)](https://godotengine.org/asset-library/asset/1183) -- supports Sprites, TextureRect, and 3D post-processing
- [PeterEve/godot-kuwahara](https://github.com/PeterEve/godot-kuwahara)
- Ships with 4 pre-made circular kernels (3, 4, 5, 6 pixels wide)

Performance note: Kuwahara is O(n*k^2) where k is kernel size. At 6px kernel on 1080p, it's affordable. For larger kernels, consider the **anisotropic Kuwahara** variant which uses eigenvalues of the structure tensor to align kernels with local image structure.

### Watercolor / Ink Wash

- [Watercolor Light Shader (godotshaders.com)](https://godotshaders.com/shader/watercolor-light-shader/) -- designed for "inked watercolor" look, uses second-pass material overlay
- Combine with edge detection (Sobel filter) for ink outlines + Kuwahara for paint fill

### CRT / VHS / Retro

Multiple ready-made implementations:
- [VHS CRT Broadcast](https://godotshaders.com/shader/vhs-crt-broadcast/) -- full CRT + VHS composite video emulation
- [VHS and CRT Monitor Effect](https://godotshaders.com/shader/vhs-and-crt-monitor-effect-2/) -- Godot 4 specific
- [CRT Display Shader (Godot 4.4.1)](https://godotshaders.com/shader/crt-display-shader-pixel-mask-scanlines-glow-godot-4-4-1/) -- pixel mask, scanlines, glow
- Effects: scanlines, screen warping, chromatic aberration, noise, color bleeding, phosphor decay, interlacing

### ASCII Art Post-Processing

- [Godot-Ascii-Shader (joryleech)](https://github.com/joryleech/Godot-Ascii-Shader) -- converts screen space to ASCII characters, adjustable pixelation/resolution
- [godot-ascii-shader (sjvnnings)](https://github.com/sjvnnings/godot-ascii-shader) -- uses texture sequence for characters, font is swappable
- [Ascii Shader (AbstractBorderStudio)](https://github.com/AbstractBorderStudio/Ascii_Shader)

### Dithering / Halftone

- [CMYK Halftone shader](https://godotshaders.com/shader/canvas-item-halftone-shader/) -- process separation halftone
- [godot-color-dither (Donitzo)](https://github.com/Donitzo/godot-color-dither) -- multicolored dithering with postprocessor support
- [Dither Gradient Shader](https://godotshaders.com/shader/dither-gradient-shader/) -- palette + ordered dithering
- [GodotDitheringShader (griffinjennings)](https://github.com/griffinjennings/GodotDitheringShader) -- custom Bayer matrices, blue noise

### Chromatic Aberration / Glitch

- [Chromatic Aberration (godotshaders.com)](https://godotshaders.com/shader/chromatic-abberation/) -- basic RGB channel separation
- [Chromatic Aberration with Offset](https://godotshaders.com/shader/chromatic-abberation-with-offset/) -- direction-controlled
- [Glitch Effect Shader](https://godotshaders.com/shader/glitch-effect-shader/)
- [Godot 4 Color Correction and Screen Effects](https://github.com/ArseniyMirniy/Godot-4-Color-Correction-and-Screen-Effects) -- comprehensive collection: blur, pixelation, bloom, halation, vignette, saturation, color filter

### Cel / Toon / NPR

- [Complete Cel Shader for Godot 4](https://godotshaders.com/shader/complete-cel-shader-for-godot-4/) -- uses shader globals and shader includes
- [Flexible Toon Shader (Asset Library)](https://godotengine.org/asset-library/asset/1900) -- customizable band counts
- Combine with edge detection for outline effects

### Ideas Not Yet Widely Implemented in Godot

- **Pixel sorting** (glitch art): Sort pixels by luminance along scanlines. Could be implemented as a compute shader operating on screen texture.
- **Datamoshing**: Requires frame history buffers. Possible via SubViewport capturing previous frames.
- **Voronoi stylization**: Apply Voronoi tessellation to screen space for mosaic/stained glass effect.
- **Crosshatch shading**: Overlay directional line patterns based on luminance bands.

---

## 6. Volumetric Rendering

### Built-in Volumetric Fog

Godot 4's volumetric fog uses a **froxel buffer** (frustum-aligned voxels), default 64x64x64. Rendered via compute shader atomic operations -- multiple overlapping FogVolumes work without GPU stalls.

**FogVolume shapes**: Box, ellipsoid, cone, cylinder, or world-covering.

**Fog shader API** (`shader_type fog`):
- Inputs: `WORLD_POSITION`, `OBJECT_POSITION`, `UVW` (within AABB), `EXTENTS`, `TIME`
- Outputs: `DENSITY` (float, supports negative for subtraction), `ALBEDO` (vec3), `EMISSION` (vec3)
- Can sample `sampler3D` textures for noise-driven density

**Custom density functions**: Animate NoiseTexture3D UVs for moving fog/mist. Use `UVW` + time offsets for scrolling, layered noise octaves for natural-looking fog.

### God Rays / Light Shafts

No native god ray implementation. Community solutions:

- **Screen-space radial blur** ([godotshaders.com](https://godotshaders.com/shader/screen-space-god-rays-godot-4-3/)): Renders light source mask to SubViewport, applies radial blur toward light position. Can be slow and hard to set up correctly.
- **SimplestGodRay3D** ([AguaMineral](https://github.com/AguaMineral/SimplestGodRay3D)): Custom Node3D using a single QuadMesh + shader. Artistic/stylized approach, much better performance than screen-space.
- **Volumetric fog exploitation**: Use FogVolumes with directional light to approximate god rays. Not physically accurate but cheap.

### Volumetric Cloud Rendering

Multiple approaches available:

- **clayjohn/godot-volumetric-cloud-demo-v2**: Uses **compute shaders + sky shaders** to generate animated clouds via raymarching 3D textures. Physically correct atmosphere. Requires Godot 4.2+. This is the gold standard for Godot clouds.
- **Volumetric Raymarched Clouds v2** ([godotshaders.com](https://godotshaders.com/shader/volumetric-raymarched-animated-clouds-v2/)): Fragment shader approach, customizable
- **kb173/godot-volumetric-clouds**: Addon with raymarching shader
- **Volumetric Nebulae** ([godotshaders.com](https://godotshaders.com/shader/volumetric-nebulae-clouds/)): Good for space scenes

### Custom Volume Rendering via Raymarching

For arbitrary volume rendering (smoke, explosions, nebulae), use the same spatial shader raymarching technique as SDF rendering but evaluate a density function instead of a distance function:

```glsl
// In fragment shader, march through volume
float density_accum = 0.0;
vec3 color_accum = vec3(0.0);
for (int i = 0; i < steps; i++) {
    vec3 p = ray_origin + ray_dir * t;
    float density = sample_3d_noise(p);  // or texture(noise_3d, p)
    if (density > threshold) {
        // Beer-Lambert absorption
        float transmittance = exp(-density * step_size * absorption);
        color_accum += density * albedo * transmittance * step_size;
        density_accum += density * step_size;
    }
    t += step_size;
}
```

Godot 4 provides `NoiseTexture3D` as a built-in resource for 3D noise generation.

### References
- [Volumetric fog docs](https://docs.godotengine.org/en/stable/tutorials/3d/volumetric_fog.html)
- [Fog shader reference](https://docs.godotengine.org/en/stable/tutorials/shaders/shader_reference/fog_shader.html)
- [Fog Volumes article](https://godotengine.org/article/fog-volumes-arrive-in-godot-4/)
- [Volumetric cloud demo v2 (clayjohn)](https://github.com/clayjohn/godot-volumetric-cloud-demo-v2)
- [SimplestGodRay3D](https://github.com/AguaMineral/SimplestGodRay3D)
- [Volumetric Fog Demo (Asset Library)](https://godotengine.org/asset-library/asset/2754)

---

## 7. Audio-Reactive 3D Geometry

### Audio Data Pipeline

Godot 4's audio analysis chain:

1. Add `AudioEffectSpectrumAnalyzer` to the audio bus
2. Get the `AudioEffectSpectrumAnalyzerInstance` at runtime
3. Call `get_magnitude_for_frequency_range(from_hz, to_hz, mode)` -- returns `Vector2` (left/right stereo magnitude), normalized 0.0 to 1.0
4. Pass values as shader uniforms

**Known issue**: `get_magnitude_for_frequency_range` can return [jittery values](https://github.com/godotengine/godot/issues/67650). Smooth with exponential moving average in GDScript before passing to shader.

### Best Approaches for Driving 3D

**Vertex Displacement (simplest)**:
Pass bass/mid/treble as uniforms to a vertex shader. Displace vertices along normals by audio magnitude. Works great for sphere/plane visualizers.

```glsl
// In vertex() function
uniform float bass;
uniform float treble;
VERTEX += NORMAL * bass * 0.5 * sin(VERTEX.x * treble * 10.0 + TIME);
```

**Spectrum Texture (more detail)**:
Pack FFT bins into a 1D texture (e.g., 64 or 128 texels wide). Update each frame via `ImageTexture.update()`. Sample in vertex or fragment shader for per-frequency response.

```gdscript
# GDScript: build spectrum texture each frame
var spectrum = AudioServer.get_bus_effect_instance(0, 0)
var img = Image.create(128, 1, false, Image.FORMAT_RF)
for i in 128:
    var hz_lo = i * 20000.0 / 128.0
    var hz_hi = (i + 1) * 20000.0 / 128.0
    var mag = spectrum.get_magnitude_for_frequency_range(hz_lo, hz_hi).length()
    img.set_pixel(i, 0, Color(mag, 0, 0, 0))
spectrum_texture.update(img)
```

**MultiMesh Instance Modulation**:
Drive `INSTANCE_CUSTOM` data per-instance from audio. Each instance gets 4 floats (32-bit in Forward+, 16-bit in Compatibility). Can encode frequency band response per instance.

**GPUParticles3D**:
Particle shaders can read uniforms. Pass audio data as uniforms to modulate emission rate, velocity, scale, and color. The `process_material` on GPUParticles3D supports custom shaders.

**Compute Shader Approach (most powerful)**:
Run audio analysis in compute shader, write particle positions/velocities to storage buffer or texture. Use Texture2DRD to feed results to particle system or vertex shader. Enables complex emergent behavior from audio.

### Performance Considerations

- Spectrum analysis is cheap (GDScript-side FFT already done by engine)
- Texture updates via `ImageTexture.update()` are fast for small textures (128x1)
- Avoid updating large textures every frame -- keep spectrum textures narrow
- For beat detection, maintain a running average and detect deviation in GDScript, pass boolean/float uniform

### References
- [AudioEffectSpectrumAnalyzer docs](https://docs.godotengine.org/en/stable/classes/class_audioeffectspectrumanalyzer.html)
- [Spectrum Analyzer shader (godotshaders.com)](https://godotshaders.com/shader/spectrum-analyzer/)
- [Jitter bug (#67650)](https://github.com/godotengine/godot/issues/67650)
- [Expose more FFT data proposal (#5910)](https://github.com/godotengine/godot-proposals/issues/5910)

---

## 8. Known Godot 4 Rendering Bugs & Limitations

### Critical: Godot 4.6 Rendering Regression

[Issue #115599](https://github.com/godotengine/godot/issues/115599): Major regression in Godot 4.6 breaking sky shaders, VoxelGI, and SDFGI lighting. Same scenes produce drastically worse results compared to 4.5. Assigned to 4.7 milestone.

**Recommendation**: Stay on Godot 4.5.x for production visual work until 4.7 ships with fixes. If using 4.6, test GI-heavy scenes carefully.

### Reverse Z Depth Buffer (Godot 4.3+)

Introduced in 4.3, reverse Z improves depth precision but breaks shaders that:
- Write hardcoded values to `DEPTH` (0.0 is now far, 1.0 is near)
- Compare depth values in clip space (comparisons must be flipped)
- Set `POSITION.z` directly

**Safe pattern**: Always transform through `PROJECTION_MATRIX` / `INV_PROJECTION_MATRIX`. The engine handles the flip automatically.

**Migration**: Switch clip-space operations to view-space operations where possible.

### Forward+ Renderer Issues

- **Frameskip/jitter bug** ([#84137](https://github.com/godotengine/godot/issues/84137)): GPU frames not sorted correctly on Windows, causing movement jitter. Deep-seated, no workaround.
- **Shader noise discontinuities** ([#84871](https://github.com/godotengine/godot/issues/84871)): Noise functions show strange discontinuities in Forward+ but work in Compatibility renderer.
- **VRAM leak on viewport resize** ([#81258](https://github.com/godotengine/godot/issues/81258)): Resizing viewport many times causes permanent FPS drop and VRAM increase.

### Compute Shader Limitations

- **vec3 alignment**: Storage buffers treat vec3 as vec4. Use structs with 3 floats or vec4.
- **No SSBO in vertex/fragment**: Cannot bind compute output directly to spatial shaders. Must use texture intermediary.
- **Shader reload bug**: Compute shaders may not recompute after project reload (historical issue, mostly fixed).
- **Global shader uniforms not accessible in GLSL compute**: Compute shaders are raw GLSL, not gdshader. You cannot use `global uniform` -- must pass all data explicitly.

### General Shader Gotchas

- **No geometry shaders**: Use compute shaders as alternative.
- **No tessellation shaders**: Proposal exists (#5995) but not implemented. Use vertex displacement on pre-subdivided meshes.
- **INSTANCE_CUSTOM precision**: 32-bit in Forward+, only 16-bit in Compatibility renderer.
- **MultiMesh limitations**: No frustum culling, no LOD. For large instance counts, implement these manually.
- **FOG writing**: Works in Forward+ and Mobile, but Compatibility renderer requires WorldEnvironment node with fog enabled.
- **Depth-writing shaders**: Cannot interact with shadow maps.
- **Sampler limit**: Some GPUs limit the number of sampler2D uniforms (reported issue at 64+ on Apple M2).

### Performance Tips for RTX 4060

- SDFGI/VoxelGI: Enable "Use Half Resolution" to halve GI buffer size (trades aliasing for 2x speed)
- Texture compression: Use GPU-compressed formats (BCn/ETC2) to reduce bandwidth
- Shader complexity: Reduce texture reads per fragment -- each read is expensive, especially trilinear/aniso filtered
- Material reuse: Godot auto-batches StandardMaterial3Ds with same configuration
- Compute workgroups: Use multiples of 32 (warp size on NVIDIA)
- VRAM budget: Keep total under 6GB to leave headroom for Ollama (5.5GB) -- though Ollama can share via unified memory management

### Useful Global Features

- **Shader Includes** (`ShaderInclude` resource): Share functions across shaders without duplication
- **Global Uniforms**: Set once in Project Settings, available in all `.gdshader` files (not compute GLSL). Good for TIME, player_position, audio_data.
- **Rendering DAG (4.3+)**: Automatic synchronization barrier management. Invisible to the programmer -- the engine handles dependency tracking and command reordering.

### References
- [Reverse Z article](https://godotengine.org/article/introducing-reverse-z/)
- [4.6 regression (#115599)](https://github.com/godotengine/godot/issues/115599)
- [Jitter bug (#84137)](https://github.com/godotengine/godot/issues/84137)
- [SSBO proposal (#7516)](https://github.com/godotengine/godot-proposals/issues/7516)
- [Compute to vertex/fragment proposal (#6989)](https://github.com/godotengine/godot-proposals/issues/6989)
- [GPU optimization docs](https://docs.godotengine.org/en/stable/tutorials/performance/gpu_optimization.html)
- [GLSL to Godot conversion guide](https://docs.godotengine.org/en/stable/tutorials/shaders/converting_glsl_to_godot_shaders.html)
- [Rendering DAG article](https://godotengine.org/article/rendering-acyclic-graph/)

---

## Summary: What to Build Next

Given the existing system already has 15+ 3D scenes, 30+ fragment shaders, audio-reactivity, particles, volumetric fog, SSR, SDFGI, and glow -- here are the highest-impact additions ranked by visual payoff vs. implementation effort:

### Tier 1: High Impact, Moderate Effort
1. **Compute shader physarum/slime mold** -- Reference implementation exists (erlingpaulsen). 1M+ agents on RTX 4060. Stunning organic visuals. Directly compatible with audio-reactive parameters.
2. **SDF raymarching scenes** -- Infinite procedural geometry from a single fullscreen quad. Domain repetition, smooth blending, kaleidoscopic effects. Depth integration with existing 3D scenes.
3. **Reaction-diffusion (Gray-Scott)** -- Compute shader ping-pong. Mesmerizing self-organizing patterns. Feed/kill parameters map perfectly to audio-reactive control.
4. **Kuwahara oil painting post-process** -- Drop-in shader, instantly transforms any 3D scene into painterly art. Toggle-able per scene.

### Tier 2: High Impact, Higher Effort
5. **Volumetric cloud rendering** -- clayjohn's compute + sky shader approach. Physically-based atmosphere. Beautiful for nature/sky scenes.
6. **GPU marching cubes** -- Realtime isosurface from 3D noise. Audio-reactive density thresholds = pulsing organic forms.
7. **Custom FogVolume shaders** -- Animate 3D noise density for scene-specific atmospheric effects (cave mist, underwater caustic-like fog, forest floor haze).

### Tier 3: Quick Wins (Post-Processing)
8. **ASCII art shader** -- Drop-in post-process, great for "terminal" themed scenes
9. **CRT/VHS shader** -- Multiple implementations ready to use
10. **Halftone/dithering** -- CMYK halftone or ordered dithering for print-media aesthetic
11. **Chromatic aberration** -- Subtle or aggressive, audio-reactive intensity
12. **Voronoi stylization** -- Screen-space Voronoi for stained-glass effect

### Things to Avoid (For Now)
- **Godot 4.6**: Stay on 4.5.x due to rendering regression
- **GPU geometry generation with CPU readback**: Wait for SSBO proposal to mature
- **Complex SDF scenes at full resolution**: Half-res or limit march steps
- **Large MultiMesh without custom culling**: Engine doesn't frustum-cull MultiMesh instances

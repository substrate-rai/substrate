shader_type canvas_item;

// Butterchurn-style frame feedback warp shader
// Self-referencing via SubViewport: reads its own previous frame (double-buffered),
// applies audio-driven zoom/rotation/displacement, injects beat-seeded content.
// The per-pixel warp with spatial variation simulates Butterchurn's warp mesh grid.

global uniform float audio_bass;
global uniform float audio_mid;
global uniform float audio_energy;
global uniform float beat_intensity;
global uniform float audio_sub_bass;
global uniform float audio_treble;
global uniform float audio_presence;
global uniform float beat_kick;
global uniform float beat_snare;
global uniform float beat_hihat;
global uniform float audio_warmth;
global uniform float audio_brightness;
global uniform float audio_flux;

uniform sampler2D previous_frame : filter_linear;
uniform float fade : hint_range(0.8, 1.0) = 0.95;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;
	vec2 center = vec2(0.5);
	vec2 offset = uv - center;
	float r = length(offset);
	float angle = atan(offset.y, offset.x);

	// ── Warp mesh simulation (per-pixel spatial variation) ──
	// Butterchurn uses a 32x24 vertex grid with per-vertex warp equations.
	// We simulate this with smoothly-varying per-pixel warp functions.

	// Zoom — bass drives zoom, kick spikes it, sub_bass adds slow breathing
	float zoom = 1.005 + audio_bass * 0.015 + beat_kick * 0.04;
	zoom += sin(TIME * 0.3) * audio_sub_bass * 0.008;

	// Rotation — mid + flux, varies spatially (center rotates more)
	float rot_base = audio_mid * 0.008 + audio_flux * 0.004;
	float rot_spatial = rot_base * (1.0 + (1.0 - r) * 0.5);
	float ca = cos(rot_spatial);
	float sa = sin(rot_spatial);

	// Per-pixel warp displacement (organic distortion from warp mesh)
	vec2 warp_disp = vec2(0.0);
	warp_disp.x += sin(uv.y * 6.28 + TIME * 0.5) * audio_mid * 0.003;
	warp_disp.y += cos(uv.x * 6.28 + TIME * 0.3) * audio_treble * 0.002;
	warp_disp += vec2(
		sin(TIME * 0.3) * audio_sub_bass * 0.002,
		cos(TIME * 0.2) * audio_sub_bass * 0.0015
	);
	// Presence adds fine ripple distortion
	warp_disp.x += sin(uv.x * 12.0 + uv.y * 8.0 + TIME) * audio_presence * 0.001;

	// Apply warp: zoom + spatially-varied rotation + displacement
	vec2 warped = center + mat2(vec2(ca, sa), vec2(-sa, ca)) * (offset / zoom) + warp_disp;

	// Sample previous frame with warp
	vec4 prev = texture(previous_frame, warped);

	// ── Dynamic fade ──
	// Higher energy = faster fade (shorter trails), lower = longer persistence
	float dynamic_fade = fade - audio_energy * 0.025;
	dynamic_fade = clamp(dynamic_fade, 0.86, 0.98);

	// ── Beat seeding — inject spatially-varied colored content ──
	// Butterchurn injects new content per-frame; we use beat onsets
	vec3 seed = vec3(0.0);

	// Kick: warm orange ring burst, strongest at mid-radius
	float kick_ring = exp(-pow((r - 0.25) * 7.0, 2.0));
	seed += vec3(1.0, 0.5, 0.15) * beat_kick * 0.35 * kick_ring;

	// Snare: cyan scatter — random dots across screen
	float snare_dot = step(0.92, hash(floor(uv * 30.0 + TIME * 7.0)));
	seed += vec3(0.15, 0.7, 1.0) * beat_snare * 0.4 * snare_dot;

	// Hihat: fine white sparkle
	float hihat_sparkle = step(0.97, hash(floor(uv * 80.0 + TIME * 13.0)));
	seed += vec3(0.9, 0.95, 1.0) * beat_hihat * 0.25 * hihat_sparkle;

	// Energy: ambient center glow (dim, continuous)
	float energy_glow = exp(-r * r * 4.0) * audio_energy * 0.06;
	seed += vec3(0.2, 0.6, 0.4) * energy_glow;

	// Beat intensity: broad radial pulse
	seed += vec3(0.4, 0.2, 0.6) * beat_intensity * 0.1 * (1.0 - r);

	// Warmth shifts seed color temperature
	seed = mix(seed, seed * vec3(1.2, 0.9, 0.7), audio_warmth * 0.5);

	// Brightness modulates overall seed intensity
	seed *= 1.0 + audio_brightness * 0.3;

	// ── Composite ──
	COLOR = vec4(prev.rgb * dynamic_fade + seed, 1.0);
}

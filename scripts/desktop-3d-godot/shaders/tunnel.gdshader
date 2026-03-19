shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

// Infinite tunnel — 1/distance + angle UV mapping
global uniform float audio_energy;
global uniform float beat_intensity;
global uniform float audio_bass;
global uniform float audio_treble;
global uniform float audio_mid;
global uniform float audio_sub_bass;
global uniform float audio_presence;
global uniform float audio_brilliance;
global uniform float beat_kick;
global uniform float beat_snare;
global uniform float beat_hihat;
global uniform float audio_warmth;
global uniform float audio_brightness;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1, 0)), f.x),
		mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x),
		f.y
	);
}

void fragment() {
	vec2 uv = UV - 0.5;
	uv.x *= 1.777;

	float r = length(uv);
	float a = atan(uv.y, uv.x);

	// Tunnel mapping — sub_bass breathes the tunnel depth
	float speed = 1.0 + audio_energy * 2.0;
	float d = (0.5 + audio_sub_bass * 0.15) / (r + 0.001); // depth with breathing
	float tunnel_u = (a + audio_mid * 0.5) / 3.14159; // mid rotates the tunnel
	float tunnel_v = d + TIME * speed;

	// Wall pattern
	vec2 tile = vec2(tunnel_u * 4.0, tunnel_v);
	float pattern = noise(tile * 3.0);
	pattern += noise(tile * 6.0) * 0.5;

	// Presence boosts wall shimmer intensity
	pattern *= (1.0 + audio_presence * 0.8);

	// Grid lines — brilliance enhances edge highlights
	vec2 grid = fract(tile) - 0.5;
	float lines = smoothstep(0.48, 0.5, abs(grid.x)) + smoothstep(0.48, 0.5, abs(grid.y));
	lines = min(lines, 1.0);
	lines *= (1.0 + audio_brilliance * 1.5);

	// Color
	vec3 col = vec3(0.0);
	col += vec3(0.0, 0.8, 0.6) * pattern * 0.5;
	col += vec3(0.0, 1.0, 0.7) * lines * 0.6;

	// Depth fog — darker toward the center
	col *= smoothstep(0.0, 0.4, r);

	// Treble adds shimmer to walls
	col += vec3(0.3, 0.5, 1.0) * audio_treble * pattern * 0.4;

	// Beat flash (original)
	float flash = beat_intensity * smoothstep(0.3, 0.0, r);
	col += vec3(1.0, 0.5, 0.8) * flash;

	// Bass warps slightly
	col *= 1.0 + audio_bass * 0.3 * sin(d * 2.0);

	// --- New audio-reactive layers ---

	// Kick → bright rings at regular depth intervals
	float ring = exp(-pow(fract(tunnel_v * 0.5) - 0.5, 2.0) * 50.0) * beat_kick;
	col += ring * vec3(1.0, 0.5, 0.8);

	// Snare → color shift toward cyan
	col = mix(col, vec3(0.2, 0.8, 1.0) * length(col), beat_snare * 0.6);

	// Hi-hat → sparkle on walls (tiny bright points)
	float sparkle = step(0.97, noise(tile * 20.0)) * beat_hihat * 0.8;
	col += sparkle * vec3(1.0, 0.9, 0.8);

	// Warmth → shift from cool cyan toward warm amber
	vec3 warm_tint = mix(vec3(1.0), vec3(1.4, 1.1, 0.6), audio_warmth);
	col *= warm_tint;

	// Brightness → overall brightness multiplier
	col *= (0.7 + audio_brightness * 0.6);

	ALBEDO = col;
}

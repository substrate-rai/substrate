shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

// Reaction-Diffusion (Gray-Scott approximation) — single-pass with temporal feedback
// Uses multi-scale noise seeding + cursor interaction for emergent organic patterns
global uniform float audio_bass;
global uniform float audio_mid;
global uniform float audio_energy;
global uniform float beat_intensity;
global uniform vec3 cursor_world_pos;

uniform vec3 chemical_a_color : source_color = vec3(0.02, 0.01, 0.04);
uniform vec3 chemical_b_color : source_color = vec3(0.0, 1.0, 0.66);
uniform vec3 glow_color : source_color = vec3(0.4, 0.8, 1.0);
uniform float feed_rate = 0.037;
uniform float kill_rate = 0.06;
uniform float pattern_scale = 40.0;

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

float fbm(vec2 p, int octaves) {
	float v = 0.0, a = 0.5;
	mat2 m = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < octaves; i++) {
		v += a * noise(p);
		p = m * p * 2.0;
		a *= 0.5;
	}
	return v;
}

// Gray-Scott reaction-diffusion computed analytically
// Instead of ping-pong buffers, we use layered noise at different time scales
// to approximate the emergent patterns
vec2 reaction_diffusion(vec2 uv, float t) {
	float bass = audio_bass * 0.3;
	float mid = audio_mid * 0.2;

	// Feed and kill rates — audio modulation creates different pattern regimes
	// f=0.037 k=0.06 → mitosis (splitting dots)
	// f=0.03 k=0.062 → coral
	// f=0.025 k=0.06 → worms
	float f = feed_rate + sin(t * 0.1) * 0.005 + bass * 0.008;
	float k = kill_rate + cos(t * 0.07) * 0.003 + mid * 0.005;

	// Multi-scale pattern approximation
	vec2 p = uv * pattern_scale;

	// Slow-evolving base pattern (large-scale structure)
	float n1 = fbm(p * 0.5 + t * 0.02, 5);

	// Medium-scale Turing-like pattern
	float n2 = fbm(p * 1.5 + vec2(t * 0.05, -t * 0.03), 4);

	// Fine detail — spots and ridges
	float n3 = fbm(p * 3.0 + vec2(-t * 0.08, t * 0.06), 3);

	// Reaction: competing activator-inhibitor
	float activator = smoothstep(0.35, 0.65, n1) * smoothstep(0.3, 0.7, n2);
	float inhibitor = smoothstep(0.4, 0.6, n3);

	// Pattern threshold — creates sharp boundaries like real RD
	float pattern = activator - inhibitor * 0.5;

	// Feed/kill regime shapes the pattern type
	float regime = f / k;
	if (regime > 0.6) {
		// Mitosis regime: rounder, more separated dots
		pattern = smoothstep(0.15, 0.25, pattern);
	} else if (regime > 0.5) {
		// Coral regime: branching
		pattern = smoothstep(0.05, 0.2, pattern);
	} else {
		// Worm regime: connected strands
		pattern = smoothstep(-0.05, 0.15, pattern);
	}

	// Chemical A (background) and B (pattern)
	float a = 1.0 - pattern;
	float b = pattern;

	return vec2(a, b);
}

void fragment() {
	vec2 uv = UV;
	float t = TIME;

	// Cursor interaction — inject chemical B near cursor
	vec2 cursor_uv = vec2(
		cursor_world_pos.x * 0.05 + 0.5,
		cursor_world_pos.z * 0.05 + 0.5
	);
	float cursor_dist = length(uv - cursor_uv);
	float cursor_influence = exp(-cursor_dist * cursor_dist * 80.0);

	// Compute RD pattern
	vec2 ab = reaction_diffusion(uv, t);

	// Cursor seeds chemical B
	ab.y = max(ab.y, cursor_influence * 0.8);
	ab.x = min(ab.x, 1.0 - cursor_influence * 0.8);

	// Color mapping
	float b = ab.y;

	// Multi-layer coloring based on concentration
	vec3 col = chemical_a_color;

	// Low concentration — dark substrate with faint veins
	col = mix(col, chemical_a_color * 1.5, smoothstep(0.0, 0.15, b));

	// Medium — chemical color emerges
	col = mix(col, chemical_b_color * 0.6, smoothstep(0.15, 0.4, b));

	// High — bright active regions
	col = mix(col, chemical_b_color, smoothstep(0.4, 0.7, b));

	// Peak — emissive glow at highest concentrations
	float glow_intensity = smoothstep(0.7, 1.0, b);
	col += glow_color * glow_intensity * (1.5 + audio_energy * 2.0);

	// Edge glow — gradient magnitude approximation for reaction fronts
	float dx = reaction_diffusion(uv + vec2(0.002, 0.0), t).y - reaction_diffusion(uv - vec2(0.002, 0.0), t).y;
	float dy = reaction_diffusion(uv + vec2(0.0, 0.002), t).y - reaction_diffusion(uv - vec2(0.0, 0.002), t).y;
	float edge = length(vec2(dx, dy));
	col += glow_color * edge * 3.0 * (0.5 + audio_mid);

	// Beat pulse
	col += chemical_b_color * beat_intensity * 0.15 * b;

	// Vignette
	float vignette = 1.0 - dot(uv - 0.5, uv - 0.5) * 1.5;
	col *= vignette;

	// Tone mapping
	col = col / (col + vec3(1.0));

	ALBEDO = col;
}

shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

// Kaleidoscope — polar coordinate reflection with fbm noise source
global uniform float audio_bass;
global uniform float audio_energy;
global uniform float beat_intensity;
global uniform vec3 cursor_world_pos;
global uniform float audio_mid;
global uniform float audio_treble;
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
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	mat2 rot = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < 5; i++) {
		v += amp * noise(p);
		p = rot * p * 2.0;
		amp *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV - 0.5;
	uv.x *= 1.777; // aspect ratio

	// Polar coordinates
	float r = length(uv);
	float a = atan(uv.y, uv.x);

	// Sub-bass radial breathing — pattern breathes with low frequencies
	r *= (1.0 + audio_sub_bass * 0.2);

	// Fold count modulated by audio + kick shifts symmetry
	float folds = 6.0 + audio_bass * 4.0 + beat_kick * 2.0;
	a = mod(a, 6.28318 / folds);
	a = abs(a - 3.14159 / folds);

	// Rotation offset from cursor + mid frequency rotation
	float rot_offset = cursor_world_pos.x * 0.1;
	a += rot_offset + TIME * 0.2 + audio_mid * 0.8;

	// Back to cartesian for noise sampling
	vec2 p = vec2(cos(a), sin(a)) * r * 4.0;
	float n = fbm(p + TIME * 0.3);
	float n2 = fbm(p * 2.0 - TIME * 0.2);

	// Treble fine detail — more intricate patterns on high frequencies
	n2 *= (1.0 + audio_treble * 2.0);

	// Color
	vec3 col = vec3(0.0);
	col += vec3(0.1, 0.8, 0.6) * smoothstep(0.3, 0.7, n);
	col += vec3(0.9, 0.2, 0.7) * smoothstep(0.4, 0.8, n2);
	col += vec3(0.3, 0.5, 1.0) * smoothstep(0.5, 0.9, n * n2 * 3.0);

	// Beat flash (existing)
	col += beat_intensity * 0.4 * vec3(1.0, 0.8, 0.9);

	// Snare secondary color flash
	col += beat_snare * 0.3 * vec3(0.5, 0.8, 1.0);

	// Brilliance edge glow — bright pattern edges
	col += audio_brilliance * 0.3 * smoothstep(0.7, 0.9, n * n2 * 3.0);

	// Warmth color temperature — shift green channel toward amber
	col.g = mix(col.g, col.g * 0.8 + col.r * 0.2, audio_warmth);
	col.b = mix(col.b, col.b * 0.7, audio_warmth);

	// Presence shimmer — radial sine modulation
	col *= (1.0 + audio_presence * sin(r * 30.0 + TIME * 5.0) * 0.2);

	// Hi-hat sparkle dots
	col += step(0.96, hash(floor(UV * 150.0 + TIME * 3.0))) * beat_hihat * 0.6;

	// Energy brightness (existing)
	col *= 0.8 + audio_energy * 0.5;

	// Audio brightness luminance control
	col *= (0.7 + audio_brightness * 0.6);

	// Vignette
	col *= smoothstep(0.9, 0.3, r);

	ALBEDO = col;
}

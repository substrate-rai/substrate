shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

// Nebula — layered fbm with space color ramp and background stars
global uniform float audio_energy;
global uniform float beat_intensity;
global uniform float audio_mid;
global uniform float audio_bass;
global uniform float audio_treble;
global uniform float audio_sub_bass;
global uniform float audio_brilliance;
global uniform float audio_presence;
global uniform float beat_kick;
global uniform float beat_snare;
global uniform float audio_warmth;
global uniform float audio_brightness;
global uniform float audio_flux;

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

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	mat2 rot = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < 6; i++) {
		v += amp * noise(p);
		p = rot * p * 2.0;
		amp *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	uv.x *= 1.777;

	// audio_flux → cloud speed: modulate time by spectral flux
	float t = TIME * 0.05 * (1.0 + audio_flux * 2.0);

	// Stars in background
	float stars = 0.0;
	vec2 star_uv = uv * 100.0;
	float sv = hash(floor(star_uv));
	if (sv > 0.98) {
		float twinkle = sin(TIME * (4.0 + sv * 8.0) + sv * 50.0) * 0.4 + 0.6;
		vec2 sc = fract(star_uv) - 0.5;
		stars = exp(-dot(sc, sc) * 120.0) * twinkle;
	}
	// audio_brilliance → star sparkle
	stars *= (1.0 + audio_brilliance * 3.0);

	// Nebula layers
	float n1 = fbm(uv * 2.0 + t);
	float n2 = fbm(uv * 3.0 - t * 0.7 + vec2(5.0, 3.0));
	float n3 = fbm(uv * 4.5 + t * 0.3 + vec2(10.0, 7.0));

	// Combine layers
	float nebula = n1 * 0.5 + n2 * 0.3 + n3 * 0.2;
	// audio_sub_bass → large-scale nebula breathing: modulate smoothstep thresholds
	float breath = audio_sub_bass * 0.1;
	nebula = smoothstep(0.3 - breath, 0.8 + breath, nebula);

	// Color ramp: blue → purple → pink → gold
	// audio_warmth → palette shift toward warmer tones (orange/gold)
	float ct = nebula + audio_mid * 0.15 + audio_warmth * 0.3;
	vec3 neb_col;
	if (ct < 0.25) {
		neb_col = mix(vec3(0.05, 0.1, 0.3), vec3(0.2, 0.1, 0.5), ct / 0.25);
	} else if (ct < 0.5) {
		neb_col = mix(vec3(0.2, 0.1, 0.5), vec3(0.7, 0.2, 0.5), (ct - 0.25) / 0.25);
	} else if (ct < 0.75) {
		neb_col = mix(vec3(0.7, 0.2, 0.5), vec3(0.9, 0.6, 0.3), (ct - 0.5) / 0.25);
	} else {
		neb_col = mix(vec3(0.9, 0.6, 0.3), vec3(1.0, 0.9, 0.5), (ct - 0.75) / 0.25);
	}

	// audio_bass → color saturation boost
	float luma = dot(neb_col, vec3(0.299, 0.587, 0.114));
	vec3 saturated = neb_col + (neb_col - vec3(luma)) * 0.6;
	neb_col = mix(neb_col, saturated, audio_bass);

	// beat_snare → secondary hue shift toward blue-white
	neb_col = mix(neb_col, vec3(0.7, 0.8, 1.0), beat_snare * 0.3);

	// Compose
	vec3 col = vec3(0.01, 0.005, 0.02); // deep space
	col += vec3(0.8, 0.85, 1.0) * stars * 0.5;
	col += neb_col * nebula;

	// audio_presence → rim glow around nebula edges
	float edge = smoothstep(0.01, 0.15, nebula) * (1.0 - smoothstep(0.15, 0.5, nebula));
	col += edge * audio_presence * vec3(0.4, 0.5, 1.0) * 1.5;

	// Audio brightness (existing audio_energy behavior preserved)
	col *= 0.8 + audio_energy * 0.5;

	// Beat pulse (existing beat_intensity behavior preserved)
	col += beat_intensity * 0.15 * neb_col * nebula;

	// beat_kick → bright flash
	col += beat_kick * 0.2 * neb_col;

	// audio_brightness → overall luminance
	col *= (0.8 + audio_brightness * 0.5);

	ALBEDO = col;
}

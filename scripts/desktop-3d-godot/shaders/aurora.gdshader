shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

// Aurora borealis — flowing curtains of light
global uniform float audio_bass;
global uniform float audio_mid;
global uniform float audio_energy;
global uniform float beat_intensity;
global uniform float audio_sub_bass;
global uniform float audio_treble;
global uniform float audio_presence;
global uniform float audio_brilliance;
global uniform float beat_kick;
global uniform float beat_snare;
global uniform float beat_hihat;
global uniform float audio_warmth;
global uniform float audio_brightness;

uniform vec3 color_green : source_color = vec3(0.1, 0.9, 0.4);
uniform vec3 color_blue : source_color = vec3(0.2, 0.4, 0.95);
uniform vec3 color_purple : source_color = vec3(0.6, 0.1, 0.8);
uniform float speed = 0.15;

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
	float a = 0.5;
	mat2 rot = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = rot * p * 2.0;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	uv.x *= 1.777;
	float t = TIME * speed;

	// Aurora curtain shape — vertical bands that wave
	float curtain = 0.0;
	for (int i = 0; i < 4; i++) {
		float fi = float(i);
		float wave = sin(uv.x * (2.0 + fi * 0.7) + t * (0.8 + fi * 0.3) + fi * 1.5);
		wave += sin(uv.x * (3.5 + fi) - t * 0.5 + fi) * 0.5;
		wave += fbm(vec2(uv.x * 2.0 + t * 0.3, fi * 3.0)) * 0.8;

		float band_center = 0.3 + wave * 0.12 + fi * 0.08 + audio_sub_bass * 0.15;
		float band = exp(-pow((uv.y - band_center) * 6.0, 2.0));

		// Audio makes bands taller and more energetic
		band *= 1.0 + audio_energy * 0.5;
		band *= 1.0 + beat_intensity * 0.3;

		curtain += band * (0.6 - fi * 0.1);
	}

	// Vertical shimmer — presence boosts shimmer intensity
	float shimmer = fbm(vec2(uv.x * 8.0, uv.y * 20.0 - t * 2.0));
	shimmer *= 1.0 + audio_presence * 1.5;
	curtain *= 0.7 + shimmer * 0.5;

	// Color gradient — green at base, blue in middle, purple at top
	float color_t = uv.y + fbm(vec2(uv.x * 3.0 + t, uv.y)) * 0.3;
	color_t += audio_mid * 0.2;
	vec3 aurora_color = mix(color_green, color_blue, smoothstep(0.2, 0.5, color_t));
	aurora_color = mix(aurora_color, color_purple, smoothstep(0.5, 0.8, color_t));

	// Warmth shifts base color toward warmer greens
	aurora_color = mix(aurora_color, vec3(0.2, 1.0, 0.3), audio_warmth * 0.3);

	// Beat pulse shifts hue
	aurora_color = mix(aurora_color, color_purple * 1.5, beat_intensity * 0.3);

	// Snare hits shift color toward cyan
	aurora_color = mix(aurora_color, vec3(0.1, 0.9, 0.95), beat_snare * 0.35);

	// Stars in background
	float stars = 0.0;
	vec2 star_uv = uv * 80.0;
	float star_val = hash(floor(star_uv));
	if (star_val > 0.985) {
		float twinkle = sin(TIME * (5.0 + star_val * 10.0) + star_val * 100.0) * 0.5 + 0.5;
		twinkle *= 1.0 + audio_treble * 1.2; // treble boosts star twinkle
		vec2 star_center = fract(star_uv) - 0.5;
		stars = exp(-dot(star_center, star_center) * 80.0) * twinkle;
	}

	// Compose
	vec3 sky = vec3(0.01, 0.005, 0.03); // dark sky
	sky += vec3(0.8, 0.85, 1.0) * stars * 0.6;
	vec3 col = sky + aurora_color * curtain;

	// Kick drum bright flash
	col += beat_kick * 0.4 * vec3(0.3, 1.0, 0.7);

	// Overall luminance boost from brightness
	col *= 1.0 + audio_brightness * 0.6;

	// Bottom fade (ground)
	col *= smoothstep(0.0, 0.15, uv.y);

	ALBEDO = col;
}

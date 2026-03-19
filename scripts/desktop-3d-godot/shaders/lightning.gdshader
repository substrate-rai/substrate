shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

// Electrical arcs — directional noise lightning bolts
global uniform float beat_intensity;
global uniform float audio_treble;
global uniform float audio_energy;
global uniform float audio_bass;
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
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float lightning_bolt(vec2 uv, float seed, float jitter_speed) {
	// Vertical bolt with noise displacement
	float x_offset = 0.0;
	float amp = 0.15;
	float freq = 3.0;
	for (int i = 0; i < 5; i++) {
		x_offset += amp * (noise(vec2(uv.y * freq, seed + TIME * jitter_speed)) * 2.0 - 1.0);
		amp *= 0.6;
		freq *= 2.0;
	}

	float dist = abs(uv.x - x_offset);
	// Core + glow — audio_presence widens glow radius
	float presence_mod = 1.0 - audio_presence * 0.3;
	float core = exp(-dist * dist * 800.0 * presence_mod);
	float glow = exp(-dist * dist * 40.0 * presence_mod);
	return core + glow * 0.5;
}

void fragment() {
	vec2 uv = UV - 0.5;
	uv.x *= 1.777;

	// Jitter responds to treble and hihat
	float jitter = 1.0 + audio_treble * 3.0 + beat_hihat * 5.0;

	vec3 col = vec3(0.01, 0.005, 0.03); // dark sky

	// Distant thunder glow from sub-bass
	col += vec3(0.15, 0.1, 0.25) * audio_sub_bass * 0.3;

	// Main bolts — position varies, flash on beat
	// beat_kick forces all bolts to max flash intensity
	float flash = max(beat_intensity + beat_kick * 0.7, 0.3); // always some activity
	float seed_base = floor(TIME * 2.0 + beat_intensity * 5.0);

	// 3 main bolts
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		float bolt_x = (hash(vec2(seed_base, fi)) - 0.5) * 1.2;
		vec2 bolt_uv = vec2(uv.x - bolt_x, uv.y + 0.5);

		float seed = seed_base * 7.0 + fi * 13.0;
		float intensity = lightning_bolt(bolt_uv, seed, jitter);

		// Bolt color: white core, blue-purple glow
		vec3 bolt_col = vec3(0.7, 0.8, 1.0) * intensity;
		bolt_col += vec3(0.3, 0.2, 0.8) * intensity * 0.5;

		// audio_mid shifts bolt color toward purple-pink
		bolt_col = mix(bolt_col, vec3(0.8, 0.3, 1.0) * intensity, audio_mid * 0.5);

		// audio_warmth shifts from blue-white toward yellow-white
		bolt_col = mix(bolt_col, vec3(1.0, 0.9, 0.5) * intensity, audio_warmth * 0.4);

		// Fade by distance from bolt center and beat
		float bolt_flash = smoothstep(0.0, 0.5, flash - fi * 0.1);
		col += bolt_col * bolt_flash;
	}

	// Snare-triggered branch bolts — 2 thinner bolts on snare hits
	if (beat_snare > 0.2) {
		for (int i = 0; i < 2; i++) {
			float fi = float(i);
			float bolt_x = (hash(vec2(seed_base + 99.0, fi + 5.0)) - 0.5) * 1.5;
			vec2 bolt_uv = vec2(uv.x - bolt_x, uv.y + 0.5);

			float seed = seed_base * 11.0 + fi * 17.0 + 37.0;
			float intensity = lightning_bolt(bolt_uv, seed, jitter * 1.5);

			vec3 bolt_col = vec3(0.7, 0.8, 1.0) * intensity;
			bolt_col += vec3(0.3, 0.2, 0.8) * intensity * 0.5;

			// Apply same mid and warmth color shifts to branch bolts
			bolt_col = mix(bolt_col, vec3(0.8, 0.3, 1.0) * intensity, audio_mid * 0.5);
			bolt_col = mix(bolt_col, vec3(1.0, 0.9, 0.5) * intensity, audio_warmth * 0.4);

			col += bolt_col * beat_snare * 0.6;
		}
	}

	// Background electric haze
	float haze = noise(uv * 3.0 + TIME * 0.5) * audio_energy * 0.15;
	col += vec3(0.2, 0.15, 0.4) * haze;

	// Flash illumination on beat
	col += vec3(0.05, 0.04, 0.1) * beat_intensity * 2.0;

	// Slight cloud texture
	float clouds = noise(uv * 2.0 + vec2(TIME * 0.02, 0.0));
	clouds = smoothstep(0.3, 0.7, clouds) * 0.1;
	col += vec3(0.1, 0.08, 0.15) * clouds;

	// audio_brightness scales overall scene brightness
	col *= 1.0 + audio_brightness * 0.5;

	ALBEDO = col;
}

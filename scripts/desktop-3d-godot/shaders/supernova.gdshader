shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

// Supernova — expanding shockwave rings driven by audio
global uniform float audio_bass;
global uniform float audio_mid;
global uniform float audio_treble;
global uniform float audio_energy;
global uniform float beat_intensity;
global uniform float audio_sub_bass;
global uniform float audio_presence;

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
	vec2 uv = (UV - 0.5) * 2.0;
	uv.x *= 1.777;

	float r = length(uv);
	float a = atan(uv.y, uv.x);

	// Expanding shockwave rings — each beat spawns a new ring
	float ring1 = sin(r * 20.0 - TIME * 3.0 - audio_bass * 8.0) * 0.5 + 0.5;
	ring1 = pow(ring1, 8.0) * smoothstep(1.5, 0.1, r);

	float ring2 = sin(r * 30.0 - TIME * 5.0 - audio_mid * 6.0) * 0.5 + 0.5;
	ring2 = pow(ring2, 10.0) * smoothstep(1.2, 0.2, r);

	float ring3 = sin(r * 15.0 + TIME * 2.0 + audio_treble * 10.0) * 0.5 + 0.5;
	ring3 = pow(ring3, 6.0) * smoothstep(1.8, 0.3, r);

	// Core — pulsing star remnant
	float core_size = 0.08 + audio_sub_bass * 0.06 + beat_intensity * 0.1;
	float core = exp(-r * r / (core_size * core_size)) * (2.0 + beat_intensity * 5.0);

	// Nebula gas — fbm distorted by audio
	vec2 gas_uv = uv * 2.0 + vec2(TIME * 0.1);
	gas_uv += vec2(audio_bass, audio_mid) * 0.5;
	float gas = fbm(gas_uv + fbm(gas_uv + TIME * 0.2));
	gas *= smoothstep(1.5, 0.3, r) * (0.4 + audio_energy * 0.8);

	// Radial streaks — explosion debris
	float streaks = 0.0;
	for (int i = 0; i < 8; i++) {
		float offset = float(i) * 0.785 + audio_mid * 2.0;
		float streak = exp(-pow(mod(a + offset, 6.283) - 3.14, 2.0) * (20.0 - audio_bass * 10.0));
		streak *= smoothstep(0.1, 0.3, r) * smoothstep(1.5, 0.5, r);
		streaks += streak;
	}
	streaks *= (0.3 + audio_treble * 0.5 + beat_intensity * 0.8);

	// Colors
	vec3 col_ring1 = vec3(1.0, 0.3, 0.1) * ring1 * (1.0 + beat_intensity * 2.0);
	vec3 col_ring2 = vec3(0.2, 0.5, 1.0) * ring2 * (1.0 + audio_mid * 1.5);
	vec3 col_ring3 = vec3(0.8, 0.2, 1.0) * ring3 * audio_treble;
	vec3 col_core = mix(vec3(1.0, 0.9, 0.7), vec3(0.5, 0.7, 1.0), audio_energy) * core;
	vec3 col_gas = mix(vec3(0.8, 0.2, 0.1), vec3(0.1, 0.3, 0.8), gas) * gas * 0.6;
	vec3 col_streaks = mix(vec3(1.0, 0.6, 0.2), vec3(0.4, 0.6, 1.0), audio_presence) * streaks;

	// Stars
	float stars = 0.0;
	vec2 star_uv = uv * 80.0;
	float sv = hash(floor(star_uv));
	if (sv > 0.988) {
		vec2 sc = fract(star_uv) - 0.5;
		stars = exp(-dot(sc, sc) * 120.0) * (0.5 + audio_treble);
	}

	vec3 col = vec3(0.01, 0.005, 0.02);
	col += col_ring1 + col_ring2 + col_ring3;
	col += col_core + col_gas + col_streaks;
	col += vec3(0.7, 0.8, 1.0) * stars * 0.3;

	ALBEDO = col;
}

shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

global uniform float audio_bass;
global uniform float audio_energy;
global uniform float beat_intensity;

// FitzHugh-Nagumo Spiral Waves
// Excitable medium producing cardiac-like spiral wave breakup
// Single-pass approximation of the reaction-diffusion PDE

vec3 pal(float t) {
	return vec3(0.5) + vec3(0.5) * cos(TAU * (vec3(1.0, 0.8, 0.6) * t + vec3(0.0, 0.1, 0.3)));
}

// Hash for seeding
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float t = TIME;
	float energy = audio_energy;
	float beat = beat_intensity;

	vec2 p = uv * 8.0;

	// Simulate spiral wave field
	// Multiple rotating spiral sources
	float u = 0.0;  // excitation variable
	float v = 0.0;  // recovery variable

	// Place spiral wave centers
	for (int i = 0; i < 5; i++) {
		float fi = float(i);
		vec2 center = vec2(
			sin(fi * 1.7 + t * 0.1) * 3.0,
			cos(fi * 2.3 + t * 0.08) * 3.0
		);

		vec2 dp = p - center;
		float r = length(dp);
		float angle = atan(dp.y, dp.x);

		// Spiral wave: phase depends on radius and angle
		float spiral_speed = 1.5 + fi * 0.3;
		float spiral_arms = 1.0 + float(i % 3);
		float phase = r * 2.0 - angle * spiral_arms - t * spiral_speed;

		// Excitation wave with sharp front, slow recovery
		float wave = sin(phase);
		float excitation = smoothstep(-0.1, 0.1, wave) * exp(-r * 0.15);

		// Recovery (slower wave following excitation)
		float recovery = smoothstep(-0.1, 0.1, sin(phase - 1.5)) * exp(-r * 0.15);

		u += excitation;
		v += recovery;
	}

	// FitzHugh-Nagumo-style coupling
	float u_cubed = u * u * u;
	float fhn = u - u_cubed / 3.0 - v;

	// Wave front detection (sharp gradient = wavefront)
	float du_dx = dFdx(u);
	float du_dy = dFdy(u);
	float wavefront = length(vec2(du_dx, du_dy));

	// Color mapping
	vec3 col = vec3(0.02, 0.01, 0.05);

	// Excitation: hot colors
	vec3 excite_col = mix(
		vec3(0.1, 0.0, 0.3),    // resting: deep purple
		vec3(1.0, 0.3, 0.05),   // excited: hot orange
		clamp(u, 0.0, 1.0)
	);

	// Recovery: cool colors
	vec3 recover_col = mix(
		vec3(0.0, 0.0, 0.0),
		vec3(0.1, 0.4, 0.8),   // recovering: blue
		clamp(v, 0.0, 1.0)
	);

	col += excite_col * 0.6 + recover_col * 0.3;

	// Wavefront glow (bright white at wave edges)
	col += vec3(1.0, 0.95, 0.8) * clamp(wavefront * 0.3, 0.0, 1.0);

	// Spiral core glow
	for (int i = 0; i < 5; i++) {
		float fi = float(i);
		vec2 center = vec2(
			sin(fi * 1.7 + t * 0.1) * 3.0,
			cos(fi * 2.3 + t * 0.08) * 3.0
		);
		float core_d = length(p - center);
		col += pal(fi * 0.2 + 0.5) * exp(-core_d * core_d * 0.5) * 0.15;
	}

	// Audio reactivity (color only)
	col *= 1.0 + energy * 0.3;
	col += vec3(1.0, 0.5, 0.2) * beat * 0.08;

	// Vignette + tone map
	col *= 1.0 - dot(uv, uv) * 0.2;
	col = col / (col + vec3(1.0));

	ALBEDO = col;
}

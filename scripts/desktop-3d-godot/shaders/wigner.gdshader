shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

global uniform float audio_bass;
global uniform float audio_energy;
global uniform float beat_intensity;

// Wigner Function — Quantum Phase Space
// Quasiprobability distribution W(x,p) for a quantum harmonic oscillator
// Negative probabilities shown as cool colors — genuinely alien

const int N_STATES = 6;

vec3 pal(float t) {
	return vec3(0.5) + vec3(0.5) * cos(TAU * (vec3(1.0, 0.7, 0.4) * t + vec3(0.0, 0.15, 0.2)));
}

// Laguerre polynomial L_n(x) via recurrence
float laguerre(int n, float x) {
	if (n == 0) return 1.0;
	if (n == 1) return 1.0 - x;
	float l0 = 1.0, l1 = 1.0 - x, l2 = 0.0;
	for (int i = 2; i <= n; i++) {
		float fi = float(i);
		l2 = ((2.0 * fi - 1.0 - x) * l1 - (fi - 1.0) * l0) / fi;
		l0 = l1; l1 = l2;
	}
	return l1;
}

// Wigner function for nth energy eigenstate of harmonic oscillator
// W_n(x,p) = (-1)^n / pi * L_n(4*(x^2+p^2)) * exp(-2*(x^2+p^2))
float wigner_n(int n, float x, float p) {
	float r2 = x * x + p * p;
	float sign = (n % 2 == 0) ? 1.0 : -1.0;
	return sign / PI * laguerre(n, 4.0 * r2) * exp(-2.0 * r2);
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float t = TIME;
	float energy = audio_energy;
	float beat = beat_intensity;

	// Phase space coordinates
	float x = uv.x * 3.0;
	float p = uv.y * 3.0;

	// Superposition of states with time-dependent phases
	float W = 0.0;
	for (int n = 0; n < N_STATES; n++) {
		float fn = float(n);
		// Time-dependent coefficient (quantum beating)
		float phase = fn * t * 0.3;
		float coeff = cos(phase + fn * 1.5) * exp(-fn * 0.2);
		W += coeff * wigner_n(n, x, p);
	}

	// Normalize for display
	W *= 3.0;

	// Color mapping: positive = warm, negative = cool (quantum weirdness!)
	vec3 col = vec3(0.02, 0.01, 0.04);

	if (W > 0.0) {
		float intensity = min(W, 1.0);
		col += mix(vec3(0.1, 0.0, 0.0), vec3(1.0, 0.6, 0.1), pow(intensity, 0.6)) * intensity;
	} else {
		float intensity = min(-W, 1.0);
		col += mix(vec3(0.0, 0.0, 0.1), vec3(0.2, 0.4, 1.0), pow(intensity, 0.6)) * intensity;
		// Negative probability glow — the quantum signature
		col += vec3(0.1, 0.2, 0.8) * intensity * 0.3;
	}

	// Phase space flow lines (classical trajectories are circles)
	float r = length(vec2(x, p));
	float flow_angle = atan(p, x);
	float flow = sin(flow_angle * 8.0 - t * 2.0) * 0.5 + 0.5;
	float flow_mask = exp(-abs(W) * 5.0); // only visible where W is near zero
	col += vec3(0.3, 0.5, 0.3) * flow * flow_mask * 0.05;

	// Zero contour glow (boundary between positive and negative)
	float zero_dist = abs(W);
	float zero_glow = exp(-zero_dist * 30.0) * 0.3;
	col += vec3(1.0, 1.0, 1.0) * zero_glow;

	// Concentric classical orbit indicators
	float orbit_ring = abs(fract(r * r * 0.5) - 0.5) * 2.0;
	orbit_ring = smoothstep(0.05, 0.0, 1.0 - orbit_ring);
	col += vec3(0.2, 0.3, 0.2) * orbit_ring * 0.08;

	// Audio
	col *= 1.0 + energy * 0.2;
	col += vec3(1.0) * beat * 0.03;

	// Vignette + tone map
	col *= 1.0 - dot(uv, uv) * 0.2;
	col = col / (col + vec3(1.0));

	ALBEDO = col;
}

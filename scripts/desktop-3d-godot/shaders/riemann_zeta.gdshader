shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

global uniform float audio_bass;
global uniform float audio_energy;
global uniform float beat_intensity;

// Riemann Zeta Function on the Critical Strip
// Domain coloring of zeta(s) via Borwein-accelerated Dirichlet eta series
// Non-trivial zeros appear as phase singularities

const int N_TERMS = 40;

vec3 pal(float t) {
	return vec3(0.5) + vec3(0.5) * cos(TAU * (vec3(1.0, 1.0, 1.0) * t + vec3(0.0, 0.33, 0.67)));
}

// Complex ops
vec2 cmul(vec2 a, vec2 b) { return vec2(a.x*b.x - a.y*b.y, a.x*b.y + a.y*b.x); }
vec2 cdiv(vec2 a, vec2 b) { float d = dot(b,b); return vec2(dot(a,b), a.y*b.x - a.x*b.y) / d; }

// Complex power: n^(-s) = exp(-s * ln(n))
vec2 cpow_real_base(float base, vec2 s) {
	float ln_base = log(base);
	float mag = exp(-s.x * ln_base);
	float phase = -s.y * ln_base;
	return mag * vec2(cos(phase), sin(phase));
}

// Dirichlet eta via Borwein acceleration (converges on critical strip)
vec2 eta(vec2 s) {
	// Precompute Borwein coefficients d_k = sum_{i=0}^{k} C(N,i)
	// For N=40, d_k approaches d_N = 2^N very quickly
	// We use the simplified Borwein method
	float d_prev = 0.0;
	vec2 result = vec2(0.0);
	float sign_k = 1.0;
	float binom = 1.0; // C(N_TERMS, 0)

	// Compute d_N = sum C(N,i) for i=0..N
	float d_N = 0.0;
	float bc = 1.0;
	for (int i = 0; i <= N_TERMS; i++) {
		d_N += bc;
		bc *= float(N_TERMS - i) / float(i + 1);
	}

	// Main sum
	bc = 1.0;
	float d_k = 0.0;
	for (int k = 0; k <= N_TERMS; k++) {
		d_k += bc;
		float coeff = sign_k * (d_k - d_N) / d_N;
		vec2 term = cpow_real_base(float(k + 1), s);
		result += coeff * term;
		sign_k *= -1.0;
		bc *= float(N_TERMS - k) / float(k + 1);
	}

	return -result;
}

// zeta(s) = eta(s) / (1 - 2^(1-s))
vec2 zeta(vec2 s) {
	vec2 eta_val = eta(s);
	vec2 pow2 = cpow_real_base(2.0, vec2(1.0, 0.0) - s);
	vec2 denom = vec2(1.0, 0.0) - pow2;
	return cdiv(eta_val, denom);
}

// Domain coloring: hue from phase, brightness from magnitude
vec3 domain_color(vec2 z) {
	float phase = atan(z.y, z.x) / TAU + 0.5;
	float mag = length(z);
	float log_mag = log(mag + 1.0);

	// Hue from phase
	vec3 col = pal(phase);

	// Brightness modulation from magnitude (log scale)
	float brightness = 1.0 - exp(-log_mag * 0.5);
	brightness = mix(0.15, 1.0, brightness);

	// Contour lines on |zeta| = const
	float contour = abs(fract(log_mag * 0.5) - 0.5) * 2.0;
	contour = smoothstep(0.0, 0.05, contour);

	// Phase lines
	float phase_lines = abs(fract(phase * 8.0) - 0.5) * 2.0;
	phase_lines = smoothstep(0.0, 0.05, phase_lines);

	col *= brightness * mix(0.7, 1.0, contour * phase_lines);

	return col;
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float t = TIME;
	float energy = audio_energy;
	float beat = beat_intensity;

	// View: critical strip 0 < Re(s) < 1, Im(s) scrolling
	// Slowly scroll up the critical strip to reveal zeros
	float scroll = t * 2.0;
	vec2 s = vec2(
		uv.x * 1.5 + 0.5,           // Re(s) from -1 to 2
		uv.y * 15.0 + scroll         // Im(s) scrolling upward
	);

	vec2 z = zeta(s);
	vec3 col = domain_color(z);

	// Highlight the critical line Re(s) = 0.5
	float crit_line = smoothstep(0.02, 0.0, abs(s.x - 0.5));
	col += vec3(1.0, 0.85, 0.3) * crit_line * 0.15;

	// Glow near zeros (where |zeta| is very small)
	float mag = length(z);
	float zero_glow = exp(-mag * 5.0) * 0.8;
	col += vec3(1.0, 1.0, 1.0) * zero_glow;

	// Audio
	col *= 1.0 + energy * 0.2;
	col += vec3(1.0) * beat * 0.03;

	// Vignette
	col *= 1.0 - dot(uv, uv) * 0.2;

	// Tone map
	col = col / (col + vec3(1.0));

	ALBEDO = col;
}

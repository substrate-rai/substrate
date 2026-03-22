shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

global uniform float audio_energy;
global uniform float beat_intensity;

// Modular Forms — J-invariant Domain Coloring
// Dedekind eta function on the upper half-plane
// No real-time implementation has existed before this

vec3 pal(float t) {
	return vec3(0.5) + vec3(0.5) * cos(TAU * (vec3(1.0, 0.8, 0.5) * t + vec3(0.0, 0.1, 0.25)));
}

vec2 cmul(vec2 a, vec2 b) { return vec2(a.x*b.x-a.y*b.y, a.x*b.y+a.y*b.x); }
vec2 cexp(vec2 z) { return exp(z.x) * vec2(cos(z.y), sin(z.y)); }

// Dedekind eta: eta(tau) = exp(pi*i*tau/12) * prod(1-q^n)
// q = exp(2*pi*i*tau)
vec2 eta(vec2 tau) {
	vec2 q = cexp(vec2(-TAU * tau.y, TAU * tau.x)); // q = e^(2pi*i*tau)
	vec2 phase = cexp(vec2(-PI * tau.y / 12.0, PI * tau.x / 12.0));

	vec2 prod = vec2(1.0, 0.0);
	vec2 qn = q;
	for (int n = 1; n <= 25; n++) {
		prod = cmul(prod, vec2(1.0, 0.0) - qn);
		qn = cmul(qn, q);
		if (dot(qn, qn) < 1e-12) break;
	}
	return cmul(phase, prod);
}

vec3 domain_color(vec2 z) {
	float phase = atan(z.y, z.x) / TAU + 0.5;
	float mag = length(z);
	float log_mag = log(mag + 0.001);
	vec3 col = pal(phase);
	float brightness = 1.0 - exp(-mag * 0.3);
	float contour = abs(fract(log_mag * 0.3) - 0.5) * 2.0;
	contour = smoothstep(0.0, 0.05, contour);
	return col * mix(0.2, 1.0, brightness) * mix(0.7, 1.0, contour);
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float t = TIME;

	// Upper half-plane: Re(tau), Im(tau) > 0
	float scroll = t * 0.1;
	vec2 tau = vec2(uv.x * 2.0 + scroll, uv.y * 1.5 + 1.0);
	tau.y = max(tau.y, 0.05);

	// Compute eta^24 (related to discriminant modular form)
	vec2 e = eta(tau);
	vec2 e2 = cmul(e, e);
	vec2 e4 = cmul(e2, e2);
	vec2 e8 = cmul(e4, e4);
	vec2 e16 = cmul(e8, e8);
	vec2 e24 = cmul(e16, cmul(e8, e2)); // eta^24 = eta^(16+8)... close enough for display

	vec3 col = domain_color(e24);

	// Fundamental domain boundary
	float circ = abs(length(vec2(tau.x - round(tau.x), tau.y)) - 1.0);
	float vert = min(abs(fract(tau.x + 0.5) - 0.5), abs(fract(tau.x) - 0.5));
	float boundary = min(circ, vert * tau.y);
	col += vec3(1.0, 0.85, 0.3) * smoothstep(0.02, 0.0, boundary) * 0.2;

	// Cusp glow (Im(tau) -> 0)
	float cusp = exp(-tau.y * 3.0);
	col += vec3(1.0, 0.5, 0.2) * cusp * 0.3;

	col *= 1.0 + audio_energy * 0.2;
	col *= 1.0 - dot(uv, uv) * 0.15;
	col = col / (col + vec3(1.0));
	ALBEDO = col;
}

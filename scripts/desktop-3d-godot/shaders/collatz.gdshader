shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

global uniform float audio_bass;
global uniform float audio_mid;
global uniform float audio_energy;
global uniform float beat_intensity;

// Collatz conjecture extended to the complex plane
// f(z) = (1/4)(2 + 7z - (2+5z)*cos(pi*z))
// This interpolates the integer Collatz map: even → z/2, odd → 3z+1
// Color by "stopping time" — iterations until |z| > escape or converges

const int MAX_ITER = 80;
const float ESCAPE = 100.0;

// ── Cosine palette ──
vec3 pal(float t) {
	vec3 a = vec3(0.5, 0.5, 0.5);
	vec3 b = vec3(0.5, 0.5, 0.5);
	vec3 c = vec3(1.0, 1.0, 1.0);
	vec3 d = vec3(0.0, 0.33, 0.67);
	return a + b * cos(TAU * (c * t + d));
}

// ── Complex multiplication ──
vec2 cmul(vec2 a, vec2 b) {
	return vec2(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
}

// ── Complex cosine: cos(z) = (e^(iz) + e^(-iz)) / 2 ──
vec2 ccos(vec2 z) {
	// cos(x+iy) = cos(x)*cosh(y) - i*sin(x)*sinh(y)
	return vec2(cos(z.x) * cosh(z.y), -sin(z.x) * sinh(z.y));
}

// ── Complex Collatz map ──
// f(z) = (1/4)(2 + 7z - (2+5z)*cos(pi*z))
vec2 collatz(vec2 z) {
	vec2 piz = vec2(PI * z.x, PI * z.y);
	vec2 cos_piz = ccos(piz);

	// (2 + 5z)
	vec2 term1 = vec2(2.0 + 5.0 * z.x, 5.0 * z.y);

	// (2 + 5z) * cos(pi*z)
	vec2 term2 = cmul(term1, cos_piz);

	// 2 + 7z - (2+5z)*cos(pi*z)
	vec2 num = vec2(2.0 + 7.0 * z.x - term2.x, 7.0 * z.y - term2.y);

	// / 4
	return num * 0.25;
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float t = TIME;

	float energy = audio_energy;
	float beat = beat_intensity;

	// Viewport: centered on origin, zoom animated slowly
	float zoom = 2.5 + sin(t * 0.05) * 0.5;
	vec2 center = vec2(0.0, 0.0);

	// Slow pan through interesting regions
	center.x += sin(t * 0.02) * 1.0;
	center.y += cos(t * 0.03) * 0.5;

	vec2 z = uv * zoom + center;

	// ── Iterate the Collatz map ──
	float stop_time = float(MAX_ITER);
	float smooth_val = 0.0;
	vec2 orbit_trap = vec2(1e10);
	float min_dist_to_int = 1e10;

	for (int i = 0; i < MAX_ITER; i++) {
		z = collatz(z);

		// Track orbit trap (distance to origin)
		float trap_d = length(z);
		if (trap_d < length(orbit_trap)) {
			orbit_trap = z;
		}

		// Track minimum distance to nearest integer (Collatz integers are the attractors)
		float nearest_int = round(z.x);
		float dist_int = length(z - vec2(nearest_int, 0.0));
		min_dist_to_int = min(min_dist_to_int, dist_int);

		// Escape condition
		if (trap_d > ESCAPE) {
			stop_time = float(i) - log(log(trap_d) / log(ESCAPE)) / log(2.0);
			break;
		}

		// Convergence to a cycle (close to integers 1, 2, 4)
		if (abs(z.y) < 0.001 && (abs(z.x - 1.0) < 0.01 || abs(z.x - 2.0) < 0.01 || abs(z.x - 4.0) < 0.01)) {
			stop_time = float(i);
			break;
		}
	}

	// ── Coloring ──
	vec3 col = vec3(0.01, 0.005, 0.03);  // deep background

	// Stopping time → palette
	float palette_t = fract(stop_time * 0.03 + t * 0.02);
	vec3 stop_col = pal(palette_t);

	// Intensity based on how quickly it escaped/converged
	float intensity = 1.0 - stop_time / float(MAX_ITER);
	intensity = pow(intensity, 0.7);

	col += stop_col * intensity * 0.8;

	// Orbit trap coloring — distance to origin gives structure-following color
	float trap_val = 1.0 - clamp(length(orbit_trap) * 0.1, 0.0, 1.0);
	col += pal(trap_val * 0.5 + 0.3) * trap_val * 0.3;

	// Integer proximity glow — highlight the integer backbone
	float int_glow = exp(-min_dist_to_int * 8.0);
	col += vec3(1.0, 0.85, 0.3) * int_glow * 0.15;

	// ── Inverse-distance glow on convergence boundaries ──
	float edge = abs(stop_time - round(stop_time));
	float edge_glow = clamp(0.01 / (edge + 0.01), 0.0, 1.0);
	col += pal(stop_time * 0.05) * edge_glow * 0.1;

	// ── Audio reactivity (color only) ──
	col *= 1.0 + energy * 0.3;
	col += vec3(1.0, 0.95, 0.9) * beat * 0.05;

	// ── Vignette ──
	float vig = 1.0 - dot(uv, uv) * 0.25;
	col *= vig;

	// ── Tone mapping ──
	col = col / (col + vec3(1.0));

	ALBEDO = col;
}

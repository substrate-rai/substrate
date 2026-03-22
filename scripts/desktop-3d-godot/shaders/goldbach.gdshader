shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

global uniform float audio_bass;
global uniform float audio_energy;
global uniform float beat_intensity;

// Goldbach Comet — Number Theory as Art
// For each even number n, count how many ways it can be written as sum of two primes
// Plot g(n) vs n — produces comet-like structure with tail rays

const int MAX_N = 2000;

vec3 pal(float t) {
	return vec3(0.5) + vec3(0.5) * cos(TAU * (vec3(1.0, 0.8, 0.5) * t + vec3(0.0, 0.1, 0.25)));
}

// Simple primality test (sufficient for shader range)
bool is_prime(int n) {
	if (n < 2) return false;
	if (n < 4) return true;
	if (n % 2 == 0 || n % 3 == 0) return false;
	for (int i = 5; i * i <= n; i += 6) {
		if (n % i == 0 || n % (i + 2) == 0) return false;
	}
	return true;
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float t = TIME;
	float energy = audio_energy;
	float beat = beat_intensity;

	// Scroll through the number line
	float scroll = t * 20.0;

	// Map pixel to (n, g(n)) space
	float n_f = (uv.x * 0.5 + 0.5) * float(MAX_N) + scroll;
	float g_max = 150.0;  // max partition count for display
	float g_f = (uv.y * 0.5 + 0.5) * g_max;

	int n = int(n_f);
	n = n - (n % 2);  // round to nearest even

	// Count Goldbach partitions
	int count = 0;
	if (n >= 4) {
		for (int i = 2; i <= n / 2; i++) {
			if (is_prime(i) && is_prime(n - i)) {
				count++;
			}
		}
	}

	float target_g = float(count);

	// Point proximity
	float dist = abs(g_f - target_g);

	vec3 col = vec3(0.01, 0.005, 0.02);

	// Comet points
	float point_glow = exp(-dist * dist * 0.5);
	col += pal(target_g / g_max + t * 0.01) * point_glow * 0.8;

	// Tail rays (lines from origin through points at specific slopes)
	// The rays correspond to small primes p: slope relates to p
	float ray_accum = 0.0;
	for (int p = 0; p < 8; p++) {
		float fi = float(p);
		float slope = (fi + 1.0) * 0.08;
		float ray_dist = abs(g_f - n_f * slope);
		ray_accum += exp(-ray_dist * ray_dist * 0.01) * 0.08;
	}
	col += vec3(0.3, 0.5, 0.8) * ray_accum;

	// Scatter glow for nearby points
	float scatter = exp(-dist * 0.3) * 0.1;
	col += pal(float(n) * 0.001) * scatter;

	// Audio
	col *= 1.0 + energy * 0.2;
	col += vec3(1.0, 0.9, 0.7) * beat * 0.04;

	// Vignette + tone map
	col *= 1.0 - dot(uv, uv) * 0.15;
	col = col / (col + vec3(1.0));

	ALBEDO = col;
}

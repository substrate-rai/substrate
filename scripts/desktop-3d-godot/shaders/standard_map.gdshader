shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

global uniform float audio_bass;
global uniform float audio_energy;
global uniform float beat_intensity;

// Chirikov Standard Map — KAM Tori Breakup
// The most beautiful transition from order to chaos in all of mathematics
// p' = p + K*sin(theta), theta' = theta + p' (mod 2pi)
// Animated K parameter sweeps from integrable to chaotic

const int N_ORBITS = 80;
const int ORBIT_LEN = 200;

vec3 pal(float t) {
	return vec3(0.5) + vec3(0.5) * cos(TAU * (vec3(0.8, 1.0, 0.6) * t + vec3(0.0, 0.1, 0.2)));
}

float hash(float n) { return fract(sin(n) * 43758.5453); }

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float t = TIME;
	float energy = audio_energy;

	// Phase space: theta (0 to 2pi), p (0 to 2pi)
	vec2 phase_pt = (uv * 0.5 + 0.5) * TAU;

	// Animated K: slowly sweep from order (K~0) through chaos (K~6)
	float K = (sin(t * 0.04) * 0.5 + 0.5) * 6.0 + 0.1;

	// Density accumulation: how many orbits pass near this pixel
	float density = 0.0;
	float closest_orbit = 1e10;
	float closest_orbit_idx = 0.0;

	for (int orbit = 0; orbit < N_ORBITS; orbit++) {
		float fi = float(orbit);
		// Initial conditions spread across phase space
		float theta = hash(fi * 1.1) * TAU;
		float p = hash(fi * 2.3 + 0.5) * TAU;

		for (int step = 0; step < ORBIT_LEN; step++) {
			// Standard map iteration
			p = p + K * sin(theta);
			theta = theta + p;

			// Wrap to [0, 2pi)
			theta = mod(theta, TAU);
			p = mod(p, TAU);

			// Distance to this pixel in phase space
			vec2 orbit_pt = vec2(theta, p);
			vec2 dp = phase_pt - orbit_pt;
			// Wrap distance (torus topology)
			dp = min(abs(dp), TAU - abs(dp));
			float d = length(dp);

			if (d < closest_orbit) {
				closest_orbit = d;
				closest_orbit_idx = fi;
			}

			// Accumulate density
			float pixel_size = TAU / 400.0;
			if (d < pixel_size * 2.0) {
				density += 1.0;
			}
		}
	}

	// Color
	vec3 col = vec3(0.01, 0.005, 0.02);

	// Density coloring (log scale)
	float log_density = log(density + 1.0) / 4.0;
	col += pal(log_density + closest_orbit_idx * 0.01 + t * 0.01) * min(log_density, 1.0) * 0.8;

	// KAM tori glow (invariant curves are bright)
	float tori_bright = smoothstep(0.0, 0.3, log_density) * (1.0 - smoothstep(0.3, 3.0, log_density));
	col += vec3(0.3, 0.6, 1.0) * tori_bright * 0.3;

	// Chaotic sea (high density, spread)
	float chaos = smoothstep(2.0, 5.0, log_density);
	col += vec3(0.8, 0.2, 0.1) * chaos * 0.2;

	// Show K value subtly (bottom bar)
	if (uv.y < -0.95) {
		float k_bar = K / 6.5;
		if (uv.x * 0.5 + 0.5 < k_bar) {
			col += vec3(0.3, 0.3, 0.5) * 0.3;
		}
	}

	// Audio
	col *= 1.0 + energy * 0.2;

	// Tone map
	col = col / (col + vec3(1.0));

	ALBEDO = col;
}

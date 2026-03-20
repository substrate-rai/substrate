shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

// Apollonian Gasket — circle inversion fractal
// Infinite circle packing with sacred geometry qualities

global uniform float audio_bass;
global uniform float audio_mid;
global uniform float audio_treble;
global uniform float audio_energy;
global uniform float beat_intensity;
global uniform vec3 cursor_world_pos;

const float PHI = 1.61803398;

vec2 rot2(vec2 p, float a) {
	float c = cos(a), s = sin(a);
	return vec2(p.x * c - p.y * s, p.x * s + p.y * c);
}

vec3 cosPalette(float t, vec3 a, vec3 b, vec3 c, vec3 d) {
	return a + b * cos(TAU * (c * t + d));
}

vec3 gasketPalette(float t) {
	return cosPalette(t,
		vec3(0.4, 0.25, 0.5),
		vec3(0.5, 0.4, 0.4),
		vec3(0.8, 0.9, 1.1),
		vec3(0.05, 0.15, 0.3)
	);
}

// Circle inversion: invert point p through circle at origin with radius r
vec2 circleInversion(vec2 p, float r) {
	return p * r * r / dot(p, p);
}

// Apollonian gasket via iterated circle inversions
// Returns: x = min distance to any circle edge, y = iteration depth, z = circle radius at closest
vec3 apollonian(vec2 p, int iterations, float t) {
	float min_dist = 1e9;
	float min_radius = 1.0;
	float depth = 0.0;

	// Main bounding circle
	float outer_r = 1.0;
	float d_outer = abs(length(p) - outer_r);
	min_dist = min(min_dist, d_outer);

	// Three initial tangent circles (Descartes circle theorem)
	// For the standard gasket: three mutually tangent circles inside a larger circle
	float inner_r = outer_r / (1.0 + 2.0 / sqrt(3.0));
	float offset = outer_r - inner_r;

	vec2 centers[3];
	for (int i = 0; i < 3; i++) {
		float a = float(i) * TAU / 3.0 + t * 0.05;
		centers[i] = vec2(cos(a), sin(a)) * offset;
	}

	// Iterative inversion
	vec2 z = p;
	for (int i = 0; i < iterations; i++) {
		// Invert through each of the three circles
		float best = 1e9;
		int best_idx = 0;

		for (int j = 0; j < 3; j++) {
			vec2 diff = z - centers[j];
			float d = length(diff) - inner_r;
			if (abs(d) < best) {
				best = abs(d);
				best_idx = j;
			}
		}

		// Invert through the nearest circle
		vec2 diff = z - centers[best_idx];
		float d = length(diff);
		if (d > 0.001) {
			z = centers[best_idx] + diff * inner_r * inner_r / (d * d);
		}

		// Track minimum distance to circle edges
		for (int j = 0; j < 3; j++) {
			float cd = abs(length(z - centers[j]) - inner_r);
			if (cd < min_dist) {
				min_dist = cd;
				min_radius = inner_r;
				depth = float(i);
			}
		}
		// Also check distance to outer circle
		float od = abs(length(z) - outer_r);
		if (od < min_dist) {
			min_dist = od;
			min_radius = outer_r;
			depth = float(i);
		}
	}

	return vec3(min_dist, depth, min_radius);
}

// Simpler approach: distance field from recursive circle packing
float circlePackingSDF(vec2 p, int depth_max, float t) {
	float d = 1e9;
	float scale = 1.0;
	vec2 z = p;

	for (int i = 0; i < depth_max; i++) {
		// Map into triangle domain
		float a = atan(z.y, z.x);
		float sector = TAU / 3.0;
		a = mod(a + sector * 0.5, sector) - sector * 0.5;
		z = vec2(cos(a), sin(a)) * length(z);

		// Three-circle inversion
		float r = 0.5;
		vec2 c = vec2(0.5, 0.0);
		vec2 dz = z - c;
		float dl = length(dz);

		// Circle SDF
		d = min(d, (abs(dl - r)) / scale);

		// Invert if inside
		if (dl < r) {
			z = c + dz * r * r / (dl * dl);
			scale *= r * r / (dl * dl);
		} else {
			break;
		}
	}

	// Outer circle
	d = min(d, abs(length(p) - 1.0));

	return d;
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float t = TIME;

	float bass = audio_bass;
	float mid = audio_mid;
	float treble = audio_treble;
	float energy = audio_energy;
	float beat = beat_intensity;

	// Slow rotation
	vec2 p = rot2(uv * 1.3, t * 0.04);
	// No breathing — keep geometry stable

	vec3 col = vec3(0.02, 0.01, 0.05);

	// ── Primary gasket ──
	vec3 gasket = apollonian(p, 12, t);
	float dist = gasket.x;
	float depth = gasket.y;
	float radius = gasket.z;

	// Edge rendering with AA
	float fw = fwidth(dist);
	float edge = smoothstep(0.008 + fw, 0.002, dist);

	// Color by depth
	float depth_norm = depth / 12.0;
	vec3 edge_col = gasketPalette(depth_norm + t * 0.03);
	col += edge_col * edge * 0.6;

	// Glow around edges
	float glow = exp(-dist * dist * 2000.0);
	col += gasketPalette(depth_norm + 0.2) * glow * 0.3;

	// ── Circle packing overlay ──
	float cp = circlePackingSDF(rot2(p, -t * 0.03), 8, t);
	float cp_edge = smoothstep(0.006 + fwidth(cp), 0.001, cp);
	col += vec3(0.6, 0.4, 1.0) * cp_edge * 0.2;
	// Soft glow
	col += vec3(0.3, 0.2, 0.5) * exp(-cp * cp * 3000.0) * 0.15;

	// ── Concentric rings ──
	float r = length(p);
	for (int i = 1; i < 6; i++) {
		float ring_r = float(i) * 0.2;
		float ring = abs(r - ring_r);
		float ring_line = smoothstep(0.004 + fwidth(ring), 0.001, ring);
		col += vec3(0.15, 0.1, 0.3) * ring_line * 0.08;
	}

	// ── Radial symmetry lines ──
	float angle = atan(p.y, p.x);
	for (int i = 0; i < 6; i++) {
		float target = float(i) * TAU / 6.0;
		float diff = abs(mod(angle - target + PI, TAU) - PI);
		float radial = smoothstep(0.012 + fwidth(diff), 0.008, diff);
		col += vec3(0.2, 0.15, 0.35) * radial * 0.06 * smoothstep(0.0, 0.15, r);
	}

	// ── Audio: energy pulses from center ──
	float pulse_r = fract(t * 0.15 + beat * 0.1) * 1.5;
	float pulse = smoothstep(0.04, 0.0, abs(r - pulse_r)) * (1.0 - pulse_r / 1.5);
	col += vec3(0.5, 0.3, 0.8) * pulse * 0.3 * (1.0 + beat * 2.0);

	// ── Beat flash ──
	col += vec3(0.6, 0.4, 1.0) * beat * 0.1;

	// ── Center glow ──
	float center_glow = exp(-r * r * 5.0) * (0.3 + energy * 0.5);
	col += vec3(0.8, 0.6, 1.0) * center_glow * 0.25;

	// Vignette
	float vig = 1.0 - dot(uv, uv) * 0.3;
	col *= vig;

	// Tone mapping
	col = col / (col + vec3(1.0));

	ALBEDO = col;
}

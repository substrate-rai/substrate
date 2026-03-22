shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

global uniform float audio_bass;
global uniform float audio_energy;
global uniform float beat_intensity;

// P-adic Numbers / Berkovich Space Visualization
// Fractal tree structure of p-adic integers
// Each digit maps to a rotation in nested circles, scaling by 1/p

const int MAX_DEPTH = 8;

vec3 pal(float t) {
	return vec3(0.5) + vec3(0.5) * cos(TAU * (vec3(0.8, 1.0, 0.6) * t + vec3(0.1, 0.2, 0.0)));
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float t = TIME;
	float energy = audio_energy;
	float beat = beat_intensity;

	// Animated prime
	float p_cycle = mod(t * 0.1, 4.0);
	int p_val;
	if (p_cycle < 1.0) p_val = 2;
	else if (p_cycle < 2.0) p_val = 3;
	else if (p_cycle < 3.0) p_val = 5;
	else p_val = 7;
	float fp = float(p_val);

	vec3 col = vec3(0.01, 0.005, 0.03);

	// Draw the p-adic tree
	// Start from center, branch into p children at each level
	// Each branch is a circle of radius 1/p^level

	vec2 center = vec2(0.0);
	float radius = 0.8;

	// Recursive tree traversal (unrolled)
	for (int depth = 0; depth < MAX_DEPTH; depth++) {
		float fd = float(depth);
		float child_radius = radius / fp;

		for (int digit = 0; digit < 7; digit++) { // max p=7
			if (digit >= p_val) break;

			float angle = float(digit) * TAU / fp + fd * 0.3 + t * 0.05 * (1.0 + fd * 0.2);
			vec2 child_center = center + vec2(cos(angle), sin(angle)) * radius * 0.6;

			// Circle at this node
			float d = abs(length(uv - child_center) - child_radius);
			float ring = smoothstep(0.008, 0.0, d);
			col += pal(fd / float(MAX_DEPTH) + float(digit) / fp) * ring * (0.5 - fd * 0.05);

			// Glow
			float glow = clamp(0.003 / (d + 0.001), 0.0, 1.0);
			col += pal(fd / float(MAX_DEPTH) + 0.3) * glow * 0.03;

			// Fill for deepest visible level
			float fill_d = length(uv - child_center);
			if (fill_d < child_radius * 0.8 && depth == MAX_DEPTH - 1) {
				col += pal(float(digit) / fp + t * 0.01) * 0.15;
			}
		}

		radius = child_radius;
	}

	// Ultrametric distance field overlay
	// Points that are p-adically close are visually close in this tree
	float r = length(uv);
	float ultra_rings = sin(log(r + 0.01) * fp * 3.0 + t * 0.5);
	col += vec3(0.2, 0.3, 0.5) * max(ultra_rings, 0.0) * 0.04;

	// Cantor-like dust at the boundary
	float boundary = abs(r - 0.8);
	float cantor = 0.0;
	float cantor_r = r;
	for (int i = 0; i < 5; i++) {
		cantor_r = fract(cantor_r * fp);
		cantor += smoothstep(0.4, 0.3, abs(cantor_r - 0.5));
	}
	col += pal(cantor * 0.3) * cantor * exp(-boundary * 20.0) * 0.08;

	// Audio
	col *= 1.0 + energy * 0.2;
	col += vec3(1.0) * beat * 0.03;

	// Vignette + tone map
	col *= 1.0 - dot(uv, uv) * 0.2;
	col = col / (col + vec3(1.0));

	ALBEDO = col;
}

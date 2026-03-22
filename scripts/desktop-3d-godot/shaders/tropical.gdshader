shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

global uniform float audio_bass;
global uniform float audio_energy;
global uniform float beat_intensity;

// Tropical Geometry — where addition becomes max
// Tropical curves are piecewise-linear skeletons of algebraic curves
// Connected to ReLU neural network decision boundaries

vec3 pal(float t) {
	return vec3(0.5) + vec3(0.5) * cos(TAU * (vec3(1.0, 0.8, 0.5) * t + vec3(0.0, 0.1, 0.3)));
}

// Tropical polynomial: trop(f) = max(a_i + <v_i, x>)
// The tropical curve is where the max is achieved by two or more terms
float tropical_curve(vec2 p, float t) {
	// Coefficients that animate
	float a0 = sin(t * 0.1) * 2.0;
	float a1 = cos(t * 0.13) * 2.0;
	float a2 = sin(t * 0.07 + 1.0) * 2.0;
	float a3 = cos(t * 0.09 + 2.0) * 1.5;
	float a4 = sin(t * 0.11 + 3.0) * 1.5;
	float a5 = cos(t * 0.08 + 0.5) * 2.0;

	// Tropical terms: a_i + <v_i, p> for various lattice vectors
	float t0 = a0;                      // constant
	float t1 = a1 + p.x;               // x
	float t2 = a2 + p.y;               // y
	float t3 = a3 + 2.0 * p.x;         // x^2
	float t4 = a4 + p.x + p.y;         // xy
	float t5 = a5 + 2.0 * p.y;         // y^2

	// Max of all terms
	float m = max(max(max(t0, t1), max(t2, t3)), max(t4, t5));

	// Distance to tropical curve = where two terms tie for max
	// Approximate: difference between max and second-max
	float second = -1e10;
	float vals[6] = float[](t0, t1, t2, t3, t4, t5);
	for (int i = 0; i < 6; i++) {
		if (vals[i] < m) second = max(second, vals[i]);
	}

	return m - second;  // 0 at the curve, positive away
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float t = TIME;
	float energy = audio_energy;
	float beat = beat_intensity;

	vec2 p = uv * 4.0;

	vec3 col = vec3(0.02, 0.01, 0.04);

	// Multiple tropical curves at different scales
	for (int layer = 0; layer < 4; layer++) {
		float fl = float(layer);
		float scale = 1.0 + fl * 0.5;
		float time_offset = fl * 2.0;
		vec2 lp = p * scale + vec2(fl * 0.7, fl * 0.3);

		float d = tropical_curve(lp, t + time_offset);

		// Curve edge (piecewise linear = sharp angles)
		float edge = smoothstep(0.15, 0.0, d);
		col += pal(fl * 0.25 + d * 0.5 + t * 0.02) * edge * (0.6 - fl * 0.12);

		// Inverse glow
		col += pal(fl * 0.25 + 0.5) * clamp(0.02 / (d + 0.01), 0.0, 1.0) * 0.06;
	}

	// Lattice points glow (integer lattice = Newton polygon vertices)
	for (int i = -4; i <= 4; i++) {
		for (int j = -4; j <= 4; j++) {
			vec2 lattice = vec2(float(i), float(j));
			float d = length(p - lattice);
			col += vec3(1.0, 0.85, 0.3) * exp(-d * d * 8.0) * 0.05;
		}
	}

	// Newton polygon edges (convex hull of exponent vectors)
	// Dual to the tropical curve structure
	float newton_edge = 0.0;
	vec2 newton_verts[6] = vec2[](vec2(0,0), vec2(1,0), vec2(0,1), vec2(2,0), vec2(1,1), vec2(0,2));
	for (int i = 0; i < 6; i++) {
		for (int j = i+1; j < 6; j++) {
			vec2 a = newton_verts[i];
			vec2 b = newton_verts[j];
			vec2 pa = p * 0.5 - a, ba = b - a;
			float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
			float d = length(pa - ba * h);
			newton_edge += exp(-d * 20.0) * 0.02;
		}
	}
	col += vec3(0.5, 0.3, 0.7) * newton_edge;

	// Audio
	col *= 1.0 + energy * 0.2;
	col += vec3(1.0) * beat * 0.03;

	// Vignette + tone map
	col *= 1.0 - dot(uv, uv) * 0.2;
	col = col / (col + vec3(1.0));

	ALBEDO = col;
}

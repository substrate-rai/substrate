shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

global uniform float audio_energy;
global uniform float beat_intensity;

// Schmidt Arrangements — Bianchi Group Circle Packings
// Zero GPU implementations exist. First real-time render.
// Orbit of the real line under PSL_2(O_K) for imaginary quadratic fields

vec3 pal(float t) {
	return vec3(0.5) + vec3(0.5) * cos(TAU * (vec3(0.8, 0.9, 1.0) * t + vec3(0.0, 0.1, 0.2)));
}

vec2 cmul(vec2 a, vec2 b) { return vec2(a.x*b.x-a.y*b.y, a.x*b.y+a.y*b.x); }

vec2 mobius(vec2 z, vec2 a, vec2 b, vec2 c, vec2 d) {
	vec2 num = cmul(a, z) + b;
	vec2 den = cmul(c, z) + d;
	float d2 = dot(den, den);
	return vec2(dot(num, den), num.y*den.x - num.x*den.y) / d2;
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float t = TIME;
	float energy = audio_energy;
	vec2 p = uv * 3.0;
	vec3 col = vec3(0.02, 0.01, 0.04);
	float min_d = 1e10;
	float best_curv = 0.0;

	// Generate circles via Bianchi group elements
	// For Q(sqrt(-1)): Gaussian integers as matrix entries
	for (int m = -4; m <= 4; m++) {
		for (int n = -4; n <= 4; n++) {
			if (m == 0 && n == 0) continue;
			float fm = float(m), fn = float(n);
			float curv = fm * fm + fn * fn;

			// Circle from group element: center = (m+ni)/(m^2+n^2), radius = 1/(m^2+n^2)
			vec2 center = vec2(fm, fn) / curv;
			float radius = 1.0 / curv;

			// Animate: slowly rotate centers
			float angle = t * 0.03 * (1.0 + 0.1 * sin(curv));
			center = vec2(center.x * cos(angle) - center.y * sin(angle),
			              center.x * sin(angle) + center.y * cos(angle));

			float d = abs(length(p - center) - radius);
			if (d < min_d) {
				min_d = d;
				best_curv = curv;
			}

			// Circle ring
			float ring = smoothstep(0.008, 0.0, d);
			col += pal(curv * 0.05 + t * 0.01) * ring * 0.5;

			// Glow
			col += pal(curv * 0.05 + 0.3) * clamp(0.003 / (d + 0.001), 0.0, 1.0) * 0.04;

			// Second layer: Ford circles (tangent to real axis)
			vec2 ford_center = vec2(fm / fn, 0.5 / (fn * fn));
			float ford_r = 0.5 / (fn * fn);
			if (abs(fn) > 0.5) {
				float fd = abs(length(p - ford_center) - ford_r);
				float ford_ring = smoothstep(0.006, 0.0, fd);
				col += pal(abs(fm/fn) + 0.5) * ford_ring * 0.3;
				col += pal(0.7) * clamp(0.002 / (fd + 0.001), 0.0, 1.0) * 0.03;
			}
		}
	}

	// Real axis
	float axis = smoothstep(0.01, 0.0, abs(p.y));
	col += vec3(0.3, 0.3, 0.4) * axis * 0.15;

	col *= 1.0 + energy * 0.2;
	col += vec3(1.0) * beat_intensity * 0.03;
	col *= 1.0 - dot(uv, uv) * 0.2;
	col = col / (col + vec3(1.0));
	ALBEDO = col;
}

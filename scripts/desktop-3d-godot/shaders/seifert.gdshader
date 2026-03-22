shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

global uniform float audio_bass;
global uniform float audio_energy;
global uniform float beat_intensity;

// Seifert Surface of a Torus Knot — Ray Marched
// The oriented surface bounded by a mathematical knot in 3D

vec3 pal(float t) {
	return vec3(0.5) + vec3(0.5) * cos(TAU * (vec3(1.0, 0.7, 0.4) * t + vec3(0.0, 0.15, 0.2)));
}

// Torus knot curve: parametric (p,q)-torus knot
vec3 torus_knot(float t_param, float p_val, float q_val, float R, float r) {
	float phi = t_param;
	float theta = q_val / p_val * phi;
	float x = (R + r * cos(theta)) * cos(phi);
	float y = (R + r * cos(theta)) * sin(phi);
	float z = r * sin(theta);
	return vec3(x, y, z);
}

// SDF for torus knot tube
float sdTorusKnot(vec3 p, float p_val, float q_val, float R, float r, float tube_r) {
	float min_d = 1e10;
	for (int i = 0; i < 128; i++) {
		float t_param = float(i) / 128.0 * TAU * p_val;
		vec3 knot_pt = torus_knot(t_param, p_val, q_val, R, r);
		min_d = min(min_d, length(p - knot_pt) - tube_r);
	}
	return min_d;
}

// SDF for the Seifert surface (approximated as thin shell between knot strands)
float sdSeifert(vec3 p, float t) {
	float p_val = 2.0;
	float q_val = 3.0;  // trefoil knot
	float R = 1.0;
	float r = 0.4;

	// Surface: interpolate between knot strands
	// Use distance to torus as proxy for surface
	float d_torus = length(vec2(length(p.xy) - R, p.z)) - r;

	// Twist to create Seifert topology
	float angle = atan(p.y, p.x);
	float twist = sin(q_val / p_val * angle + t * 0.2) * 0.15;

	return abs(d_torus + twist) - 0.02;  // thin shell
}

vec3 calcNormal(vec3 p, float t) {
	float e = 0.001;
	return normalize(vec3(
		sdSeifert(p + vec3(e,0,0), t) - sdSeifert(p - vec3(e,0,0), t),
		sdSeifert(p + vec3(0,e,0), t) - sdSeifert(p - vec3(0,e,0), t),
		sdSeifert(p + vec3(0,0,e), t) - sdSeifert(p - vec3(0,0,e), t)
	));
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float t = TIME;
	float energy = audio_energy;
	float beat = beat_intensity;

	// Camera orbiting
	float cam_angle = t * 0.15;
	float cam_elev = sin(t * 0.08) * 0.3;
	vec3 ro = vec3(cos(cam_angle) * 3.0, sin(cam_elev) * 1.5, sin(cam_angle) * 3.0);
	vec3 target = vec3(0.0);
	vec3 fwd = normalize(target - ro);
	vec3 right = normalize(cross(fwd, vec3(0,1,0)));
	vec3 up = cross(right, fwd);
	vec3 rd = normalize(fwd + uv.x * right * 0.8 + uv.y * up * 0.8);

	// Ray march
	vec3 col = vec3(0.02, 0.01, 0.04);
	float total_d = 0.0;

	for (int i = 0; i < 120; i++) {
		vec3 p = ro + rd * total_d;
		float d = sdSeifert(p, t);

		if (d < 0.001) {
			// Hit surface
			vec3 n = calcNormal(p, t);

			// Lighting
			vec3 light = normalize(vec3(1, 2, 3));
			float diff = max(dot(n, light), 0.0);
			float spec = pow(max(dot(reflect(-light, n), -rd), 0.0), 32.0);

			// Surface color based on position
			float surface_t = atan(p.y, p.x) / TAU + 0.5;
			vec3 surface_col = pal(surface_t + t * 0.03);

			// Two-sided coloring (Seifert surface has two sides)
			float side = sign(dot(n, rd));
			if (side > 0.0) surface_col = pal(surface_t + 0.5 + t * 0.03);

			col = surface_col * (0.2 + diff * 0.6) + vec3(1.0) * spec * 0.3;

			// Fresnel rim
			float fresnel = pow(1.0 - abs(dot(n, -rd)), 3.0);
			col += pal(surface_t + 0.3) * fresnel * 0.3;

			break;
		}

		total_d += d;
		if (total_d > 10.0) break;
	}

	// Background: subtle radial gradient
	col += vec3(0.03, 0.02, 0.06) * (1.0 - length(uv) * 0.5);

	// Audio
	col *= 1.0 + energy * 0.2;
	col += vec3(1.0) * beat * 0.03;

	// Tone map
	col = col / (col + vec3(1.0));

	ALBEDO = col;
}

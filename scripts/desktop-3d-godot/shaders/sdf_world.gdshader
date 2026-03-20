shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

// SDF Raymarching — morphing organic structures, infinite repetition, audio-reactive
global uniform float audio_bass;
global uniform float audio_mid;
global uniform float audio_treble;
global uniform float audio_energy;
global uniform float beat_intensity;
global uniform vec3 cursor_world_pos;

uniform vec3 color_a : source_color = vec3(0.0, 1.0, 0.66);
uniform vec3 color_b : source_color = vec3(1.0, 0.2, 0.5);
uniform vec3 color_c : source_color = vec3(0.3, 0.5, 1.0);
uniform vec3 bg_color : source_color = vec3(0.02, 0.01, 0.04);
uniform float morph_speed = 0.3;

// Smooth min for organic blending
float smin(float a, float b, float k) {
	float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
	return mix(b, a, h) - k * h * (1.0 - h);
}

// Rotation matrix
mat2 rot2(float a) {
	float c = cos(a), s = sin(a);
	return mat2(vec2(c, s), vec2(-s, c));
}

// SDF primitives
float sd_sphere(vec3 p, float r) {
	return length(p) - r;
}

float sd_box(vec3 p, vec3 b) {
	vec3 q = abs(p) - b;
	return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

float sd_torus(vec3 p, vec2 t) {
	vec2 q = vec2(length(p.xz) - t.x, p.y);
	return length(q) - t.y;
}

float sd_octahedron(vec3 p, float s) {
	p = abs(p);
	return (p.x + p.y + p.z - s) * 0.57735027;
}

// The scene — morphing organic shapes with infinite repetition
float map(vec3 p, float t) {
	float bass = audio_bass * 0.5;
	float mid = audio_mid * 0.3;

	// Infinite repetition with spacing
	float spacing = 3.5 + bass * 0.5;
	vec3 rep = p - spacing * round(p / spacing);

	// Twist the repeated space
	float twist = sin(t * 0.2) * 0.5 + mid;
	rep.xz *= rot2(rep.y * 0.15 + twist);

	// Morphing blend between shapes
	float morph = sin(t * morph_speed) * 0.5 + 0.5;
	float morph2 = sin(t * morph_speed * 0.7 + 1.5) * 0.5 + 0.5;

	float sphere = sd_sphere(rep, 0.8 + bass * 0.3);
	float oct = sd_octahedron(rep, 1.0 + mid * 0.2);
	float torus = sd_torus(rep, vec2(0.7 + bass * 0.2, 0.2 + mid * 0.1));
	float box = sd_box(rep, vec3(0.5 + mid * 0.15));

	// Smooth blend between shapes based on time
	float d = smin(mix(sphere, oct, morph), mix(torus, box, morph2), 0.4);

	// Add smaller orbiting blobs
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		float angle = t * (0.5 + fi * 0.2) + fi * 2.094;
		vec3 offset = vec3(cos(angle), sin(angle * 0.7), sin(angle)) * (1.2 + bass * 0.3);
		float blob = sd_sphere(rep - offset, 0.15 + beat_intensity * 0.1);
		d = smin(d, blob, 0.3);
	}

	// Displacement — audio-reactive surface detail
	d += sin(p.x * 4.0 + t) * sin(p.y * 4.0 + t * 0.7) * sin(p.z * 4.0 + t * 1.3) * (0.03 + bass * 0.05);

	return d;
}

// Normal via gradient
vec3 calc_normal(vec3 p, float t) {
	vec2 e = vec2(0.001, 0.0);
	return normalize(vec3(
		map(p + e.xyy, t) - map(p - e.xyy, t),
		map(p + e.yxy, t) - map(p - e.yxy, t),
		map(p + e.yyx, t) - map(p - e.yyx, t)
	));
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	uv.x *= 16.0 / 9.0;
	float t = TIME;

	// Camera orbit
	float cam_angle = t * 0.15;
	vec3 ro = vec3(sin(cam_angle) * 4.0, 2.0 + sin(t * 0.1) * 0.5, cos(cam_angle) * 4.0);

	// Cursor influence on camera target
	vec3 target = vec3(0.0, 0.0, 0.0);
	target.xz += cursor_world_pos.xz * 0.05;

	// Camera matrix
	vec3 fwd = normalize(target - ro);
	vec3 right = normalize(cross(fwd, vec3(0.0, 1.0, 0.0)));
	vec3 up = cross(right, fwd);
	vec3 rd = normalize(fwd + uv.x * right + uv.y * up);

	// Raymarching
	float total_dist = 0.0;
	float min_dist = 999.0;
	vec3 p;
	bool hit = false;

	for (int i = 0; i < 80; i++) {
		p = ro + rd * total_dist;
		float d = map(p, t);
		min_dist = min(min_dist, d);
		if (d < 0.001) {
			hit = true;
			break;
		}
		if (total_dist > 30.0) break;
		total_dist += d;
	}

	vec3 col = bg_color;

	if (hit) {
		vec3 n = calc_normal(p, t);

		// Material color based on position + normal
		float color_mix = sin(p.x * 0.5 + t * 0.3) * 0.5 + 0.5;
		float color_mix2 = sin(p.y * 0.7 + t * 0.2) * 0.5 + 0.5;
		vec3 base_col = mix(mix(color_a, color_b, color_mix), color_c, color_mix2);

		// Lighting
		vec3 light_dir = normalize(vec3(sin(t * 0.3), 1.0, cos(t * 0.3)));
		float diff = max(dot(n, light_dir), 0.0);
		float spec = pow(max(dot(reflect(-light_dir, n), -rd), 0.0), 32.0);
		float fresnel = pow(1.0 - max(dot(n, -rd), 0.0), 3.0);

		col = base_col * (0.15 + diff * 0.7) + vec3(1.0) * spec * 0.5;
		col += mix(color_a, color_b, fresnel) * fresnel * 0.4;

		// Ambient occlusion approximation
		float ao = 1.0;
		float ao_dist = 0.05;
		for (int i = 0; i < 3; i++) {
			ao -= (ao_dist * float(i + 1) - map(p + n * ao_dist * float(i + 1), t)) * (0.4 / float(i + 1));
		}
		col *= max(ao, 0.2);

		// Distance fog
		float fog = 1.0 - exp(-total_dist * 0.05);
		col = mix(col, bg_color, fog);
	} else {
		// Glow from near-misses
		float glow = exp(-min_dist * 4.0) * 0.6;
		col += mix(color_a, color_b, sin(t * 0.5) * 0.5 + 0.5) * glow;
	}

	// Beat flash
	col += vec3(0.05, 0.02, 0.08) * beat_intensity;

	// Tone mapping
	col = col / (col + vec3(1.0));
	col = pow(col, vec3(0.9));

	ALBEDO = col;
}

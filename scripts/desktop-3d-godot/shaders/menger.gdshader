shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

// Menger sponge — raymarched 3D fractal with iterative folding/modulo (64 steps)
global uniform float audio_energy;
global uniform float beat_intensity;
global uniform float audio_bass;
global uniform float audio_mid;

float box_sdf(vec3 p, vec3 b) {
	vec3 d = abs(p) - b;
	return length(max(d, 0.0)) + min(max(d.x, max(d.y, d.z)), 0.0);
}

float cross_sdf(vec3 p) {
	float da = box_sdf(p, vec3(100.0, 1.0, 1.0));
	float db = box_sdf(p, vec3(1.0, 100.0, 1.0));
	float dc = box_sdf(p, vec3(1.0, 1.0, 100.0));
	return min(da, min(db, dc));
}

float menger_sdf(vec3 p) {
	float d = box_sdf(p, vec3(1.0));
	float s = 1.0;

	// 4 iterations for good detail without excessive cost
	for (int i = 0; i < 4; i++) {
		s *= 3.0;
		vec3 q = mod(p * s + 1.5, 3.0) - 1.5;
		float c = cross_sdf(q) / s;
		d = max(d, -c);
	}
	return d;
}

vec3 calc_normal(vec3 p) {
	vec2 e = vec2(0.001, 0.0);
	return normalize(vec3(
		menger_sdf(p + e.xyy) - menger_sdf(p - e.xyy),
		menger_sdf(p + e.yxy) - menger_sdf(p - e.yxy),
		menger_sdf(p + e.yyx) - menger_sdf(p - e.yyx)
	));
}

void fragment() {
	vec2 uv = (UV - 0.5) * 2.0;
	uv.x *= 1.777;

	// Rotating camera
	float cam_t = TIME * 0.2 + audio_bass * 0.1;
	vec3 ro = vec3(2.5 * cos(cam_t), 1.5 + sin(cam_t * 0.3) * 0.5, 2.5 * sin(cam_t));
	vec3 target = vec3(0.0);
	vec3 fwd = normalize(target - ro);
	vec3 right = normalize(cross(fwd, vec3(0, 1, 0)));
	vec3 up = cross(right, fwd);
	vec3 rd = normalize(fwd + uv.x * right + uv.y * up);

	// Raymarch
	float t_march = 0.0;
	bool hit = false;
	int steps_taken = 0;
	for (int i = 0; i < 64; i++) {
		vec3 p = ro + rd * t_march;
		float d = menger_sdf(p);
		if (d < 0.001) {
			hit = true;
			break;
		}
		if (t_march > 15.0) break;
		t_march += d;
		steps_taken = i;
	}

	vec3 col = vec3(0.02, 0.01, 0.03); // background

	if (hit) {
		vec3 p = ro + rd * t_march;
		vec3 n = calc_normal(p);

		// Lighting
		vec3 light = normalize(vec3(1, 2, 1.5));
		float diff = max(dot(n, light), 0.0);
		float spec = pow(max(dot(reflect(-light, n), -rd), 0.0), 16.0);

		// AO approximation from step count
		float ao = 1.0 - float(steps_taken) / 64.0;

		// Color based on position — gives internal structure visibility
		vec3 base = vec3(0.15, 0.5, 0.4);
		base += vec3(0.4, 0.1, 0.3) * abs(sin(p * 4.0));

		col = base * (0.15 + diff * 0.5) * ao + vec3(0.8, 0.9, 1.0) * spec * 0.3;

		// Beat highlights
		col += beat_intensity * 0.25 * vec3(0.6, 0.3, 1.0);

		// Audio mid shifts color
		col += audio_mid * 0.15 * vec3(0.3, 0.7, 0.5);
	} else {
		// Step-based glow for near misses
		float glow = float(steps_taken) / 64.0;
		col += vec3(0.05, 0.15, 0.1) * glow * 0.5;
	}

	// Energy brightness
	col *= 0.8 + audio_energy * 0.4;

	ALBEDO = col;
}

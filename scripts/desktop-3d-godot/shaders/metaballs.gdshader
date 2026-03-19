shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

// Metaballs — raymarched SDF spheres with smooth-min union (48 steps)
global uniform float audio_bass;
global uniform float audio_energy;
global uniform float beat_intensity;
global uniform float audio_treble;

float smin(float a, float b, float k) {
	float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
	return mix(b, a, h) - k * h * (1.0 - h);
}

float sdf_sphere(vec3 p, vec3 center, float radius) {
	return length(p - center) - radius;
}

float scene_sdf(vec3 p) {
	float t = TIME * 0.5;
	float bass_r = 0.3 + audio_bass * 0.15;

	// 6 orbiting spheres
	float d = 1e10;
	d = smin(d, sdf_sphere(p, vec3(sin(t) * 1.5, cos(t * 0.7) * 0.8, sin(t * 0.4) * 1.0), bass_r + 0.1), 0.5);
	d = smin(d, sdf_sphere(p, vec3(cos(t * 0.8) * 1.2, sin(t * 1.1) * 1.0, cos(t * 0.6) * 0.7), bass_r), 0.5);
	d = smin(d, sdf_sphere(p, vec3(sin(t * 1.3) * 0.8, cos(t * 0.5) * 1.3, sin(t * 0.9) * 1.2), bass_r + 0.05), 0.5);
	d = smin(d, sdf_sphere(p, vec3(cos(t * 0.6) * 1.4, sin(t * 0.9) * 0.6, cos(t * 1.2) * 0.9), bass_r - 0.05), 0.5);
	d = smin(d, sdf_sphere(p, vec3(0.0, sin(t * 0.3) * 0.5, 0.0), bass_r + 0.2), 0.6); // center blob
	d = smin(d, sdf_sphere(p, vec3(sin(t * 0.4) * 1.0, cos(t * 1.5) * 1.1, sin(t * 0.7) * 0.5), bass_r), 0.5);

	return d;
}

vec3 calc_normal(vec3 p) {
	vec2 e = vec2(0.002, 0.0);
	return normalize(vec3(
		scene_sdf(p + e.xyy) - scene_sdf(p - e.xyy),
		scene_sdf(p + e.yxy) - scene_sdf(p - e.yxy),
		scene_sdf(p + e.yyx) - scene_sdf(p - e.yyx)
	));
}

void fragment() {
	vec2 uv = (UV - 0.5) * 2.0;
	uv.x *= 1.777;

	// Camera
	vec3 ro = vec3(0, 0, 4.0);
	vec3 rd = normalize(vec3(uv, -1.5));

	// Raymarch
	float t_march = 0.0;
	bool hit = false;
	for (int i = 0; i < 48; i++) {
		vec3 p = ro + rd * t_march;
		float d = scene_sdf(p);
		if (d < 0.005) {
			hit = true;
			break;
		}
		if (t_march > 20.0) break;
		t_march += d;
	}

	vec3 col = vec3(0.02, 0.01, 0.04); // background

	if (hit) {
		vec3 p = ro + rd * t_march;
		vec3 n = calc_normal(p);

		// Fresnel
		float fresnel = pow(1.0 - max(dot(n, -rd), 0.0), 3.0);

		// Base color — organic green-blue
		vec3 base = mix(vec3(0.1, 0.6, 0.4), vec3(0.3, 0.2, 0.8), fresnel);

		// Lighting
		vec3 light_dir = normalize(vec3(1, 2, 3));
		float diffuse = max(dot(n, light_dir), 0.0);
		float spec = pow(max(dot(reflect(-light_dir, n), -rd), 0.0), 32.0);

		col = base * (0.2 + diffuse * 0.6) + vec3(1.0) * spec * 0.4;
		col += vec3(0.1, 0.8, 0.5) * fresnel * 0.5;

		// Beat pulse
		col += beat_intensity * 0.3 * vec3(0.8, 0.3, 1.0);

		// Audio treble adds iridescence
		col += audio_treble * fresnel * vec3(0.5, 0.2, 0.8) * 0.3;
	}

	// Energy glow
	col *= 0.8 + audio_energy * 0.4;

	ALBEDO = col;
}

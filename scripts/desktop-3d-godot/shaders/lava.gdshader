shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

// Voronoi-based flowing lava/magma
global uniform float system_heat;
global uniform float audio_bass;
global uniform float audio_energy;
global uniform float beat_intensity;

vec2 hash2(vec2 p) {
	p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
	return fract(sin(p) * 43758.5453);
}

// Voronoi with distance
float voronoi(vec2 p, out vec2 nearest_point) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float min_dist = 1.0;
	nearest_point = vec2(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 offset = vec2(float(x), float(y));
			vec2 h = hash2(i + offset);
			h = 0.5 + 0.5 * sin(TIME * 0.3 + 6.28318 * h); // animate
			vec2 r = offset + h - f;
			float d = dot(r, r);
			if (d < min_dist) {
				min_dist = d;
				nearest_point = i + offset + h;
			}
		}
	}
	return sqrt(min_dist);
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1.0, 0.0));
	float c = hash(i + vec2(0.0, 1.0));
	float d = hash(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

void fragment() {
	vec2 uv = UV;
	uv.x *= 1.777;

	// Slow flow
	vec2 flow = uv * 3.0 + vec2(TIME * 0.05, TIME * 0.08);

	vec2 np;
	float v = voronoi(flow, np);

	// Crack pattern — edges between cells
	float crack_width = 0.15 + system_heat * 0.15;
	float cracks = smoothstep(crack_width, 0.02, v);

	// Lava glow in cracks
	float glow = smoothstep(crack_width * 1.5, 0.0, v);

	// Surface texture
	float surface_noise = noise(uv * 8.0 + TIME * 0.1) * 0.5 + noise(uv * 16.0) * 0.25;

	// Color: dark rock surface with glowing lava in cracks
	float heat = 0.5 + system_heat * 0.5;
	vec3 rock = vec3(0.08, 0.05, 0.03) + surface_noise * 0.05;
	vec3 lava_col;
	if (glow < 0.3) {
		lava_col = mix(vec3(0.8, 0.1, 0.0), vec3(1.0, 0.4, 0.0), glow / 0.3);
	} else if (glow < 0.7) {
		lava_col = mix(vec3(1.0, 0.4, 0.0), vec3(1.0, 0.8, 0.1), (glow - 0.3) / 0.4);
	} else {
		lava_col = mix(vec3(1.0, 0.8, 0.1), vec3(1.0, 1.0, 0.7), (glow - 0.7) / 0.3);
	}

	vec3 col = mix(rock, lava_col * heat, glow);

	// Audio bass pulses the lava brightness
	col += lava_col * audio_bass * 0.3 * glow;

	// Beat flash
	col += beat_intensity * 0.2 * vec3(1.0, 0.5, 0.1) * glow;

	// Emissive brightness from energy
	col *= 0.9 + audio_energy * 0.3;

	ALBEDO = col;
}

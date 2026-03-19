shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

// Reaction-diffusion inspired mycelium network
global uniform float audio_bass;
global uniform float audio_mid;
global uniform float audio_energy;
global uniform float beat_intensity;

uniform vec3 hyphae_color : source_color = vec3(0.7, 0.85, 0.6);
uniform vec3 node_color : source_color = vec3(0.0, 1.0, 0.66);
uniform vec3 bg_color : source_color = vec3(0.02, 0.01, 0.03);
uniform float evolution_speed = 0.1;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i);
	float b = hash(i + vec2(1,0));
	float c = hash(i + vec2(0,1));
	float d = hash(i + vec2(1,1));
	return mix(mix(a,b,f.x), mix(c,d,f.x), f.y);
}

float fbm(vec2 p, int octaves) {
	float v = 0.0, a = 0.5;
	mat2 rot = mat2(vec2(0.8,0.6), vec2(-0.6,0.8));
	for (int i = 0; i < octaves; i++) {
		v += a * noise(p);
		p = rot * p * 2.0;
		a *= 0.5;
	}
	return v;
}

// Voronoi — returns (distance to edge, distance to center, cell_id hash)
vec3 voronoi(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	float d1 = 1e10, d2 = 1e10;
	float cell_hash = 0.0;
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 n = vec2(float(x), float(y));
			vec2 point = vec2(hash(i+n), hash(i+n+vec2(31,17)));
			// Animate slightly
			point += 0.15 * sin(TIME * evolution_speed + point * 6.28);
			float d = length(n + point - f);
			if (d < d1) { d2 = d1; d1 = d; cell_hash = hash(i+n+vec2(73,37)); }
			else if (d < d2) { d2 = d; }
		}
	}
	return vec3(d2 - d1, d1, cell_hash);
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	uv.x *= 1.777;
	float t = TIME * evolution_speed;

	// Multi-scale Turing-like patterns
	float scale1 = 4.0 + audio_bass * 2.0;
	float scale2 = 8.0;
	float scale3 = 16.0;

	// Voronoi network at multiple scales — edges form the hyphae
	vec3 v1 = voronoi(uv * scale1 + t * 0.3);
	vec3 v2 = voronoi(uv * scale2 - t * 0.2 + 5.0);
	vec3 v3 = voronoi(uv * scale3 + t * 0.1 + 10.0);

	// Hyphae are the edges (where d2-d1 is small)
	float edge1 = 1.0 - smoothstep(0.0, 0.08, v1.x);
	float edge2 = 1.0 - smoothstep(0.0, 0.05, v2.x);
	float edge3 = 1.0 - smoothstep(0.0, 0.03, v3.x);

	// Combine scales — large network + fine detail
	float hyphae = max(edge1 * 0.8, max(edge2 * 0.5, edge3 * 0.3));

	// Nodes glow at voronoi centers
	float nodes = exp(-v1.y * 8.0) * 0.8 + exp(-v2.y * 12.0) * 0.4;
	nodes += beat_intensity * exp(-v1.y * 5.0) * 0.6;

	// Reaction-diffusion texture overlay
	float rd = fbm(uv * 6.0 + t, 5);
	float rd2 = fbm(uv * 12.0 - t * 0.5, 4);
	float pattern = smoothstep(0.4, 0.6, rd) * smoothstep(0.35, 0.65, rd2);

	// Spore release on beat
	float spores = 0.0;
	if (beat_intensity > 0.1) {
		float spore_noise = noise(uv * 30.0 + TIME * 3.0);
		spores = step(0.92, spore_noise) * beat_intensity;
	}

	// Color
	vec3 col = bg_color;
	col = mix(col, hyphae_color * 0.5, hyphae * (0.8 + audio_energy * 0.4));
	col = mix(col, hyphae_color * 0.3, pattern * 0.4);
	col += node_color * nodes * (1.0 + audio_mid * 0.5);
	col += node_color * 1.5 * spores;

	// Bioluminescent pulse
	float pulse = sin(t * 3.0 + length(uv) * 2.0) * 0.5 + 0.5;
	col += node_color * pulse * hyphae * 0.15 * (1.0 + audio_bass);

	// Dark substrate texture
	float substrate_tex = fbm(uv * 20.0, 3) * 0.08;
	col += vec3(substrate_tex * 0.5, substrate_tex, substrate_tex * 0.3);

	// Vignette
	col *= 1.0 - dot(uv * 0.35, uv * 0.35);

	ALBEDO = col;
}

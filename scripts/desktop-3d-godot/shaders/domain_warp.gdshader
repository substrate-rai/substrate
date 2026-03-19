shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

// Domain Warp — nested fBM (fbm(p + fbm(p + fbm(p)))) flowing marble textures
// Reactivity: audio_energy → warp intensity, cursor_world_pos → warp center offset

global uniform float audio_energy;
global uniform float audio_bass;
global uniform float audio_mid;
global uniform float beat_intensity;
global uniform vec3 cursor_world_pos;

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

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	mat2 rot = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < 6; i++) {
		v += amp * noise(p);
		p = rot * p * 2.0;
		amp *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV * 4.0 - 2.0;

	// Cursor offset
	vec2 cursor_offset = cursor_world_pos.xz * 0.1;
	uv += cursor_offset;

	float t = TIME * 0.15;

	// Warp intensity from audio
	float warp_strength = 1.0 + audio_energy * 2.0;

	// First layer
	vec2 q = vec2(
		fbm(uv + vec2(0.0, 0.0) + t),
		fbm(uv + vec2(5.2, 1.3) + t * 0.7)
	);

	// Second layer — warps on first
	vec2 r = vec2(
		fbm(uv + warp_strength * q + vec2(1.7, 9.2) + t * 0.5),
		fbm(uv + warp_strength * q + vec2(8.3, 2.8) + t * 0.3)
	);

	// Third layer — warps on second
	float f = fbm(uv + warp_strength * r + t * 0.2);

	// Beat burst — extra warp
	f += beat_intensity * 0.15 * fbm(uv * 2.0 + TIME);

	// Mycopunk color palette
	vec3 color;
	float c = f * 2.0;
	vec3 col1 = vec3(0.0, 0.04, 0.02);    // deep dark green
	vec3 col2 = vec3(0.0, 0.5, 0.33);     // substrate green
	vec3 col3 = vec3(0.0, 1.0, 0.67);     // bright green
	vec3 col4 = vec3(0.5, 0.0, 0.8);      // purple accent
	vec3 col5 = vec3(1.0, 0.47, 0.9);     // pink highlight
	vec3 col6 = vec3(0.1, 0.8, 1.0);      // cyan accent

	if (c < 0.4) {
		color = mix(col1, col2, c / 0.4);
	} else if (c < 0.7) {
		color = mix(col2, col3, (c - 0.4) / 0.3);
	} else if (c < 0.85) {
		color = mix(col3, col4, (c - 0.7) / 0.15);
	} else if (c < 0.95) {
		color = mix(col4, col5, (c - 0.85) / 0.1);
	} else {
		color = mix(col5, col6, (c - 0.95) / 0.05);
	}

	// Audio glow
	color += vec3(0.0, audio_bass * 0.15, audio_bass * 0.1);

	// Subtle vignette
	vec2 vig_uv = UV * 2.0 - 1.0;
	float vig = 1.0 - dot(vig_uv, vig_uv) * 0.3;
	color *= vig;

	ALBEDO = color;
	ALPHA = 1.0;
}

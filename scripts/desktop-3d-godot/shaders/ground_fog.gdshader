shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

global uniform vec3 cursor_world_pos;

uniform vec3 fog_color : source_color = vec3(0.15, 0.25, 0.1);
uniform float fog_alpha : hint_range(0.0, 1.0) = 0.35;
uniform float cursor_clear_radius : hint_range(0.5, 10.0) = 3.0;
uniform float scroll_speed : hint_range(0.0, 0.1) = 0.015;
uniform float noise_scale : hint_range(0.5, 5.0) = 2.0;

// Procedural noise (no texture dependency)
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float value_noise(vec2 p) {
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
	for (int i = 0; i < 3; i++) {
		v += amp * value_noise(p);
		p *= 2.0;
		amp *= 0.5;
	}
	return v;
}

void vertex() {
	// Y-axis billboard
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(
		vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0),
		vec4(0.0, 1.0, 0.0, 0.0),
		vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0),
		MODEL_MATRIX[3]
	);
}

void fragment() {
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;

	// Scrolling fog noise
	vec2 uv_scroll = UV * noise_scale + vec2(TIME * scroll_speed, TIME * scroll_speed * 0.7);
	float n = fbm(uv_scroll);

	// Edge fade so quads blend softly
	float edge = smoothstep(0.0, 0.3, UV.x) * smoothstep(1.0, 0.7, UV.x)
	           * smoothstep(0.0, 0.25, UV.y) * smoothstep(1.0, 0.75, UV.y);

	// Cursor clears fog
	float cursor_dist = distance(world_pos.xz, cursor_world_pos.xz);
	float cursor_fade = smoothstep(cursor_clear_radius * 0.3, cursor_clear_radius, cursor_dist);

	float alpha = n * edge * fog_alpha * cursor_fade;

	ALBEDO = fog_color;
	ALPHA = alpha;
	if (ALPHA < 0.02) discard;
}

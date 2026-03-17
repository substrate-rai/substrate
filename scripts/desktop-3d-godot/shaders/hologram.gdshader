shader_type spatial;
render_mode unshaded, cull_disabled;

global uniform vec3 cursor_world_pos;

uniform vec3 holo_color : source_color = vec3(0.0, 0.8, 1.0);
uniform float scanline_density : hint_range(10.0, 200.0) = 80.0;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.3;
uniform float flicker_speed : hint_range(0.0, 20.0) = 8.0;
uniform float base_alpha : hint_range(0.0, 1.0) = 0.7;
uniform float glitch_radius : hint_range(1.0, 15.0) = 5.0;

float rand(float x) {
	return fract(sin(x * 127.1) * 43758.5453);
}

void fragment() {
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float cursor_dist = distance(world_pos, cursor_world_pos);
	float proximity = 1.0 - clamp(cursor_dist / glitch_radius, 0.0, 1.0);

	// Scanlines
	float scanline = sin(UV.y * scanline_density + TIME * 2.0) * 0.5 + 0.5;
	scanline = mix(1.0, scanline, scanline_strength);

	// Flicker — more stable near cursor
	float flicker_intensity = mix(0.35, 0.05, proximity);
	float flicker = 1.0 - flicker_intensity * step(0.95, rand(floor(TIME * flicker_speed)));

	// Horizontal glitch offset near cursor interaction
	float glitch = 0.0;
	if (proximity > 0.3) {
		float glitch_line = step(0.97, rand(floor(UV.y * 30.0 + TIME * 3.0)));
		glitch = glitch_line * 0.03 * proximity;
	}

	vec2 uv_glitch = UV + vec2(glitch, 0.0);
	float edge_glow = smoothstep(0.0, 0.05, uv_glitch.x) * smoothstep(1.0, 0.95, uv_glitch.x);

	// Color shifts near cursor
	vec3 color = holo_color * (1.0 + 0.3 * proximity);
	color *= scanline * flicker * edge_glow;

	ALBEDO = color;
	ALPHA = base_alpha * flicker * edge_glow;
	if (ALPHA < 0.01) discard;
}

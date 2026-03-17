shader_type spatial;
render_mode cull_disabled;

global uniform vec3 cursor_world_pos;

uniform vec3 top_color : source_color = vec3(0.35, 0.6, 0.18);
uniform vec3 bottom_color : source_color = vec3(0.15, 0.3, 0.06);
uniform float wind_strength : hint_range(0.0, 1.0) = 0.15;
uniform float wind_speed : hint_range(0.0, 2.0) = 0.8;
uniform float cursor_push_radius : hint_range(0.5, 8.0) = 3.0;
uniform float cursor_push_strength : hint_range(0.0, 1.0) = 0.4;

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	// Wind sway (same as base grass shader)
	float sway = sin(world_pos.x * 1.5 + TIME * wind_speed) * cos(world_pos.z * 1.2 + TIME * wind_speed * 0.7);
	float tip_factor = 1.0 - UV.y; // tips move most

	vec3 displacement = vec3(sway * wind_strength, 0.0, sway * wind_strength * 0.5) * tip_factor;

	// Cursor push — blades lean away from cursor
	vec2 to_cursor = world_pos.xz - cursor_world_pos.xz;
	float cursor_dist = length(to_cursor);
	float push = (1.0 - clamp(cursor_dist / cursor_push_radius, 0.0, 1.0));
	push = push * push; // quadratic falloff
	vec2 push_dir = normalize(to_cursor + vec2(0.001, 0.001)); // avoid zero
	displacement.x += push_dir.x * push * cursor_push_strength * tip_factor;
	displacement.z += push_dir.y * push * cursor_push_strength * tip_factor;

	VERTEX += displacement;
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	ALBEDO = mix(bottom_color, top_color, 1.0 - UV.y);
	ROUGHNESS = 0.6;
	if (!FRONT_FACING) { NORMAL = -NORMAL; }
}

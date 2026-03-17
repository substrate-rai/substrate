shader_type spatial;
render_mode depth_draw_always, cull_disabled;

global uniform vec3 cursor_world_pos;

uniform vec3 water_color : source_color = vec3(0.06, 0.15, 0.12);
uniform float metallic = 0.7;
uniform float roughness = 0.05;
uniform float wave_speed = 1.5;
uniform float wave_strength = 0.02;
uniform float ripple_radius : hint_range(0.5, 8.0) = 3.0;
uniform float ripple_strength : hint_range(0.0, 0.1) = 0.04;
uniform float ripple_frequency : hint_range(2.0, 20.0) = 8.0;

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	// Base waves
	float base_wave = sin(world_pos.x * 3.0 + TIME * wave_speed) * wave_strength;
	base_wave += cos(world_pos.z * 2.5 + TIME * wave_speed * 0.7) * wave_strength;

	// Cursor ripple — concentric rings emanating from cursor position
	float cursor_dist = distance(world_pos.xz, cursor_world_pos.xz);
	float ripple_falloff = 1.0 - clamp(cursor_dist / ripple_radius, 0.0, 1.0);
	ripple_falloff = ripple_falloff * ripple_falloff;
	float ripple = sin(cursor_dist * ripple_frequency - TIME * 4.0) * ripple_strength * ripple_falloff;

	VERTEX.y += base_wave + ripple;
}

void fragment() {
	float fresnel = pow(1.0 - dot(NORMAL, VIEW), 3.0);
	ALBEDO = water_color;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	ALPHA = mix(0.6, 0.95, fresnel);
}

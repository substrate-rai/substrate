shader_type spatial;

global uniform vec3 cursor_world_pos;

uniform vec3 base_emission : source_color = vec3(1.0, 0.6, 0.2);
uniform float base_strength : hint_range(0.0, 5.0) = 1.0;
uniform float max_strength : hint_range(0.0, 10.0) = 6.0;
uniform float glow_radius : hint_range(0.5, 20.0) = 5.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.5;
uniform vec3 albedo : source_color = vec3(0.1, 0.08, 0.06);
uniform float pulse_speed : hint_range(0.0, 4.0) = 1.5;

void fragment() {
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float dist = distance(world_pos, cursor_world_pos);
	float proximity = 1.0 - clamp(dist / glow_radius, 0.0, 1.0);
	proximity = proximity * proximity; // quadratic falloff

	// Subtle pulse that intensifies near cursor
	float pulse = 1.0 + 0.15 * sin(TIME * pulse_speed + world_pos.x * 2.0);

	float strength = mix(base_strength, max_strength, proximity) * pulse;

	ALBEDO = albedo;
	ROUGHNESS = roughness;
	EMISSION = base_emission * strength;
}

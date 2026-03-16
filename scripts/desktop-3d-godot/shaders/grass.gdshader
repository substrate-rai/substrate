shader_type spatial;
render_mode cull_disabled;

uniform vec3 top_color : source_color = vec3(0.2, 0.45, 0.12);
uniform vec3 bottom_color : source_color = vec3(0.1, 0.2, 0.05);
uniform float wind_strength : hint_range(0.0, 1.0) = 0.15;
uniform float wind_speed : hint_range(0.0, 2.0) = 0.8;

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float sway = sin(world_pos.x * 1.5 + TIME * wind_speed) * cos(world_pos.z * 1.2 + TIME * wind_speed * 0.7);
	VERTEX.x += sway * wind_strength * (1.0 - UV.y);
	VERTEX.z += sway * wind_strength * 0.5 * (1.0 - UV.y);
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	ALBEDO = mix(bottom_color, top_color, 1.0 - UV.y);
	ROUGHNESS = 0.6;
	if (!FRONT_FACING) { NORMAL = -NORMAL; }
}

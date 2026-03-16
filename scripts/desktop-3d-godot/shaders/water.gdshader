shader_type spatial;
render_mode depth_draw_always, cull_disabled;

uniform vec3 water_color : source_color = vec3(0.06, 0.15, 0.12);
uniform float metallic = 0.7;
uniform float roughness = 0.05;
uniform float wave_speed = 1.5;
uniform float wave_strength = 0.02;

void vertex() {
	VERTEX.y += sin(VERTEX.x * 3.0 + TIME * wave_speed) * wave_strength;
	VERTEX.y += cos(VERTEX.z * 2.5 + TIME * wave_speed * 0.7) * wave_strength;
}

void fragment() {
	float fresnel = pow(1.0 - dot(NORMAL, VIEW), 3.0);
	ALBEDO = water_color;
	METALLIC = metallic;
	ROUGHNESS = roughness;
	ALPHA = mix(0.6, 0.95, fresnel);
}

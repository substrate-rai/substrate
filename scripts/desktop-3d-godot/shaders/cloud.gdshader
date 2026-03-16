shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_opaque;

uniform vec3 cloud_color : source_color = vec3(0.95, 0.93, 0.88);
uniform float alpha_base : hint_range(0.0, 1.0) = 0.4;
uniform sampler2D noise_tex;

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
	float n = texture(noise_tex, UV * 0.8 + TIME * 0.003).r;
	float edge_fade = smoothstep(0.0, 0.3, UV.x) * smoothstep(1.0, 0.7, UV.x)
	               * smoothstep(0.0, 0.3, UV.y) * smoothstep(1.0, 0.7, UV.y);
	ALBEDO = cloud_color;
	ALPHA = n * edge_fade * alpha_base;
	if (ALPHA < 0.05) discard;
}

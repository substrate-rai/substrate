shader_type canvas_item;

// Thermal camera — luminance mapped to thermal color ramp
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec3 scene = texture(screen_texture, SCREEN_UV).rgb;
	float lum = dot(scene, vec3(0.299, 0.587, 0.114));

	// Thermal color ramp: blue → cyan → green → yellow → red → white
	vec3 col;
	if (lum < 0.15) {
		col = mix(vec3(0.0, 0.0, 0.3), vec3(0.0, 0.2, 0.7), lum / 0.15);
	} else if (lum < 0.3) {
		col = mix(vec3(0.0, 0.2, 0.7), vec3(0.0, 0.7, 0.5), (lum - 0.15) / 0.15);
	} else if (lum < 0.45) {
		col = mix(vec3(0.0, 0.7, 0.5), vec3(0.2, 0.8, 0.0), (lum - 0.3) / 0.15);
	} else if (lum < 0.6) {
		col = mix(vec3(0.2, 0.8, 0.0), vec3(0.9, 0.9, 0.0), (lum - 0.45) / 0.15);
	} else if (lum < 0.78) {
		col = mix(vec3(0.9, 0.9, 0.0), vec3(0.9, 0.2, 0.0), (lum - 0.6) / 0.18);
	} else {
		col = mix(vec3(0.9, 0.2, 0.0), vec3(1.0, 1.0, 0.9), (lum - 0.78) / 0.22);
	}

	COLOR = vec4(col, 1.0);
}

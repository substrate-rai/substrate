shader_type canvas_item;

// Tilt-shift miniature effect — blur top/bottom, saturate
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float focus_center : hint_range(0.0, 1.0) = 0.5;
uniform float focus_width : hint_range(0.0, 0.5) = 0.15;
uniform float blur_amount : hint_range(0.0, 8.0) = 3.0;
uniform float saturation_boost : hint_range(1.0, 2.0) = 1.3;

vec3 blur_sample(sampler2D tex, vec2 uv, float radius) {
	vec2 pix = vec2(1.0) / vec2(textureSize(tex, 0));
	vec3 col = vec3(0.0);
	float total = 0.0;
	for (int x = -3; x <= 3; x++) {
		for (int y = -3; y <= 3; y++) {
			float w = exp(-float(x*x + y*y) / (2.0 * radius));
			col += texture(tex, uv + vec2(float(x), float(y)) * pix * radius).rgb * w;
			total += w;
		}
	}
	return col / total;
}

void fragment() {
	vec3 sharp = texture(screen_texture, UV).rgb;

	// Distance from focus band
	float dist = abs(UV.y - focus_center);
	float blur_factor = smoothstep(focus_width, focus_width + 0.2, dist);

	// Blur
	vec3 blurred = blur_sample(screen_texture, UV, blur_amount * blur_factor);

	vec3 col = mix(sharp, blurred, blur_factor);

	// Saturation boost for miniature look
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(luma), col, saturation_boost);

	// Slight warm tint
	col *= vec3(1.02, 1.0, 0.97);

	// Subtle vignette
	vec2 vc = UV - 0.5;
	col *= 1.0 - dot(vc, vc) * 0.4;

	COLOR = vec4(col, 1.0);
}

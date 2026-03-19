shader_type canvas_item;

// Night vision — green monochrome + noise grain + scanlines + heavy vignette
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float grain_amount : hint_range(0.0, 0.3) = 0.1;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.2;
uniform float brightness_boost : hint_range(1.0, 4.0) = 2.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec3 scene = texture(screen_texture, uv).rgb;

	// Convert to luminance
	float lum = dot(scene, vec3(0.299, 0.587, 0.114));

	// Boost brightness
	lum = clamp(lum * brightness_boost, 0.0, 1.0);

	// Green monochrome with slight variation
	vec3 col = vec3(lum * 0.2, lum, lum * 0.2);

	// Film grain
	float grain = (hash(uv * 500.0 + TIME * 137.0) - 0.5) * grain_amount;
	col += grain;

	// Scanlines
	float sl = sin(uv.y / SCREEN_PIXEL_SIZE.y * 3.14159 * 0.5) * 0.5 + 0.5;
	col *= 1.0 - scanline_intensity * (1.0 - sl);

	// Heavy vignette
	vec2 vc = uv - 0.5;
	float vig = 1.0 - dot(vc, vc) * 2.5;
	vig = clamp(vig, 0.0, 1.0);
	col *= vig;

	COLOR = vec4(col, 1.0);
}

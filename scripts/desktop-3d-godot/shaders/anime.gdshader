shader_type canvas_item;

// Anime Cel-Shade Post-FX — quantized diffuse (3 bands) + Sobel edge outlines + rim light
// Transforms any 3D scene into anime/cel-shaded style

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

// Edge detection kernel offsets
vec3 sobel_sample(sampler2D tex, vec2 uv, vec2 pixel_size) {
	vec3 tl = texture(tex, uv + vec2(-1, -1) * pixel_size).rgb;
	vec3 tc = texture(tex, uv + vec2(0, -1) * pixel_size).rgb;
	vec3 tr = texture(tex, uv + vec2(1, -1) * pixel_size).rgb;
	vec3 ml = texture(tex, uv + vec2(-1, 0) * pixel_size).rgb;
	vec3 mr = texture(tex, uv + vec2(1, 0) * pixel_size).rgb;
	vec3 bl = texture(tex, uv + vec2(-1, 1) * pixel_size).rgb;
	vec3 bc = texture(tex, uv + vec2(0, 1) * pixel_size).rgb;
	vec3 br = texture(tex, uv + vec2(1, 1) * pixel_size).rgb;

	// Sobel X and Y on luminance
	vec3 sx = -tl - 2.0 * ml - bl + tr + 2.0 * mr + br;
	vec3 sy = -tl - 2.0 * tc - tr + bl + 2.0 * bc + br;

	return sqrt(sx * sx + sy * sy);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 ps = SCREEN_PIXEL_SIZE;

	// Original color
	vec3 color = texture(SCREEN_TEXTURE, uv).rgb;

	// ── Quantize to 3 brightness bands (cel-shading) ──
	float luma = dot(color, vec3(0.299, 0.587, 0.114));
	float quantized;
	if (luma > 0.66) {
		quantized = 1.0;
	} else if (luma > 0.33) {
		quantized = 0.6;
	} else if (luma > 0.1) {
		quantized = 0.3;
	} else {
		quantized = 0.08;
	}

	// Preserve hue, apply quantized brightness
	vec3 cel = color * (quantized / max(luma, 0.001));
	cel = clamp(cel, vec3(0.0), vec3(1.5));

	// ── Sobel edge detection ──
	vec3 edge = sobel_sample(SCREEN_TEXTURE, uv, ps * 1.5);
	float edge_strength = dot(edge, vec3(0.333));

	// Thick dark outlines
	float outline = smoothstep(0.08, 0.2, edge_strength);

	// ── Rim light effect (bright edges at high luminance contrast) ──
	float rim = smoothstep(0.5, 0.8, edge_strength) * smoothstep(0.3, 0.6, luma);
	cel += vec3(rim * 0.2);

	// Apply outlines — dark ink lines
	vec3 result = mix(cel, vec3(0.02, 0.01, 0.03), outline);

	// Slight saturation boost for anime vibrancy
	float result_luma = dot(result, vec3(0.299, 0.587, 0.114));
	result = mix(vec3(result_luma), result, 1.3);
	result = clamp(result, vec3(0.0), vec3(1.0));

	COLOR = vec4(result, 1.0);
}

shader_type canvas_item;

// Kuwahara filter — oil painting post-processing
// Divides each pixel's neighborhood into 4 quadrants, picks the one with
// lowest variance → painterly flat-color regions with preserved edges
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform int radius : hint_range(2, 12) = 5;
uniform float sharpness : hint_range(0.5, 5.0) = 2.0;
uniform float saturation_boost : hint_range(0.0, 1.0) = 0.3;
uniform float edge_darken : hint_range(0.0, 1.0) = 0.2;

float luminance(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE;
	vec2 uv = SCREEN_UV;

	// Four quadrant accumulators: mean color + mean squared luminance
	vec3 mean[4];
	float var_acc[4];
	int count[4];

	for (int i = 0; i < 4; i++) {
		mean[i] = vec3(0.0);
		var_acc[i] = 0.0;
		count[i] = 0;
	}

	// Sample the neighborhood, assign each sample to a quadrant
	for (int y = -radius; y <= radius; y++) {
		for (int x = -radius; x <= radius; x++) {
			vec3 s = texture(screen_texture, uv + vec2(float(x), float(y)) * px).rgb;
			float lum = luminance(s);

			// Quadrant index: 0=top-left, 1=top-right, 2=bottom-left, 3=bottom-right
			int qx = x >= 0 ? 1 : 0;
			int qy = y >= 0 ? 1 : 0;
			int q = qy * 2 + qx;

			mean[q] += s;
			var_acc[q] += lum * lum;
			count[q]++;
		}
	}

	// Finalize means and variances, pick lowest variance quadrant
	float min_var = 1e10;
	vec3 result = vec3(0.0);

	for (int i = 0; i < 4; i++) {
		if (count[i] > 0) {
			float fc = float(count[i]);
			mean[i] /= fc;
			float mean_lum = luminance(mean[i]);
			float variance = (var_acc[i] / fc) - mean_lum * mean_lum;

			// Sharpness controls how aggressively we pick the flattest region
			float weight = exp(-variance * sharpness * 1000.0);
			if (variance < min_var) {
				min_var = variance;
				result = mean[i];
			}
		}
	}

	// Optional: boost saturation for more painterly look
	float lum = luminance(result);
	result = mix(vec3(lum), result, 1.0 + saturation_boost);

	// Optional: darken edges (high variance areas)
	// Compute full-neighborhood variance for edge detection
	vec3 full_mean = vec3(0.0);
	float full_var = 0.0;
	float full_count = 0.0;
	for (int y = -2; y <= 2; y++) {
		for (int x = -2; x <= 2; x++) {
			vec3 s = texture(screen_texture, uv + vec2(float(x), float(y)) * px).rgb;
			full_mean += s;
			full_var += luminance(s) * luminance(s);
			full_count += 1.0;
		}
	}
	full_mean /= full_count;
	float edge = sqrt(max(full_var / full_count - luminance(full_mean) * luminance(full_mean), 0.0));
	result *= 1.0 - edge * edge_darken * 5.0;

	COLOR = vec4(result, 1.0);
}

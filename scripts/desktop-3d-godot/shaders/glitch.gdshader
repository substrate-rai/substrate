shader_type canvas_item;

// Glitch — block displacement + color channel separation + temporal noise
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float intensity : hint_range(0.0, 1.0) = 0.5;
uniform float block_size : hint_range(4.0, 64.0) = 16.0;
uniform float color_shift : hint_range(0.0, 20.0) = 5.0;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float block_noise(vec2 uv, float t) {
	vec2 block = floor(uv * block_size);
	return hash(block + floor(t * 4.0));
}

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = TIME;

	// Determine if this block is glitching
	float glitch_trigger = block_noise(uv, t);
	float is_glitched = step(1.0 - intensity * 0.3, glitch_trigger);

	// Block displacement
	float displacement = 0.0;
	if (is_glitched > 0.5) {
		float block_hash = hash(floor(uv * block_size) + floor(t * 8.0));
		displacement = (block_hash - 0.5) * 0.1 * intensity;
	}

	vec2 displaced_uv = vec2(uv.x + displacement, uv.y);

	// Occasional full-line shift
	float line_shift = 0.0;
	float line_hash = hash(vec2(floor(uv.y * 200.0), floor(t * 3.0)));
	if (line_hash > 1.0 - intensity * 0.05) {
		line_shift = (hash(vec2(floor(uv.y * 200.0), floor(t * 7.0))) - 0.5) * 0.05 * intensity;
	}
	displaced_uv.x += line_shift;

	// Color channel separation
	float shift = color_shift * 0.001 * intensity * (1.0 + is_glitched * 2.0);
	float r = texture(screen_texture, displaced_uv + vec2(shift, 0.0)).r;
	float g = texture(screen_texture, displaced_uv).g;
	float b = texture(screen_texture, displaced_uv - vec2(shift, 0.0)).b;

	vec3 col = vec3(r, g, b);

	// Occasional color inversion on glitched blocks
	float invert_hash = hash(floor(uv * block_size * 0.5) + floor(t * 2.0));
	if (is_glitched > 0.5 && invert_hash > 0.8) {
		col = 1.0 - col;
	}

	// Temporal noise scanlines
	float scan_noise = hash(vec2(uv.y * 500.0, t * 50.0));
	col += (scan_noise - 0.5) * 0.02 * intensity;

	COLOR = vec4(col, 1.0);
}

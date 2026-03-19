shader_type canvas_item;

// Pixelate — quantize UV to grid with optional color posterization
uniform sampler2D screen_texture : hint_screen_texture, filter_nearest;
uniform float pixel_size : hint_range(2.0, 32.0) = 8.0;
uniform float color_levels : hint_range(2.0, 32.0) = 8.0;

void fragment() {
	// Quantize UV to pixel grid
	vec2 screen_res = 1.0 / SCREEN_PIXEL_SIZE;
	vec2 grid = floor(SCREEN_UV * screen_res / pixel_size) * pixel_size / screen_res;

	vec3 col = texture(screen_texture, grid).rgb;

	// Posterize colors
	col = floor(col * color_levels + 0.5) / color_levels;

	COLOR = vec4(col, 1.0);
}

shader_type canvas_item;

// ASCII art — brightness mapped to character density approximation on grid cells
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float cell_size : hint_range(4.0, 24.0) = 10.0;
uniform vec3 text_color : source_color = vec3(0.0, 1.0, 0.66);
uniform float bg_mix : hint_range(0.0, 1.0) = 0.1;

// Approximate ASCII character density patterns using procedural shapes
// Characters approximated by density: " .:-=+*#%@"
float char_pattern(vec2 uv, float density) {
	// uv is 0..1 within the cell
	float d = 0.0;

	if (density < 0.1) {
		// Space — empty
		d = 0.0;
	} else if (density < 0.2) {
		// Dot — single point
		d = step(length(uv - 0.5), 0.12);
	} else if (density < 0.3) {
		// Colon — two dots
		d = step(length(uv - vec2(0.5, 0.3)), 0.1);
		d += step(length(uv - vec2(0.5, 0.7)), 0.1);
	} else if (density < 0.4) {
		// Dash — horizontal line
		d = step(abs(uv.y - 0.5), 0.08) * step(abs(uv.x - 0.5), 0.3);
	} else if (density < 0.5) {
		// Plus — cross
		d = step(abs(uv.y - 0.5), 0.08) * step(abs(uv.x - 0.5), 0.3);
		d += step(abs(uv.x - 0.5), 0.08) * step(abs(uv.y - 0.5), 0.3);
		d = min(d, 1.0);
	} else if (density < 0.6) {
		// Star — cross + diagonals center
		d = step(abs(uv.y - 0.5), 0.06) * step(abs(uv.x - 0.5), 0.25);
		d += step(abs(uv.x - 0.5), 0.06) * step(abs(uv.y - 0.5), 0.25);
		d += step(length(uv - 0.5), 0.15);
		d = min(d, 1.0);
	} else if (density < 0.75) {
		// Hash — grid
		d = step(abs(uv.x - 0.3), 0.05) + step(abs(uv.x - 0.7), 0.05);
		d += step(abs(uv.y - 0.35), 0.05) + step(abs(uv.y - 0.65), 0.05);
		d = min(d, 1.0);
	} else if (density < 0.9) {
		// Percent — two circles + diagonal
		d = step(length(uv - vec2(0.3, 0.3)), 0.15);
		d += step(length(uv - vec2(0.7, 0.7)), 0.15);
		d += step(abs((uv.x - uv.y)), 0.06);
		d = min(d, 1.0);
	} else {
		// @ — filled circle with hole
		float outer = step(length(uv - 0.5), 0.42);
		float inner = 1.0 - step(length(uv - 0.5), 0.15);
		d = outer * inner;
		// Fill more for higher density
		d = max(d, step(length(uv - 0.5), 0.42) * 0.7);
	}

	return d;
}

void fragment() {
	vec2 screen_res = 1.0 / SCREEN_PIXEL_SIZE;

	// Cell grid
	vec2 cell = floor(SCREEN_UV * screen_res / cell_size);
	vec2 cell_uv = fract(SCREEN_UV * screen_res / cell_size);

	// Sample scene at cell center
	vec2 sample_uv = (cell + 0.5) * cell_size / screen_res;
	vec3 scene = texture(screen_texture, sample_uv).rgb;
	float lum = dot(scene, vec3(0.299, 0.587, 0.114));

	// Get character pattern
	float pattern = char_pattern(cell_uv, lum);

	// Color: text color modulated by scene brightness, with optional bg
	vec3 bg = scene * bg_mix;
	vec3 col = mix(bg, text_color * (0.5 + lum * 0.5), pattern);

	COLOR = vec4(col, 1.0);
}

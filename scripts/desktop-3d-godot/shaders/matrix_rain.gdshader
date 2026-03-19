shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

// Matrix digital rain
global uniform float audio_bass;
global uniform float audio_energy;
global uniform float beat_intensity;

uniform vec3 rain_color : source_color = vec3(0.0, 1.0, 0.4);
uniform float column_count = 40.0;
uniform float fall_speed = 0.8;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float glyph(vec2 uv, float seed) {
	// Pseudo-glyph pattern — grid of dots that hash into shapes
	vec2 cell = floor(uv * 5.0);
	float h = hash(cell + seed);
	// Different density patterns based on hash
	float pattern = step(0.35, h);
	// Smooth the edges a bit
	vec2 f = fract(uv * 5.0);
	float shape = pattern * step(0.15, f.x) * step(f.x, 0.85) * step(0.1, f.y) * step(f.y, 0.9);
	return shape;
}

void fragment() {
	vec2 uv = UV;
	uv.x *= 1.777;

	float t = TIME * fall_speed;
	vec3 col = vec3(0.005, 0.01, 0.005); // near-black green tint

	float rows = column_count * 0.5625; // 16:9 cells

	for (int layer = 0; layer < 3; layer++) {
		float fl = float(layer);
		float depth = 1.0 - fl * 0.3;
		float cols = column_count * depth;

		vec2 grid = vec2(cols, rows * depth);
		vec2 cell_id = floor(uv * grid);
		vec2 cell_uv = fract(uv * grid);

		// Column properties from hash
		float col_hash = hash(vec2(cell_id.x, fl * 100.0));
		float col_speed = 0.5 + col_hash * 1.0 + audio_energy * 0.5;
		float col_offset = col_hash * 50.0;

		// Falling position
		float fall = t * col_speed + col_offset;
		float stream_pos = fract(-cell_id.y / (rows * depth) + fall);

		// Trail — bright head, fading tail
		float trail_len = 0.3 + col_hash * 0.4 + audio_bass * 0.2;
		float brightness = smoothstep(trail_len, 0.0, stream_pos);

		// Head glow
		float head = smoothstep(0.02, 0.0, stream_pos) * 2.0;

		// Glyph character
		float change_rate = floor(TIME * (2.0 + col_hash * 5.0));
		float seed = hash(cell_id + change_rate + fl * 7.0);
		float g = glyph(cell_uv, seed);

		// Color — head is white, trail is green
		vec3 char_color = mix(rain_color * depth, vec3(0.8, 1.0, 0.9), head * 0.7);

		// Beat flash
		char_color += rain_color * beat_intensity * 0.3;

		col += char_color * g * (brightness + head) * 0.4 * depth;
	}

	// Scanline overlay
	float scanline = sin(uv.y * 800.0) * 0.03 + 1.0;
	col *= scanline;

	// Vignette
	vec2 vc = (uv - 0.5) * vec2(1.777, 1.0);
	col *= 1.0 - dot(vc, vc) * 0.3;

	ALBEDO = col;
}

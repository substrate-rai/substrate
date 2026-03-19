shader_type canvas_item;

// CRT post-processing — scanlines, barrel distortion, phosphor glow
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float scanline_intensity : hint_range(0.0, 1.0) = 0.3;
uniform float curvature : hint_range(0.0, 10.0) = 3.0;
uniform float vignette_strength : hint_range(0.0, 2.0) = 0.8;
uniform float rgb_shift : hint_range(0.0, 5.0) = 1.5;
uniform float noise_amount : hint_range(0.0, 0.2) = 0.03;
uniform float flicker : hint_range(0.0, 0.1) = 0.02;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 barrel_distort(vec2 uv, float k) {
	vec2 c = uv - 0.5;
	float r2 = dot(c, c);
	float f = 1.0 + r2 * k * 0.01;
	return c * f + 0.5;
}

void fragment() {
	// Barrel distortion
	vec2 uv = barrel_distort(UV, curvature);

	// Screen pixel size (Godot 4 canvas_item uses 1/viewport_size)
	vec2 pix = vec2(1.0) / vec2(textureSize(screen_texture, 0));

	// Out of bounds — black border (no return in fragment)
	bool oob = uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0;

	// RGB shift (chromatic aberration)
	float shift = rgb_shift * 0.001;
	float r = texture(screen_texture, uv + vec2(shift, 0)).r;
	float g = texture(screen_texture, uv).g;
	float b = texture(screen_texture, uv - vec2(shift, 0)).b;
	vec3 col = vec3(r, g, b);

	// Scanlines
	float sl = sin(uv.y / pix.y * 3.14159) * 0.5 + 0.5;
	col *= 1.0 - scanline_intensity * (1.0 - sl);

	// Phosphor pattern (RGB subpixels)
	float px = mod(uv.x / pix.x, 3.0);
	vec3 phosphor = vec3(
		smoothstep(0.0, 1.0, px) * smoothstep(2.0, 1.0, px),
		smoothstep(1.0, 2.0, px) * smoothstep(3.0, 2.0, px),
		smoothstep(2.0, 3.0, px)
	);
	col *= mix(vec3(1.0), phosphor * 1.5, 0.15);

	// Film grain noise
	float grain = hash(uv * 500.0 + TIME * 100.0) * noise_amount;
	col += grain;

	// Flicker
	col *= 1.0 - flicker * sin(TIME * 8.0 + sin(TIME * 23.0));

	// Vignette
	vec2 vc = uv - 0.5;
	float vig = 1.0 - dot(vc, vc) * vignette_strength;
	col *= vig;

	// Slight green phosphor tint
	col *= vec3(0.95, 1.0, 0.95);

	// Apply OOB mask (black outside barrel distortion)
	col = mix(col, vec3(0.0), float(oob));

	COLOR = vec4(col, 1.0);
}

shader_type canvas_item;

// Ink/watercolor post-processing — edge detection + paper texture
uniform sampler2D screen_texture : hint_screen_texture, filter_linear_mipmap;
uniform float edge_strength : hint_range(0.0, 5.0) = 2.0;
uniform float color_reduction : hint_range(2.0, 16.0) = 6.0;
uniform float paper_strength : hint_range(0.0, 0.5) = 0.15;
uniform vec3 ink_color : source_color = vec3(0.08, 0.05, 0.03);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1,0)), f.x),
		mix(hash(i + vec2(0,1)), hash(i + vec2(1,1)), f.x),
		f.y
	);
}

float fbm(vec2 p) {
	float v = 0.0, a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.0;
		a *= 0.5;
	}
	return v;
}

float luminance(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

void fragment() {
	vec2 px = SCREEN_PIXEL_SIZE;

	// Sobel edge detection
	float tl = luminance(texture(screen_texture, UV + vec2(-px.x, -px.y)).rgb);
	float t  = luminance(texture(screen_texture, UV + vec2(0, -px.y)).rgb);
	float tr = luminance(texture(screen_texture, UV + vec2(px.x, -px.y)).rgb);
	float l  = luminance(texture(screen_texture, UV + vec2(-px.x, 0)).rgb);
	float r  = luminance(texture(screen_texture, UV + vec2(px.x, 0)).rgb);
	float bl = luminance(texture(screen_texture, UV + vec2(-px.x, px.y)).rgb);
	float b  = luminance(texture(screen_texture, UV + vec2(0, px.y)).rgb);
	float br = luminance(texture(screen_texture, UV + vec2(px.x, px.y)).rgb);

	float gx = -tl - 2.0*l - bl + tr + 2.0*r + br;
	float gy = -tl - 2.0*t - tr + bl + 2.0*b + br;
	float edge = sqrt(gx*gx + gy*gy) * edge_strength;
	edge = clamp(edge, 0.0, 1.0);

	// Base color with reduced palette
	vec3 base = texture(screen_texture, UV).rgb;
	base = floor(base * color_reduction + 0.5) / color_reduction;

	// Desaturate slightly for watercolor look
	float luma = luminance(base);
	base = mix(vec3(luma), base, 0.7);

	// Lighten to simulate watercolor transparency
	base = mix(base, vec3(0.95, 0.92, 0.88), 0.3);

	// Paper texture
	float paper = fbm(UV / SCREEN_PIXEL_SIZE * 0.003);
	paper = paper * 0.5 + 0.5;

	// Ink edges
	vec3 col = mix(base, ink_color, edge);

	// Paper grain
	col = mix(col, col * (0.85 + paper * 0.3), paper_strength);

	// Water bleed — slight color shift at edges
	float bleed = fbm(UV / SCREEN_PIXEL_SIZE * 0.01 + 5.0) * edge * 0.15;
	col += vec3(bleed * 0.5, bleed * 0.3, -bleed * 0.2);

	// Warm paper tint
	col *= vec3(1.0, 0.97, 0.93);

	COLOR = vec4(col, 1.0);
}

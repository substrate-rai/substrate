shader_type canvas_item;

// Chromatic Aberration Post-FX — radial RGB channel offset from center
// Lighter than CRT, works on any scene

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 center = vec2(0.5);

	// Offset direction: radial from center
	vec2 dir = uv - center;
	float dist = length(dir);

	// Aberration strength increases toward edges
	float strength = 0.004 * dist;

	// Sample each channel with offset
	float r = texture(SCREEN_TEXTURE, uv + dir * strength).r;
	float g = texture(SCREEN_TEXTURE, uv).g;
	float b = texture(SCREEN_TEXTURE, uv - dir * strength).b;

	COLOR = vec4(r, g, b, 1.0);
}

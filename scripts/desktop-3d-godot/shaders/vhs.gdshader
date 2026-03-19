shader_type canvas_item;

// VHS Post-FX — horizontal jitter, rolling band, color bleed, tracking lines, interlace
// Distinct from CRT (which does barrel distortion + phosphor grid)

uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

void fragment() {
	vec2 uv = SCREEN_UV;
	float t = TIME;

	// ── Tracking distortion — rolling horizontal band ──
	float band_pos = fract(t * 0.05); // slow rolling
	float band_dist = abs(uv.y - band_pos);
	float band = smoothstep(0.06, 0.0, band_dist);

	// Horizontal jitter in the band
	float jitter = band * sin(uv.y * 200.0 + t * 50.0) * 0.015;

	// Random horizontal jitter (tape wobble)
	float wobble = sin(uv.y * 5.0 + t * 3.0) * 0.001;
	wobble += sin(uv.y * 100.0 + t * 20.0) * 0.0005;

	vec2 distorted_uv = uv + vec2(jitter + wobble, 0.0);

	// ── Color channel separation (color bleed) ──
	float separation = 0.003 + band * 0.008;
	float r = texture(SCREEN_TEXTURE, distorted_uv + vec2(separation, 0.0)).r;
	float g = texture(SCREEN_TEXTURE, distorted_uv).g;
	float b = texture(SCREEN_TEXTURE, distorted_uv - vec2(separation, 0.0)).b;
	vec3 color = vec3(r, g, b);

	// ── Interlace lines ──
	float interlace = 0.92 + 0.08 * step(0.5, fract(uv.y * 540.0)); // 540 lines
	color *= interlace;

	// ── Tape noise — horizontal static bursts ──
	float noise_seed = fract(sin(dot(floor(vec2(uv.y * 300.0, floor(t * 8.0))), vec2(127.1, 311.7))) * 43758.5453);
	float tape_noise = step(0.995, noise_seed);
	color = mix(color, vec3(noise_seed), tape_noise * 0.6);

	// ── Vertical color shift (tape age) ──
	color.r *= 1.05;
	color.b *= 0.92;

	// ── Slight desaturation ──
	float luma = dot(color, vec3(0.299, 0.587, 0.114));
	color = mix(vec3(luma), color, 0.85);

	// ── Vignette (soft CRT-like) ──
	vec2 vig = uv * (1.0 - uv);
	float vignette = pow(vig.x * vig.y * 15.0, 0.25);
	color *= vignette;

	// ── Rolling bar brightness ──
	color *= 1.0 - band * 0.3;

	COLOR = vec4(color, 1.0);
}

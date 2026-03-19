shader_type canvas_item;

// Noise-based dissolve transition between two scenes
// progress: 0.0 = fully scene A, 1.0 = fully scene B
// beat_intensity modulates edge glow width

global uniform float beat_intensity;
global uniform float audio_energy;

uniform sampler2D scene_a : filter_linear;
uniform sampler2D scene_b : filter_linear;
uniform float progress : hint_range(0.0, 1.0) = 0.0;
uniform float edge_width : hint_range(0.01, 0.2) = 0.08;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1, 0)), f.x),
		mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x),
		f.y
	);
}

float fbm(vec2 p) {
	float v = 0.0;
	float amp = 0.5;
	for (int i = 0; i < 4; i++) {
		v += amp * noise(p);
		p *= 2.0;
		amp *= 0.5;
	}
	return v;
}

void fragment() {
	vec4 col_a = texture(scene_a, UV);
	vec4 col_b = texture(scene_b, UV);

	// Noise pattern for dissolve — audio-reactive movement
	float n = fbm(UV * 6.0 + TIME * audio_energy * 0.5);

	// Dissolve threshold
	float threshold = progress;
	float diff = n - threshold;

	// Dynamic edge width — beats make the dissolve edge glow wider
	float dyn_edge = edge_width + beat_intensity * 0.05;

	// Edge glow — bright line at the dissolve boundary
	float edge_glow = smoothstep(dyn_edge, 0.0, abs(diff));
	vec3 glow_color = mix(vec3(0.0, 1.0, 0.66), vec3(1.0, 0.3, 0.8), progress);

	// Blend
	float mix_factor = smoothstep(-dyn_edge * 0.5, dyn_edge * 0.5, diff);
	vec4 result = mix(col_b, col_a, mix_factor);

	// Add edge glow
	result.rgb += glow_color * edge_glow * 0.8;

	COLOR = result;
}

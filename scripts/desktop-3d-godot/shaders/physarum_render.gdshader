shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

// Physarum trail map renderer — reads trail texture, applies mycopunk color ramp
// Trail map is updated by compute shader (physarum.glsl)

uniform sampler2D trail_texture : filter_linear;

global uniform float audio_energy;
global uniform float beat_intensity;
global uniform float system_load;
global uniform vec3 cursor_world_pos;

void fragment() {
	vec2 uv = UV;

	float trail = texture(trail_texture, uv).r;

	// Cursor attractor glow
	vec2 cursor_uv = cursor_world_pos.xz * 0.05 + 0.5;
	float cursor_dist = length(uv - cursor_uv);
	float cursor_glow = smoothstep(0.15, 0.0, cursor_dist) * 0.3;
	trail += cursor_glow;

	// Mycopunk color ramp — dark → green → cyan → bright
	vec3 color;
	if (trail < 0.1) {
		color = mix(vec3(0.0, 0.01, 0.005), vec3(0.0, 0.1, 0.05), trail / 0.1);
	} else if (trail < 0.3) {
		color = mix(vec3(0.0, 0.1, 0.05), vec3(0.0, 0.6, 0.4), (trail - 0.1) / 0.2);
	} else if (trail < 0.6) {
		color = mix(vec3(0.0, 0.6, 0.4), vec3(0.0, 1.0, 0.67), (trail - 0.3) / 0.3);
	} else if (trail < 0.85) {
		color = mix(vec3(0.0, 1.0, 0.67), vec3(0.3, 1.0, 0.9), (trail - 0.6) / 0.25);
	} else {
		color = mix(vec3(0.3, 1.0, 0.9), vec3(1.0, 1.0, 1.0), (trail - 0.85) / 0.15);
	}

	// Beat pulse glow
	color *= 1.0 + beat_intensity * 0.3;

	// Audio energy ambient glow
	color += vec3(0.0, audio_energy * 0.05, audio_energy * 0.03);

	ALBEDO = color;
	ALPHA = smoothstep(0.01, 0.05, trail);
}

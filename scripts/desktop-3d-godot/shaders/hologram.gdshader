shader_type spatial;
render_mode unshaded, cull_disabled;

global uniform vec3 cursor_world_pos;
global uniform float audio_bass;
global uniform float audio_mid;
global uniform float audio_treble;
global uniform float audio_energy;
global uniform float beat_intensity;
global uniform float notify_flash;

uniform vec3 holo_color : source_color = vec3(0.0, 0.8, 1.0);
uniform float scanline_density : hint_range(10.0, 200.0) = 80.0;
uniform float scanline_strength : hint_range(0.0, 1.0) = 0.3;
uniform float flicker_speed : hint_range(0.0, 20.0) = 8.0;
uniform float base_alpha : hint_range(0.0, 1.0) = 0.7;
uniform float glitch_radius : hint_range(1.0, 15.0) = 5.0;

float rand(float x) {
	return fract(sin(x * 127.1) * 43758.5453);
}

void fragment() {
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float cursor_dist = distance(world_pos, cursor_world_pos);
	float proximity = 1.0 - clamp(cursor_dist / glitch_radius, 0.0, 1.0);

	// Scanlines scroll speed synced to audio mid — feels like data flow
	float scan_speed = 2.0 + audio_mid * 12.0;
	float scanline = sin(UV.y * scanline_density + TIME * scan_speed) * 0.5 + 0.5;
	scanline = mix(1.0, scanline, scanline_strength);

	// Flicker — bass hits cause brief stability breaks
	float flicker_rate = flicker_speed + audio_bass * 15.0;
	float flicker_intensity = mix(0.35, 0.05, proximity);
	float flicker = 1.0 - flicker_intensity * step(0.95, rand(floor(TIME * flicker_rate)));

	// Beat causes full-screen glitch burst
	float beat_glitch = beat_intensity * step(0.85, rand(floor(UV.y * 20.0 + TIME * 5.0))) * 0.08;

	// Cursor + treble glitch
	float glitch = beat_glitch;
	if (proximity > 0.3) {
		float glitch_line = step(0.97, rand(floor(UV.y * 30.0 + TIME * 3.0)));
		glitch += glitch_line * 0.03 * proximity;
	}
	// Treble causes fine horizontal noise
	glitch += audio_treble * 0.01 * (rand(floor(UV.y * 80.0 + TIME * 20.0)) - 0.5);

	vec2 uv_glitch = UV + vec2(glitch, 0.0);
	float edge_glow = smoothstep(0.0, 0.05, uv_glitch.x) * smoothstep(1.0, 0.95, uv_glitch.x);

	// Color reacts to audio energy — brighter, more saturated
	float energy_boost = 1.0 + audio_energy * 0.8;
	vec3 color = holo_color * energy_boost * (1.0 + 0.3 * proximity);

	// Bass shifts hue toward warmer tones
	color = mix(color, color * vec3(1.2, 0.9, 0.8), audio_bass * 0.4);

	// Notification flash — screen goes white briefly
	color = mix(color, vec3(2.0), notify_flash * 0.6);

	color *= scanline * flicker * edge_glow;

	ALBEDO = color;
	ALPHA = base_alpha * flicker * edge_glow * (0.8 + audio_energy * 0.4);
	if (ALPHA < 0.01) discard;
}

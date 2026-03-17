shader_type spatial;
render_mode depth_draw_always, cull_disabled;

global uniform vec3 cursor_world_pos;
global uniform float audio_bass;
global uniform float audio_mid;
global uniform float audio_treble;
global uniform float beat_intensity;
global uniform float weather_intensity;

uniform vec3 water_color : source_color = vec3(0.06, 0.15, 0.12);
uniform float metallic = 0.7;
uniform float roughness = 0.05;
uniform float wave_speed = 1.5;
uniform float wave_strength = 0.02;
uniform float ripple_radius : hint_range(0.5, 8.0) = 3.0;
uniform float ripple_strength : hint_range(0.0, 0.1) = 0.04;
uniform float ripple_frequency : hint_range(2.0, 20.0) = 8.0;

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	// Base waves — bass amplifies, weather adds chop
	float bass_amp = 1.0 + audio_bass * 3.0 + weather_intensity * 0.5;
	float base_wave = sin(world_pos.x * 3.0 + TIME * wave_speed) * wave_strength * bass_amp;
	base_wave += cos(world_pos.z * 2.5 + TIME * wave_speed * 0.7) * wave_strength * bass_amp;

	// Mid-frequency detail waves — audio mid adds surface texture
	float detail = sin(world_pos.x * 8.0 + TIME * 3.0) * audio_mid * 0.008;
	detail += cos(world_pos.z * 7.0 + TIME * 2.5) * audio_mid * 0.006;

	// Beat splash — sudden upward displacement
	float beat_splash = beat_intensity * 0.03 * sin(world_pos.x * 5.0 + world_pos.z * 5.0);

	// Cursor ripple with audio-enhanced frequency
	float cursor_dist = distance(world_pos.xz, cursor_world_pos.xz);
	float ripple_falloff = 1.0 - clamp(cursor_dist / ripple_radius, 0.0, 1.0);
	ripple_falloff = ripple_falloff * ripple_falloff;
	float freq = ripple_frequency + audio_treble * 8.0;
	float ripple = sin(cursor_dist * freq - TIME * 4.0) * ripple_strength * ripple_falloff;

	VERTEX.y += base_wave + detail + beat_splash + ripple;
}

void fragment() {
	float fresnel = pow(1.0 - dot(NORMAL, VIEW), 3.0);

	// Audio energy subtly brightens water, bass warms it
	vec3 color = water_color * (1.0 + audio_bass * 0.3);
	color = mix(color, color + vec3(0.02, 0.01, 0.0), audio_bass);

	ALBEDO = color;
	METALLIC = metallic;
	ROUGHNESS = roughness * (1.0 - audio_mid * 0.3); // smoother when music flows
	ALPHA = mix(0.6, 0.95, fresnel);
}

shader_type spatial;
render_mode cull_disabled;

global uniform vec3 cursor_world_pos;
global uniform float audio_bass;
global uniform float audio_energy;
global uniform float beat_intensity;
global uniform float system_heat;
global uniform float weather_intensity;

uniform vec3 top_color : source_color = vec3(0.35, 0.6, 0.18);
uniform vec3 bottom_color : source_color = vec3(0.15, 0.3, 0.06);
uniform float wind_strength : hint_range(0.0, 1.0) = 0.15;
uniform float wind_speed : hint_range(0.0, 2.0) = 0.8;
uniform float cursor_push_radius : hint_range(0.5, 8.0) = 3.0;
uniform float cursor_push_strength : hint_range(0.0, 1.0) = 0.4;

void vertex() {
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;

	// Wind sway — audio energy amplifies, weather (wind) adds intensity
	float wind_amp = wind_strength * (1.0 + audio_energy * 1.5 + weather_intensity * 0.5);
	float wind_spd = wind_speed * (1.0 + audio_bass * 0.8);
	float sway = sin(world_pos.x * 1.5 + TIME * wind_spd)
	           * cos(world_pos.z * 1.2 + TIME * wind_spd * 0.7);
	float tip_factor = 1.0 - UV.y;

	vec3 displacement = vec3(sway * wind_amp, 0.0, sway * wind_amp * 0.5) * tip_factor;

	// Beat stomp — all grass briefly flattens on hard bass hits
	displacement.y -= beat_intensity * 0.08 * tip_factor;

	// Cursor push
	vec2 to_cursor = world_pos.xz - cursor_world_pos.xz;
	float cursor_dist = length(to_cursor);
	float push = 1.0 - clamp(cursor_dist / cursor_push_radius, 0.0, 1.0);
	push = push * push;
	vec2 push_dir = normalize(to_cursor + vec2(0.001, 0.001));
	displacement.x += push_dir.x * push * cursor_push_strength * tip_factor;
	displacement.z += push_dir.y * push * cursor_push_strength * tip_factor;

	VERTEX += displacement;
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	// Heat shifts grass from green toward dry golden/brown
	vec3 cool_top = top_color;
	vec3 hot_top = vec3(0.55, 0.45, 0.15);  // parched golden
	vec3 final_top = mix(cool_top, hot_top, system_heat * 0.6);

	vec3 cool_bot = bottom_color;
	vec3 hot_bot = vec3(0.3, 0.22, 0.06);
	vec3 final_bot = mix(cool_bot, hot_bot, system_heat * 0.6);

	// Audio energy adds subtle luminous tint to tips
	vec3 audio_tint = vec3(0.1, 0.15, 0.05) * audio_energy;

	ALBEDO = mix(final_bot, final_top + audio_tint, 1.0 - UV.y);
	ROUGHNESS = 0.6;
	if (!FRONT_FACING) { NORMAL = -NORMAL; }
}

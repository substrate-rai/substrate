shader_type spatial;

global uniform vec3 cursor_world_pos;
global uniform float audio_bass;
global uniform float audio_mid;
global uniform float audio_energy;
global uniform float beat_intensity;
global uniform float system_heat;
global uniform float notify_flash;

uniform vec3 base_emission : source_color = vec3(1.0, 0.6, 0.2);
uniform float base_strength : hint_range(0.0, 5.0) = 1.0;
uniform float max_strength : hint_range(0.0, 10.0) = 6.0;
uniform float glow_radius : hint_range(0.5, 20.0) = 5.0;
uniform float roughness : hint_range(0.0, 1.0) = 0.5;
uniform vec3 albedo : source_color = vec3(0.1, 0.08, 0.06);
uniform float pulse_speed : hint_range(0.0, 4.0) = 1.5;

void fragment() {
	vec3 world_pos = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float dist = distance(world_pos, cursor_world_pos);
	float proximity = 1.0 - clamp(dist / glow_radius, 0.0, 1.0);
	proximity = proximity * proximity;

	// Pulse syncs to music — bass drives the throb
	float audio_pulse = 1.0 + audio_bass * 0.8 + beat_intensity * 0.5;
	float time_pulse = 1.0 + 0.15 * sin(TIME * pulse_speed + world_pos.x * 2.0);

	// Glow radius expands with audio energy
	float effective_radius = glow_radius * (1.0 + audio_energy * 0.5);
	float audio_proximity = 1.0 - clamp(dist / effective_radius, 0.0, 1.0);

	float strength = mix(base_strength, max_strength, max(proximity, audio_proximity * 0.6))
	               * audio_pulse * time_pulse;

	// Heat shifts emission toward red/amber
	vec3 heat_tint = mix(vec3(1.0), vec3(1.4, 0.7, 0.3), system_heat);

	// Notification flash — white burst
	vec3 notify_color = mix(vec3(0.0), vec3(3.0, 3.0, 3.0), notify_flash);

	ALBEDO = albedo;
	ROUGHNESS = roughness;
	EMISSION = base_emission * heat_tint * strength + notify_color;
}

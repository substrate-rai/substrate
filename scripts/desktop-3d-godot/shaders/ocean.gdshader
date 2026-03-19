shader_type spatial;
render_mode cull_disabled;

// Ocean surface — Gerstner wave displacement with Fresnel, foam, depth color
// Reactivity: audio_bass → wave height, weather_intensity → choppiness, system_heat → color

global uniform float audio_bass;
global uniform float audio_mid;
global uniform float audio_energy;
global uniform float beat_intensity;
global uniform float weather_intensity;
global uniform float system_heat;
global uniform vec3 cursor_world_pos;

// Gerstner wave: returns displacement
vec3 gerstner(vec2 pos, vec2 dir, float steepness, float wavelength, float t) {
	float k = TAU / wavelength;
	float c = sqrt(9.8 / k);
	float f = k * (dot(dir, pos) - c * t);
	float a = steepness / k;
	return vec3(dir.x * a * cos(f), a * sin(f), dir.y * a * cos(f));
}

void vertex() {
	vec2 pos = VERTEX.xz;

	float wave_height = 0.8 + audio_bass * 1.5;
	float chop = 0.3 + weather_intensity * 0.5;

	// Sum 4 Gerstner waves
	vec3 disp = vec3(0.0);
	disp += gerstner(pos, normalize(vec2(1.0, 0.3)), chop * 0.4, 8.0, TIME * 1.0) * wave_height;
	disp += gerstner(pos, normalize(vec2(-0.5, 0.7)), chop * 0.3, 5.0, TIME * 1.2) * wave_height * 0.7;
	disp += gerstner(pos, normalize(vec2(0.3, -0.8)), chop * 0.25, 3.0, TIME * 0.9) * wave_height * 0.5;
	disp += gerstner(pos, normalize(vec2(-0.7, -0.4)), chop * 0.2, 2.0, TIME * 1.5) * wave_height * 0.3;

	// Beat splash
	disp.y += beat_intensity * 0.3 * sin(pos.x * 2.0 + pos.y * 2.0);

	VERTEX += disp;

	// Compute approximate normal via finite differences
	float eps = 0.1;
	vec3 dx = gerstner(pos + vec2(eps, 0.0), normalize(vec2(1.0, 0.3)), chop * 0.4, 8.0, TIME) * wave_height;
	vec3 dz = gerstner(pos + vec2(0.0, eps), normalize(vec2(1.0, 0.3)), chop * 0.4, 8.0, TIME) * wave_height;
	NORMAL = normalize(vec3(-dx.y / eps, 1.0, -dz.y / eps));
}

void fragment() {
	// Beer's Law depth coloring
	vec3 deep_color = mix(vec3(0.0, 0.05, 0.2), vec3(0.2, 0.05, 0.02), system_heat);
	vec3 shallow_color = mix(vec3(0.0, 0.4, 0.5), vec3(0.3, 0.35, 0.15), system_heat);

	// Use world-space Y as depth proxy
	float depth = clamp((VERTEX.y + 1.0) * 0.5, 0.0, 1.0);
	vec3 water_color = mix(deep_color, shallow_color, depth);

	// Fresnel
	float fresnel = pow(1.0 - max(dot(NORMAL, VIEW), 0.0), 4.0);
	vec3 sky_reflect = mix(vec3(0.1, 0.15, 0.3), vec3(0.6, 0.5, 0.4), fresnel);

	// Foam at wave crests
	float foam = smoothstep(0.3, 0.8, VERTEX.y + 0.5) * (0.5 + weather_intensity * 0.5);
	foam *= 0.5 + 0.5 * sin(UV.x * 50.0 + TIME * 2.0); // breakup pattern

	vec3 color = mix(water_color, sky_reflect, fresnel * 0.6);
	color = mix(color, vec3(0.9, 0.95, 1.0), foam * 0.5);

	// Audio energy as subtle glow
	color += vec3(0.0, audio_energy * 0.05, audio_energy * 0.08);

	ALBEDO = color;
	METALLIC = 0.3;
	ROUGHNESS = mix(0.15, 0.5, foam);
	SPECULAR = 0.8;
	ALPHA = 0.92;
}

shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

// Volumetric Cloudscape — raymarched fBM noise with Beer-Lambert absorption
// Displayed as fullscreen spatial shader (same approach as fractal/aurora)
// Reactivity: weather_intensity → cloud density, audio_energy → turbulence

global uniform float weather_intensity;
global uniform float audio_energy;
global uniform float audio_bass;
global uniform float beat_intensity;
global uniform float system_heat;

float hash(vec3 p) {
	p = fract(p * vec3(443.897, 441.423, 437.195));
	p += dot(p, p.yzx + 19.19);
	return fract((p.x + p.y) * p.z);
}

float noise3d(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);

	float n = mix(
		mix(mix(hash(i), hash(i + vec3(1, 0, 0)), f.x),
			mix(hash(i + vec3(0, 1, 0)), hash(i + vec3(1, 1, 0)), f.x), f.y),
		mix(mix(hash(i + vec3(0, 0, 1)), hash(i + vec3(1, 0, 1)), f.x),
			mix(hash(i + vec3(0, 1, 1)), hash(i + vec3(1, 1, 1)), f.x), f.y),
		f.z
	);
	return n;
}

float fbm(vec3 p) {
	float v = 0.0;
	float amp = 0.5;
	float turbulence = audio_energy * 0.3;
	for (int i = 0; i < 6; i++) {
		v += amp * noise3d(p);
		p = p * 2.0 + vec3(0.1 * turbulence);
		amp *= 0.5;
	}
	return v;
}

float cloud_density(vec3 p) {
	float base_density = 0.4 + weather_intensity * 0.4;

	// Wind drift
	vec3 wind = vec3(TIME * 0.08, 0.0, TIME * 0.03);
	float n = fbm(p * 0.3 + wind);

	// Shape: clouds are denser in the middle band
	float height_fade = 1.0 - abs(p.y) * 0.15;
	height_fade = max(height_fade, 0.0);

	float density = (n - (1.0 - base_density)) * height_fade;
	return max(density, 0.0);
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;

	// Ray direction from camera-facing quad
	vec3 rd = normalize(vec3(uv.x * 1.6, uv.y * 0.9 + 0.2, -1.0));

	// Time-based sun angle
	float sun_angle = TIME * 0.02;
	vec3 sun_dir = normalize(vec3(cos(sun_angle), 0.4, sin(sun_angle)));

	// Sky gradient
	float sky_t = rd.y * 0.5 + 0.5;
	vec3 sky_top = mix(vec3(0.1, 0.15, 0.4), vec3(0.05, 0.08, 0.15), system_heat);
	vec3 sky_bottom = mix(vec3(0.5, 0.6, 0.8), vec3(0.6, 0.4, 0.3), system_heat);
	vec3 sky = mix(sky_bottom, sky_top, sky_t);

	// Sun glow
	float sun_dot = max(dot(rd, sun_dir), 0.0);
	sky += vec3(1.0, 0.8, 0.4) * pow(sun_dot, 32.0) * 0.5;
	sky += vec3(1.0, 0.6, 0.3) * pow(sun_dot, 4.0) * 0.15;

	// Raymarch through clouds
	vec3 color = sky;
	float transmittance = 1.0;
	float ray_start = 2.0;
	float ray_end = 20.0;
	int steps = 32;
	float step_size = (ray_end - ray_start) / float(steps);

	for (int i = 0; i < steps; i++) {
		float t = ray_start + (float(i) + 0.5) * step_size;
		vec3 p = rd * t;
		p.y += 3.0; // camera height offset

		float d = cloud_density(p);
		if (d > 0.001) {
			// Beer-Lambert absorption
			float absorption = exp(-d * step_size * 3.0);

			// Light sampling — single step toward sun
			vec3 light_pos = p + sun_dir * 2.0;
			float light_density = cloud_density(light_pos);
			float light_atten = exp(-light_density * 4.0);

			// Silver lining
			float silver = pow(max(dot(normalize(p), sun_dir), 0.0), 8.0) * 0.3;

			// Cloud color
			vec3 cloud_lit = mix(vec3(0.15, 0.17, 0.25), vec3(1.0, 0.95, 0.85), light_atten);
			cloud_lit += vec3(1.0, 0.9, 0.7) * silver;

			// Beat flash
			cloud_lit += vec3(0.1, 0.05, 0.15) * beat_intensity;

			// Accumulate
			color = mix(color, cloud_lit, (1.0 - absorption) * transmittance);
			transmittance *= absorption;

			if (transmittance < 0.01) break;
		}
	}

	ALBEDO = color;
	ALPHA = 1.0;
}

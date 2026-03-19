shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

// Julia set fractal — 2D complex plane (distinct from 3D Mandelbulb)
// Note: single-precision floats limit zoom depth — no deep zoom promised
global uniform float audio_bass;
global uniform float audio_energy;
global uniform float beat_intensity;

void fragment() {
	vec2 uv = (UV - 0.5) * 3.0;
	uv.x *= 1.777;

	// c parameter slowly orbits a circle in the complex plane
	float ct = TIME * 0.15;
	vec2 c = vec2(
		-0.7 + 0.15 * cos(ct) + audio_bass * 0.05,
		0.27015 + 0.15 * sin(ct * 0.7) + audio_bass * 0.03
	);

	vec2 z = uv;
	float iter = 0.0;
	float max_iter = 128.0;

	for (float i = 0.0; i < 128.0; i++) {
		// z = z^2 + c
		z = vec2(z.x * z.x - z.y * z.y, 2.0 * z.x * z.y) + c;
		if (dot(z, z) > 4.0) {
			iter = i;
			break;
		}
		iter = i;
	}

	// Smooth iteration count
	float smooth_iter = iter;
	if (dot(z, z) > 4.0) {
		smooth_iter = iter - log2(log2(dot(z, z))) + 4.0;
	}

	float t = smooth_iter / max_iter;

	// Color ramp — deep blue → cyan → magenta → gold
	vec3 col;
	if (t < 0.02) {
		col = vec3(0.0); // interior is black
	} else if (t < 0.15) {
		float s = (t - 0.02) / 0.13;
		col = mix(vec3(0.0, 0.0, 0.2), vec3(0.0, 0.5, 0.8), s);
	} else if (t < 0.4) {
		float s = (t - 0.15) / 0.25;
		col = mix(vec3(0.0, 0.5, 0.8), vec3(0.8, 0.2, 0.9), s);
	} else if (t < 0.7) {
		float s = (t - 0.4) / 0.3;
		col = mix(vec3(0.8, 0.2, 0.9), vec3(1.0, 0.8, 0.2), s);
	} else {
		float s = (t - 0.7) / 0.3;
		col = mix(vec3(1.0, 0.8, 0.2), vec3(1.0, 1.0, 0.9), s);
	}

	// Audio brightness
	col *= 0.8 + audio_energy * 0.4;

	// Beat pulse
	col += beat_intensity * 0.15 * col;

	ALBEDO = col;
}

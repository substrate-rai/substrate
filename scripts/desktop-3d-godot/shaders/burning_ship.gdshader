shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

// Burning Ship fractal — abs() variant of Mandelbrot
// Produces dramatic asymmetric structures resembling burning ships

global uniform float audio_bass;
global uniform float audio_mid;
global uniform float audio_treble;
global uniform float audio_energy;
global uniform float beat_intensity;
global uniform vec3 cursor_world_pos;

const int MAX_ITER = 256;

vec3 cosPalette(float t, vec3 a, vec3 b, vec3 c, vec3 d) {
	return a + b * cos(TAU * (c * t + d));
}

// Fire/ember palette
vec3 firePalette(float t) {
	return cosPalette(t,
		vec3(0.5, 0.2, 0.1),
		vec3(0.5, 0.4, 0.2),
		vec3(1.0, 0.8, 0.4),
		vec3(0.0, 0.05, 0.2)
	);
}

// Deep ocean palette
vec3 abyssPalette(float t) {
	return cosPalette(t,
		vec3(0.02, 0.05, 0.15),
		vec3(0.4, 0.3, 0.5),
		vec3(1.0, 0.7, 0.5),
		vec3(0.25, 0.1, 0.0)
	);
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float t = TIME;

	float bass = audio_bass;
	float mid = audio_mid;
	float treble = audio_treble;
	float energy = audio_energy;
	float beat = beat_intensity;

	// Zoom and pan — audio reactive slow zoom
	float zoom = 2.8 - bass * 0.3;
	// Interesting region of Burning Ship: around (-1.75, -0.04)
	float cycle = t * 0.02;
	vec2 center = vec2(
		-1.75 + sin(cycle) * 0.15,
		-0.035 + cos(cycle * 0.7) * 0.08
	);

	vec2 c = uv * zoom + center;

	// Burning Ship iteration: z = (|Re(z)| + i|Im(z)|)^2 + c
	vec2 z = vec2(0.0);
	float iter = 0.0;
	float smooth_iter = 0.0;

	for (int i = 0; i < MAX_ITER; i++) {
		z = abs(z); // The key difference from Mandelbrot
		float xnew = z.x * z.x - z.y * z.y + c.x;
		z.y = 2.0 * z.x * z.y + c.y;
		z.x = xnew;

		float mag2 = dot(z, z);
		if (mag2 > 256.0) {
			// Smooth iteration count
			smooth_iter = float(i) - log2(log2(mag2)) + 4.0;
			break;
		}
		iter = float(i);
		smooth_iter = float(i);
	}

	// Normalize iteration count
	float n = smooth_iter / float(MAX_ITER);

	vec3 col;
	if (smooth_iter >= float(MAX_ITER) - 1.0) {
		// Interior: deep black with faint ember glow
		col = vec3(0.01, 0.005, 0.0);
		float interior_glow = exp(-length(z) * 0.5);
		col += vec3(0.15, 0.03, 0.0) * interior_glow;
	} else {
		// Exterior: palette based on iteration count
		float palette_t = sqrt(n) * 3.0 + t * 0.05 + beat * 0.2;

		// Blend between fire and abyss palettes with mid
		vec3 fire = firePalette(palette_t);
		vec3 abyss = abyssPalette(palette_t + 0.3);
		float blend = sin(t * 0.08) * 0.5 + 0.5;
		col = mix(fire, abyss, blend);

		// Boost brightness for low iteration (near boundary)
		col *= 1.0 + (1.0 - n) * 0.5;

		// Audio: treble adds detail highlighting
		float detail = fract(smooth_iter * 0.1) * treble * 0.3;
		col += vec3(detail * 0.5, detail * 0.3, detail);
	}

	// Energy pulse
	col += vec3(0.1, 0.04, 0.0) * energy * 0.3;

	// Beat flash — orange
	col += vec3(0.3, 0.15, 0.05) * beat * 0.15;

	// Vignette
	float vig = 1.0 - dot(uv, uv) * 0.25;
	col *= vig;

	// Tone mapping
	col = col / (col + vec3(1.0));

	ALBEDO = col;
}

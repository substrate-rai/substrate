shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

global uniform float audio_bass;
global uniform float audio_energy;
global uniform float beat_intensity;

// Arnold Tongues — Mode Locking in Forced Oscillators
// Circle map: theta_{n+1} = theta_n + Omega - (K/2pi)*sin(2*pi*theta_n)
// X-axis: driving frequency Omega, Y-axis: coupling strength K
// Color by winding number (rotation number)

const int MAX_ITER = 200;
const int TRANSIENT = 100;

vec3 pal(float t) {
	return vec3(0.5) + vec3(0.5) * cos(TAU * (vec3(1.0, 1.0, 1.0) * t + vec3(0.0, 0.33, 0.67)));
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float t = TIME;
	float energy = audio_energy;
	float beat = beat_intensity;

	// Parameter space: Omega (0 to 1), K (0 to ~4)
	float omega = uv.x * 0.5 + 0.5;  // 0 to 1
	float K = (uv.y * 0.5 + 0.5) * 4.0;  // 0 to 4

	// Slowly drift through parameter space
	omega += sin(t * 0.02) * 0.05;

	// Iterate circle map
	float theta = 0.5;  // initial condition
	float total_rotation = 0.0;

	// Transient
	for (int i = 0; i < TRANSIENT; i++) {
		float old_theta = theta;
		theta = theta + omega - (K / TAU) * sin(TAU * theta);
		total_rotation += theta - old_theta;
	}

	// Measure winding number
	float rotation_sum = 0.0;
	for (int i = 0; i < MAX_ITER; i++) {
		float old_theta = theta;
		theta = theta + omega - (K / TAU) * sin(TAU * theta);
		rotation_sum += (theta - old_theta);
	}

	float winding = rotation_sum / float(MAX_ITER);

	// Detect mode-locked regions (rational winding number)
	// Near-rational winding numbers produce tongue interiors
	float nearest_rational = round(winding * 12.0) / 12.0;
	float lock_dist = abs(winding - nearest_rational);
	bool locked = lock_dist < 0.005;

	// Color scheme
	vec3 col = vec3(0.02, 0.01, 0.04);

	if (locked) {
		// Inside a tongue: color by which rational it locks to
		col = pal(nearest_rational + t * 0.01) * 0.9;
		// Brighter at tongue center
		float center_bright = 1.0 - lock_dist / 0.005;
		col *= 0.7 + center_bright * 0.3;
	} else {
		// Quasiperiodic region: color by winding number
		col = pal(winding * 3.0 + t * 0.02) * 0.25;
	}

	// Tongue boundary glow
	float boundary = smoothstep(0.008, 0.003, lock_dist);
	col += vec3(1.0, 0.85, 0.3) * boundary * 0.3;

	// Highlight specific famous tongues (1/1, 1/2, 1/3, 2/3, etc.)
	for (int p = 1; p <= 5; p++) {
		for (int q = 1; q <= 5; q++) {
			float rational = float(p) / float(q);
			if (rational <= 1.0) {
				float d = abs(winding - rational);
				float glow = exp(-d * 500.0) * 0.15;
				col += pal(rational) * glow;
			}
		}
	}

	// Audio
	col *= 1.0 + energy * 0.2;
	col += vec3(1.0) * beat * 0.03;

	// Vignette + tone map
	col *= 1.0 - dot(uv, uv) * 0.2;
	col = col / (col + vec3(1.0));

	ALBEDO = col;
}

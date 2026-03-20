shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

// Newton fractal — root-finding iteration for z^N - 1 = 0
// Each pixel colored by which root it converges to + how fast

global uniform float audio_bass;
global uniform float audio_mid;
global uniform float audio_treble;
global uniform float audio_energy;
global uniform float beat_intensity;
global uniform vec3 cursor_world_pos;

const int MAX_ITER = 64;
const float EPSILON = 0.0001;

// Complex multiplication
vec2 cmul(vec2 a, vec2 b) {
	return vec2(a.x * b.x - a.y * b.y, a.x * b.y + a.y * b.x);
}

// Complex division
vec2 cdiv(vec2 a, vec2 b) {
	float d = dot(b, b);
	return vec2(a.x * b.x + a.y * b.y, a.y * b.x - a.x * b.y) / d;
}

// z^n for integer n via repeated squaring
vec2 cpow(vec2 z, int n) {
	vec2 result = vec2(1.0, 0.0);
	vec2 base = z;
	int power = n;
	for (int i = 0; i < 8; i++) {
		if (power <= 0) break;
		if ((power & 1) == 1) {
			result = cmul(result, base);
		}
		base = cmul(base, base);
		power >>= 1;
	}
	return result;
}

// Derivative: d/dz(z^n) = n * z^(n-1)
vec2 cpow_deriv(vec2 z, int n) {
	return vec2(float(n), 0.0) * cpow(z, n - 1);
}

// Root colors — vivid and distinct
vec3 rootColor(int root_idx, float speed) {
	vec3 colors[7];
	colors[0] = vec3(0.1, 0.6, 1.0);   // cyan-blue
	colors[1] = vec3(1.0, 0.2, 0.4);   // red-pink
	colors[2] = vec3(0.2, 1.0, 0.4);   // green
	colors[3] = vec3(1.0, 0.7, 0.1);   // gold
	colors[4] = vec3(0.7, 0.2, 1.0);   // purple
	colors[5] = vec3(1.0, 0.4, 0.0);   // orange
	colors[6] = vec3(0.0, 0.9, 0.8);   // teal

	vec3 base = colors[root_idx % 7];
	// Darken based on convergence speed (more iterations = darker)
	return base * (0.3 + 0.7 * speed);
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float t = TIME;

	float bass = audio_bass;
	float mid = audio_mid;
	float treble = audio_treble;
	float energy = audio_energy;
	float beat = beat_intensity;

	// Polynomial degree: smoothly varies 3-7 with audio
	int degree = 3 + int(mid * 3.99);
	degree = clamp(degree, 3, 7);

	// Zoom and rotation
	float zoom = 1.8 + bass * 0.2;
	float angle = t * 0.04;
	float ca = cos(angle), sa = sin(angle);
	vec2 p = vec2(uv.x * ca - uv.y * sa, uv.x * sa + uv.y * ca) * zoom;

	// Small constant added to Newton's method for visual interest
	// a = relaxation parameter (1.0 = standard Newton)
	float relax = 1.0 + sin(t * 0.15) * 0.15 + treble * 0.1;

	// Newton iteration: z_new = z - relax * f(z)/f'(z)
	// f(z) = z^n - 1
	vec2 z = p;
	float iter = 0.0;
	int converged_root = -1;

	for (int i = 0; i < MAX_ITER; i++) {
		vec2 zn = cpow(z, degree);
		vec2 fz = zn - vec2(1.0, 0.0); // z^n - 1
		vec2 dfz = cpow_deriv(z, degree); // n * z^(n-1)

		if (dot(dfz, dfz) < EPSILON) break;

		vec2 step = cdiv(fz, dfz);
		z -= step * relax;

		// Check convergence
		if (dot(step, step) < EPSILON * EPSILON) {
			iter = float(i);
			break;
		}
		iter = float(i);
	}

	// Determine which root z converged to
	// Roots of z^n - 1 are at exp(2*pi*i*k/n) for k = 0..n-1
	float best_dist = 1e9;
	for (int k = 0; k < 7; k++) {
		if (k >= degree) break;
		float a = float(k) * TAU / float(degree);
		vec2 root = vec2(cos(a), sin(a));
		float d = length(z - root);
		if (d < best_dist) {
			best_dist = d;
			converged_root = k;
		}
	}

	// Speed: how quickly it converged (0 = slow, 1 = fast)
	float speed = 1.0 - iter / float(MAX_ITER);

	vec3 col;
	if (converged_root >= 0) {
		col = rootColor(converged_root, speed);

		// Add convergence contours (orbit trap rings)
		float contour = fract(iter * 0.15 + t * 0.03);
		contour = smoothstep(0.4, 0.5, contour) - smoothstep(0.5, 0.6, contour);
		col += vec3(contour) * 0.15;
	} else {
		col = vec3(0.02);
	}

	// Boundary glow — where convergence is slow, add glow
	float boundary = (1.0 - speed);
	col += vec3(0.3, 0.2, 0.5) * boundary * boundary * 0.4;

	// Energy: brighten boundaries
	col += vec3(0.15, 0.1, 0.25) * energy * boundary * 0.5;

	// Beat: flash white on boundaries
	col += vec3(1.0) * beat * boundary * 0.15;

	// Vignette
	float vig = 1.0 - dot(uv, uv) * 0.25;
	col *= vig;

	// Tone mapping
	col = col / (col + vec3(1.0));

	ALBEDO = col;
}

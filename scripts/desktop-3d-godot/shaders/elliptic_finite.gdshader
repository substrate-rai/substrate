shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

global uniform float audio_bass;
global uniform float audio_energy;
global uniform float beat_intensity;

// Elliptic Curves over Finite Fields
// y^2 = x^3 + ax + b (mod p)
// Each pixel tests if (x,y) is a point on the curve
// Animate the prime p for restructuring crystal patterns

vec3 pal(float t) {
	return vec3(0.5) + vec3(0.5) * cos(TAU * (vec3(1.0, 0.7, 0.4) * t + vec3(0.0, 0.15, 0.20)));
}

// Integer mod that handles negatives
int imod(int a, int m) {
	return ((a % m) + m) % m;
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float t = TIME;
	float energy = audio_energy;
	float beat = beat_intensity;

	// Animate prime: cycle through primes
	int primes[20] = int[](7, 11, 13, 17, 19, 23, 29, 31, 37, 41,
	                        43, 47, 53, 59, 61, 67, 71, 73, 79, 83);
	int prime_idx = int(mod(t * 0.3, 20.0));
	int p = primes[prime_idx];
	float fp = float(p);

	// Curve parameters (animate slowly)
	int a = int(mod(t * 0.1, fp));
	int b = int(mod(t * 0.07 + 3.0, fp));

	// Map pixel to field element
	int ix = int(floor((uv.x * 0.5 + 0.5) * fp));
	int iy = int(floor((uv.y * 0.5 + 0.5) * fp));
	ix = clamp(ix, 0, p - 1);
	iy = clamp(iy, 0, p - 1);

	// Check if (ix, iy) satisfies y^2 = x^3 + ax + b (mod p)
	int lhs = imod(iy * iy, p);
	int rhs = imod(ix * ix * ix + a * ix + b, p);
	bool on_curve = (lhs == rhs);

	// Color
	vec3 col = vec3(0.02, 0.01, 0.04);

	if (on_curve) {
		// Points on the curve
		float pt_color = float(ix + iy) / (fp * 2.0);
		col = pal(pt_color + t * 0.02) * 0.9;

		// Glow based on field element magnitude
		float mag = float(ix * ix + iy * iy) / (fp * fp);
		col *= 0.6 + mag * 0.5;
	} else {
		// Background: subtle grid showing the field
		float grid_x = abs(fract((uv.x * 0.5 + 0.5) * fp) - 0.5);
		float grid_y = abs(fract((uv.y * 0.5 + 0.5) * fp) - 0.5);
		float grid = min(grid_x, grid_y);
		col += vec3(0.05, 0.03, 0.08) * smoothstep(0.1, 0.0, grid);

		// Quadratic residue shading
		int qr = imod(lhs - rhs, p);
		float qr_shade = float(qr) / fp;
		col += pal(qr_shade + 0.5) * 0.05;
	}

	// Show current prime
	float prime_indicator = smoothstep(0.98, 0.97, uv.y) * smoothstep(-1.0, -0.98, uv.x);
	col += vec3(0.5) * prime_indicator * 0.1;

	// Audio
	col *= 1.0 + energy * 0.2;
	col += vec3(1.0, 0.85, 0.3) * beat * 0.05;

	// Vignette + tone map
	col *= 1.0 - dot(uv, uv) * 0.15;
	col = col / (col + vec3(1.0));

	ALBEDO = col;
}

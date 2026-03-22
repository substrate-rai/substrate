shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

global uniform float audio_bass;
global uniform float audio_energy;
global uniform float beat_intensity;

// Hopf Fibration — S3 -> S2 with S1 fibers
// The most beautiful map in topology
// Project circles from 4D that interlink and fill space

const int N_FIBERS = 30;
const int FIBER_POINTS = 80;

vec3 pal(float t) {
	return vec3(0.5) + vec3(0.5) * cos(TAU * (vec3(1.0, 0.7, 0.4) * t + vec3(0.0, 0.15, 0.2)));
}

// Hopf map: point on S2 -> circle in S3 -> projected to R3
// For a base point (theta, phi) on S2, the fiber is a great circle in S3
vec3 hopf_fiber_point(float base_theta, float base_phi, float fiber_t) {
	// Base point on S2 in Cartesian
	float ct = cos(base_theta * 0.5);
	float st = sin(base_theta * 0.5);
	float cp = cos(base_phi);
	float sp = sin(base_phi);

	// Point on the S1 fiber
	float cf = cos(fiber_t);
	float sf = sin(fiber_t);

	// S3 coordinates (w, x, y, z)
	float w = ct * cf;
	float x = ct * sf;
	float y = st * cos(base_phi + fiber_t);
	float z = st * sin(base_phi + fiber_t);

	// Stereographic projection S3 -> R3
	float denom = 1.0 / (1.0 - w + 0.01);
	return vec3(x, y, z) * denom;
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float t = TIME;
	float energy = audio_energy;
	float beat = beat_intensity;

	vec3 col = vec3(0.01, 0.005, 0.03);

	// Camera
	float cam_rot = t * 0.1;
	float cr = cos(cam_rot), sr = sin(cam_rot);

	float min_dist = 1e10;
	float closest_fiber = 0.0;

	// Sample base points on S2 and draw their fibers
	for (int f = 0; f < N_FIBERS; f++) {
		float fi = float(f);

		// Distribute base points on S2 (Fibonacci sphere)
		float golden = (1.0 + sqrt(5.0)) / 2.0;
		float base_theta = acos(1.0 - 2.0 * (fi + 0.5) / float(N_FIBERS));
		float base_phi = TAU * fi / golden + t * 0.05;

		// Draw fiber as projected circle
		for (int p = 0; p < FIBER_POINTS; p++) {
			float fiber_t = float(p) / float(FIBER_POINTS) * TAU;

			vec3 pt = hopf_fiber_point(base_theta, base_phi, fiber_t);

			// Rotate view
			float rx = pt.x * cr - pt.z * sr;
			float rz = pt.x * sr + pt.z * cr;
			pt = vec3(rx, pt.y, rz);

			// Simple projection
			float proj = 1.0 / (5.0 - pt.z);
			vec2 screen = pt.xy * proj;

			float d = length(uv - screen);
			if (d < min_dist) {
				min_dist = d;
				closest_fiber = fi;
			}

			// Accumulate glow
			float glow = exp(-d * d * 2000.0) * 0.02;
			col += pal(fi / float(N_FIBERS) + t * 0.02) * glow;
		}
	}

	// Closest fiber highlight
	float edge_glow = clamp(0.003 / (min_dist + 0.001), 0.0, 1.0);
	col += pal(closest_fiber / float(N_FIBERS)) * edge_glow * 0.3;

	// Center glow
	float center = exp(-dot(uv, uv) * 3.0);
	col += vec3(0.2, 0.15, 0.3) * center * 0.15;

	// Audio
	col *= 1.0 + energy * 0.3;
	col += vec3(1.0) * beat * 0.04;

	// Vignette + tone map
	col *= 1.0 - dot(uv, uv) * 0.2;
	col = col / (col + vec3(1.0));

	ALBEDO = col;
}

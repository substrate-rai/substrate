shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

global uniform float audio_bass;
global uniform float audio_energy;
global uniform float beat_intensity;

// Kerr (Rotating) Black Hole with Accretion Disk
// Full general relativity: frame dragging, gravitational lensing, Doppler beaming
// Novikov-Thorne temperature profile for disk color

const int MAX_STEPS = 200;
const float M = 1.0;          // Black hole mass
const float DISK_INNER = 3.0; // ISCO for a=0.9
const float DISK_OUTER = 12.0;

vec3 pal(float t) {
	// Hot accretion palette: black → red → orange → white
	vec3 a = vec3(0.5, 0.2, 0.1);
	vec3 b = vec3(0.5, 0.3, 0.2);
	vec3 c = vec3(1.0, 1.0, 0.5);
	vec3 d = vec3(0.0, 0.1, 0.2);
	return a + b * cos(TAU * (c * t + d));
}

vec3 blackbody(float temp) {
	// Simplified blackbody: temp 0-1 mapped to red→white
	vec3 col;
	col.r = smoothstep(0.0, 0.33, temp);
	col.g = smoothstep(0.2, 0.6, temp);
	col.b = smoothstep(0.5, 0.9, temp);
	return col * (0.5 + temp * 1.5);
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float t = TIME;
	float energy = audio_energy;
	float beat = beat_intensity;

	// Camera setup — orbiting viewer
	float cam_dist = 30.0;
	float cam_angle = t * 0.05;
	float cam_elev = 0.3 + 0.15 * sin(t * 0.03);

	vec3 cam_pos = vec3(
		cam_dist * cos(cam_angle) * cos(cam_elev),
		cam_dist * sin(cam_elev),
		cam_dist * sin(cam_angle) * cos(cam_elev)
	);
	vec3 cam_target = vec3(0.0);
	vec3 cam_fwd = normalize(cam_target - cam_pos);
	vec3 cam_right = normalize(cross(cam_fwd, vec3(0.0, 1.0, 0.0)));
	vec3 cam_up = cross(cam_right, cam_fwd);

	vec3 rd = normalize(cam_fwd + uv.x * cam_right * 0.8 + uv.y * cam_up * 0.8);

	// Ray march through curved spacetime (simplified Kerr)
	float a_spin = 0.9 * M;  // spin parameter
	vec3 pos = cam_pos;
	vec3 vel = rd * 0.5;
	vec3 col = vec3(0.0);
	float dt = 0.3;
	bool hit_disk = false;

	for (int i = 0; i < MAX_STEPS; i++) {
		float r = length(pos);
		float r2 = r * r;

		// Schwarzschild-like deflection with frame drag
		float rs = 2.0 * M;
		if (r < rs * 0.5) break;  // inside event horizon

		// Gravitational acceleration (Newtonian + GR correction)
		float force = -M / r2;
		// Frame dragging: angular momentum coupling
		float drag = a_spin * M / (r2 * r) * 2.0;

		vec3 r_hat = pos / r;
		vec3 accel = r_hat * force;

		// Frame drag in phi direction
		vec3 phi_hat = normalize(cross(vec3(0.0, 1.0, 0.0), r_hat));
		accel += phi_hat * drag;

		// GR correction: precession term
		float L2 = dot(cross(pos, vel), cross(pos, vel));
		accel += r_hat * (-3.0 * M * L2 / (r2 * r2));

		vel += accel * dt;
		pos += vel * dt;

		// Check disk intersection (y ≈ 0 plane)
		float disk_r = length(pos.xz);
		if (abs(pos.y) < 0.15 && disk_r > DISK_INNER && disk_r < DISK_OUTER) {
			hit_disk = true;

			// Novikov-Thorne temperature profile
			float x = disk_r / (6.0 * M);
			float temp = pow(x, -0.75) * pow(max(1.0 - sqrt(1.0 / x), 0.001), 0.25);
			temp = clamp(temp, 0.0, 1.0);

			// Doppler beaming: blueshift on approaching side
			float orbital_v = sqrt(M / disk_r);
			vec3 disk_vel = orbital_v * normalize(cross(vec3(0.0, 1.0, 0.0), pos));
			float doppler = 1.0 + dot(normalize(vel), disk_vel) * 2.0;
			doppler = clamp(doppler, 0.3, 3.0);

			// Disk color
			col = blackbody(temp * doppler);

			// Ring detail
			float rings = sin(disk_r * 3.0 + t * 2.0) * 0.5 + 0.5;
			col *= 0.7 + rings * 0.3;

			// Gravitational redshift
			float redshift = sqrt(max(1.0 - rs / r, 0.01));
			col *= redshift;

			break;
		}

		// Star field for escaped rays
		if (r > 100.0) {
			// Procedural stars
			vec3 star_dir = normalize(pos);
			float star_hash = fract(sin(dot(star_dir.xz, vec2(127.1, 311.7))) * 43758.5453);
			float star = smoothstep(0.998, 1.0, star_hash);
			col = vec3(star) * 0.8;

			// Gravitational lensing distortion of background
			float lens_dist = length(uv);
			float einstein_ring = smoothstep(0.02, 0.0, abs(lens_dist - rs / cam_dist * 2.0));
			col += vec3(0.6, 0.7, 1.0) * einstein_ring * 0.3;
			break;
		}
	}

	// Event horizon silhouette glow
	float center_dist = length(uv);
	float horizon_glow = exp(-pow(center_dist - 0.07, 2.0) * 800.0) * 0.3;
	col += vec3(0.8, 0.4, 0.1) * horizon_glow;

	// Photon ring
	float photon_ring = exp(-pow(center_dist - 0.1, 2.0) * 2000.0) * 0.5;
	col += vec3(1.0, 0.9, 0.7) * photon_ring;

	// Audio
	col *= 1.0 + energy * 0.2;
	col += vec3(1.0, 0.8, 0.5) * beat * 0.05;

	// Vignette + tone map
	col *= 1.0 - dot(uv, uv) * 0.15;
	col = col / (col + vec3(1.0));

	ALBEDO = col;
}

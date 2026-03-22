shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

global uniform float audio_bass;
global uniform float audio_energy;
global uniform float beat_intensity;

// Loss Landscape — AI's Inner Geography
// Ray-marched terrain of neural network loss surfaces
// Saddle points, local minima, flat regions, sharp valleys

vec3 pal(float t) {
	return vec3(0.5) + vec3(0.5) * cos(TAU * (vec3(1.0, 0.8, 0.5) * t + vec3(0.0, 0.1, 0.25)));
}

// Hash functions
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }

// Smooth noise
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash(i), b = hash(i + vec2(1,0));
	float c = hash(i + vec2(0,1)), d = hash(i + vec2(1,1));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// FBM for terrain
float fbm(vec2 p) {
	float v = 0.0, a = 0.5;
	mat2 rot = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < 6; i++) {
		v += a * noise(p);
		p = rot * p * 2.0;
		a *= 0.5;
	}
	return v;
}

// Loss landscape heightfield
float loss_height(vec2 p, float t) {
	// Base: smooth quadratic bowl (global minimum)
	float bowl = dot(p, p) * 0.05;

	// Local minima (Gaussian wells)
	float wells = 0.0;
	for (int i = 0; i < 5; i++) {
		float fi = float(i);
		vec2 well_pos = vec2(sin(fi * 2.1 + t * 0.03), cos(fi * 1.7 + t * 0.02)) * 3.0;
		float depth = 0.3 + hash(vec2(fi, 0.0)) * 0.4;
		wells -= depth * exp(-length(p - well_pos) * 0.8);
	}

	// Saddle points
	float saddles = 0.0;
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		vec2 sp = vec2(cos(fi * 3.0), sin(fi * 2.5)) * 2.0;
		vec2 dp = p - sp;
		saddles += (dp.x * dp.x - dp.y * dp.y) * 0.02 * exp(-length(dp) * 0.3);
	}

	// Sharp valleys (ReLU-like ridges)
	float ridges = abs(sin(p.x * 1.5 + p.y * 0.7)) * 0.15;
	ridges *= exp(-dot(p, p) * 0.02);

	// Noise for texture
	float detail = fbm(p * 0.8 + t * 0.02) * 0.2;

	return bowl + wells + saddles + ridges + detail;
}

// SDF: heightfield
float sdLandscape(vec3 p, float t) {
	return p.y - loss_height(p.xz, t);
}

vec3 calcNormal(vec3 p, float t) {
	float e = 0.01;
	return normalize(vec3(
		loss_height(p.xz + vec2(e,0), t) - loss_height(p.xz - vec2(e,0), t),
		2.0 * e,
		loss_height(p.xz + vec2(0,e), t) - loss_height(p.xz - vec2(0,e), t)
	));
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float t = TIME;
	float energy = audio_energy;
	float beat = beat_intensity;

	// Camera
	float cam_angle = t * 0.08;
	vec3 ro = vec3(cos(cam_angle) * 8.0, 4.0 + sin(t * 0.05) * 1.0, sin(cam_angle) * 8.0);
	vec3 target = vec3(0.0, 0.0, 0.0);
	vec3 fwd = normalize(target - ro);
	vec3 right = normalize(cross(fwd, vec3(0,1,0)));
	vec3 up = cross(right, fwd);
	vec3 rd = normalize(fwd + uv.x * right * 0.6 + uv.y * up * 0.6);

	vec3 col = vec3(0.02, 0.01, 0.04);
	float total_d = 0.0;

	for (int i = 0; i < 150; i++) {
		vec3 p = ro + rd * total_d;
		float d = sdLandscape(p, t);

		if (abs(d) < 0.005) {
			vec3 n = calcNormal(p, t);
			vec3 light = normalize(vec3(2, 4, 1));
			float diff = max(dot(n, light), 0.0);

			// Color by height (loss value)
			float h = loss_height(p.xz, t);
			vec3 terrain_col;
			if (h < -0.2) terrain_col = vec3(0.1, 0.3, 0.8);    // deep minima: blue
			else if (h < 0.0) terrain_col = vec3(0.1, 0.6, 0.3); // valleys: green
			else if (h < 0.3) terrain_col = vec3(0.8, 0.7, 0.2);  // ridges: yellow
			else terrain_col = vec3(0.9, 0.3, 0.1);               // peaks: red

			col = terrain_col * (0.3 + diff * 0.7);

			// Height contour lines
			float contour = abs(fract(h * 5.0) - 0.5) * 2.0;
			contour = smoothstep(0.0, 0.05, contour);
			col *= 0.85 + contour * 0.15;

			// Gradient descent path glow
			float grad_mag = length(vec2(
				loss_height(p.xz + vec2(0.01,0), t) - loss_height(p.xz - vec2(0.01,0), t),
				loss_height(p.xz + vec2(0,0.01), t) - loss_height(p.xz - vec2(0,0.01), t)
			));
			float flat_region = exp(-grad_mag * 20.0);
			col += vec3(0.5, 0.3, 0.8) * flat_region * 0.2;

			break;
		}

		total_d += max(d * 0.5, 0.01);
		if (total_d > 30.0) break;
	}

	// Sky gradient for missed rays
	if (total_d > 30.0) {
		col = mix(vec3(0.02, 0.01, 0.06), vec3(0.05, 0.02, 0.1), uv.y * 0.5 + 0.5);
	}

	// Audio
	col *= 1.0 + energy * 0.2;
	col += vec3(1.0) * beat * 0.03;

	// Tone map
	col = col / (col + vec3(1.0));

	ALBEDO = col;
}

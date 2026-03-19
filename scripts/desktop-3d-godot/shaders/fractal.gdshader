shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

// Raymarched Mandelbulb fractal — audio-reactive
global uniform float audio_bass;
global uniform float audio_mid;
global uniform float audio_energy;
global uniform float beat_intensity;
global uniform float audio_treble;
global uniform float audio_sub_bass;
global uniform float audio_presence;
global uniform float audio_brilliance;
global uniform float beat_kick;
global uniform float beat_snare;
global uniform float audio_warmth;
global uniform float audio_brightness;

uniform float power_base : hint_range(2.0, 12.0) = 8.0;
uniform vec3 glow_color : source_color = vec3(0.0, 1.0, 0.66);
uniform float rotation_speed = 0.08;

const int MAX_STEPS = 64;
const float MAX_DIST = 20.0;
const float SURF_DIST = 0.002;

mat3 rotate_y(float a) {
	float s = sin(a), c = cos(a);
	return mat3(vec3(c,0,s), vec3(0,1,0), vec3(-s,0,c));
}

mat3 rotate_x(float a) {
	float s = sin(a), c = cos(a);
	return mat3(vec3(1,0,0), vec3(0,c,-s), vec3(0,s,c));
}

vec2 mandelbulb_de(vec3 pos, float power) {
	vec3 z = pos;
	float dr = 1.0;
	float r = 0.0;
	float trap = 1e10;

	for (int i = 0; i < 8; i++) {
		r = length(z);
		if (r > 2.0) break;

		float theta = acos(z.z / r);
		float phi = atan(z.y, z.x);
		dr = pow(r, power - 1.0) * power * dr + 1.0;

		float zr = pow(r, power);
		theta *= power;
		phi *= power;

		z = zr * vec3(sin(theta)*cos(phi), sin(phi)*sin(theta), cos(theta));
		z += pos;

		trap = min(trap, length(z));
	}
	return vec2(0.5 * log(r) * r / dr, trap);
}

vec3 get_normal(vec3 p, float power) {
	float h = 0.001;
	vec2 k = vec2(1, -1);
	return normalize(
		k.xyy * mandelbulb_de(p + k.xyy*h, power).x +
		k.yyx * mandelbulb_de(p + k.yyx*h, power).x +
		k.yxy * mandelbulb_de(p + k.yxy*h, power).x +
		k.xxx * mandelbulb_de(p + k.xxx*h, power).x
	);
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	uv.x *= 1.777; // 16:9

	float t = TIME * rotation_speed;
	float power = power_base + audio_bass * 4.0 + beat_kick * 2.0 + sin(TIME * 0.3) * 0.5;

	// Camera
	vec3 ro = vec3(0, 0, -2.5 + audio_energy * 0.3 - audio_sub_bass * 0.5);
	ro *= rotate_y(t);
	ro *= rotate_x(t * 0.37 + audio_mid * 0.5);

	vec3 target = vec3(0);
	vec3 fwd = normalize(target - ro);
	vec3 right = normalize(cross(vec3(0,1,0), fwd));
	vec3 up = cross(fwd, right);
	vec3 rd = normalize(fwd * 1.5 + right * uv.x + up * uv.y);

	// Raymarch
	float d_total = 0.0;
	float orbit_trap = 0.0;
	bool hit = false;

	for (int i = 0; i < MAX_STEPS; i++) {
		vec3 p = ro + rd * d_total;
		vec2 res = mandelbulb_de(p, power);
		float d = res.x;
		orbit_trap = res.y;

		if (d < SURF_DIST) { hit = true; break; }
		if (d_total > MAX_DIST) break;
		d_total += d;
	}

	vec3 col = vec3(0.01, 0.005, 0.02); // bg

	// Warm-shifted glow color based on audio_warmth
	vec3 warm_glow = mix(glow_color, vec3(1.0, 0.5, 0.2), audio_warmth * 0.4);

	if (hit) {
		vec3 p = ro + rd * d_total;
		vec3 n = get_normal(p, power);

		// Lighting
		vec3 light_dir = normalize(vec3(1, 1, -1));
		float diff = max(dot(n, light_dir), 0.0);
		float spec = pow(max(dot(reflect(-light_dir, n), -rd), 0.0), 32.0);

		// Treble → crystalline specular highlights
		spec *= (1.0 + audio_treble * 2.0);

		// Color from orbit trap
		vec3 base = mix(warm_glow, vec3(1.0, 0.3, 0.9), orbit_trap);
		base = mix(base, vec3(0.3, 0.8, 1.0), pow(orbit_trap, 3.0));

		col = base * (diff * 0.6 + 0.2) + vec3(1) * spec * 0.5;

		// Audio glow
		float glow = beat_intensity * 0.8;
		col += warm_glow * glow * (1.0 - orbit_trap);

		// Presence → fresnel rim lighting
		float fresnel = pow(1.0 - max(dot(n, -rd), 0.0), 3.0);
		col += fresnel * audio_presence * 0.5 * warm_glow;

		// Snare → color flash
		col += beat_snare * 0.5 * warm_glow;

		// Depth fade
		float fog = exp(-d_total * 0.3);
		col *= fog;

		// Brightness → overall scene brightness
		col *= (0.8 + audio_brightness * 0.5);
	} else {
		// Background glow
		float bg_glow = exp(-length(uv) * 1.5) * 0.15;
		col += warm_glow * bg_glow * (1.0 + audio_energy);

		// Brilliance → background sparkle
		float sparkle_hash = fract(sin(dot(uv * 200.0, vec2(12.9898, 78.233)) + TIME * 3.0) * 43758.5453);
		float sparkle = step(0.997, sparkle_hash) * audio_brilliance * 2.0;
		col += vec3(sparkle);

		// Brightness → overall scene brightness
		col *= (0.8 + audio_brightness * 0.5);
	}

	// Vignette
	float vig = 1.0 - dot(uv * 0.4, uv * 0.4);
	col *= vig;

	ALBEDO = col;
}

shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

global uniform float audio_bass;
global uniform float audio_energy;
global uniform float beat_intensity;

// Kleinian Group Limit Sets (Indra's Pearls)
// Animated parameter sweep through quasi-Fuchsian space
// Möbius transformations via circle inversions

vec3 pal(float t) {
	return vec3(0.5) + vec3(0.5) * cos(TAU * (vec3(0.8, 0.6, 1.0) * t + vec3(0.0, 0.1, 0.2)));
}

// Möbius transformation: T(z) = (a*z + b) / (c*z + d)
vec2 mobius(vec2 z, vec2 a, vec2 b, vec2 c, vec2 d) {
	vec2 num = vec2(a.x*z.x - a.y*z.y + b.x, a.x*z.y + a.y*z.x + b.y);
	vec2 den = vec2(c.x*z.x - c.y*z.y + d.x, c.x*z.y + c.y*z.x + d.y);
	float den_sq = dot(den, den);
	return vec2(dot(num, den), num.y*den.x - num.x*den.y) / den_sq;
}

// Circle inversion
vec2 invert_in_circle(vec2 z, vec2 center, float radius) {
	vec2 dz = z - center;
	float d2 = dot(dz, dz);
	return center + dz * (radius * radius) / d2;
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float t = TIME;
	float energy = audio_energy;
	float beat = beat_intensity;

	vec2 p = uv * 2.0;

	// Animated Grandma's Recipe parameters
	// ta, tb trace parameters — sweep through quasi-Fuchsian space
	float ta_r = 2.0 + 0.3 * sin(t * 0.08);
	float tb_r = 2.0 + 0.3 * cos(t * 0.11);
	float tab_phase = t * 0.05;

	// Generators a, b from traces
	vec2 ta = vec2(ta_r * cos(tab_phase), ta_r * sin(tab_phase * 0.7));
	vec2 tb = vec2(tb_r * cos(tab_phase * 0.6 + 1.0), tb_r * sin(tab_phase * 0.4));

	// Fixed circles for the group
	vec2 c1 = vec2(-0.8, 0.0);
	vec2 c2 = vec2(0.8, 0.0);
	vec2 c3 = vec2(0.0, 0.8);
	vec2 c4 = vec2(0.0, -0.8);
	float r1 = 0.6 + 0.1 * sin(t * 0.07);
	float r2 = 0.6 + 0.1 * cos(t * 0.09);
	float r3 = 0.5 + 0.1 * sin(t * 0.11);
	float r4 = 0.5 + 0.1 * cos(t * 0.06);

	// Iterate inversions — limit set emerges
	vec3 col = vec3(0.02, 0.01, 0.04);
	float min_dist = 1e10;
	int last_circle = -1;

	vec2 z = p;
	for (int i = 0; i < 60; i++) {
		// Invert in whichever circle z is outside of
		float d1 = length(z - c1) - r1;
		float d2 = length(z - c2) - r2;
		float d3 = length(z - c3) - r3;
		float d4 = length(z - c4) - r4;

		bool moved = false;
		if (d1 > 0.0 && last_circle != 0) {
			z = invert_in_circle(z, c1, r1);
			last_circle = 0;
			moved = true;
		} else if (d2 > 0.0 && last_circle != 1) {
			z = invert_in_circle(z, c2, r2);
			last_circle = 1;
			moved = true;
		} else if (d3 > 0.0 && last_circle != 2) {
			z = invert_in_circle(z, c3, r3);
			last_circle = 2;
			moved = true;
		} else if (d4 > 0.0 && last_circle != 3) {
			z = invert_in_circle(z, c4, r4);
			last_circle = 3;
			moved = true;
		}

		if (!moved) break;

		// Track orbit for coloring
		float d = min(min(d1, d2), min(d3, d4));
		min_dist = min(min_dist, abs(d));
	}

	// Color by orbit depth and minimum distance to circles
	float detail = exp(-min_dist * 20.0);
	col += pal(min_dist * 3.0 + t * 0.03) * detail * 0.8;

	// Circle boundaries glow
	float glow = 0.0;
	glow += clamp(0.005 / abs(length(p - c1) - r1), 0.0, 1.0);
	glow += clamp(0.005 / abs(length(p - c2) - r2), 0.0, 1.0);
	glow += clamp(0.005 / abs(length(p - c3) - r3), 0.0, 1.0);
	glow += clamp(0.005 / abs(length(p - c4) - r4), 0.0, 1.0);
	col += vec3(0.4, 0.6, 1.0) * glow * 0.3;

	// Limit set accumulation (where orbit gets trapped)
	float trap = 1.0 / (1.0 + length(z) * 0.5);
	col += pal(trap + 0.5) * trap * 0.3;

	// Audio
	col *= 1.0 + energy * 0.3;
	col += vec3(1.0) * beat * 0.04;

	// Vignette + tone map
	col *= 1.0 - dot(uv, uv) * 0.25;
	col = col / (col + vec3(1.0));

	ALBEDO = col;
}

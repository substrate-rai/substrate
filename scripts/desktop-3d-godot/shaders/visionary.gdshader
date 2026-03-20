shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

global uniform float audio_bass;
global uniform float audio_mid;
global uniform float audio_treble;
global uniform float audio_energy;
global uniform float beat_intensity;
global uniform vec3 cursor_world_pos;

// PI and TAU are Godot built-ins

// ── Alex Grey palette ──
const vec3 DEEP_INDIGO = vec3(0.04, 0.01, 0.12);
const vec3 ELECTRIC_BLUE = vec3(0.2, 0.5, 1.0);
const vec3 GOLD = vec3(1.0, 0.85, 0.3);
const vec3 VIOLET = vec3(0.55, 0.15, 0.85);
const vec3 ROSE = vec3(0.9, 0.3, 0.5);

// ── Noise ──
float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1, 0)), f.x),
		mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x),
		f.y
	);
}

float fbm(vec2 p) {
	float v = 0.0, a = 0.5;
	mat2 m = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < 5; i++) {
		v += a * noise(p);
		p = m * p * 2.0;
		a *= 0.5;
	}
	return v;
}

// ── IQ cosine palette ──
vec3 cosPalette(float t, vec3 a, vec3 b, vec3 c, vec3 d) {
	return a + b * cos(TAU * (c * t + d));
}

// Alex Grey-inspired chakra palette
vec3 chakraColor(float t) {
	return cosPalette(t,
		vec3(0.5, 0.3, 0.6),   // bias
		vec3(0.5, 0.4, 0.4),   // amplitude
		vec3(1.0, 1.0, 1.2),   // frequency
		vec3(0.0, 0.15, 0.35)  // phase
	);
}

// ── Rotation ──
vec2 rot2(vec2 p, float a) {
	float c = cos(a), s = sin(a);
	return vec2(p.x * c - p.y * s, p.x * s + p.y * c);
}

// ── SDF helpers ──
float sdCircle(vec2 p, float r) {
	return abs(length(p) - r);
}

float sdLine(float d, float width) {
	float fw = fwidth(d);
	return smoothstep(width + fw, width - fw, d);
}

// ── Net of Being tiling ──
// Simplified eye/face form per tile
float eyeForm(vec2 p) {
	// Almond eye shape: intersection of two circles
	float r = 0.35;
	float d1 = length(p - vec2(0.0, 0.12)) - r;
	float d2 = length(p + vec2(0.0, 0.12)) - r;
	float eye = max(d1, d2);
	// Pupil
	float pupil = length(p) - 0.08;
	// Iris ring
	float iris = abs(length(p) - 0.15);
	return min(eye, min(pupil, iris));
}

float netOfBeing(vec2 p, float tile_size, float t) {
	vec2 tile_id = floor(p / tile_size);
	vec2 local = fract(p / tile_size) - 0.5;

	float d = 0.0;

	// Eye form per tile
	float eye = eyeForm(local * 2.0);
	float eye_line = sdLine(eye, 0.025);

	// Golden emanation rays per tile
	float a = atan(local.y, local.x);
	float rays = sin(a * 8.0 + t * 2.0) * 0.5 + 0.5;
	rays *= exp(-length(local) * 3.0);

	// Connecting lines between tiles
	float grid_x = abs(fract(p.x / tile_size) - 0.5);
	float grid_y = abs(fract(p.y / tile_size) - 0.5);
	float grid = min(grid_x, grid_y);
	float grid_line = sdLine(grid, 0.015);

	d = eye_line * 0.6 + rays * 0.3 + grid_line * 0.2;
	return d;
}

// ── Third Eye ──
float thirdEye(vec2 p, float t, float energy) {
	float r = length(p);
	float a = atan(p.y, p.x);

	float d = 0.0;

	// Multi-frequency radial burst
	float burst = 0.0;
	burst += sin(a * 8.0 + t * 1.5) * 0.35;
	burst += sin(a * 16.0 - t * 2.2) * 0.25;
	burst += sin(a * 32.0 + t * 0.7) * 0.15;
	burst += sin(a * 5.0 + t * 0.5) * 0.25;
	burst = burst * 0.5 + 0.5;

	// Emanation falloff
	float emanation = burst * exp(-r * (2.5 - energy * 0.8));

	// Iris fibers
	float fibers = sin(a * 32.0 + r * 20.0) * 0.5 + 0.5;
	fibers *= smoothstep(0.3, 0.08, r);

	// Pupil
	float pupil = smoothstep(0.06, 0.04, r);

	// Iris ring
	float iris = sdLine(sdCircle(p, 0.12), 0.01);
	float outer_iris = sdLine(sdCircle(p, 0.22), 0.008);

	d = emanation + fibers * 0.4 + pupil + iris * 0.6 + outer_iris * 0.3;
	return d;
}

// ── Energy Rings ──
float energyRings(vec2 p, float t, float bass) {
	float r = length(p);
	float d = 0.0;
	for (int i = 0; i < 7; i++) {
		float ring_r = fract(float(i) * 0.143 + t * 0.08) * 1.6;
		float fade = (1.0 - ring_r * 0.625) * 0.5;
		float ring = sdLine(abs(r - ring_r), 0.006);
		d += ring * max(fade, 0.0);
	}
	return d;
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float t = TIME;

	// Audio
	float bass = audio_bass;
	float mid = audio_mid;
	float treble = audio_treble;
	float energy = audio_energy;
	float beat = beat_intensity;

	vec2 p = uv * 1.5;
	vec3 col = DEEP_INDIGO;

	// ── Layer 1: Domain-warped noise background ──
	vec2 warp = vec2(
		fbm(p * 1.5 + t * 0.1),
		fbm(p * 1.5 + vec2(5.2, 1.3) + t * 0.08)
	);
	float bg_noise = fbm(p * 2.0 + warp * 0.6);
	col += VIOLET * bg_noise * 0.12;

	// ── Layer 2: Net of Being grid ──
	float tile_size = 0.55;
	vec2 p_net = rot2(p, t * 0.02);
	float net = netOfBeing(p_net, tile_size, t);
	vec3 net_col = mix(ELECTRIC_BLUE, GOLD, net);
	col += net_col * net * 0.25;

	// ── Layer 3: Central third eye ──
	float eye = thirdEye(p, t, energy);
	vec3 eye_col = mix(VIOLET, GOLD, eye * 0.6);
	eye_col = mix(eye_col, vec3(1.0), smoothstep(0.8, 1.0, eye)); // bright core
	col += eye_col * eye * 0.55;

	// ── Layer 4: Translucent triangles ──
	for (int i = 0; i < 5; i++) {
		float fi = float(i);
		float scale = 0.3 + fi * 0.2;
		float angle = t * (0.05 + fi * 0.02) + fi * PI / 5.0;
		vec2 pt = rot2(p, angle);

		// Equilateral triangle SDF (edges only)
		float h = scale * 0.866;
		float d = 1e9;
		vec2 a = vec2(0.0, h * 0.667);
		vec2 b = vec2(-scale * 0.5, -h * 0.333);
		vec2 c = vec2(scale * 0.5, -h * 0.333);
		float seg1 = length(pt - a + clamp(dot(b - a, pt - a) / dot(b - a, b - a), 0.0, 1.0) * (a - b)) ;

		// Simplified: distance to edges
		float d1 = abs(dot(normalize(vec2(b.y - a.y, a.x - b.x)), pt - a));
		float d2 = abs(dot(normalize(vec2(c.y - b.y, b.x - c.x)), pt - b));
		float d3 = abs(dot(normalize(vec2(a.y - c.y, c.x - a.x)), pt - c));
		d = min(d1, min(d2, d3));

		float tri_line = sdLine(d, 0.005);
		vec3 tri_col = chakraColor(fi * 0.2 + t * 0.05);
		col += tri_col * tri_line * 0.15;
	}

	// ── Layer 5: Energy rings ──
	float rings = energyRings(p, t, bass);
	col += ELECTRIC_BLUE * rings * 0.3 * (1.0 + beat * 1.5);

	// ── Layer 6: Chakra color gradient (vertical) ──
	float chakra_t = uv.y * 0.5 + 0.5; // 0 at bottom, 1 at top
	vec3 chakra = chakraColor(chakra_t + t * 0.02);
	col = mix(col, col * chakra, 0.15);

	// ── Beat flash ──
	col += vec3(0.9, 0.85, 1.0) * beat * 0.12;

	// ── Center glow ──
	float glow = exp(-length(p) * 1.8) * (0.4 + energy * 0.6);
	col += GOLD * glow * 0.35;

	// ── Vignette ──
	float vig = 1.0 - dot(uv, uv) * 0.35;
	col *= vig;

	// ── Tone mapping ──
	col = col / (col + vec3(1.0));

	ALBEDO = col;
}

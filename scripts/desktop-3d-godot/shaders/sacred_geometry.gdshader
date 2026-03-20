shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

global uniform float audio_bass;
global uniform float audio_mid;
global uniform float audio_treble;
global uniform float audio_energy;
global uniform float beat_intensity;
global uniform vec3 cursor_world_pos;

const float PHI = 1.61803398;

// ── Colors ──
const vec3 BG_COLOR = vec3(0.05, 0.02, 0.15);
const vec3 LINE_BLUE = vec3(0.2, 0.6, 1.0);
const vec3 GOLD_GLOW = vec3(1.0, 0.85, 0.3);
const vec3 VIOLET = vec3(0.6, 0.2, 0.9);

// ── SDF helpers ──

float sdCircle(vec2 p, float r) {
	return abs(length(p) - r);
}

float sdSegment(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a, ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

float sdLine(vec2 p, float d, float width) {
	float fw = max(fwidth(d), 0.003);
	return smoothstep(width + fw, max(width - fw, 0.0), d);
}

// ── Rotation ──
vec2 rot2(vec2 p, float a) {
	float c = cos(a), s = sin(a);
	return vec2(p.x * c - p.y * s, p.x * s + p.y * c);
}

// ── Flower of Life ──
// Hex grid of overlapping circles
float flowerOfLife(vec2 p, float scale) {
	float d = 1e9;
	float r = scale;
	// Center circle
	d = min(d, sdCircle(p, r));
	// 6 surrounding circles
	for (int i = 0; i < 6; i++) {
		float a = float(i) * TAU / 6.0;
		vec2 c = vec2(cos(a), sin(a)) * r;
		d = min(d, sdCircle(p - c, r));
	}
	// Second ring — 6 more at 2r distance, offset 30 degrees
	for (int i = 0; i < 6; i++) {
		float a = float(i) * TAU / 6.0 + PI / 6.0;
		vec2 c = vec2(cos(a), sin(a)) * r * 1.732;
		d = min(d, sdCircle(p - c, r));
	}
	// Third ring — 6 at the hex vertices
	for (int i = 0; i < 6; i++) {
		float a = float(i) * TAU / 6.0;
		vec2 c = vec2(cos(a), sin(a)) * r * 2.0;
		d = min(d, sdCircle(p - c, r));
	}
	return d;
}

// ── Metatron's Cube ──
// 13 circles + connecting lines between all 13 points
float metatronsCube(vec2 p, float scale) {
	// 13 points: center + 6 inner + 6 outer
	vec2 pts[13];
	pts[0] = vec2(0.0);
	for (int i = 0; i < 6; i++) {
		float a = float(i) * TAU / 6.0;
		pts[i + 1] = vec2(cos(a), sin(a)) * scale;
		pts[i + 7] = vec2(cos(a + PI / 6.0), sin(a + PI / 6.0)) * scale * 2.0;
	}

	float d = 1e9;
	// 13 circles
	for (int i = 0; i < 13; i++) {
		d = min(d, sdCircle(p - pts[i], scale * 0.15));
	}
	// Connecting lines between all pairs (78 lines)
	for (int i = 0; i < 13; i++) {
		for (int j = i + 1; j < 13; j++) {
			d = min(d, sdSegment(p, pts[i], pts[j]));
		}
	}
	return d;
}

// ── Sri Yantra ──
// 9 interlocking triangles (4 pointing up, 5 pointing down) + bindu
float sdTriangleLine(vec2 p, vec2 a, vec2 b, vec2 c) {
	float d = sdSegment(p, a, b);
	d = min(d, sdSegment(p, b, c));
	d = min(d, sdSegment(p, c, a));
	return d;
}

float sriYantra(vec2 p, float scale) {
	float d = 1e9;
	// 4 upward triangles at different scales
	float up_scales[4] = float[](1.0, 0.72, 0.48, 0.22);
	for (int i = 0; i < 4; i++) {
		float s = up_scales[i] * scale;
		float h = s * 0.866;
		vec2 a = vec2(0.0, h * 0.667);
		vec2 b = vec2(-s * 0.5, -h * 0.333);
		vec2 c = vec2(s * 0.5, -h * 0.333);
		float offset_y = (float(i) - 1.5) * scale * 0.06;
		d = min(d, sdTriangleLine(p - vec2(0.0, offset_y), a, b, c));
	}
	// 5 downward triangles
	float down_scales[5] = float[](0.92, 0.65, 0.44, 0.28, 0.12);
	for (int i = 0; i < 5; i++) {
		float s = down_scales[i] * scale;
		float h = s * 0.866;
		vec2 a = vec2(0.0, -h * 0.667);
		vec2 b = vec2(-s * 0.5, h * 0.333);
		vec2 c = vec2(s * 0.5, h * 0.333);
		float offset_y = (float(i) - 2.0) * scale * 0.05;
		d = min(d, sdTriangleLine(p - vec2(0.0, offset_y), a, b, c));
	}
	// Bindu (center point)
	d = min(d, length(p) - scale * 0.015);
	return d;
}

// ── Seed of Life ──
// 7 circles: 1 center + 6 surrounding
float seedOfLife(vec2 p, float r) {
	float d = sdCircle(p, r);
	for (int i = 0; i < 6; i++) {
		float a = float(i) * TAU / 6.0;
		vec2 c = vec2(cos(a), sin(a)) * r;
		d = min(d, sdCircle(p - c, r));
	}
	return d;
}

// ── Golden Spiral ──
float goldenSpiral(vec2 p, float t) {
	float r = length(p);
	float a = atan(p.y, p.x);
	// Logarithmic spiral: r = exp(b * theta)
	float b = log(PHI) / (PI * 0.5);
	// Unwrap angle for continuous spiral
	float spiral_r = exp(b * (a + t));
	float d = 1e9;
	// Multiple spiral arms
	for (int n = -6; n < 6; n++) {
		float sr = exp(b * (a + float(n) * TAU + t * 0.3));
		d = min(d, abs(r - sr));
	}
	return d;
}

// ── Emanation Rings ──
float emanationRings(vec2 p, float t, float beat) {
	float r = length(p);
	float d = 0.0;
	for (int i = 0; i < 8; i++) {
		float ring_r = fract(float(i) * 0.125 + t * 0.15) * 2.0;
		float fade = 1.0 - ring_r * 0.5;
		float ring_d = abs(r - ring_r) * 8.0;
		d += fade * exp(-ring_d * ring_d);
	}
	return d;
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float aspect = 1.0; // fullscreen quad is pre-corrected
	float t = TIME;

	// Audio modulation
	float bass = audio_bass;
	float mid = audio_mid;
	float energy = audio_energy;
	float beat = beat_intensity;

	vec2 p = uv * 1.8;

	vec3 col = BG_COLOR;
	float line_width = 0.008;

	// ── Layer 1: Flower of Life (slowest rotation) ──
	vec2 p1 = rot2(p, t * 0.05);
	float fol = flowerOfLife(p1, 0.35);
	float fol_line = sdLine(p, fol, line_width * 1.2);
	col += LINE_BLUE * 0.35 * fol_line;

	// ── Layer 2: Metatron's Cube (counter-rotation) ──
	vec2 p2 = rot2(p, -t * 0.08);
	float mc = metatronsCube(p2, 0.3);
	float mc_line = sdLine(p, mc, line_width);
	col += VIOLET * 0.5 * mc_line;

	// ── Layer 3: Sri Yantra (subtle rotation) ──
	vec2 p3 = rot2(p, t * 0.03);
	float sy = sriYantra(p3, 0.8);
	float sy_line = sdLine(p, sy, line_width * 0.9);
	col += GOLD_GLOW * 0.6 * sy_line;

	// ── Layer 4: Seed of Life ──
	float seed_scale = 0.2;
	vec2 p4 = rot2(p, t * 0.12);
	float sol = seedOfLife(p4, seed_scale);
	float sol_line = sdLine(p, sol, line_width * 1.5);
	col += mix(LINE_BLUE, GOLD_GLOW, 0.5) * 0.45 * sol_line;

	// ── Layer 5: Golden Spiral overlay ──
	vec2 p5 = rot2(p, -t * 0.06);
	float gs = goldenSpiral(p5, t * 0.2);
	float gs_line = sdLine(p, gs, line_width * 2.0);
	col += GOLD_GLOW * 0.2 * gs_line;

	// ── Layer 6: Emanation rings ──
	float em = emanationRings(p, t, beat);
	col += mix(LINE_BLUE, VIOLET, 0.3) * em * 0.15 * (1.0 + beat * 2.0);

	// ── Beat flash ──
	col += vec3(0.8, 0.7, 1.0) * beat * 0.15;

	// ── Energy glow at center ──
	float center_glow = exp(-length(p) * 2.0) * (0.5 + energy * 0.8);
	col += GOLD_GLOW * center_glow * 0.4;

	// ── Vignette ──
	float vig = 1.0 - dot(uv, uv) * 0.4;
	col *= vig;

	// ── Tone mapping ──
	col = col / (col + vec3(1.0));

	ALBEDO = col;
}

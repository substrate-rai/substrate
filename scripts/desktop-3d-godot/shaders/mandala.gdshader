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
const vec3 BG_COLOR = vec3(0.03, 0.01, 0.08);
const vec3 CYAN = vec3(0.1, 0.8, 0.9);
const vec3 MAGENTA = vec3(0.9, 0.2, 0.7);
const vec3 GOLD = vec3(1.0, 0.85, 0.3);
const vec3 WHITE = vec3(1.0);

// ── IQ cosine palette ──
vec3 cosPalette(float t, vec3 a, vec3 b, vec3 c, vec3 d) {
	return a + b * cos(TAU * (c * t + d));
}

vec3 mandalaPalette(float t) {
	return cosPalette(t,
		vec3(0.5, 0.5, 0.5),
		vec3(0.5, 0.5, 0.5),
		vec3(1.0, 0.7, 0.4),
		vec3(0.0, 0.15, 0.2)
	);
}

// ── Rotation ──
vec2 rot2(vec2 p, float a) {
	float c = cos(a), s = sin(a);
	return vec2(p.x * c - p.y * s, p.x * s + p.y * c);
}

// ── Anti-aliased line ──
float aaLine(float d, float width) {
	float fw = max(fwidth(d), 0.003);
	return smoothstep(width + fw, max(width - fw, 0.0), d);
}

// ── Polar mirror fold for N-fold symmetry ──
vec2 polarFold(vec2 p, float n) {
	float a = atan(p.y, p.x);
	float sector = TAU / n;
	a = mod(a + sector * 0.5, sector) - sector * 0.5;
	a = abs(a);
	float r = length(p);
	return vec2(cos(a), sin(a)) * r;
}

// ── SDF shapes ──
float sdCircle(vec2 p, float r) {
	return abs(length(p) - r);
}

float sdHexagon(vec2 p, float r) {
	p = abs(p);
	float d = max(p.x * 0.866 + p.y * 0.5, p.y) - r;
	return abs(d);
}

float sdStar(vec2 p, float r, int n, float inner_ratio) {
	float a = atan(p.y, p.x);
	float seg = TAU / float(n);
	a = mod(a + seg * 0.5, seg) - seg * 0.5;

	float outer_r = r;
	float inner_r = r * inner_ratio;

	// Star shape via alternating radius
	float half_seg = seg * 0.5;
	float t = abs(a) / half_seg;
	float star_r = mix(outer_r, inner_r, t);

	return abs(length(p) - star_r);
}

float sdEquilateralTriangle(vec2 p, float r) {
	p.x = abs(p.x);
	float d = max(
		p.x * 0.866 + p.y * 0.5,
		-p.y
	) - r * 0.5;
	return abs(d);
}

float sdSegment(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a, ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

// ── Fibonacci spiral arms ──
float fibonacciSpirals(vec2 p, float t) {
	float r = length(p);
	float a = atan(p.y, p.x);
	float b = log(PHI) / (PI * 0.5);
	float d = 0.0;

	// Two interlocking spiral sets (clockwise + counter-clockwise)
	for (int n = -4; n < 5; n++) {
		float sr1 = exp(b * (a + float(n) * TAU + t * 0.3));
		float sr2 = exp(b * (-a + float(n) * TAU + t * 0.2));
		d += exp(-abs(r - sr1) * 15.0) * 0.3;
		d += exp(-abs(r - sr2) * 15.0) * 0.2;
	}
	return d;
}

// ── Wave interference moire ──
float moirePattern(vec2 p, float t, float treble) {
	float r = length(p);
	float d = 0.0;
	// Overlapping sinusoidal rings from offset centers
	float freq = 20.0 + treble * 10.0;
	d += sin(r * freq + t) * 0.5 + 0.5;
	d += sin(length(p - vec2(0.3, 0.0)) * freq * 0.9 - t * 0.7) * 0.5 + 0.5;
	d += sin(length(p + vec2(0.15, 0.26)) * freq * 1.1 + t * 0.5) * 0.5 + 0.5;
	return d / 3.0;
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

	// Slow overall rotation
	p = rot2(p, t * 0.04);

	vec3 col = BG_COLOR;
	float line_width = 0.006;

	// ── 12-fold polar symmetry ──
	// Blend fold count with mid frequency
	float fold_n = 12.0;
	vec2 pf = polarFold(p, fold_n);

	// ── Nested geometry rings at golden-ratio-spaced radii ──
	float base_r = 0.12;
	float accum = 0.0;

	// Ring 1: Hexagons
	float r1 = base_r;
	float hex = sdHexagon(pf - vec2(r1, 0.0), 0.04);
	float hex_line = aaLine(hex, line_width);
	col += CYAN * hex_line * 0.5;

	// Ring 2: Stars
	float r2 = base_r * PHI;
	vec2 star_p = polarFold(p, fold_n);
	float star = sdStar(star_p - vec2(r2, 0.0), 0.06, 6, 0.4);
	float star_line = aaLine(star, line_width);
	col += MAGENTA * star_line * 0.45;

	// Ring 3: Circles
	float r3 = base_r * PHI * PHI;
	float circ = sdCircle(pf - vec2(r3, 0.0), 0.035);
	float circ_line = aaLine(circ, line_width);
	col += GOLD * circ_line * 0.5;

	// Ring 4: Triangles
	float r4 = base_r * PHI * PHI * PHI;
	vec2 tri_p = pf - vec2(r4, 0.0);
	tri_p = rot2(tri_p, t * 0.1);
	float tri = sdEquilateralTriangle(tri_p, 0.08);
	float tri_line = aaLine(tri, line_width);
	col += mix(CYAN, GOLD, 0.5) * tri_line * 0.4;

	// Ring 5: Large outer hexagons
	float r5 = base_r * PHI * PHI * PHI * PHI;
	float hex2 = sdHexagon(pf - vec2(r5, 0.0), 0.07);
	float hex2_line = aaLine(hex2, line_width * 1.3);
	col += mix(MAGENTA, CYAN, 0.3) * hex2_line * 0.35;

	// ── Concentric rings at golden-ratio radii ──
	for (int i = 1; i < 8; i++) {
		float ring_r = base_r * pow(PHI, float(i));
		if (ring_r > 2.0) break;
		float ring = sdCircle(p, ring_r);
		float ring_line = aaLine(ring, line_width * 0.7);
		col += mix(CYAN, MAGENTA, float(i) / 7.0) * ring_line * 0.12;
	}

	// ── Radial lines from center (connecting geometry) ──
	float a = atan(p.y, p.x);
	for (int i = 0; i < 12; i++) {
		float target_a = float(i) * TAU / 12.0;
		float diff = abs(mod(a - target_a + PI, TAU) - PI);
		float fw = fwidth(diff);
		float radial = smoothstep(0.015 + fw, 0.015 - fw, diff);
		float fade = smoothstep(0.0, 0.1, length(p)) * smoothstep(2.0, 0.5, length(p));
		col += GOLD * radial * fade * 0.08;
	}

	// ── Fibonacci spiral arms ──
	float spirals = fibonacciSpirals(p, t);
	col += mix(CYAN, GOLD, spirals) * spirals * 0.15;

	// ── Wave interference moire ──
	float moire = moirePattern(p * 0.8, t * 0.5, treble);
	// Subtle moire overlay
	col += vec3(moire * 0.04) * mix(CYAN, MAGENTA, moire);

	// ── Center mandala detail ──
	float center_r = length(p);
	// Petal pattern
	float petals = sin(atan(p.y, p.x) * fold_n + t) * 0.5 + 0.5;
	petals *= smoothstep(0.15, 0.05, center_r);
	col += GOLD * petals * 0.3;

	// Center dot
	float center_dot = smoothstep(0.025, 0.015, center_r);
	col += WHITE * center_dot * 0.8;

	// ── Audio color shift ──
	float color_shift = beat * 0.3;
	vec3 shifted = mandalaPalette(length(p) * 0.5 + t * 0.05 + color_shift);
	col = mix(col, col * shifted * 2.0, 0.2);

	// ── Beat flash ──
	col += vec3(0.7, 0.5, 1.0) * beat * 0.1;

	// ── Energy center glow ──
	float glow = exp(-center_r * 2.5) * (0.3 + energy * 0.5);
	col += mix(GOLD, WHITE, 0.3) * glow * 0.3;

	// ── Vignette ──
	float vig = 1.0 - dot(uv, uv) * 0.35;
	col *= vig;

	// ── Tone mapping ──
	col = col / (col + vec3(1.0));

	ALBEDO = col;
}

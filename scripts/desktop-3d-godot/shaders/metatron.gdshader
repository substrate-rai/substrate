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
const vec3 BG = vec3(0.02, 0.01, 0.06);
const vec3 VIOLET = vec3(0.55, 0.2, 0.9);
const vec3 ELECTRIC_BLUE = vec3(0.2, 0.55, 1.0);
const vec3 GOLD = vec3(1.0, 0.85, 0.3);
const vec3 WHITE = vec3(1.0, 0.95, 0.9);

// ── Rotation ──
vec2 rot2(vec2 p, float a) {
	float c = cos(a), s = sin(a);
	return vec2(p.x * c - p.y * s, p.x * s + p.y * c);
}

// ── SDF helpers ──
float sdCircleRing(vec2 p, float r) {
	return abs(length(p) - r);
}

float sdSegment(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a, ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h);
}

float aaLine(float d, float width) {
	float fw = fwidth(d);
	return smoothstep(width + fw, width - fw, d);
}

// ── Metatron's Cube: 13 points, 13 circles, 78 lines ──
// Center + 6 inner hexagon vertices + 6 outer hexagon vertices (rotated 30°)

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float t = TIME;

	float bass = audio_bass;
	float mid = audio_mid;
	float treble = audio_treble;
	float energy = audio_energy;
	float beat = beat_intensity;

	// Slow rotation
	vec2 p = rot2(uv * 1.3, t * 0.06);

	float scale = 0.38;

	// ── Build 13 points ──
	vec2 pts[13];
	pts[0] = vec2(0.0);
	for (int i = 0; i < 6; i++) {
		float a = float(i) * TAU / 6.0;
		pts[i + 1] = vec2(cos(a), sin(a)) * scale;
		pts[i + 7] = vec2(cos(a + PI / 6.0), sin(a + PI / 6.0)) * scale * 1.732;
	}

	vec3 col = BG;

	// ── Outer bounding circle ──
	float outer_r = scale * 1.732;
	float outer = sdCircleRing(p, outer_r * 1.05);
	col += VIOLET * 0.2 * aaLine(outer, 0.004);

	// ── 78 connecting lines ──
	float line_accum = 0.0;
	float line_glow = 0.0;
	for (int i = 0; i < 13; i++) {
		for (int j = i + 1; j < 13; j++) {
			float d = sdSegment(p, pts[i], pts[j]);
			// Thin crisp line
			line_accum += aaLine(d, 0.003);
			// Soft glow
			line_glow += exp(-d * d * 800.0) * 0.015;
		}
	}
	// Lines: blue-violet base
	vec3 line_col = mix(ELECTRIC_BLUE, VIOLET, 0.4);
	col += line_col * min(line_accum, 1.0) * 0.45;
	// Glow: gold tint, reacts to energy
	col += GOLD * line_glow * (0.6 + energy * 1.2);

	// ── 13 circles ──
	float circle_r = scale * 0.18;
	for (int i = 0; i < 13; i++) {
		float cd = sdCircleRing(p - pts[i], circle_r);
		float ring = aaLine(cd, 0.004);

		// Color: center is gold, inner ring is violet, outer is blue
		vec3 ring_col;
		if (i == 0) {
			ring_col = GOLD;
		} else if (i < 7) {
			ring_col = VIOLET;
		} else {
			ring_col = ELECTRIC_BLUE;
		}
		col += ring_col * ring * 0.55;

		// Soft glow per circle
		float cg = exp(-cd * cd * 600.0);
		col += ring_col * cg * 0.08;
	}

	// ── Inner Seed of Life (7 overlapping circles at center) ──
	float seed_r = scale * 0.52;
	float seed_accum = 0.0;
	// Center
	seed_accum += aaLine(sdCircleRing(p, seed_r), 0.002);
	for (int i = 0; i < 6; i++) {
		float a = float(i) * TAU / 6.0 + t * 0.03;
		vec2 c = vec2(cos(a), sin(a)) * seed_r;
		seed_accum += aaLine(sdCircleRing(p - c, seed_r), 0.002);
	}
	col += GOLD * min(seed_accum, 1.0) * 0.18;

	// ── Platonic solid edges (cube + octahedron outlines inscribed) ──
	// Cube: 8 vertices projected, 12 edges
	float cube_s = scale * 0.58;
	// Simplified: draw the 2D projection of a rotating cube
	float cube_rot = t * 0.12;
	float cr = cos(cube_rot), sr = sin(cube_rot);
	float cr2 = cos(cube_rot * 0.7), sr2 = sin(cube_rot * 0.7);

	vec2 cube_verts[8];
	for (int i = 0; i < 8; i++) {
		// 3D cube vertices: (±1, ±1, ±1)
		float x = float((i & 1) * 2 - 1) * cube_s * 0.5;
		float y = float(((i >> 1) & 1) * 2 - 1) * cube_s * 0.5;
		float z = float(((i >> 2) & 1) * 2 - 1) * cube_s * 0.5;
		// Rotate in 3D then project
		float rx = x * cr - z * sr;
		float rz = x * sr + z * cr;
		float ry = y * cr2 - rz * sr2;
		float rz2 = y * sr2 + rz * cr2;
		// Perspective-ish projection
		float proj = 1.0 / (3.0 - rz2);
		cube_verts[i] = vec2(rx, ry) * proj * 3.0;
	}
	// 12 cube edges
	int edges_a[12] = int[](0,1,2,3,4,5,6,7,0,1,2,3);
	int edges_b[12] = int[](1,3,3,2,5,7,7,6,4,5,6,7);
	float cube_lines = 0.0;
	for (int i = 0; i < 12; i++) {
		float d = sdSegment(p, cube_verts[edges_a[i]], cube_verts[edges_b[i]]);
		cube_lines += aaLine(d, 0.002);
	}
	col += WHITE * min(cube_lines, 1.0) * 0.12;

	// ── Emanation pulse rings ──
	float r = length(p);
	for (int i = 0; i < 5; i++) {
		float ring_t = fract(float(i) * 0.2 + t * 0.1 + beat * 0.05);
		float ring_r = ring_t * outer_r * 1.3;
		float fade = (1.0 - ring_t);
		float ring = aaLine(abs(r - ring_r), 0.003);
		col += VIOLET * ring * fade * 0.15 * (1.0 + beat * 2.0);
	}

	// ── Center glow ──
	float center = exp(-r * r * 8.0) * (0.4 + energy * 0.8 + beat * 0.5);
	col += GOLD * center * 0.5;

	// ── Beat flash ──
	col += WHITE * beat * 0.08;

	// ── Treble sparkle on vertices ──
	for (int i = 0; i < 13; i++) {
		float d = length(p - pts[i]);
		float spark = exp(-d * d * 2000.0) * treble * 1.5;
		col += WHITE * spark;
	}

	// ── Vignette ──
	float vig = 1.0 - dot(uv, uv) * 0.3;
	col *= vig;

	// ── Tone mapping ──
	col = col / (col + vec3(1.0));

	ALBEDO = col;
}

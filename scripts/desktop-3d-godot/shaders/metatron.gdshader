shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

global uniform float audio_bass;
global uniform float audio_mid;
global uniform float audio_treble;
global uniform float audio_energy;
global uniform float beat_intensity;
global uniform vec3 cursor_world_pos;

const float PHI = 1.61803398;

// ── Cosine palette (Inigo Quilez) ──
vec3 pal(float t) {
	vec3 a = vec3(0.5, 0.5, 0.5);
	vec3 b = vec3(0.5, 0.5, 0.5);
	vec3 c = vec3(1.0, 0.7, 0.4);
	vec3 d = vec3(0.0, 0.15, 0.20);
	return a + b * cos(TAU * (c * t + d));
}

// ── Colors (base tints) ──
const vec3 BG = vec3(0.02, 0.01, 0.06);
const vec3 WHITE = vec3(1.0, 0.95, 0.9);
const vec3 GOLD = vec3(1.0, 0.85, 0.3);

// ── Rotation ──
vec2 rot2(vec2 p, float a) {
	float c = cos(a), s = sin(a);
	return vec2(p.x * c - p.y * s, p.x * s + p.y * c);
}

// ── SDF helpers ──
float sdCircleRing(vec2 p, float r) {
	return abs(length(p) - r);
}

float sdSegment(vec2 p, vec2 a, vec2 b, out float h_param) {
	vec2 pa = p - a, ba = b - a;
	h_param = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return length(pa - ba * h_param);
}

float aaLine(float d, float width) {
	float fw = max(fwidth(d), 0.003);
	return smoothstep(width + fw, max(width - fw, 0.0), d);
}

// ── Build 13 points for a given scale ──
void buildPoints(float scale, out vec2 pts[13]) {
	pts[0] = vec2(0.0);
	for (int i = 0; i < 6; i++) {
		float a = float(i) * TAU / 6.0;
		pts[i + 1] = vec2(cos(a), sin(a)) * scale;
		pts[i + 7] = vec2(cos(a + PI / 6.0), sin(a + PI / 6.0)) * scale * 1.732;
	}
}

// ── Render one layer of Metatron's Cube ──
// detail_level: 0 = full (main layer), 1 = simplified (background layer)
vec3 renderLayer(vec2 p, float scale, float t, float energy, float beat, float treble, float palette_offset, float opacity, int detail_level) {
	vec3 col = vec3(0.0);

	// Early out — skip pixels far from the geometry
	float r = length(p);
	float outer_r = scale * 1.732;
	if (r > outer_r * 1.4) {
		return col;
	}

	vec2 pts[13];
	buildPoints(scale, pts);

	// ── Outer bounding circle ──
	float outer = sdCircleRing(p, outer_r * 1.05);
	col += pal(palette_offset + 0.7) * 0.2 * aaLine(outer, 0.004);
	col += pal(palette_offset + 0.7) * clamp(0.004 / abs(outer), 0.0, 1.0) * 0.15;

	// ── 78 connecting lines ──
	// Only compute glow for main layer; skip energy flow for background layers
	float line_accum = 0.0;
	float line_glow = 0.0;
	float flow_accum = 0.0;
	for (int i = 0; i < 13; i++) {
		for (int j = i + 1; j < 13; j++) {
			float h_param;
			float d = sdSegment(p, pts[i], pts[j], h_param);
			line_accum += aaLine(d, 0.003);
			if (detail_level == 0) {
				line_glow += clamp(0.008 / abs(d + 0.001), 0.0, 1.0) * 0.008;
				float flow = sin((h_param - t * 0.5) * 12.0 * TAU) * 0.5 + 0.5;
				flow *= smoothstep(0.02, 0.0, d);
				flow_accum += flow * 0.015;
			}
		}
	}
	float line_palette_t = fract(t * 0.05 + palette_offset);
	vec3 line_col = pal(line_palette_t);
	col += line_col * min(line_accum, 1.0) * 0.45;
	if (detail_level == 0) {
		col += pal(line_palette_t + 0.3) * line_glow * (0.6 + energy * 1.2);
		col += mix(WHITE, GOLD, 0.5) * flow_accum * (1.0 + beat * 2.0);
	}

	// ── 13 circles with glow ──
	float circle_r = scale * 0.18;
	for (int i = 0; i < 13; i++) {
		float cd = sdCircleRing(p - pts[i], circle_r);
		float ring = aaLine(cd, 0.004);

		float ring_t;
		if (i == 0) ring_t = palette_offset;
		else if (i < 7) ring_t = palette_offset + 0.33;
		else ring_t = palette_offset + 0.66;

		vec3 ring_col = pal(ring_t + t * 0.04);
		col += ring_col * ring * 0.55;
		col += ring_col * clamp(0.006 / abs(cd + 0.001), 0.0, 1.0) * 0.08;

		// Mandala detail only on main layer and only if pixel is inside the circle
		if (detail_level == 0) {
			vec2 local = p - pts[i];
			float local_r = length(local);
			if (local_r < circle_r * 0.95) {
				float local_a = atan(local.y, local.x);
				float seg = TAU / 6.0;
				local_a -= seg * floor(local_a / seg);
				local_a = min(local_a, seg - local_a);
				float inner_rings = sin(local_r / circle_r * 12.0 + t * 0.8) * 0.5 + 0.5;
				float fade_in = smoothstep(circle_r, circle_r * 0.5, local_r);
				col += ring_col * inner_rings * fade_in * 0.2;
			}
		}
	}

	// ── Inner Seed of Life (main layer only) ──
	if (detail_level == 0) {
		float seed_r = scale * 0.52;
		float seed_accum = 0.0;
		seed_accum += aaLine(sdCircleRing(p, seed_r), 0.002);
		for (int i = 0; i < 6; i++) {
			float a = float(i) * TAU / 6.0 + t * 0.03;
			vec2 c = vec2(cos(a), sin(a)) * seed_r;
			seed_accum += aaLine(sdCircleRing(p - c, seed_r), 0.002);
		}
		col += GOLD * min(seed_accum, 1.0) * 0.18;

		// ── Platonic solid edges (rotating cube) ──
		float cube_s = scale * 0.58;
		float cube_rot = t * 0.12;
		float cr = cos(cube_rot), sr = sin(cube_rot);
		float cr2 = cos(cube_rot * 0.7), sr2 = sin(cube_rot * 0.7);
		vec2 cube_verts[8];
		for (int i = 0; i < 8; i++) {
			float x = float((i & 1) * 2 - 1) * cube_s * 0.5;
			float y = float(((i >> 1) & 1) * 2 - 1) * cube_s * 0.5;
			float z = float(((i >> 2) & 1) * 2 - 1) * cube_s * 0.5;
			float rx = x * cr - z * sr;
			float rz = x * sr + z * cr;
			float ry = y * cr2 - rz * sr2;
			float rz2 = y * sr2 + rz * cr2;
			float proj = 1.0 / (3.0 - rz2);
			cube_verts[i] = vec2(rx, ry) * proj * 3.0;
		}
		int edges_a[12] = int[](0,1,2,3,4,5,6,7,0,1,2,3);
		int edges_b[12] = int[](1,3,3,2,5,7,7,6,4,5,6,7);
		float cube_lines = 0.0;
		for (int i = 0; i < 12; i++) {
			float h_dummy;
			float d = sdSegment(p, cube_verts[edges_a[i]], cube_verts[edges_b[i]], h_dummy);
			cube_lines += aaLine(d, 0.002);
		}
		col += WHITE * min(cube_lines, 1.0) * 0.12;
	}

	return col * opacity;
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float t = TIME;

	float bass = audio_bass;
	float mid = audio_mid;
	float treble = audio_treble;
	float energy = audio_energy;
	float beat = beat_intensity;

	vec3 col = BG;

	// ── Layer 0: Main geometry (full detail) ──
	vec2 p0 = rot2(uv * 1.3, t * 0.06);
	col += renderLayer(p0, 0.38, t, energy, beat, treble, 0.0, 1.0, 0);

	// ── Layer 1: Larger, counter-rotating (simplified — no mandala, seed, cube) ──
	vec2 p1 = rot2(uv * 1.3 / 1.15, -t * 0.04);
	col += renderLayer(p1, 0.38, t, energy, beat, treble, 0.33, 0.2, 1);

	// ── Interference wave overlay (6 sources instead of 13) ──
	vec2 pts_main[13];
	buildPoints(0.38, pts_main);
	vec2 p_main = rot2(uv * 1.3, t * 0.06);
	float interference = 0.0;
	for (int i = 0; i < 7; i++) {
		float d = length(p_main - pts_main[i]);
		interference += sin(8.0 / (d + 0.05) + t * 0.3);
	}
	interference /= 7.0;
	col += pal(interference * 0.5 + t * 0.02) * abs(interference) * 0.08;

	// ── Emanation pulse rings ──
	float r = length(p0);
	float outer_r = 0.38 * 1.732;
	for (int i = 0; i < 4; i++) {
		float ring_t = fract(float(i) * 0.25 + t * 0.1);
		float ring_r = ring_t * outer_r * 1.3;
		float fade = (1.0 - ring_t);
		float ring = aaLine(abs(r - ring_r), 0.003);
		col += pal(ring_t + 0.5) * ring * fade * 0.15 * (1.0 + beat * 2.0);
	}

	// ── Center glow ──
	float center_r = length(p0);
	float center = exp(-center_r * center_r * 8.0) * (0.4 + energy * 0.8 + beat * 0.5);
	col += GOLD * center * 0.5;

	// ── Beat flash ──
	col += WHITE * beat * 0.08;

	// ── Treble sparkle on vertices (7 instead of 13) ──
	for (int i = 0; i < 7; i++) {
		float d = length(p0 - pts_main[i]);
		float spark = exp(-d * 40.0) * treble * 0.8;
		col += WHITE * spark;
	}

	// ── Vignette ──
	float vig = 1.0 - dot(uv, uv) * 0.3;
	col *= vig;

	// ── Tone mapping ──
	col = col / (col + vec3(1.0));

	ALBEDO = col;
}

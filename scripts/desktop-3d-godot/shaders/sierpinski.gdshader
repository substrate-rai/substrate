shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

// Sierpinski triangle/carpet via domain folding
// Clean geometric fractal with infinite detail

global uniform float audio_bass;
global uniform float audio_mid;
global uniform float audio_treble;
global uniform float audio_energy;
global uniform float beat_intensity;
global uniform vec3 cursor_world_pos;

const float PHI = 1.61803398;

vec2 rot2(vec2 p, float a) {
	float c = cos(a), s = sin(a);
	return vec2(p.x * c - p.y * s, p.x * s + p.y * c);
}

vec3 cosPalette(float t, vec3 a, vec3 b, vec3 c, vec3 d) {
	return a + b * cos(TAU * (c * t + d));
}

vec3 crystalPalette(float t) {
	return cosPalette(t,
		vec3(0.3, 0.2, 0.5),
		vec3(0.5, 0.4, 0.3),
		vec3(1.0, 1.0, 0.8),
		vec3(0.0, 0.1, 0.25)
	);
}

// Sierpinski Triangle via iterated domain folding
// Returns: x = distance estimate, y = iteration depth, z = trap value
vec3 sierpinskiTriangle(vec2 p, int iterations) {
	// Triangle vertices
	vec2 a = vec2(0.0, 1.15);
	vec2 b = vec2(-1.0, -0.577);
	vec2 c = vec2(1.0, -0.577);

	float trap = 1e9;

	for (int i = 0; i < iterations; i++) {
		// Find nearest vertex and fold toward it
		float da = length(p - a);
		float db = length(p - b);
		float dc = length(p - c);

		if (da < db && da < dc) {
			p = 2.0 * p - a;
		} else if (db < dc) {
			p = 2.0 * p - b;
		} else {
			p = 2.0 * p - c;
		}

		trap = min(trap, dot(p, p));
	}

	// Distance estimate
	float scale = pow(2.0, float(iterations));
	// Distance to triangle edges
	float d1 = dot(p - a, normalize(b - a));
	float d2 = dot(p - b, normalize(c - b));
	float d3 = dot(p - c, normalize(a - c));
	float de = max(max(d1, d2), d3) / scale;

	return vec3(de, float(iterations), trap);
}

// Sierpinski Carpet (square version)
float sierpinskiCarpet(vec2 p, int iterations) {
	float scale = 1.0;
	float d = 0.0;

	for (int i = 0; i < iterations; i++) {
		p = fract(p * 3.0);
		scale *= 3.0;

		// Check if in center square (removed in carpet)
		vec2 center = step(vec2(1.0 / 3.0), p) * step(p, vec2(2.0 / 3.0));
		if (center.x * center.y > 0.5) {
			d = 1.0;
			break;
		}
	}
	return d;
}

// Koch snowflake-ish edge fractal
float kochEdge(vec2 p, int iterations) {
	// Start with line along x-axis
	float angle = 0.0;
	float scale = 1.0;

	for (int i = 0; i < iterations; i++) {
		p *= 3.0;
		scale *= 3.0;

		p.x = abs(p.x);
		p.x -= 0.5;
		// Fold
		if (p.x + p.y * 1.732 > 0.0) {
			p = vec2(p.x * 0.5 - p.y * 0.866, p.x * 0.866 + p.y * 0.5);
		}
	}

	return length(p) / scale;
}

void fragment() {
	vec2 uv = UV * 2.0 - 1.0;
	float t = TIME;

	float bass = audio_bass;
	float mid = audio_mid;
	float treble = audio_treble;
	float energy = audio_energy;
	float beat = beat_intensity;

	// Zoom: oscillates slowly, bass deepens zoom
	float zoom_cycle = sin(t * 0.06) * 0.5 + 0.5;
	float zoom = mix(1.2, 2.5, zoom_cycle) + bass * 0.3;
	vec2 p = rot2(uv * zoom, t * 0.03);

	// Iteration depth: treble adds detail
	int iters = 8 + int(treble * 4.0);
	iters = clamp(iters, 8, 14);

	vec3 col = vec3(0.02, 0.01, 0.04);

	// ── Sierpinski Triangle (primary) ──
	vec2 p_tri = p * 0.8;
	vec3 tri = sierpinskiTriangle(p_tri, iters);

	float tri_de = tri.x;
	float tri_trap = tri.z;

	// Edge rendering
	float fw = fwidth(tri_de);
	float edge = smoothstep(0.004 + fw, 0.001, abs(tri_de));

	// Color by trap value (orbit distance)
	float trap_norm = clamp(log(tri_trap + 1.0) * 0.2, 0.0, 1.0);
	vec3 tri_col = crystalPalette(trap_norm + t * 0.03 + beat * 0.15);

	// Filled regions with gradient
	float fill = smoothstep(0.01, -0.005, tri_de);
	col += tri_col * (edge * 0.7 + fill * 0.2);

	// ── Sierpinski Carpet overlay (rotated) ──
	vec2 p_carpet = rot2(p * 0.5 + 0.5, -t * 0.02);
	p_carpet = fract(p_carpet) * 3.0;
	float carpet = sierpinskiCarpet(p_carpet, 5);

	// Carpet holes glow
	vec3 carpet_col = mix(vec3(0.1, 0.05, 0.2), vec3(0.4, 0.2, 0.7), carpet);
	col = mix(col, carpet_col, carpet * 0.15);

	// ── Koch edge detail ──
	float koch = kochEdge(rot2(p * 1.2, t * 0.05 + PI * 0.25), 6);
	float koch_line = smoothstep(0.003, 0.001, koch);
	col += vec3(0.3, 0.6, 1.0) * koch_line * 0.12;

	// ── Concentric depth rings ──
	float r = length(p);
	float rings = sin(r * 15.0 - t * 2.0) * 0.5 + 0.5;
	rings *= exp(-r * 1.5);
	col += vec3(0.2, 0.1, 0.4) * rings * 0.08 * (1.0 + beat);

	// ── Audio reactivity ──
	// Energy brightens edges
	col += tri_col * edge * energy * 0.3;

	// Beat flash
	col += vec3(0.5, 0.3, 0.8) * beat * 0.12;

	// Mid: subtle color shift
	float shift = mid * 0.15;
	col.rb += shift * 0.1;

	// ── Center glow ──
	float glow = exp(-length(p) * 2.0) * (0.2 + energy * 0.4);
	col += vec3(0.4, 0.2, 0.7) * glow * 0.3;

	// Vignette
	float vig = 1.0 - dot(uv, uv) * 0.3;
	col *= vig;

	// Tone mapping
	col = col / (col + vec3(1.0));

	ALBEDO = col;
}

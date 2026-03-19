shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

// PIXEL ART: Mycopunk forest clearing — parallax layers, bioluminescent mushrooms,
// animated figure, fireflies, stream with reflections, falling spores, moon, fog

global uniform float system_heat;
global uniform float audio_bass;
global uniform float audio_mid;
global uniform float audio_energy;
global uniform float beat_intensity;
global uniform float audio_sub_bass;
global uniform float audio_treble;
global uniform float audio_presence;
global uniform float beat_kick;
global uniform float beat_snare;
global uniform float beat_hihat;
global uniform float audio_warmth;
global uniform float audio_brightness;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1,311.7)))*43758.5453); }
float hash1(float p) { return fract(sin(p * 127.1) * 43758.5453); }

float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f*f*(3.0-2.0*f);
	return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);
}

float fbm(vec2 p, int oct) {
	float v=0.0, a=0.5;
	for(int i=0;i<oct;i++){v+=a*noise(p);p=mat2(vec2(0.87,0.5),vec2(-0.5,0.87))*p*2.0;a*=0.5;}
	return v;
}

vec2 px(vec2 uv, float r) { return floor(uv*r)/r; }

// ── Palettes ──
vec3 sky_color(float y) {
	// Quantized sky bands — no smooth gradients
	if (y > 0.85) return vec3(0.015, 0.008, 0.04);
	if (y > 0.65) return vec3(0.025, 0.012, 0.055);
	if (y > 0.50) return vec3(0.035, 0.018, 0.065);
	return vec3(0.04, 0.02, 0.06); // horizon and below
}

vec3 mushroom_color(float type, float glow) {
	vec3 cap, stem;
	if (type < 0.33) { cap = vec3(0.1, 0.8, 0.5); stem = vec3(0.4, 0.6, 0.5); }       // cyan-green
	else if (type < 0.66) { cap = vec3(0.6, 0.2, 0.9); stem = vec3(0.5, 0.4, 0.6); }   // purple
	else { cap = vec3(0.2, 0.5, 0.9); stem = vec3(0.3, 0.5, 0.6); }                     // blue
	cap += glow * 0.3;
	return cap;
}

void fragment() {
	vec2 uv = UV;
	float t = TIME;
	float R = 96.0; // pixel resolution
	vec2 p = px(uv, R);
	vec2 cell = floor(uv * R);
	float ch = hash(cell);

	vec3 col = sky_color(p.y);

	// ══════════════════════════════════════════════
	// LAYER 0: Stars and moon
	// ══════════════════════════════════════════════
	if (p.y > 0.55) {
		// Stars — multiple brightness levels
		float s1 = step(0.992, hash(cell * 0.07));
		float s2 = step(0.985, hash(cell * 0.11 + 50.0)) * 0.5;
		float twink = sin(t * (1.5 + ch * 5.0) + ch * 30.0) * 0.4 + 0.6;
		twink *= 0.6 + audio_treble * 0.4;
		col += vec3(0.55, 0.6, 0.8) * (s1 + s2) * twink;

		// Shooting star (rare)
		float shoot_t = mod(t * 0.1, 1.0);
		float shoot_x = 0.3 + shoot_t * 0.5;
		float shoot_y = 0.9 - shoot_t * 0.25;
		if (abs(p.x - shoot_x) < 0.02 && abs(p.y - shoot_y) < 0.005 && shoot_t < 0.15) {
			col += vec3(0.8, 0.85, 1.0) * (1.0 - shoot_t / 0.15);
		}
	}

	// Moon
	vec2 moon_c = vec2(0.78, 0.85);
	float moon_r = 0.045;
	float moon_d = length(p - moon_c);
	if (moon_d < moon_r) {
		col = vec3(0.75, 0.78, 0.85);
		// Craters
		if (length(p - moon_c - vec2(0.01, 0.01)) < 0.012) col *= 0.85;
		if (length(p - moon_c + vec2(0.015, -0.005)) < 0.008) col *= 0.88;
		if (length(p - moon_c + vec2(-0.005, 0.015)) < 0.01) col *= 0.87;
		// Moon glow
	}
	// Moon halo — pixelated ring
	if (moon_d > moon_r && moon_d < moon_r + 0.02) {
		col += vec3(0.08, 0.08, 0.12);
	}

	// ══════════════════════════════════════════════
	// LAYER 1: Far mountain silhouette (parallax)
	// ══════════════════════════════════════════════
	float far_scroll = t * 0.002;
	float mtn_h = 0.52 + fbm(vec2(p.x * 3.0 + far_scroll, 0.0), 3) * 0.12;
	if (p.y < mtn_h && p.y > 0.4) {
		col = mix(vec3(0.03, 0.015, 0.05), vec3(0.05, 0.025, 0.07), (p.y - 0.4) / 0.15);
	}

	// ══════════════════════════════════════════════
	// LAYER 2: Mid forest silhouette (parallax)
	// ══════════════════════════════════════════════
	float mid_scroll = t * 0.005;
	float tree_line = 0.42;
	// Procedural tree tops
	for (int i = 0; i < 20; i++) {
		float fi = float(i);
		float tx = hash1(fi * 73.1) + mid_scroll;
		tx = fract(tx) * 1.2 - 0.1; // spread across screen
		float th = 0.06 + hash1(fi * 37.3) * 0.08;
		float tw = 0.015 + hash1(fi * 91.7) * 0.01;
		// Triangle tree shape
		float tree_top = tree_line + th;
		float rel = (p.y - tree_line) / th;
		if (p.y > tree_line && p.y < tree_top && abs(p.x - tx) < tw * (1.0 - rel)) {
			col = vec3(0.02, 0.03, 0.02);
		}
	}
	// Tree line base
	if (p.y < tree_line + 0.01 && p.y > tree_line - 0.02) {
		col = mix(col, vec3(0.02, 0.025, 0.02), smoothstep(tree_line + 0.01, tree_line - 0.02, p.y));
	}

	// ══════════════════════════════════════════════
	// LAYER 3: Clearing ground
	// ══════════════════════════════════════════════
	float ground_y = 0.32;
	if (p.y < ground_y) {
		float dirt = hash(cell * 0.2 + 200.0);
		vec3 gnd = mix(vec3(0.03, 0.05, 0.02), vec3(0.05, 0.07, 0.03), dirt);
		// Grass blades
		float grass_tip = ground_y + (hash(vec2(cell.x, 0.0)) - 0.5) * 0.02;
		if (p.y > grass_tip - 0.015 && p.y < grass_tip) {
			float blade = step(0.3, hash(vec2(cell.x * 0.5, 5.0)));
			gnd = mix(gnd, vec3(0.02, 0.08, 0.02), blade * 0.5);
		}
		col = gnd;

		// Path (lighter dirt in center)
		float path_d = abs(p.x - 0.5);
		if (path_d < 0.06 && p.y < ground_y - 0.03) {
			col = mix(col, vec3(0.08, 0.06, 0.04), smoothstep(0.06, 0.02, path_d));
		}
	}

	// ══════════════════════════════════════════════
	// LAYER 4: Stream
	// ══════════════════════════════════════════════
	float stream_y = 0.12;
	float stream_w = 0.4;
	float stream_d = abs(p.y - stream_y);
	float stream_cx = 0.5 + sin(p.y * 8.0) * 0.03; // slight meander
	float stream_xd = abs(p.x - stream_cx);
	if (stream_d < 0.025 && stream_xd < stream_w * 0.5) {
		// Water with animated ripples
		float ripple = noise(vec2(p.x * 30.0 - t * 2.0, p.y * 10.0)) * 0.3;
		ripple += noise(vec2(p.x * 15.0 - t * 1.2, p.y * 5.0)) * 0.2;
		vec3 water = vec3(0.02, 0.06, 0.12) + vec3(0.02, 0.04, 0.08) * ripple;

		// Moonlight reflection on water
		float moon_ref_x = abs(p.x - moon_c.x);
		if (moon_ref_x < 0.03) {
			float shimmer = noise(vec2(p.x * 40.0 - t * 3.0, p.y * 20.0));
			water += vec3(0.15, 0.15, 0.2) * shimmer * smoothstep(0.03, 0.0, moon_ref_x);
		}

		// Fire reflection
		float fire_ref = smoothstep(0.15, 0.0, abs(p.x - 0.5));
		water += vec3(0.15, 0.05, 0.01) * fire_ref * (0.3 + audio_energy * 0.3);

		col = water;

		// Stepping stones
		for (int i = 0; i < 3; i++) {
			float sx = 0.35 + float(i) * 0.1;
			if (abs(p.x - sx) < 0.012 && stream_d < 0.01) {
				col = vec3(0.12, 0.11, 0.1);
			}
		}
	}

	// ══════════════════════════════════════════════
	// LAYER 5: Giant bioluminescent mushrooms
	// ══════════════════════════════════════════════
	// Left mushroom (large, cyan)
	{
		vec2 mc = vec2(0.18, ground_y);
		float stem_w = 0.018;
		float stem_h = 0.12;
		float cap_r = 0.05;
		float cap_y = mc.y + stem_h;
		// Stem
		if (abs(p.x - mc.x) < stem_w && p.y > mc.y && p.y < cap_y) {
			col = vec3(0.3, 0.5, 0.45) + vec3(0.05) * hash(cell * 0.5);
		}
		// Cap (dome shape)
		float cap_d = length(vec2((p.x - mc.x) * 1.0, (p.y - cap_y) * 2.5));
		if (cap_d < cap_r && p.y > cap_y - 0.01) {
			float glow_pulse = 0.7 + 0.3 * sin(t * 1.2 + 0.0) + audio_bass * 0.3;
			col = vec3(0.05, 0.6, 0.4) * glow_pulse;
			// Spots
			if (hash(cell * 0.6 + 10.0) > 0.7) col += vec3(0.1, 0.3, 0.2);
		}
		// Spore gills (lines under cap)
		if (abs(p.y - cap_y + 0.005) < 0.004 && abs(p.x - mc.x) < cap_r * 0.8) {
			if (mod(cell.x, 2.0) < 1.0) col = vec3(0.08, 0.45, 0.35);
		}
	}

	// Right mushroom (large, purple)
	{
		vec2 mc = vec2(0.82, ground_y);
		float stem_h = 0.1;
		float cap_y = mc.y + stem_h;
		float cap_r = 0.04;
		if (abs(p.x - mc.x) < 0.014 && p.y > mc.y && p.y < cap_y) {
			col = vec3(0.4, 0.3, 0.5) + vec3(0.05) * hash(cell * 0.4);
		}
		float cap_d = length(vec2((p.x - mc.x), (p.y - cap_y) * 2.5));
		if (cap_d < cap_r && p.y > cap_y - 0.01) {
			float glow_pulse = 0.7 + 0.3 * sin(t * 0.9 + 2.0) + audio_mid * 0.3;
			col = vec3(0.5, 0.15, 0.7) * glow_pulse;
			if (hash(cell * 0.55 + 20.0) > 0.7) col += vec3(0.2, 0.1, 0.3);
		}
		// No smooth aura — pixel art uses hard edges
	}

	// Small mushroom cluster (center-left, blue)
	for (int i = 0; i < 4; i++) {
		float fi = float(i);
		float sx = 0.35 + fi * 0.015 + hash1(fi * 51.0) * 0.01;
		float sh = 0.03 + hash1(fi * 33.0) * 0.03;
		float sy = ground_y;
		float cap_y2 = sy + sh;
		if (abs(p.x - sx) < 0.006 && p.y > sy && p.y < cap_y2) {
			col = vec3(0.25, 0.4, 0.5);
		}
		float cd = length(vec2(p.x - sx, (p.y - cap_y2) * 3.0));
		if (cd < 0.015 && p.y > cap_y2 - 0.005) {
			float gp = 0.7 + 0.3 * sin(t * 1.5 + fi) + audio_treble * 0.2;
			col = vec3(0.15, 0.4, 0.8) * gp;
		}
	}

	// ══════════════════════════════════════════════
	// LAYER 6: Campfire (center)
	// ══════════════════════════════════════════════
	float fire = 0.0;
	float fb = ground_y - 0.005;
	float fcx = 0.5;

	// Stones
	for (int i = 0; i < 6; i++) {
		float fi = float(i);
		float ang = fi * 1.05 + 0.2;
		float rx = fcx + cos(ang) * 0.04;
		float ry = fb + sin(ang) * 0.008;
		if (max(abs(p.x - rx), abs(p.y - ry) * 3.0) < 0.008) {
			col = vec3(0.12, 0.11, 0.1) + hash(vec2(fi, 88.0)) * 0.05;
		}
	}

	// Logs
	float ldx = p.x - fcx;
	if (abs(ldx) < 0.04 && abs(p.y - (fb + ldx * 0.2)) < 0.006) {
		col = vec3(0.2, 0.1, 0.04) + hash(cell * 0.3) * 0.08;
	}
	if (abs(ldx) < 0.035 && abs(p.y - (fb - ldx * 0.18)) < 0.006) {
		col = vec3(0.18, 0.09, 0.03) + hash(cell * 0.35) * 0.08;
	}

	// Flames
	for (int i = 0; i < 5; i++) {
		float fi = float(i);
		float xo = (fi - 2.0) * 0.01;
		float w = 0.02 - abs(xo) * 0.3;
		float h = 0.1 + 0.04 * noise(vec2(fi * 5.0, t * 2.5));
		h += audio_bass * 0.04 + beat_kick * 0.06;
		float sway = noise(vec2(fi * 4.0, t * 2.0)) * 0.008;
		float fx = fcx + xo + sway;
		float fy_rel = (p.y - fb) / h;
		if (fy_rel > 0.0 && fy_rel < 1.0) {
			float taper = w * (1.0 - fy_rel * fy_rel);
			if (abs(p.x - fx) < taper) {
				float inten = (1.0 - fy_rel) * (0.5 + noise(vec2(cell.x * 0.3 + fi, t * 5.0)) * 0.5);
				fire = max(fire, inten);
			}
		}
	}
	if (fire > 0.02) {
		float f = clamp(fire + beat_kick * 0.2, 0.0, 1.0);
		f = floor(f * 8.0 + ch * 0.1) / 8.0;
		vec3 fc = vec3(0.0);
		fc = mix(fc, vec3(0.5, 0.05, 0.0), smoothstep(0.0, 0.2, f));
		fc = mix(fc, vec3(0.9, 0.2, 0.0), smoothstep(0.15, 0.4, f));
		fc = mix(fc, vec3(1.0, 0.55, 0.05), smoothstep(0.35, 0.6, f));
		fc = mix(fc, vec3(1.0, 0.85, 0.2), smoothstep(0.55, 0.8, f));
		fc = mix(fc, vec3(1.0, 0.97, 0.7), smoothstep(0.75, 1.0, f));
		col = fc;
	}

	// ══════════════════════════════════════════════
	// LAYER 7: Seated figure (silhouette by fire)
	// ══════════════════════════════════════════════
	{
		float fx = 0.56;
		float fy = ground_y;
		// Body (sitting)
		if (abs(p.x - fx) < 0.012 && p.y > fy && p.y < fy + 0.035) {
			col = vec3(0.06, 0.05, 0.04);
		}
		// Head (with subtle breathing)
		float breathe = sin(t * 1.2) * 0.002;
		vec2 head_c = vec2(fx, fy + 0.045 + breathe);
		if (length(p - head_c) < 0.01) {
			col = vec3(0.06, 0.05, 0.04);
		}
		// Arm reaching toward fire
		float arm_y = fy + 0.025;
		if (p.y > arm_y - 0.004 && p.y < arm_y + 0.004 && p.x > fx - 0.012 && p.x < fx - 0.025) {
			col = vec3(0.06, 0.05, 0.04);
		}
		// Fire light on figure — only on the figure pixels
		if (abs(p.x - fx) < 0.015 && p.y > fy && p.y < fy + 0.05) {
			col += vec3(0.15, 0.05, 0.01) * fire;
		}
	}

	// ══════════════════════════════════════════════
	// LAYER 8: Fireflies
	// ══════════════════════════════════════════════
	for (int i = 0; i < 25; i++) {
		float fi = float(i);
		float s = hash(vec2(fi * 67.3, fi * 23.7));
		float fx = s;
		float fy = 0.28 + hash(vec2(fi * 41.1, 0.0)) * 0.25;
		// Slow drift
		fx += sin(t * (0.3 + s * 0.5) + fi * 2.0) * 0.04;
		fy += cos(t * (0.2 + s * 0.4) + fi * 3.0) * 0.02;
		// Blinking
		float blink = sin(t * (1.0 + s * 2.0) + fi * 5.0);
		blink = smoothstep(0.3, 0.8, blink);
		blink *= 0.6 + audio_presence * 0.4;

		vec2 fcell = floor(vec2(fx, fy) * R);
		if (fcell.x == cell.x && fcell.y == cell.y && blink > 0.1) {
			col = mix(col, vec3(0.4, 0.9, 0.3), blink * 0.8);
		}
		// No smooth glow — pixel art fireflies are just bright dots
	}

	// ══════════════════════════════════════════════
	// LAYER 9: Falling spores
	// ══════════════════════════════════════════════
	for (int i = 0; i < 20; i++) {
		float fi = float(i);
		float s = hash(vec2(fi * 53.1, fi * 89.3));
		float sx = s + sin(t * 0.3 + fi) * 0.03;
		float sy = fract(1.0 - (s * 5.0 + t * (0.02 + s * 0.02)));
		float drift = sin(t * (0.5 + s) + fi * 2.0) * 0.01;

		vec2 scell = floor(vec2(sx + drift, sy) * R);
		if (scell.x == cell.x && scell.y == cell.y && sy > 0.2) {
			float brightness = 0.3 + 0.3 * sin(t + fi * 3.0);
			brightness *= 0.5 + audio_treble * 0.5;
			col = mix(col, vec3(0.3, 0.6, 0.5), brightness * 0.5);
		}
	}

	// ══════════════════════════════════════════════
	// LAYER 10: Sparks from fire
	// ══════════════════════════════════════════════
	for (int i = 0; i < 10; i++) {
		float fi = float(i);
		float s = hash(vec2(fi * 83.1, fi * 59.7));
		float ex = fcx + (s - 0.5) * 0.06;
		float ey = fb + fract(s * 9.0 + t * (0.06 + s * 0.08)) * 0.2;
		float edrift = sin(t * (1.5 + s * 2.0) + fi) * 0.015;

		vec2 ecell = floor(vec2(ex + edrift, ey) * R);
		if (ecell.x == cell.x && ecell.y == cell.y) {
			float life = 1.0 - (ey - fb) / 0.2;
			if (life > 0.0) {
				vec3 sc = mix(vec3(1.0, 0.3, 0.0), vec3(1.0, 0.8, 0.2), life);
				col = sc * (0.5 + beat_hihat * 0.5);
			}
		}
	}

	// ══════════════════════════════════════════════
	// LAYER 11: Fog / mist
	// ══════════════════════════════════════════════
	// Fog disabled — was causing color bleeding

	// ══════════════════════════════════════════════
	// Global: fire light cast + audio brightness
	// ══════════════════════════════════════════════
	// Fire light — only on ground, hard cutoff above flames
	if (p.y < fb + 0.05) {
		float fire_dx = abs(p.x - fcx);
		float fire_light = step(fire_dx, 0.12) * (1.0 - fire_dx / 0.12) * 0.1;
		fire_light = floor(fire_light * 4.0) / 4.0;
		fire_light *= 1.0 + audio_energy * 0.5;
		col += vec3(0.25, 0.07, 0.01) * fire_light;
	}

	// Mushroom/fire lights removed — smooth falloffs break pixel art

	col *= 1.0 + audio_brightness * 0.3;
	col += beat_snare * 0.03 * vec3(0.5, 0.3, 0.1); // subtle snare flash

	ALBEDO = col;
}

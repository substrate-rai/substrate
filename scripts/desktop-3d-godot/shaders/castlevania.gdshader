shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

// PIXEL ART: Castlevania hallway — gothic stone corridor, candles, bats,
// moonlit stained glass windows, swinging chandelier, red carpet, torches

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

vec2 px(vec2 uv, float r) { return floor(uv*r)/r; }

// SNES-style ordered dithering (2x2 Bayer matrix)
float dither2x2(vec2 pos) {
	int x = int(mod(pos.x, 2.0));
	int y = int(mod(pos.y, 2.0));
	if (x == 0 && y == 0) return 0.0;
	if (x == 1 && y == 1) return 0.25;
	if (x == 1 && y == 0) return 0.5;
	return 0.75;
}

// Quantize color to SNES-like palette (5 bits per channel = 32 levels)
vec3 snes_quantize(vec3 c) {
	return floor(c * 31.0 + 0.5) / 31.0;
}

// Smooth light with dithered falloff (SNES mode 7 style)
float dithered_light(float intensity, vec2 cell_pos) {
	float d = dither2x2(cell_pos);
	return floor((intensity + d * 0.04) * 12.0) / 12.0;
}

void fragment() {
	vec2 uv = UV;
	float t = TIME;
	float R = 720.0; // HD pixel art — maximum detail
	vec2 p = px(uv, R);
	vec2 cell = floor(uv * R);
	float ch = hash(cell);

	// ── SNES color palette (richer, more tonal variation) ──
	vec3 stone_dark = vec3(0.07, 0.06, 0.09);
	vec3 stone_mid = vec3(0.13, 0.11, 0.15);
	vec3 stone_light = vec3(0.21, 0.19, 0.24);
	vec3 stone_highlight = vec3(0.28, 0.25, 0.3);
	vec3 mortar = vec3(0.04, 0.035, 0.05);
	vec3 carpet_dark = vec3(0.3, 0.02, 0.04);
	vec3 carpet_mid = vec3(0.48, 0.04, 0.06);
	vec3 carpet_light = vec3(0.6, 0.1, 0.12);
	vec3 carpet_highlight = vec3(0.7, 0.15, 0.1);
	vec3 gold = vec3(0.75, 0.6, 0.18);
	vec3 gold_mid = vec3(0.55, 0.42, 0.12);
	vec3 gold_dark = vec3(0.35, 0.25, 0.06);
	vec3 gold_shadow = vec3(0.2, 0.14, 0.03);

	vec3 col = stone_dark;

	// ══════════════════════════════════════════════
	// LAYER 0: Stone wall background (HD detail)
	// ══════════════════════════════════════════════
	{
		float brick_h = 0.014;
		float brick_w = 0.032;
		float row = floor(p.y / brick_h);
		float offset = mod(row, 2.0) * brick_w * 0.5;
		float col_idx2 = floor((p.x + offset) / brick_w);

		float in_brick_y = fract(p.y / brick_h);
		float in_brick_x = fract((p.x + offset) / brick_w);

		float mortar_w = 0.06;
		bool is_mortar = in_brick_y > (1.0 - mortar_w) || in_brick_y < mortar_w || in_brick_x > (1.0 - mortar_w) || in_brick_x < mortar_w;

		if (is_mortar) {
			col = mortar;
			// Mortar depth: top-left of gap = lit, bottom-right = shadow
			if (in_brick_y > (1.0 - mortar_w) || in_brick_x > (1.0 - mortar_w)) col = mortar * 0.6;
			if (in_brick_y < mortar_w && in_brick_y > mortar_w * 0.5) col = mortar * 1.3;
			if (in_brick_x < mortar_w && in_brick_x > mortar_w * 0.5) col = mortar * 1.2;
			// Mortar crumbling
			float crumble = noise(cell * 0.8 + 300.0);
			if (crumble > 0.7) col *= 0.7;
		} else {
			float brick_hash = hash(vec2(col_idx2, row));
			float brick_hash2 = hash(vec2(col_idx2 + 100.0, row + 100.0));

			// Base color — wide tonal range
			vec3 base = mix(stone_dark, stone_mid, brick_hash * 0.5 + 0.25);
			// Some bricks slightly warmer, some cooler
			if (brick_hash2 > 0.5) base += vec3(0.01, 0.005, -0.005);
			else base += vec3(-0.005, 0.0, 0.01);

			// Multi-octave surface texture
			float tex1 = noise(vec2(col_idx2 * 8.0 + p.x * 80.0, row * 6.0 + p.y * 60.0));
			float tex2 = noise(vec2(p.x * 200.0 + col_idx2, p.y * 150.0 + row)) * 0.5;
			float tex3 = noise(vec2(p.x * 400.0, p.y * 300.0)) * 0.25;
			float surface = tex1 + tex2 + tex3;
			col = base + vec3(surface * 0.04 - 0.03);

			// Edge lighting (top and left edges catch light)
			float edge_top = smoothstep(0.7, 0.92, in_brick_y) * 0.12;
			float edge_left = smoothstep(0.7, 0.92, in_brick_x) * 0.06;
			col += stone_highlight * (edge_top + edge_left);

			// Shadow on bottom and right edges
			float shadow_bot = smoothstep(0.2, mortar_w, in_brick_y) * 0.15;
			float shadow_right = smoothstep(0.2, mortar_w, in_brick_x) * 0.08;
			col *= 1.0 - (shadow_bot + shadow_right);

			// Weathering: cracks, chips, discoloration
			float crack = hash(cell * 0.25 + vec2(row * 0.7, col_idx2 * 0.3));
			if (crack > 0.96) col *= 0.4; // deep crack
			else if (crack > 0.93) col *= 0.6; // medium crack
			else if (crack > 0.88) col = mix(col, col * 0.7, noise(p * 300.0)); // hairline

			// Chipped corners
			if (brick_hash > 0.9) {
				if ((in_brick_y > 0.85 && in_brick_x > 0.85) || (in_brick_y > 0.85 && in_brick_x < 0.15)) {
					col = mortar;
				}
			}

			// Moss and lichen (lower wall, spreading from mortar)
			if (p.y < 0.32) {
				float moss_d = min(
					min(in_brick_y, 1.0 - in_brick_y),
					min(in_brick_x, 1.0 - in_brick_x)
				);
				float moss_noise = noise(p * 50.0 + 100.0);
				float moss_str = smoothstep(0.15, 0.0, moss_d) * moss_noise;
				moss_str *= smoothstep(0.32, 0.2, p.y); // stronger lower
				if (moss_str > 0.1) {
					vec3 moss_col = mix(vec3(0.02, 0.08, 0.03), vec3(0.05, 0.14, 0.04), noise(p * 80.0));
					col = mix(col, moss_col, moss_str * 0.7);
				}
			}

			// Water stains (damp vertical streaks)
			float stain_x = hash(vec2(floor(p.x * 30.0), 0.0));
			if (stain_x > 0.88) {
				float stain = noise(vec2(p.x * 60.0, p.y * 8.0 + 50.0));
				col = mix(col, col * 0.7, stain * 0.4 * smoothstep(0.7, 0.3, p.y));
			}
		}
	}

	// ══════════════════════════════════════════════
	// LAYER 1: Floor
	// ══════════════════════════════════════════════
	float floor_y = 0.18;
	if (p.y < floor_y) {
		// Checkerboard stone floor (HD detail)
		float tile_sz = 0.018;
		float tile_x = floor(p.x / tile_sz);
		float tile_y = floor(p.y / tile_sz);
		float tile_hash = hash(vec2(tile_x, tile_y));
		bool checker = mod(tile_x + tile_y, 2.0) < 1.0;

		float in_tile_x = fract(p.x / tile_sz);
		float in_tile_y = fract(p.y / tile_sz);
		bool tile_edge = in_tile_x > 0.93 || in_tile_x < 0.07 || in_tile_y > 0.93 || in_tile_y < 0.07;

		if (tile_edge) {
			col = mortar * 0.6;
			if (in_tile_y > 0.93 || in_tile_x < 0.07) col = mortar * 0.4; // shadow edges
		} else {
			if (checker) {
				col = mix(stone_mid, stone_light, 0.3 + tile_hash * 0.15);
			} else {
				col = mix(stone_dark, stone_mid, 0.4 + tile_hash * 0.15);
			}
			// Stone texture
			float floor_tex = noise(p * 150.0) * 0.04 + noise(p * 300.0) * 0.02;
			col += vec3(floor_tex);
			// Edge bevels
			if (in_tile_y > 0.85) col = mix(col, stone_highlight, 0.12);
			if (in_tile_y < 0.12) col *= 0.88;
			if (in_tile_x > 0.85) col = mix(col, stone_highlight, 0.08);
			if (in_tile_x < 0.12) col *= 0.9;
			// Worn center of hallway
			if (abs(p.x - 0.5) < 0.12) {
				col *= 0.92 + noise(p * 100.0) * 0.05;
			}
		}

		// Red carpet runner (richer SNES detail)
		float carpet_edge = 0.11;
		float carpet_d = abs(p.x - 0.5);
		if (carpet_d < carpet_edge) {
			// Carpet base with woven texture
			float weave_x = sin(p.x * 120.0) * 0.5 + 0.5;
			float weave_y = sin(p.y * 150.0) * 0.5 + 0.5;
			float weave = weave_x * weave_y;
			col = mix(carpet_dark, carpet_mid, weave * 0.4 + 0.3);

			// Ornate pattern — fleur-de-lis repeating
			float pat_cell_x = fract(p.x * 15.0);
			float pat_cell_y = fract(p.y * 18.0);
			float diamond = abs(pat_cell_x - 0.5) + abs(pat_cell_y - 0.5);
			if (diamond < 0.3) {
				col = carpet_light;
				if (diamond < 0.15) col = carpet_highlight;
			}

			// Gold trim at edges (double line)
			if (carpet_d > carpet_edge - 0.005) {
				col = gold;
			} else if (carpet_d > carpet_edge - 0.01) {
				col = gold_dark;
			}
			// Inner gold accent line
			if (abs(carpet_d - carpet_edge + 0.02) < 0.002) {
				col = gold_mid;
			}

			// Fringe tassels
			if (p.y < 0.025) {
				float tassel = sin(p.x * 200.0);
				if (tassel > 0.3) col = gold;
				else col = carpet_dark;
			}

			// Carpet shadow at edges (dithered)
			float shadow = smoothstep(carpet_edge - 0.015, carpet_edge, carpet_d);
			col *= 1.0 - shadow * 0.3;
		}
	}

	// ══════════════════════════════════════════════
	// LAYER 2: Ceiling
	// ══════════════════════════════════════════════
	float ceiling_y = 0.88;
	if (p.y > ceiling_y) {
		// Vaulted ceiling — GG detail
		col = stone_dark * 0.6;
		// Surface texture
		col += vec3(noise(p * 60.0) * 0.02);

		// Gothic ribbed vaulting
		for (int i = 0; i < 5; i++) {
			float fi = float(i);
			float arch_x = 0.1 + fi * 0.2;
			float arch_curve = ceiling_y + (1.0 - pow(abs(p.x - arch_x) * 3.5, 1.5)) * 0.08;
			float arch_d = abs(p.y - arch_curve);
			if (arch_d < 0.006 && abs(p.x - arch_x) < 0.14) {
				// Rib with highlight and shadow
				col = stone_mid;
				if (arch_d < 0.002) col = stone_highlight; // top highlight
				if (p.y < arch_curve - 0.003) col = stone_dark; // bottom shadow
			}
		}
		// Cross ribs (diagonal)
		float diag1 = abs((p.x - 0.5) * 0.3 - (p.y - ceiling_y));
		float diag2 = abs((0.5 - p.x) * 0.3 - (p.y - ceiling_y));
		if (diag1 < 0.004 || diag2 < 0.004) {
			col = stone_mid * 0.9;
		}

		// Cobwebs (more detailed strands)
		if ((p.x < 0.1 || p.x > 0.9) && p.y > 0.91) {
			float web = noise(p * 120.0);
			float web2 = noise(p * 60.0 + 50.0);
			if (web > 0.6 || (web2 > 0.7 && web > 0.4)) {
				col = mix(col, vec3(0.22, 0.22, 0.24), 0.35);
			}
			// Spider (rare)
			if (abs(p.x - 0.05) < 0.004 && abs(p.y - 0.93) < 0.004) {
				col = vec3(0.05, 0.03, 0.03);
			}
		}
	}

	// ══════════════════════════════════════════════
	// LAYER 3: Gothic windows with moonlight
	// ══════════════════════════════════════════════
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		float wx = 0.2 + fi * 0.3; // three windows
		float wy = 0.55;
		float ww = 0.06;
		float wh = 0.2;

		// Gothic arch shape
		float arch_top = wy + wh;
		float arch_r = ww;
		bool in_rect = abs(p.x - wx) < ww && p.y > wy && p.y < arch_top;
		bool in_arch = length(vec2(p.x - wx, max(0.0, p.y - arch_top))) < arch_r && p.y >= arch_top;

		if (in_rect || in_arch) {
			// Window frame (stone border)
			float border = 0.008;
			float inner_w = ww - border;
			float inner_top = arch_top - border;
			bool in_inner_rect = abs(p.x - wx) < inner_w && p.y > wy + border && p.y < inner_top;
			bool in_inner_arch = length(vec2(p.x - wx, max(0.0, p.y - inner_top))) < (arch_r - border) && p.y >= inner_top;

			if (in_inner_rect || in_inner_arch) {
				// Stained glass — GG detail: more panels, richer colors, inner glow
				float panel_x = floor((p.x - wx + ww) / (ww * 0.33));
				float panel_y = floor((p.y - wy) / (wh * 0.167));
				float panel = hash(vec2(panel_x, panel_y) + fi * 10.0);

				vec3 glass;
				if (panel < 0.15) glass = vec3(0.08, 0.08, 0.45);       // deep blue
				else if (panel < 0.28) glass = vec3(0.12, 0.12, 0.55);  // lighter blue
				else if (panel < 0.4) glass = vec3(0.45, 0.04, 0.08);   // crimson
				else if (panel < 0.5) glass = vec3(0.55, 0.08, 0.12);   // lighter red
				else if (panel < 0.6) glass = vec3(0.08, 0.35, 0.08);   // emerald
				else if (panel < 0.7) glass = vec3(0.12, 0.45, 0.15);   // light green
				else if (panel < 0.8) glass = vec3(0.4, 0.3, 0.06);     // amber
				else if (panel < 0.9) glass = vec3(0.5, 0.38, 0.1);     // gold
				else glass = vec3(0.35, 0.1, 0.4);                       // purple

				// Inner glow variation (lighter at center of each panel)
				float pcx = fract((p.x - wx + ww) / (ww * 0.33));
				float pcy = fract((p.y - wy) / (wh * 0.167));
				float panel_center = 1.0 - length(vec2(pcx - 0.5, pcy - 0.5)) * 1.5;
				glass *= 0.8 + clamp(panel_center, 0.0, 1.0) * 0.4;

				// Moonlight streaming through
				float moonlight = 0.5 + 0.3 * sin(t * 0.3 + fi);
				moonlight *= 0.7 + audio_presence * 0.3;
				glass *= (0.7 + moonlight * 0.5);

				// Lead came lines (thinner at GG res)
				float lead_x = abs(fract((p.x - wx + ww) / (ww * 0.33)) - 0.5);
				float lead_y = abs(fract((p.y - wy) / (wh * 0.167)) - 0.5);
				if (lead_x > 0.44 || lead_y > 0.44) {
					glass = vec3(0.04, 0.04, 0.05);
				}

				// Center cross (thinner)
				if (abs(p.x - wx) < 0.002 || abs(p.y - (wy + wh * 0.5)) < 0.002) {
					glass = vec3(0.04, 0.04, 0.05);
				}

				// Rose window circle in arch area
				if (in_inner_arch) {
					float rose_d = length(vec2(p.x - wx, p.y - arch_top));
					float rose_ang = atan(p.x - wx, p.y - arch_top);
					if (abs(rose_d - 0.025) < 0.003) glass = vec3(0.04, 0.04, 0.05);
					// Radial spokes
					if (mod(rose_ang * 3.0, 3.14159) < 0.15 && rose_d < 0.03) {
						glass = vec3(0.04, 0.04, 0.05);
					}
				}

				col = glass;
			} else {
				col = stone_light; // frame
			}
		}

		// Angled light shafts from windows (GG style volumetric)
		{
			float shaft_angle = 0.15; // slight angle
			float shaft_top = wy;
			float shaft_bottom = floor_y - 0.01;
			float shaft_x_at_floor = wx + (shaft_top - shaft_bottom) * shaft_angle;
			// Interpolate beam position based on y
			float beam_y_frac = clamp((shaft_top - p.y) / (shaft_top - shaft_bottom), 0.0, 1.0);
			float beam_cx = wx + beam_y_frac * (shaft_top - shaft_bottom) * shaft_angle;
			float beam_w = ww * (1.0 + beam_y_frac * 0.8); // widens toward floor

			float beam_d = abs(p.x - beam_cx);
			if (beam_d < beam_w && p.y < shaft_top && p.y > shaft_bottom) {
				float beam_strength = (1.0 - beam_d / beam_w) * 0.1;
				beam_strength *= beam_y_frac * 0.6 + 0.4; // stronger near floor
				beam_strength *= 0.7 + 0.3 * sin(t * 0.3 + fi);
				// Colored by window
				vec3 beam_color;
				if (fi < 1.0) beam_color = vec3(0.08, 0.08, 0.25);
				else if (fi < 2.0) beam_color = vec3(0.25, 0.04, 0.06);
				else beam_color = vec3(0.06, 0.18, 0.06);
				// Dust motes in beam
				float dust2 = noise(vec2(p.x * 80.0 + t * 2.0, p.y * 40.0 - t * 1.5));
				beam_strength *= 0.7 + dust2 * 0.6;
				col += beam_color * beam_strength;
			}
		}
	}

	// ══════════════════════════════════════════════
	// LAYER 4: Wall-mounted torches / candle sconces
	// ══════════════════════════════════════════════
	for (int i = 0; i < 6; i++) {
		float fi = float(i);
		float tx = 0.08 + fi * 0.17;
		float ty = 0.52;

		// Iron bracket
		if (abs(p.x - tx) < 0.005 && p.y > ty - 0.03 && p.y < ty) {
			col = vec3(0.15, 0.13, 0.12);
		}
		// Bracket arm
		if (abs(p.y - ty) < 0.003 && p.x > tx - 0.005 && p.x < tx + 0.012) {
			col = vec3(0.15, 0.13, 0.12);
		}

		// Candle body (detailed wax with drips)
		float candle_x = tx + 0.01;
		float candle_w = 0.003;
		float candle_top = ty + 0.022;
		if (abs(p.x - candle_x) < candle_w && p.y > ty && p.y < candle_top) {
			float cx_frac = (p.x - candle_x + candle_w) / (candle_w * 2.0);
			col = mix(vec3(0.55, 0.5, 0.38), vec3(0.75, 0.72, 0.58), cx_frac); // cylindrical shading
			// Wick at top
			if (p.y > candle_top - 0.003 && abs(p.x - candle_x) < 0.001) col = vec3(0.1, 0.08, 0.05);
		}
		// Wax drips running down
		for (int d2 = 0; d2 < 2; d2++) {
			float drip_x = candle_x + (hash1(fi * 30.0 + float(d2) * 50.0) - 0.5) * candle_w * 1.5;
			float drip_top = candle_top - hash1(fi * 20.0 + float(d2)) * 0.008;
			float drip_len = 0.005 + hash1(fi * 70.0 + float(d2)) * 0.01;
			if (abs(p.x - drip_x) < 0.0015 && p.y < drip_top && p.y > drip_top - drip_len) {
				col = vec3(0.72, 0.68, 0.52);
			}
			// Drip blob at bottom
			if (length(vec2(p.x - drip_x, p.y - (drip_top - drip_len))) < 0.002) {
				col = vec3(0.7, 0.66, 0.5);
			}
		}

		// Flame (multi-layer, smooth gradient)
		float flame_y = candle_top;
		float flame_h = 0.018 + 0.008 * sin(t * 4.0 + fi * 3.0) + beat_kick * 0.005;
		float flame_sway = sin(t * 3.0 + fi * 5.0) * 0.003;
		float flame_sway2 = sin(t * 7.0 + fi * 2.0) * 0.001; // secondary flicker
		float flame_rel = (p.y - flame_y) / flame_h;
		if (flame_rel > -0.1 && flame_rel < 1.0) {
			float taper = 1.0 - flame_rel * flame_rel;
			float fw = 0.005 * taper;
			float fdx = abs(p.x - candle_x - flame_sway - flame_sway2 * flame_rel);
			if (fdx < fw) {
				float f = 1.0 - flame_rel;
				float core = 1.0 - fdx / fw; // brighter at center
				// 5-color flame gradient
				vec3 fc;
				if (f > 0.8) fc = vec3(1.0, 0.95, 0.8);        // white-hot tip
				else if (f > 0.6) fc = vec3(1.0, 0.85, 0.3);   // bright yellow
				else if (f > 0.4) fc = vec3(1.0, 0.55, 0.08);  // orange
				else if (f > 0.2) fc = vec3(0.85, 0.25, 0.02); // dark orange
				else fc = vec3(0.5, 0.1, 0.02);                 // red base
				// Blue inner core
				if (core > 0.7 && flame_rel < 0.3) {
					fc = mix(fc, vec3(0.3, 0.4, 0.9), 0.3);
				}
				col = fc * (0.7 + core * 0.3);
			}
			// Outer glow (wider, faint)
			if (fdx < fw * 2.0 && fdx > fw) {
				float glow_str = (1.0 - (fdx - fw) / fw) * 0.15;
				col += vec3(0.4, 0.15, 0.02) * glow_str * taper;
			}
		}

		// Light pool on wall (SNES — dithered falloff, more radius)
		float light_d = length(vec2((p.x - candle_x) * 1.3, p.y - flame_y));
		if (light_d < 0.12) {
			float light_str = (1.0 - light_d / 0.12) * 0.15;
			light_str = dithered_light(light_str, cell);
			light_str *= 0.7 + 0.3 * sin(t * 3.5 + fi * 4.0);
			light_str *= 0.8 + audio_energy * 0.2;
			// Warmer light with color gradient (orange center, red edges)
			vec3 light_col = mix(vec3(0.3, 0.1, 0.02), vec3(0.5, 0.3, 0.08), 1.0 - light_d / 0.12);
			col += light_col * light_str;
		}
	}

	// ══════════════════════════════════════════════
	// LAYER 5: Swinging chandelier
	// ══════════════════════════════════════════════
	{
		float chandelier_cx = 0.5;
		float chain_top = ceiling_y;
		float chain_bottom = 0.72;
		// Swing
		float swing = sin(t * 0.7) * 0.03;
		swing += audio_bass * 0.01;
		float cx = chandelier_cx + swing;

		// Chain
		if (abs(p.x - cx) < 0.003 && p.y > chain_bottom && p.y < chain_top) {
			// Chain links
			if (mod(cell.y, 2.0) < 1.0) col = vec3(0.3, 0.25, 0.15);
			else col = vec3(0.2, 0.17, 0.1);
		}

		// Ring
		float ring_y = chain_bottom;
		float ring_r = 0.04;
		float ring_d = length(vec2(p.x - cx, (p.y - ring_y) * 2.5));
		if (ring_d > ring_r - 0.005 && ring_d < ring_r + 0.005 && p.y < ring_y + 0.01) {
			col = gold;
		}

		// Candles on chandelier (5 candles)
		for (int j = 0; j < 5; j++) {
			float fj = float(j);
			float ang = (fj / 5.0) * 3.14159 + 0.3;
			float candle_cx = cx + cos(ang) * ring_r;
			float candle_cy = ring_y - 0.005;

			// Candle
			if (abs(p.x - candle_cx) < 0.003 && p.y > candle_cy && p.y < candle_cy + 0.018) {
				col = vec3(0.7, 0.65, 0.5);
			}

			// Flame
			float cf_y = candle_cy + 0.018;
			float cf_h = 0.012 + 0.005 * sin(t * 5.0 + fj * 2.0);
			float cf_sway = sin(t * 4.0 + fj * 3.0) * 0.002;
			float cf_rel = (p.y - cf_y) / cf_h;
			if (cf_rel > 0.0 && cf_rel < 1.0) {
				float cfw = 0.004 * (1.0 - cf_rel);
				if (abs(p.x - candle_cx - cf_sway) < cfw) {
					float brightness = 1.0 - cf_rel;
					col = mix(vec3(0.9, 0.3, 0.0), vec3(1.0, 0.9, 0.3), brightness);
				}
			}
		}

		// Chandelier glow pool on floor
		float cg_d = abs(p.x - cx);
		if (p.y < floor_y + 0.03 && cg_d < 0.15) {
			float glow_s = (1.0 - cg_d / 0.15) * 0.08;
			glow_s *= 0.8 + 0.2 * sin(t * 0.7);
			col += vec3(0.35, 0.2, 0.05) * glow_s;
		}
	}

	// ══════════════════════════════════════════════
	// LAYER 6: Suits of armor (GG detail)
	// ══════════════════════════════════════════════
	for (int i = 0; i < 2; i++) {
		float fi = float(i);
		float ax = (fi < 0.5) ? 0.08 : 0.92;
		float mirror = (fi < 0.5) ? 1.0 : -1.0; // flip for right side
		float ay = floor_y;
		vec3 metal_hi = vec3(0.45, 0.44, 0.5);
		vec3 metal_mid = vec3(0.3, 0.29, 0.34);
		vec3 metal_lo = vec3(0.15, 0.14, 0.18);
		vec3 metal_shadow = vec3(0.08, 0.07, 0.1);

		// Pedestal (stone block with beveled edge)
		if (abs(p.x - ax) < 0.022 && p.y > ay && p.y < ay + 0.012) {
			col = stone_light;
			if (p.y > ay + 0.009) col = stone_highlight; // top bevel
			if (abs(p.x - ax) > 0.019) col = stone_mid; // side bevel
		}

		float base = ay + 0.012;
		float dx = p.x - ax;

		// Sabatons (feet) — pointed
		if (p.y > base && p.y < base + 0.012) {
			float foot_w = 0.012 + (p.y - base) * 0.3;
			if (abs(dx) < foot_w) {
				col = metal_mid;
				if (abs(dx) < foot_w * 0.5) col = metal_hi; // center highlight
				if (p.y < base + 0.004) col = metal_lo; // sole
			}
		}

		// Greaves (shin armor) — tapered
		float shin_b = base + 0.012;
		float shin_t = shin_b + 0.03;
		if (p.y > shin_b && p.y < shin_t) {
			float shin_w = 0.008 + (p.y - shin_b) * 0.1;
			if (abs(dx) < shin_w) {
				float shade = (dx * mirror + shin_w) / (shin_w * 2.0); // light from left
				col = mix(metal_shadow, metal_hi, shade);
				// Knee cop (bulge at top)
				if (p.y > shin_t - 0.006) {
					float knee_w = shin_w + 0.003;
					if (abs(dx) < knee_w) col = mix(metal_lo, metal_hi, shade * 1.2);
				}
				// Shin ridge
				if (abs(dx) < 0.002) col = metal_hi;
			}
		}

		// Tassets / waist — wider
		float waist_b = shin_t;
		float waist_t = waist_b + 0.015;
		if (p.y > waist_b && p.y < waist_t) {
			float waist_w = 0.013;
			if (abs(dx) < waist_w) {
				float shade = (dx * mirror + waist_w) / (waist_w * 2.0);
				col = mix(metal_shadow, metal_mid, shade);
				// Belt
				if (abs(p.y - waist_b - 0.004) < 0.002) col = gold_dark;
				// Belt buckle
				if (abs(dx) < 0.004 && abs(p.y - waist_b - 0.004) < 0.003) col = gold;
			}
		}

		// Cuirass (chest plate) — shaped
		float chest_b = waist_t;
		float chest_t = chest_b + 0.035;
		if (p.y > chest_b && p.y < chest_t) {
			float chest_frac = (p.y - chest_b) / (chest_t - chest_b);
			float chest_w = 0.014 - abs(chest_frac - 0.5) * 0.008; // narrower at top and bottom
			if (abs(dx) < chest_w) {
				float shade = (dx * mirror + chest_w) / (chest_w * 2.0);
				col = mix(metal_shadow, metal_hi, shade * 0.8 + 0.1);
				// Chest ridge line
				if (abs(dx) < 0.001) col = metal_hi;
				// Pectoral line
				float pec_y = chest_b + 0.02;
				if (abs(p.y - pec_y) < 0.001 && abs(dx) < chest_w * 0.8) col = metal_lo;
				// Crest emblem
				if (abs(dx) < 0.005 && abs(p.y - (chest_b + 0.018)) < 0.005) {
					float emblem_d = length(vec2(dx * 2.0, p.y - chest_b - 0.018));
					if (emblem_d < 0.006) col = gold_mid;
					if (emblem_d < 0.003) col = gold;
				}
			}
		}

		// Pauldrons (shoulder plates) — rounded
		float should_y = chest_t - 0.01;
		for (int s = -1; s <= 1; s += 2) {
			float sx = ax + float(s) * 0.016;
			float sd = length(vec2((p.x - sx) * 1.5, p.y - should_y));
			if (sd < 0.012 && p.y > should_y - 0.005) {
				float shade = (p.x - sx) * mirror * 40.0 + 0.5;
				col = mix(metal_shadow, metal_hi, clamp(shade, 0.0, 1.0));
				// Edge rim
				if (sd > 0.009) col = metal_lo;
			}
		}

		// Gorget (neck)
		float neck_b = chest_t;
		if (abs(dx) < 0.006 && p.y > neck_b && p.y < neck_b + 0.008) {
			col = metal_mid;
			if (abs(dx) < 0.003) col = metal_shadow; // neck gap
		}

		// Helmet — great helm shape
		float helm_b = neck_b + 0.005;
		float helm_t = helm_b + 0.025;
		if (p.y > helm_b && p.y < helm_t) {
			float helm_frac = (p.y - helm_b) / (helm_t - helm_b);
			float helm_w = 0.01 + sin(helm_frac * 3.14159) * 0.004;
			if (abs(dx) < helm_w) {
				float shade = (dx * mirror + helm_w) / (helm_w * 2.0);
				col = mix(metal_shadow, metal_hi, shade);
				// Visor slit
				if (abs(p.y - (helm_b + 0.012)) < 0.002 && abs(dx) < helm_w * 0.8) {
					col = vec3(0.02, 0.01, 0.01);
					// Eye glow
					float eye_glow = 0.3 + 0.7 * sin(t * 1.5 + fi * 3.14);
					eye_glow *= 0.5 + audio_bass * 0.5;
					if (abs(dx - 0.003 * mirror) < 0.002 || abs(dx + 0.003 * mirror) < 0.002) {
						col = vec3(0.8, 0.1, 0.05) * eye_glow;
					}
				}
				// Breathing holes
				if (p.y < helm_b + 0.008 && abs(dx) < 0.005) {
					if (mod(cell.x + cell.y, 3.0) < 1.0) col = metal_shadow;
				}
				// Top crest ridge
				if (abs(dx) < 0.001 && helm_frac > 0.6) col = metal_hi;
			}
			// Plume
			if (abs(dx) < 0.003 && p.y > helm_t && p.y < helm_t + 0.018) {
				float plume_frac = (p.y - helm_t) / 0.018;
				float sway = sin(t * 2.0 + fi * 3.0) * 0.003 * plume_frac;
				if (abs(p.x - ax - sway) < 0.003 * (1.0 - plume_frac * 0.5)) {
					col = mix(vec3(0.5, 0.05, 0.05), vec3(0.7, 0.15, 0.08), plume_frac);
				}
			}
		}

		// Halberd
		float wpn_x = ax + mirror * 0.022;
		if (abs(p.x - wpn_x) < 0.0015 && p.y > base && p.y < helm_t + 0.03) {
			col = vec3(0.2, 0.15, 0.08); // wooden pole
			// Wood grain
			if (mod(cell.y, 3.0) < 1.0) col *= 1.1;
		}
		// Axe head
		float axe_y = helm_t + 0.02;
		if (p.y > axe_y - 0.01 && p.y < axe_y + 0.01) {
			float axe_d = abs(p.x - wpn_x - mirror * 0.006);
			if (axe_d < 0.008 * (1.0 - abs(p.y - axe_y) / 0.01)) {
				col = vec3(0.4, 0.4, 0.45);
				if (axe_d < 0.002) col = vec3(0.6, 0.6, 0.65); // edge gleam
			}
		}
		// Spike on top
		float spike_base = axe_y + 0.005;
		if (abs(p.x - wpn_x) < 0.002 * (1.0 - (p.y - spike_base) / 0.012) && p.y > spike_base && p.y < spike_base + 0.012) {
			col = vec3(0.45, 0.45, 0.5);
		}
	}

	// ══════════════════════════════════════════════
	// LAYER 7: Bats (bigger, 3-pixel wings)
	// ══════════════════════════════════════════════
	for (int i = 0; i < 8; i++) {
		float fi = float(i);
		float s = hash(vec2(fi * 67.3, fi * 23.7));

		float bat_speed = 0.4 + s * 0.6;
		float orbit_r = 0.06 + s * 0.1;
		float bat_cx = 0.15 + s * 0.7;
		float bat_cy = 0.72 + hash(vec2(fi, 99.0)) * 0.12;
		float bat_x = bat_cx + cos(t * bat_speed + fi * 2.0) * orbit_r;
		float bat_y = bat_cy + sin(t * bat_speed * 1.3 + fi * 2.0) * orbit_r * 0.3;

		bat_x += beat_snare * (s - 0.5) * 0.15;
		bat_y += beat_snare * (hash(vec2(fi, 77.0)) - 0.5) * 0.08;

		float wing_phase = sin(t * 8.0 + fi * 3.0);
		float wing_up = abs(wing_phase);
		vec3 bat_col = vec3(0.06, 0.02, 0.08);

		// Body (2 pixels wide)
		for (int bx2 = -1; bx2 <= 0; bx2++) {
			vec2 bc = floor(vec2(bat_x + float(bx2)/R, bat_y) * R);
			if (bc.x == cell.x && bc.y == cell.y) col = bat_col;
		}
		// Ears
		vec2 ear1 = floor(vec2(bat_x - 0.5/R, bat_y + 1.0/R) * R);
		vec2 ear2 = floor(vec2(bat_x + 0.5/R, bat_y + 1.0/R) * R);
		if (ear1.x == cell.x && ear1.y == cell.y) col = bat_col;
		if (ear2.x == cell.x && ear2.y == cell.y) col = bat_col;
		// Eyes (red dots)
		vec2 eye1 = floor(vec2(bat_x - 0.5/R, bat_y) * R);
		if (eye1.x == cell.x && eye1.y == cell.y) col = vec3(0.5, 0.05, 0.05);
		// Wings — 3 pixels each, angle changes with flap
		for (int w = 1; w <= 3; w++) {
			float fw = float(w);
			float wy2 = wing_up * fw * 0.5 / R;
			vec2 lw = floor(vec2(bat_x - fw * 1.2/R, bat_y + wy2) * R);
			vec2 rw = floor(vec2(bat_x + fw * 1.2/R, bat_y + wy2) * R);
			if (lw.x == cell.x && lw.y == cell.y) col = bat_col * (1.0 - fw * 0.15);
			if (rw.x == cell.x && rw.y == cell.y) col = bat_col * (1.0 - fw * 0.15);
		}
	}

	// ══════════════════════════════════════════════
	// LAYER 8: Dust motes in light beams
	// ══════════════════════════════════════════════
	for (int i = 0; i < 15; i++) {
		float fi = float(i);
		float s = hash(vec2(fi * 53.1, fi * 89.3));
		// Drift in window light beams
		float dx = 0.2 + hash(vec2(fi, 11.0)) * 0.6;
		float dy = fract(s * 3.0 + t * (0.01 + s * 0.01));
		dy = dy * 0.5 + 0.3; // keep in middle height
		float drift = sin(t * 0.5 + fi * 2.0) * 0.01;

		vec2 dcell = floor(vec2(dx + drift, dy) * R);
		if (dcell.x == cell.x && dcell.y == cell.y) {
			float brightness = 0.2 + 0.3 * sin(t + fi * 4.0);
			brightness *= 0.5 + audio_treble * 0.5;
			col = mix(col, vec3(0.5, 0.45, 0.35), brightness * 0.4);
		}
	}

	// ══════════════════════════════════════════════
	// LAYER 9: Blood drips on walls (subtle)
	// ══════════════════════════════════════════════
	for (int i = 0; i < 5; i++) {
		float fi = float(i);
		float bx = hash1(fi * 131.0);
		float by_top = 0.4 + hash1(fi * 79.0) * 0.2;
		float drip_len = 0.03 + hash1(fi * 41.0) * 0.05;
		// Thin drip
		if (abs(p.x - bx) < 0.003 && p.y > by_top - drip_len && p.y < by_top) {
			float drip_fade = (p.y - (by_top - drip_len)) / drip_len;
			col = mix(col, vec3(0.3, 0.01, 0.01), 0.4 * drip_fade);
		}
		// Droplet at bottom
		if (abs(p.x - bx) < 0.004 && abs(p.y - (by_top - drip_len)) < 0.004) {
			col = vec3(0.35, 0.02, 0.02);
		}
	}

	// ══════════════════════════════════════════════
	// LAYER 10: Candelabra / table
	// ══════════════════════════════════════════════
	{
		float table_x = 0.7;
		float table_y = floor_y;
		float table_h = 0.04;
		float table_w = 0.04;

		// Table legs
		if ((abs(p.x - (table_x - table_w + 0.005)) < 0.003 || abs(p.x - (table_x + table_w - 0.005)) < 0.003)
			&& p.y > table_y && p.y < table_y + table_h) {
			col = vec3(0.2, 0.1, 0.04);
		}
		// Table top
		if (abs(p.y - (table_y + table_h)) < 0.004 && abs(p.x - table_x) < table_w) {
			col = vec3(0.25, 0.12, 0.05);
		}

		// Candelabra on table
		float cb_y = table_y + table_h + 0.004;
		// Base
		if (abs(p.x - table_x) < 0.008 && abs(p.y - cb_y) < 0.004) {
			col = gold;
		}
		// Center post
		if (abs(p.x - table_x) < 0.003 && p.y > cb_y && p.y < cb_y + 0.04) {
			col = gold_dark;
		}
		// Three candles
		for (int j = -1; j <= 1; j++) {
			float fj = float(j);
			float ccx = table_x + fj * 0.012;
			float ccy = cb_y + 0.04;
			// Arm
			if (j != 0) {
				if (abs(p.y - (ccy - 0.005)) < 0.002 && ((fj < 0.0 && p.x > ccx && p.x < table_x) || (fj > 0.0 && p.x < ccx && p.x > table_x))) {
					col = gold_dark;
				}
			}
			// Candle
			if (abs(p.x - ccx) < 0.003 && p.y > ccy && p.y < ccy + 0.015) {
				col = vec3(0.7, 0.65, 0.5);
			}
			// Flame
			float fl_y = ccy + 0.015;
			float fl_h = 0.01 + 0.004 * sin(t * 5.0 + fj * 2.0);
			float fl_sw = sin(t * 3.5 + fj * 4.0) * 0.002;
			float fl_rel = (p.y - fl_y) / fl_h;
			if (fl_rel > 0.0 && fl_rel < 1.0 && abs(p.x - ccx - fl_sw) < 0.003 * (1.0 - fl_rel)) {
				col = mix(vec3(0.9, 0.25, 0.0), vec3(1.0, 0.85, 0.2), 1.0 - fl_rel);
			}
		}
	}

	// ══════════════════════════════════════════════
	// LAYER 11: Skull on wall (GG detail)
	// ══════════════════════════════════════════════
	{
		float sk_x = 0.35;
		float sk_y = 0.42;
		vec3 bone_hi = vec3(0.7, 0.68, 0.6);
		vec3 bone_mid = vec3(0.55, 0.52, 0.45);
		vec3 bone_lo = vec3(0.35, 0.32, 0.28);
		vec3 bone_shadow = vec3(0.2, 0.18, 0.15);

		// Cranium (wider at top, narrower at jaw)
		float sk_rel_y = (p.y - sk_y) / 0.02;
		float skull_w = 0.013 * (1.0 - clamp(sk_rel_y * sk_rel_y * 0.15, 0.0, 0.4));
		// Jaw narrowing
		if (sk_rel_y < -0.3) skull_w *= 0.7 + (sk_rel_y + 0.3) * 0.5;

		float sk_dx = abs(p.x - sk_x);
		if (sk_dx < skull_w && abs(sk_rel_y) < 1.0) {
			float shade = (p.x - sk_x + skull_w) / (skull_w * 2.0);
			col = mix(bone_shadow, bone_hi, shade * 0.7 + 0.15);
			// Brow ridge
			if (abs(sk_rel_y - 0.35) < 0.08) {
				col = mix(col, bone_hi, 0.2);
				if (sk_rel_y > 0.35) col = mix(col, bone_lo, 0.3); // shadow under brow
			}
			// Cheekbones
			if (abs(sk_rel_y + 0.1) < 0.1 && sk_dx > skull_w * 0.5) {
				col = mix(col, bone_hi, 0.15);
			}
			// Temple indentations
			if (abs(sk_rel_y - 0.15) < 0.1 && sk_dx > skull_w * 0.6) {
				col = mix(col, bone_lo, 0.2);
			}

			// Eye sockets (teardrop shaped)
			for (int e = -1; e <= 1; e += 2) {
				float ex = sk_x + float(e) * 0.005;
				float ey = sk_y + 0.005;
				float eye_dx = (p.x - ex) / 0.004;
				float eye_dy = (p.y - ey) / 0.005;
				float eye_d = eye_dx * eye_dx + eye_dy * eye_dy;
				if (eye_d < 1.0) {
					float eye_glow = 0.3 + 0.5 * sin(t * 2.0 + float(e));
					eye_glow *= 0.5 + audio_mid * 0.5;
					col = vec3(0.5, 0.08, 0.03) * eye_glow;
					// Inner glow center
					if (eye_d < 0.3) col = vec3(0.7, 0.15, 0.05) * eye_glow;
					// Socket rim (dark bone)
					if (eye_d > 0.7) col = bone_shadow;
				}
			}

			// Nasal cavity (inverted triangle)
			float nose_w = 0.003 * (1.0 - clamp((p.y - sk_y) / 0.008, 0.0, 1.0));
			if (sk_dx < nose_w && p.y < sk_y + 0.002 && p.y > sk_y - 0.006) {
				col = vec3(0.08, 0.06, 0.05);
			}

			// Maxilla / upper jaw
			if (sk_rel_y < -0.4 && sk_rel_y > -0.6) {
				col = mix(col, bone_lo, 0.15);
			}

			// Teeth (individual)
			if (p.y < sk_y - 0.012 && p.y > sk_y - 0.018 && sk_dx < 0.009) {
				float tooth_idx = floor((p.x - sk_x + 0.009) / 0.003);
				if (mod(tooth_idx, 2.0) < 1.0) {
					col = bone_hi;
					// Canine fangs (slightly longer)
					if (abs(tooth_idx - 1.0) < 0.5 || abs(tooth_idx - 4.0) < 0.5) {
						if (p.y < sk_y - 0.012 && p.y > sk_y - 0.02) col = bone_hi;
					}
				} else {
					col = vec3(0.08, 0.06, 0.05); // gap between teeth
				}
			}

			// Suture lines on cranium
			if (abs(sk_dx) < 0.001 && sk_rel_y > 0.3) col = mix(col, bone_lo, 0.3);
		}
	}

	// ══════════════════════════════════════════════
	// LAYER 12: Dracula's portrait (GG detail)
	// ══════════════════════════════════════════════
	{
		float pt_x = 0.65;
		float pt_y = 0.55;
		float pt_w = 0.04;
		float pt_h = 0.07;

		// Ornate gold frame with carved detail
		float frame_outer = 0.008;
		float frame_inner = 0.003;
		bool in_outer = abs(p.x - pt_x) < pt_w + frame_outer && abs(p.y - pt_y) < pt_h + frame_outer;
		bool in_canvas = abs(p.x - pt_x) < pt_w && abs(p.y - pt_y) < pt_h;

		if (in_outer) {
			if (!in_canvas) {
				// Frame layers
				float fd = max(abs(p.x - pt_x) - pt_w, abs(p.y - pt_y) - pt_h);
				if (fd < 0.002) col = gold_shadow; // inner shadow
				else if (fd < 0.004) col = gold;
				else if (fd < 0.006) col = gold_mid;
				else col = gold_dark;
				// Corner rosettes
				for (int c = 0; c < 4; c++) {
					float cx2 = pt_x + ((c % 2 == 0) ? -1.0 : 1.0) * (pt_w + 0.004);
					float cy2 = pt_y + ((c < 2) ? -1.0 : 1.0) * (pt_h + 0.004);
					if (length(vec2(p.x - cx2, p.y - cy2)) < 0.004) col = gold;
				}
			} else {
				// Canvas — dark moody background
				col = vec3(0.1, 0.04, 0.06);
				float canvas_noise = noise(p * 200.0) * 0.03;
				col += vec3(canvas_noise, canvas_noise * 0.5, canvas_noise * 0.3);

				float rel_x = (p.x - pt_x) / pt_w;
				float rel_y = (p.y - pt_y) / pt_h;

				// Cape and shoulders (lower portion)
				if (rel_y < -0.1) {
					float cape_w = 0.7 + (rel_y + 0.1) * 0.5;
					if (abs(rel_x) < cape_w) {
						// Cape with folds
						float fold = sin(rel_x * 15.0) * 0.05;
						col = vec3(0.25 + fold, 0.02, 0.04 + fold * 0.5);
						// Cape lining (inner)
						if (abs(rel_x) < cape_w * 0.3 && rel_y > -0.4) {
							col = vec3(0.15, 0.02, 0.2); // purple inner
						}
						// High collar
						if (rel_y > -0.25 && rel_y < -0.1) {
							if (abs(rel_x) < 0.5) {
								float collar_shade = abs(rel_x) / 0.5;
								col = mix(vec3(0.65, 0.63, 0.58), vec3(0.4, 0.38, 0.35), collar_shade);
							}
						}
					}
				}

				// Face (upper-middle)
				float face_cx = 0.0; // centered in frame
				float face_cy = 0.25;
				float face_w = 0.35;
				float face_h = 0.45;
				float face_dx = (rel_x - face_cx) / face_w;
				float face_dy = (rel_y - face_cy) / face_h;
				float face_d = face_dx * face_dx + face_dy * face_dy;

				if (face_d < 1.0) {
					// Skin with shading
					float face_shade = face_dx * 0.3 + 0.5;
					vec3 skin_hi = vec3(0.6, 0.5, 0.45);
					vec3 skin_lo = vec3(0.35, 0.25, 0.22);
					col = mix(skin_lo, skin_hi, face_shade);

					// Shadow under brow
					if (face_dy > 0.1 && face_dy < 0.25) col *= 0.85;

					// Widow's peak hair
					if (face_dy > 0.4) {
						col = vec3(0.04, 0.02, 0.05);
						// Highlight streaks
						if (abs(face_dx) < 0.3 && noise(vec2(rel_x * 50.0, rel_y * 20.0)) > 0.6) {
							col = vec3(0.08, 0.04, 0.1);
						}
					}
					// V-point of widow's peak
					float peak_w = (rel_y - face_cy - face_h * 0.3) * 2.0;
					if (peak_w > 0.0 && abs(face_dx) < peak_w * 0.4) {
						col = mix(skin_lo, skin_hi, face_shade);
					}

					// Eyes
					float eg2 = 0.5 + 0.5 * sin(t * 1.0);
					eg2 *= 0.6 + audio_bass * 0.4;
					for (int e = -1; e <= 1; e += 2) {
						float ex = float(e) * 0.35;
						float ey = 0.15;
						float ed = length(vec2((face_dx - ex) * 1.5, face_dy - ey));
						if (ed < 0.2) {
							col = vec3(0.02, 0.01, 0.01); // socket
							if (ed < 0.12) col = vec3(0.6, 0.08, 0.03) * eg2; // iris
							if (ed < 0.05) col = vec3(0.8, 0.15, 0.05) * eg2; // pupil glow
						}
					}

					// Nose
					if (abs(face_dx) < 0.08 && abs(face_dy + 0.05) < 0.12) {
						col = mix(col, skin_hi, 0.1); // nose bridge highlight
						// Nostrils
						if (face_dy < -0.1 && abs(face_dx) < 0.06) col *= 0.8;
					}

					// Mouth / cruel smile with fangs
					if (abs(face_dy + 0.3) < 0.06 && abs(face_dx) < 0.25) {
						float mouth_curve = -0.3 + abs(face_dx) * 0.15; // slight smile
						if (abs(face_dy - mouth_curve) < 0.03) {
							col = vec3(0.2, 0.02, 0.03); // dark lips
							// Fangs
							if (face_dy < mouth_curve && abs(abs(face_dx) - 0.12) < 0.04) {
								col = vec3(0.75, 0.72, 0.65);
							}
						}
					}

					// Cheekbone highlights
					if (abs(face_dy + 0.1) < 0.08 && abs(face_dx) > 0.25) {
						col = mix(col, skin_hi, 0.15);
					}
				}

				// Medallion on chest
				if (abs(rel_x) < 0.12 && abs(rel_y + 0.55) < 0.06) {
					float med_d = length(vec2(rel_x, rel_y + 0.55)) * 12.0;
					if (med_d < 1.0) {
						col = gold;
						if (med_d < 0.6) col = vec3(0.5, 0.05, 0.05); // ruby center
						if (med_d > 0.8) col = gold_dark; // rim
					}
				}
			}
		}
	}

	// ══════════════════════════════════════════════
	// LAYER 13: Distant hallway / doorway (depth)
	// ══════════════════════════════════════════════
	{
		// Dark archway at far end (center of wall)
		float door_x = 0.5;
		float door_w = 0.04;
		float door_h = 0.15;
		float door_bottom = floor_y;
		float door_top = door_bottom + door_h;
		float arch_r2 = door_w;
		bool in_door = abs(p.x - door_x) < door_w && p.y > door_bottom && p.y < door_top;
		bool in_door_arch = length(vec2(p.x - door_x, max(0.0, p.y - door_top))) < arch_r2 && p.y >= door_top;

		if (in_door || in_door_arch) {
			// Deep darkness with perspective lines
			col = vec3(0.02, 0.015, 0.025);
			// Distant hallway — smaller rectangle inside
			float inner_scale = 0.5;
			float inner_w = door_w * inner_scale;
			float inner_h = door_h * inner_scale;
			float inner_bottom = door_bottom + (door_h - inner_h) * 0.3;
			if (abs(p.x - door_x) < inner_w && p.y > inner_bottom && p.y < inner_bottom + inner_h) {
				col = vec3(0.03, 0.02, 0.035);
				// Distant torch glow
				float dist_glow = 0.3 + 0.3 * sin(t * 2.5);
				col += vec3(0.08, 0.03, 0.01) * dist_glow;
			}
			// Perspective lines converging
			float pline_d = abs(p.x - door_x);
			if (abs(pline_d - (door_w * (p.y - door_bottom) / door_h)) < 0.003) {
				col += vec3(0.02, 0.015, 0.02);
			}
		}
		// Stone arch frame
		if ((in_door || in_door_arch) == false) {
			float frame_w = door_w + 0.008;
			bool in_frame = abs(p.x - door_x) < frame_w && p.y > door_bottom && p.y < door_top + 0.01;
			bool in_frame_arch = length(vec2(p.x - door_x, max(0.0, p.y - door_top))) < (arch_r2 + 0.008) && p.y >= door_top;
			if ((in_frame || in_frame_arch) && abs(p.x - door_x) > door_w - 0.002) {
				col = stone_light;
			}
		}
	}

	// ══════════════════════════════════════════════
	// LAYER 14: Hanging chains from ceiling
	// ══════════════════════════════════════════════
	for (int i = 0; i < 4; i++) {
		float fi = float(i);
		float chain_x = 0.12 + fi * 0.25;
		float chain_len = 0.06 + hash1(fi * 83.0) * 0.08;
		float chain_sway = sin(t * 0.5 + fi * 2.0) * 0.005;
		// Chain links
		if (abs(p.x - chain_x - chain_sway) < 0.003) {
			if (p.y > ceiling_y - chain_len && p.y < ceiling_y) {
				if (mod(cell.y, 2.0) < 1.0) col = vec3(0.2, 0.18, 0.15);
				else col = vec3(0.15, 0.13, 0.1);
			}
		}
		// Shackle at end
		float sh_y = ceiling_y - chain_len;
		if (abs(p.x - chain_x - chain_sway) < 0.005 && abs(p.y - sh_y) < 0.004) {
			col = vec3(0.18, 0.15, 0.12);
		}
	}

	// ══════════════════════════════════════════════
	// LAYER 15: Pendulum (clock tower)
	// ══════════════════════════════════════════════
	{
		float pend_x = 0.85;
		float pend_pivot = ceiling_y - 0.02;
		float pend_len = 0.35;
		float pend_angle = sin(t * 0.8) * 0.25; // slow swing
		pend_angle += audio_sub_bass * 0.05;

		float pend_tip_x = pend_x + sin(pend_angle) * pend_len;
		float pend_tip_y = pend_pivot - cos(pend_angle) * pend_len;

		// Rod
		float rod_steps = 30.0;
		for (float s2 = 0.0; s2 < 1.0; s2 += 1.0/rod_steps) {
			float rx = mix(pend_x, pend_tip_x, s2);
			float ry = mix(pend_pivot, pend_tip_y, s2);
			vec2 rc = floor(vec2(rx, ry) * R);
			if (rc.x == cell.x && rc.y == cell.y) {
				col = vec3(0.2, 0.18, 0.14);
			}
		}
		// Bob (blade shape)
		float bob_w = 0.015;
		float bob_h = 0.025;
		if (abs(p.x - pend_tip_x) < bob_w && abs(p.y - pend_tip_y) < bob_h) {
			// Diamond/blade shape
			float blade_d = abs(p.x - pend_tip_x) / bob_w + abs(p.y - pend_tip_y) / bob_h;
			if (blade_d < 1.0) {
				col = vec3(0.4, 0.38, 0.35); // polished metal
				// Edge gleam
				if (blade_d > 0.7) col = vec3(0.55, 0.52, 0.48);
			}
		}
	}

	// ══════════════════════════════════════════════
	// LAYER 16: Rats scurrying on floor
	// ══════════════════════════════════════════════
	for (int i = 0; i < 4; i++) {
		float fi = float(i);
		float rat_speed = 0.08 + hash1(fi * 47.0) * 0.06;
		float rat_y_base = floor_y - 0.02 - hash1(fi * 31.0) * 0.04;
		float rat_cycle = mod(t * rat_speed + fi * 7.0, 3.0);
		float rat_x;
		int rat_dir_i;
		if (rat_cycle < 1.5) {
			rat_x = rat_cycle / 1.5; // run right
			rat_dir_i = 1;
		} else {
			rat_x = 1.0 - (rat_cycle - 1.5) / 1.5; // run left
			rat_dir_i = -1;
		}
		// Pause sometimes (stop at random spots)
		float pause_hash = hash(vec2(fi, floor(t * 0.5)));
		if (pause_hash > 0.85) rat_x = rat_x; // freeze position briefly

		float rat_dir = float(rat_dir_i);

		// Body (3 pixels)
		for (int rb = -1; rb <= 1; rb++) {
			vec2 rc2 = floor(vec2(rat_x + float(rb) * 0.8/R, rat_y_base) * R);
			if (rc2.x == cell.x && rc2.y == cell.y) {
				col = vec3(0.12, 0.1, 0.08);
			}
		}
		// Head
		vec2 rh = floor(vec2(rat_x + rat_dir * 1.5/R, rat_y_base + 0.5/R) * R);
		if (rh.x == cell.x && rh.y == cell.y) {
			col = vec3(0.14, 0.11, 0.09);
		}
		// Eyes
		vec2 re = floor(vec2(rat_x + rat_dir * 2.0/R, rat_y_base + 0.8/R) * R);
		if (re.x == cell.x && re.y == cell.y) {
			col = vec3(0.4, 0.1, 0.1); // beady red eyes
		}
		// Tail (wavy)
		float tail_wave = sin(t * 10.0 + fi * 5.0) * 0.5/R;
		vec2 rt = floor(vec2(rat_x - rat_dir * 2.0/R, rat_y_base + tail_wave) * R);
		vec2 rt2 = floor(vec2(rat_x - rat_dir * 3.0/R, rat_y_base + tail_wave * 1.5) * R);
		if (rt.x == cell.x && rt.y == cell.y) col = vec3(0.15, 0.1, 0.08);
		if (rt2.x == cell.x && rt2.y == cell.y) col = vec3(0.15, 0.1, 0.08);
	}

	// ══════════════════════════════════════════════
	// LAYER 17: Dripping water from ceiling
	// ══════════════════════════════════════════════
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		float drip_x = 0.15 + fi * 0.35;
		float drip_period = 3.0 + fi * 1.5;
		float drip_phase = mod(t, drip_period) / drip_period;

		if (drip_phase < 0.4) {
			// Droplet falling
			float drop_y = ceiling_y - drip_phase * (ceiling_y - floor_y) / 0.4;
			vec2 dc = floor(vec2(drip_x, drop_y) * R);
			if (dc.x == cell.x && dc.y == cell.y) {
				col = vec3(0.2, 0.25, 0.35);
			}
			// Streak above
			if (drip_phase > 0.05) {
				vec2 streak = floor(vec2(drip_x, drop_y + 1.0/R) * R);
				if (streak.x == cell.x && streak.y == cell.y) {
					col = mix(col, vec3(0.15, 0.2, 0.3), 0.3);
				}
			}
		} else if (drip_phase < 0.5) {
			// Splash on floor
			float splash_r = (drip_phase - 0.4) * 30.0;
			float splash_d = abs(p.x - drip_x);
			if (splash_d < splash_r * 0.02 && abs(p.y - floor_y) < 0.005) {
				col = mix(col, vec3(0.2, 0.25, 0.35), 0.3 * (1.0 - splash_r));
			}
		}
		// Wet spot on ceiling (constant)
		if (abs(p.x - drip_x) < 0.006 && abs(p.y - ceiling_y + 0.005) < 0.004) {
			col = mix(col, vec3(0.06, 0.08, 0.12), 0.4);
		}
	}

	// ══════════════════════════════════════════════
	// LAYER 18: Candle wax pools on floor
	// ══════════════════════════════════════════════
	for (int i = 0; i < 6; i++) {
		float fi = float(i);
		float wx2 = 0.08 + fi * 0.17 + 0.01; // under each wall sconce
		float wy2 = floor_y + 0.005;
		float wax_r = 0.008 + hash1(fi * 53.0) * 0.006;
		float wax_d = length(vec2((p.x - wx2) * 1.5, p.y - wy2));
		if (wax_d < wax_r && p.y < floor_y + 0.01) {
			col = vec3(0.55, 0.5, 0.35) + hash(cell * 0.4) * 0.1;
		}
	}

	// ══════════════════════════════════════════════
	// LAYER 19: Ghost / wraith drifting through
	// ══════════════════════════════════════════════
	{
		float ghost_speed = 0.03;
		float ghost_cycle = mod(t * ghost_speed, 2.5);
		float ghost_x;
		if (ghost_cycle < 1.25) {
			ghost_x = ghost_cycle / 1.25; // drift right
		} else {
			ghost_x = -0.2; // offscreen (invisible gap between passes)
		}
		float ghost_y = 0.45 + sin(t * 0.5) * 0.04; // hover bob
		float ghost_alpha = 0.3 + 0.2 * sin(t * 1.5); // fade in/out
		ghost_alpha *= 0.5 + audio_presence * 0.5;

		if (ghost_x > 0.0 && ghost_x < 1.0) {
			// Head (circular)
			float gh_d = length(vec2((p.x - ghost_x) * 1.8, p.y - ghost_y - 0.03));
			if (gh_d < 0.015) {
				col = mix(col, vec3(0.4, 0.45, 0.5), ghost_alpha * 0.5);
				// Eyes (hollow)
				if (abs(p.y - ghost_y - 0.033) < 0.004) {
					if (abs(p.x - ghost_x + 0.004) < 0.003 || abs(p.x - ghost_x - 0.004) < 0.003) {
						col = mix(col, vec3(0.05, 0.1, 0.2), ghost_alpha);
					}
				}
				// Mouth (O shape)
				if (abs(p.x - ghost_x) < 0.003 && abs(p.y - ghost_y - 0.025) < 0.003) {
					col = mix(col, vec3(0.05, 0.1, 0.15), ghost_alpha);
				}
			}
			// Body (tapered)
			if (abs(p.x - ghost_x) < 0.012 && p.y > ghost_y - 0.02 && p.y < ghost_y + 0.02) {
				float body_taper = 1.0 - (ghost_y + 0.02 - p.y) / 0.04;
				if (abs(p.x - ghost_x) < 0.012 * (1.0 - body_taper * 0.4)) {
					col = mix(col, vec3(0.35, 0.4, 0.45), ghost_alpha * 0.4);
				}
			}
			// Trailing wisps
			for (int w2 = 1; w2 <= 3; w2++) {
				float fw2 = float(w2);
				float wisp_x = ghost_x - fw2 * 0.015;
				float wisp_y = ghost_y - 0.01 + sin(t * 2.0 + fw2 * 2.0) * 0.008;
				vec2 wc = floor(vec2(wisp_x, wisp_y) * R);
				if (wc.x == cell.x && wc.y == cell.y) {
					col = mix(col, vec3(0.3, 0.35, 0.4), ghost_alpha * 0.2 / fw2);
				}
			}
		}
	}

	// ══════════════════════════════════════════════
	// GLOBAL: Ambient flicker and audio
	// ══════════════════════════════════════════════
	// Overall warm ambient from all candles
	// Subtle ambient flicker — barely perceptible candlelight waver
	float ambient_flicker = 0.96 + 0.04 * sin(t * 2.3) * sin(t * 3.7);
	col *= ambient_flicker;

	// Lightning flash through windows (rare, on beat)
	if (beat_snare > 0.6) {
		float flash = beat_snare * 0.15;
		col += vec3(0.15, 0.12, 0.2) * flash;
	}

	col *= 1.0 + audio_brightness * 0.15;

	ALBEDO = col;
}

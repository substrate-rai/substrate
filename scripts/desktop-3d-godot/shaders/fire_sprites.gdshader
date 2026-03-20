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

// Sprite sheet texture (CC0 RPG characters, 256x128, 16x16 tiles)
// No source_color — raw pixel values, no sRGB conversion darkening
uniform sampler2D sprite_sheet : filter_nearest, repeat_disable;
uniform vec2 sheet_size;  // 256, 128
uniform vec2 tile_size;   // 16, 16

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

// ── Sprite sheet reader ──
// Read a pixel from a sprite at (char_col, direction_row) with animation frame
// Sheet layout: each character = 3 cols (walk frames) × 4 rows (directions: down/left/right/up)
// Characters arranged: top half (rows 0-3) = chars 0-3, bottom half (rows 4-7) = chars 4-6
// char_id: 0-6 (7 characters), dir: 0=down,1=left,2=right,3=up, frame: 0-2
vec4 read_sprite(int char_id, int dir, int frame, vec2 local_px) {
	// Sheet layout: 5 characters per row block, each = 3 cols × 4 rows
	// Top (rows 0-3): chars 0-4 (red, gold, blue, dark, olive)
	// Bottom (rows 4-7): chars 5-8 (white, magenta, cyan, green)
	int char_row = char_id / 5;
	int char_col = char_id - char_row * 5;

	float tx = float(char_col * 3 + frame) * tile_size.x;
	float ty = float(char_row * 4 + dir) * tile_size.y;

	vec2 uv_sprite = (vec2(tx, ty) + local_px) / sheet_size;
	// Clamp to valid range
	uv_sprite = clamp(uv_sprite, vec2(0.0), vec2(1.0));
	return texture(sprite_sheet, uv_sprite);
}

// Draw a sprite at screen position, returns color and alpha
// pos = bottom-center of sprite in UV space
// Aspect ratio correction: quad is 16:9, so height in UV needs 1.78x to appear square
const float ASPECT = 16.0 / 9.0;

vec4 draw_sprite_at(vec2 screen_uv, vec2 pos, float scale, int char_id, int dir, int frame, float R_val) {
	float sprite_w = tile_size.x / R_val * scale;
	float sprite_h = tile_size.y / R_val * scale * ASPECT; // taller to compensate 16:9

	vec2 tl = vec2(pos.x - sprite_w * 0.5, pos.y);
	vec2 rel = screen_uv - tl;
	if (rel.x >= 0.0 && rel.x < sprite_w && rel.y >= 0.0 && rel.y < sprite_h) {
		vec2 local_px = vec2(
			floor(rel.x / sprite_w * tile_size.x),
			tile_size.y - 1.0 - floor(rel.y / sprite_h * tile_size.y)
		);
		local_px = clamp(local_px, vec2(0.0), tile_size - vec2(1.0));

		vec4 texel = read_sprite(char_id, dir, frame, local_px);
		if (texel.a < 0.1 || (texel.r + texel.g + texel.b) < 0.05) {
			return vec4(0.0);
		}
		return texel;
	}
	return vec4(0.0);
}

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
	// Dense treeline — mix of conifers and deciduous
	for (int i = 0; i < 30; i++) {
		float fi = float(i);
		float tx = hash1(fi * 73.1) + mid_scroll;
		tx = fract(tx) * 1.3 - 0.15;
		float th = 0.05 + hash1(fi * 37.3) * 0.1;
		float tw = 0.012 + hash1(fi * 91.7) * 0.012;
		float tree_type = hash1(fi * 121.0);
		float tree_top = tree_line + th;
		float rel = (p.y - tree_line) / th;
		vec3 tree_col = vec3(0.015, 0.025, 0.015);

		if (p.y > tree_line && p.y < tree_top) {
			if (tree_type < 0.5) {
				// Conifer — narrow triangle
				if (abs(p.x - tx) < tw * 0.7 * (1.0 - rel)) {
					col = tree_col;
				}
			} else if (tree_type < 0.8) {
				// Deciduous — rounder, wider crown
				float crown_y = tree_line + th * 0.4;
				if (p.y > crown_y) {
					float cr = tw * 1.3 * sin(clamp(rel * 2.0, 0.0, 3.14159));
					if (abs(p.x - tx) < cr) {
						col = tree_col + vec3(0.005, 0.01, 0.005);
					}
				} else {
					// Trunk
					if (abs(p.x - tx) < 0.004) col = tree_col;
				}
			} else {
				// Dead/bare tree — trunk + sparse branches
				if (abs(p.x - tx) < 0.004) col = vec3(0.04, 0.03, 0.02);
				// Branches
				if (rel > 0.4 && rel < 0.8) {
					float bx = tx + (hash1(fi * 53.0) - 0.5) * 0.03;
					if (abs(p.x - bx) < 0.008 && abs(p.y - (tree_line + th * 0.6)) < 0.004) {
						col = vec3(0.04, 0.03, 0.02);
					}
				}
			}
		}
	}
	// Tree line base — solid dark band
	if (p.y > tree_line - 0.015 && p.y < tree_line + 0.008) {
		col = vec3(0.015, 0.02, 0.015);
	}
	// Underglow from mushrooms on treeline
	if (p.y > tree_line - 0.02 && p.y < tree_line + 0.01) {
		float lg = step(abs(p.x - 0.18), 0.06) * 0.08;
		float rg = step(abs(p.x - 0.82), 0.05) * 0.06;
		float glow_pulse = 0.5 + 0.5 * sin(t * 0.8);
		col += vec3(0.02, 0.08, 0.05) * lg * glow_pulse;
		col += vec3(0.06, 0.02, 0.08) * rg * glow_pulse;
	}

	// ══════════════════════════════════════════════
	// LAYER 3: Clearing ground
	// ══════════════════════════════════════════════
	float ground_y = 0.32;
	if (p.y < ground_y) {
		float dirt = hash(cell * 0.2 + 200.0);
		vec3 gnd = mix(vec3(0.03, 0.05, 0.02), vec3(0.05, 0.07, 0.03), dirt);

		// Moss patches (darker green splotches)
		float moss = noise(p * 25.0 + 100.0);
		if (moss > 0.6) gnd = mix(gnd, vec3(0.02, 0.09, 0.04), 0.4);

		// Grass blades at ground line
		float grass_tip = ground_y + (hash(vec2(cell.x, 0.0)) - 0.5) * 0.02;
		if (p.y > grass_tip - 0.018 && p.y < grass_tip) {
			float blade = step(0.25, hash(vec2(cell.x * 0.5, 5.0)));
			float sway = sin(t * 0.8 + cell.x * 0.5) * 0.3;
			gnd = mix(gnd, vec3(0.02, 0.1, 0.02), blade * (0.4 + sway * 0.1));
		}
		col = gnd;

		// Dirt path (winding toward fire)
		float path_cx = 0.5 + sin(p.y * 12.0) * 0.015;
		float path_d = abs(p.x - path_cx);
		if (path_d < 0.055 && p.y < ground_y - 0.02) {
			col = vec3(0.08, 0.06, 0.04) + hash(cell * 0.15) * 0.03;
			// Pebbles on path
			if (hash(cell * 0.7 + 300.0) > 0.85) {
				col = vec3(0.13, 0.12, 0.1);
			}
		}

		// Small rocks scattered
		for (int i = 0; i < 6; i++) {
			float fi = float(i);
			float rx = hash1(fi * 97.3 + 50.0);
			float ry = hash1(fi * 61.7 + 50.0) * 0.12 + 0.05;
			if (abs(p.x - rx) < 0.008 && abs(p.y - ry) < 0.005) {
				col = vec3(0.1, 0.09, 0.08) + hash(vec2(fi, 99.0)) * 0.04;
			}
		}

		// Ferns (small green tufts)
		for (int i = 0; i < 8; i++) {
			float fi = float(i);
			float fx2 = hash1(fi * 113.7);
			float fy2 = ground_y - 0.01;
			// Skip if too close to path center
			if (abs(fx2 - 0.5) > 0.08) {
				float fh = 0.02 + hash1(fi * 43.1) * 0.02;
				// Frond shape — triangular spray
				for (int j = -2; j <= 2; j++) {
					float fj = float(j);
					float lx = fx2 + fj * 0.005;
					float ly = fy2 + fh * (1.0 - abs(fj) * 0.3);
					float sway2 = sin(t * 0.5 + fi + fj) * 0.003;
					if (abs(p.x - lx - sway2) < 0.004 && p.y > fy2 && p.y < ly) {
						col = vec3(0.03, 0.12, 0.04) + vec3(0.01) * hash1(fi + fj);
					}
				}
			}
		}

		// ── Mycelium network (glowing veins connecting mushrooms) ──
		// Horizontal veins
		for (int i = 0; i < 5; i++) {
			float fi = float(i);
			float vy = 0.08 + fi * 0.04 + hash1(fi * 77.0) * 0.02;
			float vx_start = hash1(fi * 31.0) * 0.3;
			float vx_end = vx_start + 0.3 + hash1(fi * 53.0) * 0.4;
			if (p.y > vy - 0.003 && p.y < vy + 0.003 && p.x > vx_start && p.x < vx_end) {
				float vein_noise = noise(vec2(p.x * 40.0 + fi * 10.0, vy * 20.0));
				if (vein_noise > 0.4) {
					float glow = 0.3 + 0.3 * sin(t * 0.8 + p.x * 10.0 + fi * 2.0);
					glow *= 0.5 + audio_sub_bass * 0.5;
					col = mix(col, vec3(0.05, 0.35, 0.25), glow * 0.5);
				}
			}
		}
		// Branching veins (vertical connectors)
		for (int i = 0; i < 8; i++) {
			float fi = float(i);
			float bx = hash1(fi * 137.0);
			float by_start = hash1(fi * 89.0) * 0.1 + 0.05;
			float by_end = by_start + 0.05 + hash1(fi * 67.0) * 0.08;
			if (abs(p.x - bx) < 0.003 && p.y > by_start && p.y < by_end) {
				float glow = 0.2 + 0.2 * sin(t * 1.2 + fi * 3.0 + p.y * 15.0);
				glow *= 0.5 + audio_sub_bass * 0.5;
				col = mix(col, vec3(0.05, 0.35, 0.25), glow * 0.4);
			}
		}
		// Mycelium nodes (bright dots at intersections)
		for (int i = 0; i < 10; i++) {
			float fi = float(i);
			float nx = hash1(fi * 157.0);
			float ny = hash1(fi * 101.0) * 0.15 + 0.06;
			vec2 ncell = floor(vec2(nx, ny) * R);
			if (ncell.x == cell.x && ncell.y == cell.y) {
				float pulse = 0.5 + 0.5 * sin(t * 1.5 + fi * 4.0);
				pulse *= 0.6 + audio_bass * 0.4;
				col = vec3(0.08, 0.5, 0.35) * pulse;
			}
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
				// Moss on stones
				if (hash(cell * 0.4 + vec2(float(i), 55.0)) > 0.6) {
					col = vec3(0.06, 0.12, 0.06);
				}
			}
		}
		// Lily pads
		for (int i = 0; i < 4; i++) {
			float fi = float(i);
			float lx = 0.15 + fi * 0.2 + hash1(fi * 79.0) * 0.05;
			float ly = stream_y + (hash1(fi * 41.0) - 0.5) * 0.015;
			if (length(vec2(p.x - lx, (p.y - ly) * 3.0)) < 0.012) {
				col = vec3(0.04, 0.15, 0.05);
				// Notch in lily pad
				if (p.x > lx && abs(p.y - ly) < 0.002) col = water;
			}
		}
	}

	// Cattails at stream edges
	for (int i = 0; i < 5; i++) {
		float fi = float(i);
		float cx = 0.1 + fi * 0.2 + hash1(fi * 63.0) * 0.05;
		float cy = stream_y + 0.025;
		float ch2 = 0.04 + hash1(fi * 29.0) * 0.02;
		float sway3 = sin(t * 0.6 + fi * 2.0) * 0.003;
		// Stalk
		if (abs(p.x - cx - sway3) < 0.002 && p.y > cy && p.y < cy + ch2) {
			col = vec3(0.04, 0.08, 0.03);
		}
		// Head (brown tuft)
		if (abs(p.x - cx - sway3) < 0.004 && abs(p.y - (cy + ch2)) < 0.006) {
			col = vec3(0.15, 0.08, 0.03);
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
	// LAYER 7: Sprite characters from sprite sheet
	// ══════════════════════════════════════════════

	// Character 1: Blue mage sitting by fire (facing left toward fire)
	{
		vec2 sitter_pos = vec2(0.58, ground_y);
		int sit_frame = int(mod(t * 0.5, 3.0));
		vec4 spr = draw_sprite_at(p, sitter_pos, 0.35, 2, 1, sit_frame, R);
		if (spr.a > 0.1) {
			col = spr.rgb;
			col += vec3(0.12, 0.04, 0.01) * (0.5 + audio_energy * 0.3);
		}
	}

	// Character 2: Red warrior patrolling the path
	{
		float walk_speed = 0.015;
		float walk_cycle = mod(t * walk_speed, 2.0);
		float walk_x;
		int walk_dir;
		if (walk_cycle < 1.0) {
			walk_x = walk_cycle * 0.5 + 0.2;
			walk_dir = 2;
		} else {
			walk_x = (2.0 - walk_cycle) * 0.5 + 0.2;
			walk_dir = 1;
		}
		vec2 walker_pos = vec2(walk_x, ground_y);
		int walk_frame = int(mod(t * 4.0, 3.0));
		vec4 spr2 = draw_sprite_at(p, walker_pos, 0.35, 0, walk_dir, walk_frame, R);
		if (spr2.a > 0.1) {
			col = spr2.rgb;
		}
	}

	// Character 3: Gold knight standing guard near left mushroom
	{
		vec2 guard_pos = vec2(0.14, ground_y);
		vec4 spr3 = draw_sprite_at(p, guard_pos, 0.35, 1, 2, 1, R);
		if (spr3.a > 0.1) {
			col = spr3.rgb;
			float glow_t = 0.5 + 0.5 * sin(t * 1.2);
			col += vec3(0.02, 0.06, 0.04) * glow_t;
		}
	}

	// Character 4: Cyan ranger near right mushroom
	{
		vec2 ranger_pos = vec2(0.86, ground_y);
		int ranger_frame = int(mod(t * 0.3, 3.0));
		vec4 spr4 = draw_sprite_at(p, ranger_pos, 0.35, 7, 1, ranger_frame, R);
		if (spr4.a > 0.1) {
			col = spr4.rgb;
		}
	}

	// Staff leaning behind the seated character
	{
		float staff_x = 0.59;
		if (abs(p.x - staff_x) < 0.003 && p.y > ground_y && p.y < ground_y + 0.09) {
			col = vec3(0.25, 0.15, 0.06);
		}
		if (abs(p.x - staff_x) < 0.005 && abs(p.y - (ground_y + 0.093)) < 0.005) {
			float gp = 0.6 + 0.4 * sin(t * 2.0);
			col = vec3(0.2, 0.7, 0.5) * gp;
		}
	}

	// ══════════════════════════════════════════════
	// LAYER 7.5: Smoke wisps rising from fire
	// ══════════════════════════════════════════════
	for (int i = 0; i < 4; i++) {
		float fi = float(i);
		float smoke_x = fcx + (fi - 1.5) * 0.012;
		float smoke_base = fb + 0.12; // start above flames
		float smoke_life = fract(fi * 0.37 + t * 0.03);
		float smoke_y = smoke_base + smoke_life * 0.25;
		float drift = sin(t * 0.4 + fi * 2.0 + smoke_life * 5.0) * 0.02;
		float spread = 0.005 + smoke_life * 0.012; // widens as rises

		if (abs(p.x - smoke_x - drift) < spread && abs(p.y - smoke_y) < 0.008) {
			float alpha = (1.0 - smoke_life) * 0.25;
			// Dithered — only some pixels
			if (hash(cell + vec2(fi, smoke_life * 10.0)) > 0.5) {
				col = mix(col, vec3(0.15, 0.12, 0.1), alpha);
			}
		}
	}

	// ══════════════════════════════════════════════
	// LAYER 7.6: Extra mushroom clusters
	// ══════════════════════════════════════════════
	// Tiny ground mushrooms scattered
	for (int i = 0; i < 12; i++) {
		float fi = float(i);
		float mx = hash1(fi * 173.0);
		float my = ground_y;
		// Skip near center path
		if (abs(mx - 0.5) > 0.1) {
			float mh = 0.015 + hash1(fi * 47.0) * 0.015;
			float mw = 0.004;
			// Tiny stem
			if (abs(p.x - mx) < mw && p.y > my && p.y < my + mh * 0.6) {
				col = vec3(0.3, 0.35, 0.3);
			}
			// Tiny cap
			float cap_y3 = my + mh * 0.6;
			if (abs(p.x - mx) < mw * 2.0 && abs(p.y - cap_y3) < mw * 1.5) {
				float type3 = hash1(fi * 211.0);
				float gp3 = 0.5 + 0.5 * sin(t * 1.0 + fi * 2.5);
				gp3 *= 0.5 + audio_mid * 0.5;
				if (type3 < 0.33) col = vec3(0.1, 0.6, 0.4) * gp3; // cyan
				else if (type3 < 0.66) col = vec3(0.5, 0.15, 0.6) * gp3; // purple
				else col = vec3(0.15, 0.35, 0.7) * gp3; // blue
			}
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

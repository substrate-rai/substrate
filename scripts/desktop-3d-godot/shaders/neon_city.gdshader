shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

// PIXEL ART: Cyberpunk neon city — rain-slicked streets, glowing signs,
// holographic billboards, steam vents, flying cars, neon-lit buildings

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

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float hash1(float p) { return fract(sin(p * 127.1) * 43758.5453); }

float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

vec2 px(vec2 uv, float r) { return floor(uv * r) / r; }

float dither2x2(vec2 pos) {
	int x = int(mod(pos.x, 2.0));
	int y = int(mod(pos.y, 2.0));
	if (x == 0 && y == 0) return 0.0;
	if (x == 1 && y == 1) return 0.25;
	if (x == 1 && y == 0) return 0.5;
	return 0.75;
}

float dithered_light(float intensity, vec2 cell_pos) {
	float d = dither2x2(cell_pos);
	return floor((intensity + d * 0.04) * 12.0) / 12.0;
}

void fragment() {
	vec2 uv = UV;
	float t = TIME;
	float R = 480.0; // chunky pixel art
	vec2 p = px(uv, R);
	vec2 cell = floor(uv * R);
	float ch = hash(cell);

	// ── Palette ──
	vec3 sky_top = vec3(0.02, 0.01, 0.07);
	vec3 sky_horizon = vec3(0.08, 0.03, 0.16);
	vec3 concrete_dark = vec3(0.06, 0.06, 0.09);
	vec3 concrete_mid = vec3(0.11, 0.10, 0.15);
	vec3 concrete_light = vec3(0.18, 0.16, 0.22);
	vec3 street_dark = vec3(0.04, 0.04, 0.06);
	vec3 neon_pink = vec3(1.0, 0.0, 0.4);
	vec3 neon_cyan = vec3(0.0, 1.0, 0.7);
	vec3 neon_blue = vec3(0.25, 0.45, 1.0);
	vec3 neon_orange = vec3(1.0, 0.4, 0.0);
	vec3 neon_purple = vec3(0.65, 0.0, 1.0);
	vec3 neon_yellow = vec3(1.0, 0.9, 0.1);
	vec3 win_warm = vec3(1.0, 0.8, 0.4);
	vec3 win_cool = vec3(0.5, 0.7, 1.0);

	vec3 col = sky_top;
	float street_y = 0.18;

	// ══════════════════════════════════════════════
	// LAYER 0: Night sky — gradient, stars, moon
	// ══════════════════════════════════════════════
	{
		float grad = smoothstep(0.45, 1.0, p.y);
		col = mix(sky_horizon, sky_top, grad);
		// Purple haze band near horizon
		float haze = smoothstep(0.65, 0.5, p.y) * smoothstep(0.45, 0.55, p.y);
		col += vec3(0.03, 0.01, 0.06) * haze;

		// Stars
		if (p.y > 0.62) {
			float star = hash(cell * 0.1);
			float twinkle = 0.5 + 0.5 * sin(t * 2.0 + star * 100.0);
			if (star > 0.997) col += vec3(0.6, 0.6, 0.7) * twinkle;
			else if (star > 0.993) col += vec3(0.2, 0.2, 0.3) * twinkle * 0.6;
		}

		// Moon
		float moon_d = length(vec2((p.x - 0.86) * 1.6, p.y - 0.89));
		if (moon_d < 0.035) {
			col = mix(col, vec3(0.65, 0.60, 0.80), smoothstep(0.035, 0.008, moon_d));
			if (length(vec2(p.x - 0.855, p.y - 0.885)) < 0.008) col *= 0.82;
			if (length(vec2(p.x - 0.868, p.y - 0.895)) < 0.005) col *= 0.86;
		}
		if (moon_d > 0.035 && moon_d < 0.07) {
			col += vec3(0.12, 0.08, 0.22) * (1.0 - (moon_d - 0.035) / 0.035) * 0.15;
		}
	}

	// ══════════════════════════════════════════════
	// LAYER 1: Distant skyline (background buildings)
	// ══════════════════════════════════════════════
	float skyline_base = 0.44;
	{
		for (int i = 0; i < 22; i++) {
			float fi = float(i);
			float bx = hash1(fi * 73.1) * 1.1 - 0.05;
			float bw = 0.018 + hash1(fi * 31.7) * 0.035;
			float bh = 0.08 + hash1(fi * 47.3) * 0.22;
			float btop = skyline_base + bh;

			if (abs(p.x - bx) < bw && p.y > skyline_base && p.y < btop) {
				col = concrete_dark * (0.55 + hash1(fi * 13.3) * 0.35);

				// Scattered distant windows
				float wcx = floor((p.x - bx + bw) / 0.006);
				float wcy = floor((p.y - skyline_base) / 0.008);
				float wh = hash(vec2(wcx + fi * 10.0, wcy));
				float iwx = fract((p.x - bx + bw) / 0.006);
				float iwy = fract((p.y - skyline_base) / 0.008);
				if (wh > 0.55 && iwx > 0.2 && iwx < 0.8 && iwy > 0.2 && iwy < 0.7) {
					float b = 0.25 + wh * 0.35;
					col = ((wh > 0.82) ? win_warm : win_cool) * b * 0.35;
				}

				// Rooftop neon accent
				if (abs(p.y - btop) < 0.002) {
					float nh = hash1(fi * 99.1);
					if (nh > 0.6) col = neon_pink * 0.35;
					else if (nh > 0.35) col = neon_cyan * 0.35;
				}
			}
		}
	}

	// ══════════════════════════════════════════════
	// LAYER 2: Main foreground buildings (8 buildings)
	// ══════════════════════════════════════════════
	float fg_base = street_y + 0.04;
	{
		for (int i = 0; i < 8; i++) {
			float fi = float(i);
			// Building positions: 4 left of center, 4 right
			float bx, bw, bh;
			if (i == 0) { bx = 0.02; bw = 0.065; bh = 0.34; }
			else if (i == 1) { bx = 0.13; bw = 0.06; bh = 0.40; }
			else if (i == 2) { bx = 0.24; bw = 0.055; bh = 0.30; }
			else if (i == 3) { bx = 0.34; bw = 0.04; bh = 0.24; }
			else if (i == 4) { bx = 0.62; bw = 0.055; bh = 0.36; }
			else if (i == 5) { bx = 0.73; bw = 0.065; bh = 0.44; }
			else if (i == 6) { bx = 0.85; bw = 0.055; bh = 0.32; }
			else { bx = 0.95; bw = 0.05; bh = 0.28; }

			float btop = fg_base + bh;

			if (abs(p.x - bx) < bw && p.y > fg_base && p.y < btop) {
				// Body with varied tone
				col = mix(concrete_dark, concrete_mid, hash1(fi * 53.0) * 0.5);
				col += vec3(noise(p * 200.0 + fi * 100.0) * 0.025);

				// Horizontal neon trim strips
				for (int s = 0; s < 4; s++) {
					float strip_y = fg_base + bh * (0.22 + float(s) * 0.2);
					if (abs(p.y - strip_y) < 0.0015) {
						float sh = hash(vec2(fi, float(s)));
						vec3 sc;
						if (sh > 0.7) sc = neon_pink;
						else if (sh > 0.4) sc = neon_cyan;
						else sc = neon_blue;
						col = sc * (0.65 + 0.35 * sin(t * 2.0 + fi + float(s)));
					}
				}

				// Vertical neon edge strips (some buildings)
				if (hash1(fi * 77.0) > 0.45) {
					if (abs(abs(p.x - bx) - bw + 0.003) < 0.0015) {
						col = neon_purple * (0.5 + 0.5 * sin(t * 1.5 + fi * 3.0));
					}
				}

				// Windows grid
				float ww = 0.006; float wh2 = 0.008;
				float wcx = floor((p.x - bx + bw) / ww);
				float wcy = floor((p.y - fg_base) / wh2);
				float iwx = fract((p.x - bx + bw) / ww);
				float iwy = fract((p.y - fg_base) / wh2);
				float whash = hash(vec2(wcx + fi * 20.0, wcy));

				// Check if on a neon strip (skip window drawing there)
				bool on_strip = false;
				for (int s = 0; s < 4; s++) {
					float strip_y = fg_base + bh * (0.22 + float(s) * 0.2);
					if (abs(p.y - strip_y) < 0.003) on_strip = true;
				}

				if (!on_strip && iwx > 0.15 && iwx < 0.85 && iwy > 0.15 && iwy < 0.75) {
					if (whash > 0.22) {
						vec3 wc;
						if (whash > 0.92) wc = neon_cyan * 0.55;
						else if (whash > 0.84) wc = neon_pink * 0.45;
						else if (whash > 0.55) wc = win_warm;
						else wc = win_cool;
						float flicker = (whash > 0.96) ? (0.5 + 0.5 * sin(t * 8.0 + whash * 50.0)) : 1.0;
						col = wc * (0.25 + whash * 0.35) * flicker;
					} else {
						col = vec3(0.02, 0.02, 0.04);
					}
				}

				// Balcony ledges (every other floor, some buildings)
				if (hash1(fi * 41.0) > 0.45) {
					float fh = 0.04;
					float fi2 = floor((p.y - fg_base) / fh);
					if (mod(fi2, 2.0) < 1.0) {
						float ly = fg_base + fi2 * fh;
						if (abs(p.y - ly) < 0.002 && abs(p.x - bx) < bw + 0.005) {
							col = concrete_light;
						}
					}
				}

				// Roof edge
				if (abs(p.y - btop) < 0.003) {
					col = concrete_light * 0.75;
				}
			}

			// Antenna above roof
			float ant_x = bx + (hash1(fi * 67.0) - 0.5) * bw * 0.6;
			if (abs(p.x - ant_x) < 0.002 && p.y > btop && p.y < btop + 0.025) {
				col = concrete_mid;
				// Blinking red light at tip
				if (abs(p.y - (btop + 0.024)) < 0.002) {
					col = vec3(1.0, 0.05, 0.0) * step(0.5, sin(t * 3.0 + fi * 5.0));
				}
			}

			// Ground-floor shopfronts (30% of buildings)
			if (hash1(fi * 89.0) > 0.7 && abs(p.x - bx) < bw) {
				if (p.y > fg_base - 0.005 && p.y < fg_base + 0.028) {
					// Storefront glow
					if (p.y < fg_base + 0.020 && abs(p.x - bx) < bw * 0.8) {
						float sh = hash1(fi * 91.0);
						vec3 sc;
						if (sh > 0.6) sc = neon_orange;
						else if (sh > 0.3) sc = neon_cyan;
						else sc = neon_pink;
						col = sc * (0.35 + 0.15 * sin(t + fi));
					}
					// Awning
					if (p.y > fg_base + 0.020 && p.y < fg_base + 0.026 && abs(p.x - bx) < bw * 0.9) {
						col = vec3(0.22, 0.08, 0.06);
					}
				}
			}
		}
	}

	// ══════════════════════════════════════════════
	// LAYER 3: Street surface, markings, puddles
	// ══════════════════════════════════════════════
	if (p.y < street_y + 0.04) {
		col = street_dark;
		col += vec3(noise(p * 300.0) * 0.012);

		// Sidewalk curbs
		if (abs(p.x - 0.38) < 0.006 || abs(p.x - 0.62) < 0.006) {
			col = concrete_light * 0.7;
		}

		// Sidewalks
		if ((p.x < 0.375 || p.x > 0.625) && p.y > street_y) {
			col = concrete_mid * 0.6;
			col += vec3(noise(p * 150.0) * 0.015);
		}

		// Road (center)
		if (p.x > 0.385 && p.x < 0.615) {
			// Dashed center line
			if (abs(p.x - 0.5) < 0.003) {
				float dash = mod(p.y * 40.0, 2.0);
				if (dash < 1.2) col = neon_yellow * 0.45;
			}
			// Crosswalk
			if (abs(p.y - (street_y + 0.012)) < 0.007) {
				float stripe = mod((p.x - 0.385) * 60.0, 2.0);
				if (stripe < 1.0) col = vec3(0.55, 0.50, 0.25) * 0.45;
			}
		}

		// Puddles (6, centered in road)
		for (int i = 0; i < 6; i++) {
			float fi = float(i);
			float px2 = 0.42 + hash1(fi * 33.0) * 0.16;
			float py2 = street_y + 0.003 + hash1(fi * 57.0) * 0.025;
			float pr = 0.008 + hash1(fi * 71.0) * 0.015;
			float pd = length(vec2((p.x - px2) * 1.5, p.y - py2));
			if (pd < pr) {
				vec3 rc = mix(neon_pink, neon_cyan, hash1(fi * 41.0));
				float ripple = sin(pd * 200.0 - t * 3.0) * 0.3 + 0.7;
				col = rc * 0.12 * ripple + vec3(0.015, 0.015, 0.03);
			}
		}

		// Manhole covers (2)
		for (int i = 0; i < 2; i++) {
			float fi = float(i);
			float mx = 0.46 + fi * 0.09;
			float my = street_y + 0.015;
			if (length(vec2(p.x - mx, (p.y - my) * 2.0)) < 0.007) {
				col = vec3(0.10, 0.10, 0.13);
				if (abs(p.x - mx) < 0.001 || abs(p.y - my) < 0.0008) col = vec3(0.07, 0.07, 0.09);
			}
		}
	}

	// ══════════════════════════════════════════════
	// LAYER 4: Neon signs (6 signs on building faces)
	// ══════════════════════════════════════════════
	{
		// Sign 1: pink, left
		float s1x = 0.15, s1y = 0.39, s1w = 0.038, s1h = 0.014;
		if (abs(p.x - s1x) < s1w && abs(p.y - s1y) < s1h) {
			float pulse = 0.65 + 0.35 * sin(t * 2.5);
			pulse *= 0.8 + audio_mid * 0.2;
			col = neon_pink * pulse;
			// Inner grid (pseudo-text)
			float tx = fract((p.x - s1x + s1w) / (s1w * 2.0) * 6.0);
			if (tx < 0.12) col *= 0.25;
		}
		float s1d = max(abs(p.x - s1x) - s1w, abs(p.y - s1y) - s1h);
		if (s1d > 0.0 && s1d < 0.015) col += neon_pink * 0.10 * (1.0 - s1d / 0.015);

		// Sign 2: cyan, right
		float s2x = 0.82, s2y = 0.43, s2w = 0.032, s2h = 0.012;
		if (abs(p.x - s2x) < s2w && abs(p.y - s2y) < s2h) {
			col = neon_cyan * (0.6 + 0.4 * sin(t * 1.8 + 1.0));
		}
		float s2d = max(abs(p.x - s2x) - s2w, abs(p.y - s2y) - s2h);
		if (s2d > 0.0 && s2d < 0.012) col += neon_cyan * 0.08 * (1.0 - s2d / 0.012);

		// Sign 3: orange, vertical (kanji-style)
		float s3x = 0.28, s3y = 0.47, s3w = 0.009, s3h = 0.035;
		if (abs(p.x - s3x) < s3w && abs(p.y - s3y) < s3h) {
			float pulse = 0.5 + 0.5 * sin(t * 3.0 + 2.0);
			pulse *= 0.7 + audio_energy * 0.3;
			col = neon_orange * pulse;
			float ky = fract((p.y - s3y + s3h) / (s3h * 2.0) * 5.0);
			if (ky < 0.12) col *= 0.2; // segment gaps
		}
		float s3d = max(abs(p.x - s3x) - s3w, abs(p.y - s3y) - s3h);
		if (s3d > 0.0 && s3d < 0.01) col += neon_orange * 0.06 * (1.0 - s3d / 0.01);

		// Sign 4: purple, right upper
		float s4x = 0.74, s4y = 0.53, s4w = 0.028, s4h = 0.01;
		if (abs(p.x - s4x) < s4w && abs(p.y - s4y) < s4h) {
			col = neon_purple * (0.6 + 0.4 * sin(t * 2.0 + 3.0));
		}
		float s4d = max(abs(p.x - s4x) - s4w, abs(p.y - s4y) - s4h);
		if (s4d > 0.0 && s4d < 0.01) col += neon_purple * 0.05 * (1.0 - s4d / 0.01);

		// Sign 5: flickering / damaged blue
		float s5x = 0.07, s5y = 0.36, s5w = 0.022, s5h = 0.008;
		if (abs(p.x - s5x) < s5w && abs(p.y - s5y) < s5h) {
			float flicker = step(0.3, hash(vec2(floor(t * 12.0), 0.0)));
			col = neon_blue * 0.75 * flicker;
		}

		// Sign 6: vertical multi-color (right edge)
		float s6x = 0.93, s6y = 0.40, s6w = 0.007, s6h = 0.055;
		if (abs(p.x - s6x) < s6w && abs(p.y - s6y) < s6h) {
			float pulse = 0.7 + 0.3 * sin(t * 1.5 + 4.0);
			float seg = floor((p.y - s6y + s6h) / (s6h * 2.0 / 5.0));
			vec3 sc;
			if (mod(seg, 3.0) < 1.0) sc = neon_pink;
			else if (mod(seg, 3.0) < 2.0) sc = neon_cyan;
			else sc = neon_orange;
			col = sc * pulse;
		}
		float s6d = max(abs(p.x - s6x) - s6w, abs(p.y - s6y) - s6h);
		if (s6d > 0.0 && s6d < 0.008) col += neon_pink * 0.04 * (1.0 - s6d / 0.008);
	}

	// ══════════════════════════════════════════════
	// LAYER 5: Holographic billboards (2 large panels)
	// ══════════════════════════════════════════════
	{
		// Billboard 1: cyan, left
		float hx1 = 0.20, hy1 = 0.52, hw1 = 0.048, hh1 = 0.028;
		if (abs(p.x - hx1) < hw1 && abs(p.y - hy1) < hh1) {
			float scan = sin(p.y * 400.0 + t * (5.0 + audio_mid * 10.0)) * 0.5 + 0.5;
			float hflick = 0.6 + 0.4 * sin(t * 8.0);
			hflick *= step(0.05, hash(vec2(floor(t * 15.0), 1.0)));
			vec3 hc = neon_cyan;
			float glitch = hash(vec2(floor(p.y * 100.0), floor(t * 5.0)));
			if (glitch > 0.94 + audio_treble * 0.04) hc = neon_pink;
			col = hc * scan * 0.45 * hflick;
			float edge = smoothstep(0.0, 0.006, abs(p.x - hx1) - hw1 + 0.006);
			col *= 1.0 - edge;
		}
		float h1d = max(abs(p.x - hx1) - hw1, abs(p.y - hy1) - hh1);
		if (h1d > 0.0 && h1d < 0.012) col += neon_cyan * 0.06 * (1.0 - h1d / 0.012);

		// Billboard 2: pink, right
		float hx2 = 0.78, hy2 = 0.48, hw2 = 0.040, hh2 = 0.024;
		if (abs(p.x - hx2) < hw2 && abs(p.y - hy2) < hh2) {
			float scan = sin(p.y * 350.0 + t * (4.0 + audio_mid * 8.0)) * 0.5 + 0.5;
			float hflick = 0.7 + 0.3 * sin(t * 6.0 + 2.0);
			hflick *= step(0.03, hash(vec2(floor(t * 12.0), 2.0)));
			col = neon_pink * scan * 0.40 * hflick;
		}
		float h2d = max(abs(p.x - hx2) - hw2, abs(p.y - hy2) - hh2);
		if (h2d > 0.0 && h2d < 0.01) col += neon_pink * 0.05 * (1.0 - h2d / 0.01);
	}

	// ══════════════════════════════════════════════
	// LAYER 6: Street lamps (4 along curbs)
	// ══════════════════════════════════════════════
	for (int i = 0; i < 4; i++) {
		float fi = float(i);
		float lx;
		if (i == 0) lx = 0.39;
		else if (i == 1) lx = 0.40;
		else if (i == 2) lx = 0.61;
		else lx = 0.60;
		float lz = street_y + 0.005 + mod(fi, 2.0) * 0.012;
		float lt = street_y + 0.06;

		// Pole
		if (abs(p.x - lx) < 0.002 && p.y > lz && p.y < lt) {
			col = concrete_light * 0.55;
		}
		// Lamp head
		if (abs(p.x - lx) < 0.005 && abs(p.y - lt) < 0.003) {
			col = ((i < 2) ? neon_cyan : neon_pink) * 0.8;
		}
		// Light cone on street
		float cd = length(vec2((p.x - lx) * 2.0, p.y - lz));
		if (cd < 0.035 && p.y < lt) {
			vec3 lc = (i < 2) ? neon_cyan : neon_pink;
			float ls = (1.0 - cd / 0.035) * 0.10;
			ls = dithered_light(ls, cell);
			col += lc * ls;
		}
	}

	// ══════════════════════════════════════════════
	// LAYER 7: Street props
	// ══════════════════════════════════════════════
	{
		// Vending machine 1 (left sidewalk)
		float vm1x = 0.33;
		float vm1y = street_y + 0.005;
		float vmw = 0.009;
		float vmh = 0.024;
		if (abs(p.x - vm1x) < vmw && p.y > vm1y && p.y < vm1y + vmh) {
			col = vec3(0.05, 0.05, 0.08);
			if (abs(p.x - vm1x) < vmw * 0.65 && p.y > vm1y + vmh * 0.3 && p.y < vm1y + vmh * 0.82) {
				col = neon_cyan * 0.45 * (0.7 + 0.3 * sin(t));
			}
		}
		// Vending machine 2 (right sidewalk)
		float vm2x = 0.67;
		if (abs(p.x - vm2x) < vmw && p.y > vm1y && p.y < vm1y + vmh) {
			col = vec3(0.05, 0.05, 0.08);
			if (abs(p.x - vm2x) < vmw * 0.65 && p.y > vm1y + vmh * 0.3 && p.y < vm1y + vmh * 0.82) {
				col = neon_orange * 0.45 * (0.7 + 0.3 * sin(t * 1.5 + 1.0));
			}
		}
		// Crates
		float cx1 = 0.30;
		if (abs(p.x - cx1) < 0.006 && p.y > vm1y && p.y < vm1y + 0.010) {
			col = vec3(0.14, 0.10, 0.06);
			if (mod(cell.y, 2.0) < 1.0) col *= 1.12;
		}
		// Dumpster
		float dx1 = 0.70;
		if (abs(p.x - dx1) < 0.011 && p.y > vm1y && p.y < vm1y + 0.014) {
			col = vec3(0.07, 0.10, 0.05);
			if (abs(p.y - (vm1y + 0.014)) < 0.002) col = vec3(0.11, 0.11, 0.13);
		}
	}

	// ══════════════════════════════════════════════
	// LAYER 8: Flying cars / air traffic (3 cars)
	// ══════════════════════════════════════════════
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		float car_y = 0.56 + fi * 0.075;
		float car_spd = 0.055 + hash1(fi * 43.0) * 0.04;
		float car_dir = (mod(fi, 2.0) < 1.0) ? 1.0 : -1.0;
		float car_x = fract(t * car_spd * car_dir + fi * 0.37);
		if (car_dir < 0.0) car_x = 1.0 - car_x;
		float cw = 0.014;
		float chl = 0.005;

		if (abs(p.x - car_x) < cw && abs(p.y - car_y) < chl) {
			float shade = (p.y - car_y + chl) / (chl * 2.0);
			col = mix(vec3(0.07, 0.07, 0.11), vec3(0.14, 0.13, 0.17), shade);
			// Headlights
			float front = car_x + car_dir * cw;
			if (abs(p.x - front) < 0.004 && abs(p.y - car_y) < chl * 0.5)
				col = vec3(0.85, 0.80, 0.65);
			// Tail lights
			float back = car_x - car_dir * cw;
			if (abs(p.x - back) < 0.003 && abs(p.y - car_y) < chl * 0.4)
				col = vec3(0.75, 0.04, 0.02);
			// Window strip
			if (abs(p.y - (car_y + chl * 0.3)) < 0.001 && abs(p.x - car_x) < cw * 0.55)
				col = win_cool * 0.35;
		}
		// Thruster glow
		float td = length(vec2((p.x - car_x) * 2.0, p.y - (car_y - chl - 0.003)));
		if (td < 0.007) col += neon_cyan * 0.12 * (1.0 - td / 0.007);
		// Light trail
		if (abs(p.y - car_y) < 0.0015) {
			float dx2 = (p.x - car_x) * (-car_dir);
			if (dx2 > 0.0 && dx2 < 0.04) {
				col += vec3(0.7, 0.04, 0.02) * 0.08 * (1.0 - dx2 / 0.04);
			}
		}
	}

	// ══════════════════════════════════════════════
	// LAYER 9: Rain (pixel drops)
	// ══════════════════════════════════════════════
	for (int i = 0; i < 50; i++) {
		float fi = float(i);
		float rx = hash1(fi * 73.1);
		float ry = fract(hash1(fi * 47.3) + t * (0.7 + hash1(fi * 31.0) * 0.4));
		float rlen = 0.010 + hash1(fi * 53.0) * 0.008;
		float wind = 0.003;
		for (float s = 0.0; s < 1.0; s += 0.25) {
			float ry2 = ry - s * rlen;
			float rx2 = rx + s * wind;
			vec2 rc = floor(vec2(rx2, ry2) * R);
			if (rc.x == cell.x && rc.y == cell.y && ry2 > street_y) {
				col = mix(col, vec3(0.35, 0.40, 0.55), 0.22);
			}
		}
	}

	// ══════════════════════════════════════════════
	// LAYER 10: Steam vents (3 plumes)
	// ══════════════════════════════════════════════
	for (int i = 0; i < 3; i++) {
		float fi = float(i);
		float sx = 0.43 + fi * 0.07;
		float sy = street_y + 0.005;
		for (int j = 0; j < 8; j++) {
			float fj = float(j);
			float steam_y = sy + fract(fj * 0.13 + t * 0.15) * 0.045;
			float steam_x = sx + sin(t * 2.0 + fj * 3.0 + fi * 5.0) * 0.004;
			float sr = 0.003 + fj * 0.0008;
			float sd = length(vec2(p.x - steam_x, p.y - steam_y));
			if (sd < sr) {
				float alpha = 0.12 * (1.0 - fract(fj * 0.13 + t * 0.15));
				col = mix(col, vec3(0.28, 0.28, 0.33), alpha);
			}
		}
	}

	// ══════════════════════════════════════════════
	// LAYER 11: Ground fog (street haze)
	// ══════════════════════════════════════════════
	if (p.y < street_y + 0.055) {
		float fs = smoothstep(street_y + 0.055, street_y, p.y) * 0.13;
		float fn = noise(vec2(p.x * 20.0 + t * 0.5, p.y * 10.0));
		fs *= 0.5 + fn * 0.5;
		fs *= 0.8 + audio_bass * 0.2;
		vec3 fc = mix(vec3(0.10, 0.04, 0.14), vec3(0.04, 0.10, 0.13), noise(vec2(p.x * 5.0, t * 0.1)));
		col = mix(col, fc, fs);
	}

	// ══════════════════════════════════════════════
	// LAYER 12: Neon reflections on wet street
	// ══════════════════════════════════════════════
	if (p.y < street_y + 0.035 && p.x > 0.385 && p.x < 0.615) {
		float refl_dist = street_y + 0.035 - p.y;
		float ref_s = 0.07 * (1.0 - refl_dist / 0.035);
		float rh = hash(vec2(floor(p.x * 30.0), floor((street_y + 0.035 + refl_dist * 3.0) * 20.0)));
		vec3 rc;
		if (rh > 0.8) rc = neon_pink;
		else if (rh > 0.6) rc = neon_cyan;
		else if (rh > 0.4) rc = neon_blue;
		else rc = neon_purple;
		float ripple = sin(p.x * 100.0 + t * 2.0) * sin(p.y * 80.0 - t * 1.5);
		ref_s *= 0.5 + ripple * 0.5;
		col += rc * ref_s;
	}

	// ══════════════════════════════════════════════
	// LAYER 13: Pedestrian silhouettes (4 people)
	// ══════════════════════════════════════════════
	for (int i = 0; i < 4; i++) {
		float fi = float(i);
		float ped_spd = 0.013 + hash1(fi * 67.0) * 0.012;
		float ped_dir = (mod(fi, 2.0) < 1.0) ? 1.0 : -1.0;
		float ped_raw = fract(t * ped_spd * ped_dir + fi * 0.27);
		// Keep on sidewalks
		float side = (fi < 2.0) ? 0.34 : 0.66;
		float ped_x = side + (ped_raw - 0.5) * 0.04;
		float ped_y = street_y + 0.005;
		float ph = 0.017;
		float pw = 0.004;

		if (abs(p.x - ped_x) < pw && p.y > ped_y && p.y < ped_y + ph) {
			float bf = (p.y - ped_y) / ph;
			float w = pw;
			if (bf > 0.85) w *= 0.6;
			else if (bf < 0.4) w *= 0.7;
			if (abs(p.x - ped_x) < w) {
				col = vec3(0.035, 0.03, 0.05);
				float eg = smoothstep(w * 0.5, w, abs(p.x - ped_x));
				col += ((fi < 2.0) ? neon_pink : neon_cyan) * eg * 0.13;
			}
		}
		// Legs
		float lp = sin(t * 4.0 + fi * 3.0) * 0.002;
		if (abs(p.x - ped_x - lp) < 0.0015 && p.y > ped_y - 0.003 && p.y < ped_y + ph * 0.3)
			col = vec3(0.035, 0.03, 0.05);
		if (abs(p.x - ped_x + lp) < 0.0015 && p.y > ped_y - 0.003 && p.y < ped_y + ph * 0.3)
			col = vec3(0.035, 0.03, 0.05);
	}

	// ══════════════════════════════════════════════
	// LAYER 14: Power lines / cables
	// ══════════════════════════════════════════════
	{
		for (int i = 0; i < 3; i++) {
			float fi = float(i);
			float cable_y = 0.60 + fi * 0.04;
			// Sagging catenary
			float sag = sin(p.x * 3.14159) * 0.008 * (1.0 + fi * 0.3);
			float sway = sin(t * 0.8 + fi * 2.0) * 0.002;
			float cy = cable_y + sag + sway;
			vec2 cc = floor(vec2(p.x, cy) * R);
			if (cc.x == cell.x && cc.y == cell.y && p.x > 0.05 && p.x < 0.95) {
				col = vec3(0.06, 0.05, 0.08);
			}
		}
	}

	// ══════════════════════════════════════════════
	// GLOBAL: Beat flash, lightning, vignette
	// ══════════════════════════════════════════════
	if (beat_kick > 0.5) {
		col += vec3(0.025, 0.01, 0.035) * beat_kick;
	}
	if (beat_snare > 0.7) {
		col += vec3(0.12, 0.08, 0.20) * beat_snare * 0.12;
	}
	col *= 1.0 + audio_brightness * 0.1;

	// Vignette
	float vignette = 1.0 - length(uv - 0.5) * 0.55;
	col *= vignette;

	ALBEDO = col;
}

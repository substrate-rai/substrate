shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

// SHADOW MOSES — Metal Gear Solid 1 corridor
// Industrial metal walls, security cameras, guard patrol, snow, soliton radar

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

void fragment() {
	vec2 uv = UV;
	float t = TIME;
	float R = 540.0;
	vec2 p = px(uv, R);
	vec2 cell = floor(uv * R);
	float ch = hash(cell);

	// ── MGS1 palette ──
	vec3 metal_dark = vec3(0.06, 0.07, 0.08);
	vec3 metal_mid = vec3(0.12, 0.13, 0.15);
	vec3 metal_light = vec3(0.2, 0.21, 0.24);
	vec3 metal_hi = vec3(0.3, 0.31, 0.35);
	vec3 rivet = vec3(0.08, 0.09, 0.1);
	vec3 panel_dark = vec3(0.07, 0.08, 0.09);
	vec3 panel_mid = vec3(0.1, 0.11, 0.13);
	vec3 caution_yellow = vec3(0.6, 0.5, 0.05);
	vec3 warning_red = vec3(0.5, 0.05, 0.02);
	vec3 pipe_col = vec3(0.15, 0.16, 0.18);
	vec3 vent_col = vec3(0.09, 0.1, 0.11);
	vec3 snow_col = vec3(0.6, 0.65, 0.7);
	vec3 green_tint = vec3(0.02, 0.06, 0.03); // MGS green overlay

	vec3 col = metal_dark;

	// ══════════════════════════════════════════════
	// LAYER 0: Metal wall panels
	// ══════════════════════════════════════════════
	{
		float panel_w = 0.08;
		float panel_h = 0.12;
		float px2 = floor(p.x / panel_w);
		float py2 = floor(p.y / panel_h);
		float in_x = fract(p.x / panel_w);
		float in_y = fract(p.y / panel_h);
		float panel_hash = hash(vec2(px2, py2));

		// Panel seams
		float seam = 0.03;
		bool is_seam = in_x < seam || in_x > (1.0 - seam) || in_y < seam || in_y > (1.0 - seam);

		if (is_seam) {
			col = metal_dark * 0.7;
			// Seam highlight on top/left edges
			if (in_y > (1.0 - seam) || in_x < seam * 0.5) col = metal_mid * 0.6;
		} else {
			// Panel surface — subtle brushed metal texture
			float brush = noise(vec2(p.x * 5.0 + px2, p.y * 300.0)) * 0.03;
			col = metal_mid + vec3(brush);
			// Slight color variation per panel
			col += vec3(panel_hash * 0.015 - 0.008);

			// Panel edge bevels
			float bevel = 0.06;
			if (in_y > (1.0 - seam - bevel)) col = mix(col, metal_hi, 0.15); // top highlight
			if (in_y < seam + bevel) col *= 0.88; // bottom shadow
			if (in_x > (1.0 - seam - bevel)) col *= 0.92; // right shadow
			if (in_x < seam + bevel) col = mix(col, metal_hi, 0.08); // left highlight

			// Rivets at corners of each panel
			for (int rx = 0; rx <= 1; rx++) {
				for (int ry = 0; ry <= 1; ry++) {
					float rvx = seam + 0.03 + float(rx) * (1.0 - seam * 2.0 - 0.06);
					float rvy = seam + 0.04 + float(ry) * (1.0 - seam * 2.0 - 0.08);
					float rd = length(vec2(in_x - rvx, (in_y - rvy) * 1.8));
					if (rd < 0.02) {
						col = rivet;
						if (rd < 0.012) col = metal_hi * 0.7; // rivet highlight
						if (rd > 0.016) col = metal_dark; // rivet shadow ring
					}
				}
			}

			// Some panels have wear scratches
			if (panel_hash > 0.7) {
				float scratch = noise(vec2(p.x * 200.0 + panel_hash * 50.0, p.y * 20.0));
				if (scratch > 0.75) col = mix(col, metal_hi, 0.15);
			}
		}
	}

	// ══════════════════════════════════════════════
	// LAYER 1: Floor — industrial metal grating
	// ══════════════════════════════════════════════
	float floor_y = 0.15;
	if (p.y < floor_y) {
		// Diamond plate pattern
		float grid = 0.012;
		float gx = fract(p.x / grid);
		float gy = fract(p.y / grid);
		float diamond = abs(gx - 0.5) + abs(gy - 0.5);

		col = metal_dark * 0.8;
		if (diamond < 0.35) {
			col = metal_mid;
			// Diamond raised highlight
			if (diamond < 0.2) col = metal_light;
			if (diamond < 0.1) col = metal_hi * 0.8;
		}

		// Floor texture noise
		col += vec3(noise(p * 200.0) * 0.02);

		// Yellow caution stripe at edges
		if (abs(p.x - 0.05) < 0.015 || abs(p.x - 0.95) < 0.015) {
			float stripe = fract((p.x + p.y) * 15.0);
			if (stripe < 0.5) col = caution_yellow * 0.7;
			else col = metal_dark;
		}

		// Center walkway marking
		if (abs(p.x - 0.5) < 0.002 && mod(cell.y, 4.0) < 2.0) {
			col = caution_yellow * 0.5;
		}
	}

	// ══════════════════════════════════════════════
	// LAYER 2: Ceiling — conduit-heavy industrial
	// ══════════════════════════════════════════════
	float ceiling_y = 0.88;
	if (p.y > ceiling_y) {
		col = metal_dark * 0.5;
		// Ceiling panels
		float cp_w = 0.1;
		float cp_x = fract(p.x / cp_w);
		if (cp_x < 0.03 || cp_x > 0.97) col = metal_dark * 0.3;
		else col += vec3(noise(p * 100.0) * 0.015);

		// Pipes running along ceiling
		for (int i = 0; i < 3; i++) {
			float fi = float(i);
			float pipe_y = ceiling_y + 0.02 + fi * 0.03;
			float pipe_r = 0.006 + fi * 0.002;
			float pd = abs(p.y - pipe_y);
			if (pd < pipe_r) {
				float shade = (pd / pipe_r); // cylindrical shading
				vec3 pc = mix(metal_hi * 0.6, metal_dark, shade);
				// Pipe color coding
				if (i == 0) pc *= vec3(1.0, 1.0, 0.9); // slightly warm
				if (i == 1) pc = mix(pc, vec3(0.15, 0.2, 0.15), 0.3); // green pipe
				if (i == 2) pc *= vec3(0.9, 0.9, 1.0); // slightly cool
				col = pc;
				// Pipe joints
				if (mod(p.x, 0.15) < 0.008) col = metal_hi * 0.5;
			}
		}

		// Fluorescent light fixtures (flickering)
		for (int i = 0; i < 3; i++) {
			float fi = float(i);
			float light_x = 0.2 + fi * 0.3;
			float light_w = 0.05;
			if (abs(p.x - light_x) < light_w && p.y > ceiling_y && p.y < ceiling_y + 0.01) {
				float flicker = 0.7 + 0.3 * sin(t * 15.0 + fi * 5.0) * sin(t * 23.0 + fi * 7.0);
				flicker = (flicker > 0.5) ? 1.0 : 0.3; // harsh on/off flicker
				col = vec3(0.5, 0.55, 0.5) * flicker;
				// Light housing
				if (abs(p.x - light_x) > light_w - 0.005) col = metal_mid;
			}
		}
	}

	// ══════════════════════════════════════════════
	// LAYER 3: Blast door / bulkhead (center)
	// ══════════════════════════════════════════════
	{
		float door_x = 0.5;
		float door_w = 0.06;
		float door_b = floor_y;
		float door_t = 0.52;
		if (abs(p.x - door_x) < door_w && p.y > door_b && p.y < door_t) {
			// Heavy blast door
			float dx2 = (p.x - door_x + door_w) / (door_w * 2.0);
			col = mix(metal_dark, metal_mid, dx2 * 0.4 + 0.3);
			// Vertical split line
			if (abs(p.x - door_x) < 0.002) col = metal_dark * 0.5;
			// Horizontal reinforcement bars
			for (int i = 0; i < 4; i++) {
				float bar_y = door_b + 0.03 + float(i) * 0.1;
				if (abs(p.y - bar_y) < 0.004) {
					col = metal_light;
					if (abs(p.y - bar_y) < 0.001) col = metal_hi;
				}
			}
			// Warning stripes at top
			if (p.y > door_t - 0.02) {
				float stripe2 = fract((p.x + p.y) * 20.0);
				if (stripe2 < 0.5) col = caution_yellow * 0.8;
				else col = metal_dark;
			}
			// Door handle / lock mechanism
			if (abs(p.x - door_x + 0.03) < 0.008 && abs(p.y - (door_b + 0.2)) < 0.015) {
				col = metal_hi;
				// Keycard slot
				if (abs(p.x - door_x + 0.03) < 0.004 && abs(p.y - (door_b + 0.2)) < 0.008) {
					col = vec3(0.02, 0.02, 0.02);
				}
			}
			// Status LED
			float led_pulse = step(0.5, sin(t * 2.0));
			if (abs(p.x - door_x + 0.03) < 0.003 && abs(p.y - (door_b + 0.23)) < 0.003) {
				col = warning_red * (0.3 + led_pulse * 0.7);
			}
		}
		// Door frame
		if ((abs(abs(p.x - door_x) - door_w) < 0.005 || abs(p.y - door_t) < 0.005) &&
			abs(p.x - door_x) < door_w + 0.005 && p.y > door_b && p.y < door_t + 0.005) {
			col = metal_hi * 0.6;
		}
	}

	// ══════════════════════════════════════════════
	// LAYER 4: Security camera with sweeping spotlight
	// ══════════════════════════════════════════════
	{
		float cam_x = 0.3;
		float cam_y = 0.78;
		float cam_angle = sin(t * 0.4) * 0.8; // sweep left-right

		// Camera mount bracket
		if (abs(p.x - cam_x) < 0.004 && p.y > cam_y && p.y < cam_y + 0.02) {
			col = metal_mid;
		}
		// Camera body
		float cam_body_x = cam_x + sin(cam_angle) * 0.01;
		float cam_body_y = cam_y - 0.005;
		if (abs(p.x - cam_body_x) < 0.012 && abs(p.y - cam_body_y) < 0.008) {
			col = vec3(0.1, 0.1, 0.12);
			// Lens
			float lens_d = length(vec2((p.x - cam_body_x - 0.008) * 2.0, p.y - cam_body_y));
			if (lens_d < 0.006) {
				col = vec3(0.02, 0.02, 0.05);
				if (lens_d < 0.003) col = vec3(0.1, 0.15, 0.3); // lens reflection
			}
			// Recording LED
			float rec_blink = step(0.0, sin(t * 3.0));
			if (abs(p.x - cam_body_x + 0.008) < 0.002 && abs(p.y - cam_body_y + 0.005) < 0.002) {
				col = warning_red * (0.2 + rec_blink * 0.8);
			}
		}

		// Spotlight cone on floor/wall
		float cone_dir = cam_angle;
		float cone_cx = cam_x + sin(cone_dir) * 0.3;
		float cone_w = 0.12;
		// On floor
		if (p.y < floor_y + 0.04) {
			float cone_d = abs(p.x - cone_cx);
			if (cone_d < cone_w) {
				float cone_str = (1.0 - cone_d / cone_w);
				cone_str *= cone_str; // quadratic falloff
				cone_str *= 0.2;
				col += vec3(0.3, 0.35, 0.4) * cone_str;
			}
		}
		// Light cone through air (volumetric)
		float beam_bottom = floor_y;
		float beam_top = cam_y - 0.02;
		if (p.y > beam_bottom && p.y < beam_top) {
			float beam_frac = (p.y - beam_bottom) / (beam_top - beam_bottom);
			float beam_cx2 = mix(cone_cx, cam_x, beam_frac);
			float beam_w = cone_w * (1.0 - beam_frac * 0.8);
			float beam_d = abs(p.x - beam_cx2);
			if (beam_d < beam_w) {
				float beam_str = (1.0 - beam_d / beam_w) * (1.0 - beam_frac) * 0.06;
				// Dust in beam
				beam_str *= 0.7 + noise(vec2(p.x * 50.0 + t, p.y * 30.0)) * 0.6;
				col += vec3(0.2, 0.25, 0.3) * beam_str;
			}
		}
	}

	// ══════════════════════════════════════════════
	// LAYER 5: Windows with snow outside
	// ══════════════════════════════════════════════
	for (int i = 0; i < 2; i++) {
		float fi = float(i);
		float wx = 0.15 + fi * 0.7; // left and right
		float wy = 0.5;
		float ww = 0.04;
		float wh = 0.15;

		if (abs(p.x - wx) < ww && p.y > wy && p.y < wy + wh) {
			// Window frame
			bool is_frame = abs(p.x - wx) > ww - 0.004 || p.y < wy + 0.004 || p.y > wy + wh - 0.004;
			if (is_frame) {
				col = metal_hi * 0.5;
			} else {
				// Outside — dark sky with blowing snow
				col = vec3(0.03, 0.04, 0.06); // dark arctic sky
				// Distant mountains
				float mtn = noise(vec2(p.x * 5.0, 0.0)) * 0.04 + wy + 0.04;
				if (p.y < mtn) col = vec3(0.08, 0.1, 0.13);

				// Blowing snow particles
				for (int s = 0; s < 20; s++) {
					float fs = float(s);
					float sx = fract(hash1(fs * 73.0) + t * (0.05 + hash1(fs * 31.0) * 0.08));
					float sy = fract(hash1(fs * 41.0) - t * (0.02 + hash1(fs * 59.0) * 0.03));
					// Map to window area
					float snow_px = wx - ww + 0.004 + sx * (ww * 2.0 - 0.008);
					float snow_py = wy + 0.004 + sy * (wh - 0.008);
					vec2 sc = floor(vec2(snow_px, snow_py) * R);
					if (sc.x == cell.x && sc.y == cell.y) {
						float brightness = 0.4 + hash1(fs * 89.0) * 0.4;
						col = mix(col, snow_col, brightness);
					}
				}

				// Frost on window edges
				float frost_d = min(
					min(abs(p.x - wx) - (ww - 0.008), ww),
					min(p.y - wy - 0.004, wy + wh - 0.004 - p.y)
				);
				if (frost_d < 0.015) {
					float frost = noise(p * 200.0) * noise(p * 100.0 + 50.0);
					float frost_str = smoothstep(0.015, 0.0, frost_d) * frost;
					col = mix(col, vec3(0.25, 0.3, 0.35), frost_str * 0.6);
				}
			}
			// Cross bars
			if (abs(p.x - wx) < 0.002 || abs(p.y - wy - wh * 0.5) < 0.002) {
				col = metal_hi * 0.4;
			}
		}
	}

	// ══════════════════════════════════════════════
	// LAYER 6: Ventilation grates
	// ══════════════════════════════════════════════
	for (int i = 0; i < 2; i++) {
		float fi = float(i);
		float vx = 0.38 + fi * 0.3;
		float vy = 0.22;
		float vw = 0.035;
		float vh = 0.025;

		if (abs(p.x - vx) < vw && abs(p.y - vy) < vh) {
			// Vent frame
			if (abs(p.x - vx) > vw - 0.003 || abs(p.y - vy) > vh - 0.003) {
				col = metal_mid;
			} else {
				// Horizontal slats
				float slat = fract((p.y - vy + vh) / 0.005);
				if (slat < 0.4) col = vent_col;
				else col = metal_dark * 0.3; // dark gaps between slats
			}
			// Screws in corners
			for (int cx2 = -1; cx2 <= 1; cx2 += 2) {
				for (int cy2 = -1; cy2 <= 1; cy2 += 2) {
					float screw_x = vx + float(cx2) * (vw - 0.006);
					float screw_y = vy + float(cy2) * (vh - 0.005);
					if (length(vec2(p.x - screw_x, p.y - screw_y)) < 0.003) {
						col = metal_hi * 0.6;
					}
				}
			}
		}
	}

	// ══════════════════════════════════════════════
	// LAYER 7: Fire extinguisher
	// ══════════════════════════════════════════════
	{
		float fe_x = 0.72;
		float fe_y = 0.35;
		// Cylinder body
		float fe_dx = (p.x - fe_x) / 0.01;
		float fe_dy = (p.y - fe_y) / 0.04;
		if (fe_dx * fe_dx + fe_dy * fe_dy < 1.0 && abs(fe_dx) < 0.8) {
			float shade = fe_dx * 0.4 + 0.5;
			col = mix(vec3(0.3, 0.03, 0.02), vec3(0.6, 0.08, 0.03), shade);
			// Label
			if (abs(fe_dy) < 0.3) {
				col = mix(col, vec3(0.6, 0.58, 0.5), 0.3);
			}
		}
		// Nozzle
		if (abs(p.x - fe_x) < 0.005 && p.y > fe_y + 0.04 && p.y < fe_y + 0.055) {
			col = metal_mid;
		}
		// Handle
		if (abs(p.x - fe_x + 0.008) < 0.004 && abs(p.y - (fe_y + 0.048)) < 0.006) {
			col = metal_dark;
		}
		// Bracket
		if (abs(p.x - fe_x) < 0.015 && abs(p.y - (fe_y + 0.05)) < 0.002) {
			col = metal_mid;
		}
	}

	// ══════════════════════════════════════════════
	// LAYER 8: Guard on patrol (silhouette style)
	// ══════════════════════════════════════════════
	{
		float guard_speed = 0.02;
		float guard_cycle = mod(t * guard_speed, 2.0);
		float guard_x;
		int guard_dir;
		if (guard_cycle < 1.0) {
			guard_x = 0.6 + guard_cycle * 0.25;
			guard_dir = 1;
		} else {
			guard_x = 0.85 - (guard_cycle - 1.0) * 0.25;
			guard_dir = -1;
		}
		float guard_y = floor_y;
		float gd = float(guard_dir);
		float walk_bob = sin(t * 6.0) * 0.002;

		// Boots
		for (int leg = -1; leg <= 1; leg += 2) {
			float leg_phase = sin(t * 6.0 + float(leg) * 3.14159) * 0.004;
			float boot_x = guard_x + float(leg) * 0.005 + leg_phase;
			if (abs(p.x - boot_x) < 0.004 && p.y > guard_y && p.y < guard_y + 0.02) {
				col = vec3(0.06, 0.06, 0.05);
			}
		}
		// Legs (camo pants)
		if (abs(p.x - guard_x) < 0.008 && p.y > guard_y + 0.02 && p.y < guard_y + 0.05 + walk_bob) {
			float camo = noise(vec2(p.x * 100.0, p.y * 80.0));
			col = mix(vec3(0.12, 0.14, 0.1), vec3(0.08, 0.1, 0.07), camo);
		}
		// Torso (tactical vest)
		if (abs(p.x - guard_x) < 0.01 && p.y > guard_y + 0.05 && p.y < guard_y + 0.08 + walk_bob) {
			float vest_shade = (p.x - guard_x + 0.01) / 0.02;
			col = mix(vec3(0.1, 0.12, 0.08), vec3(0.16, 0.18, 0.13), vest_shade);
			// Vest pouches
			if (abs(p.y - (guard_y + 0.065)) < 0.005 && abs(p.x - guard_x) < 0.007) {
				col *= 0.85;
			}
		}
		// Head (balaclava)
		float head_y = guard_y + 0.085 + walk_bob;
		float head_d = length(vec2((p.x - guard_x) * 1.5, p.y - head_y));
		if (head_d < 0.008) {
			col = vec3(0.08, 0.08, 0.07);
			// NVG goggles on forehead
			if (p.y > head_y + 0.003 && abs(p.x - guard_x) < 0.006) {
				col = vec3(0.04, 0.05, 0.04);
			}
		}
		// Rifle (FAMAS)
		float rifle_x = guard_x + gd * 0.012;
		if (abs(p.x - rifle_x) < 0.002 && p.y > guard_y + 0.04 && p.y < guard_y + 0.075 + walk_bob) {
			col = vec3(0.05, 0.05, 0.06);
		}
		// Rifle barrel
		if (abs(p.y - (guard_y + 0.065 + walk_bob)) < 0.0015 && p.x > rifle_x && p.x < rifle_x + gd * 0.02) {
			col = vec3(0.06, 0.06, 0.07);
		}

		// Exclamation point (alert — on beat)
		if (beat_kick > 0.5) {
			float ex_y = head_y + 0.02;
			if (abs(p.x - guard_x) < 0.003 && p.y > ex_y && p.y < ex_y + 0.015) {
				col = vec3(0.9, 0.9, 0.2);
			}
			if (abs(p.x - guard_x) < 0.003 && abs(p.y - ex_y - 0.018) < 0.002) {
				col = vec3(0.9, 0.9, 0.2); // dot under exclamation
			}
		}
	}

	// ══════════════════════════════════════════════
	// LAYER 9: Soliton radar (bottom-right corner)
	// ══════════════════════════════════════════════
	{
		float radar_x = 0.88;
		float radar_y = 0.06;
		float radar_r = 0.045;

		float rd2 = length(vec2((p.x - radar_x) * 1.6, p.y - radar_y)); // slightly oval

		if (rd2 < radar_r + 0.004) {
			if (rd2 > radar_r) {
				col = vec3(0.05, 0.15, 0.05); // border
			} else {
				// Radar background — dark green
				col = vec3(0.01, 0.04, 0.02);
				// Grid lines
				float grid_x = abs(fract((p.x - radar_x) * 25.0) - 0.5);
				float grid_y = abs(fract((p.y - radar_y) * 25.0) - 0.5);
				if (grid_x > 0.45 || grid_y > 0.45) {
					col = vec3(0.02, 0.06, 0.03);
				}
				// Sweep line
				float sweep_angle = mod(t * 2.0, 6.28318);
				float pixel_angle = atan(p.y - radar_y, (p.x - radar_x) * 1.6);
				float angle_diff = mod(sweep_angle - pixel_angle, 6.28318);
				if (angle_diff < 0.3) {
					float sweep_str = (0.3 - angle_diff) / 0.3;
					col += vec3(0.0, 0.15, 0.02) * sweep_str;
				}
				// Player blip (center)
				if (rd2 < 0.005) {
					col = vec3(0.1, 0.7, 0.2); // bright green blip
				}
				// Enemy blip (moving)
				float enemy_angle = t * 0.3;
				float enemy_r2 = 0.025;
				vec2 enemy_pos = vec2(radar_x + cos(enemy_angle) * enemy_r2 / 1.6, radar_y + sin(enemy_angle) * enemy_r2);
				if (length(vec2((p.x - enemy_pos.x) * 1.6, p.y - enemy_pos.y)) < 0.004) {
					col = vec3(0.8, 0.2, 0.1); // red enemy blip
				}
				// Cone of vision from enemy
				float vis_angle = enemy_angle + 3.14159;
				float vis_dx = p.x - enemy_pos.x;
				float vis_dy = p.y - enemy_pos.y;
				float vis_a = atan(vis_dy, vis_dx * 1.6);
				float vis_dist = length(vec2(vis_dx * 1.6, vis_dy));
				if (abs(mod(vis_a - vis_angle + 3.14159, 6.28318) - 3.14159) < 0.4 && vis_dist < 0.02 && vis_dist > 0.005) {
					col = mix(col, vec3(0.4, 0.15, 0.05), 0.2);
				}
			}
		}
	}

	// ══════════════════════════════════════════════
	// LAYER 10: Wall-mounted equipment
	// ══════════════════════════════════════════════
	// Electrical panel
	{
		float ep_x = 0.22;
		float ep_y = 0.4;
		if (abs(p.x - ep_x) < 0.02 && abs(p.y - ep_y) < 0.03) {
			col = panel_mid;
			// Panel border
			if (abs(p.x - ep_x) > 0.017 || abs(p.y - ep_y) > 0.027) col = metal_mid;
			// Warning label
			if (abs(p.x - ep_x) < 0.01 && abs(p.y - ep_y - 0.015) < 0.006) {
				col = caution_yellow * 0.6;
				// Lightning bolt symbol
				if (abs(p.x - ep_x) < 0.004 && abs(p.y - ep_y - 0.015) < 0.004) {
					col = metal_dark;
				}
			}
			// Status LEDs
			for (int led = 0; led < 3; led++) {
				float ly = ep_y - 0.01 + float(led) * 0.008;
				if (abs(p.x - ep_x + 0.01) < 0.003 && abs(p.y - ly) < 0.002) {
					if (led == 0) col = vec3(0.05, 0.4, 0.05); // green
					else if (led == 1) col = vec3(0.05, 0.4, 0.05) * (0.5 + 0.5 * sin(t * 3.0));
					else col = warning_red * 0.3;
				}
			}
		}
	}

	// ══════════════════════════════════════════════
	// LAYER 11: Cardboard box (easter egg, appears briefly)
	// ══════════════════════════════════════════════
	{
		float box_cycle = mod(t * 0.05, 4.0);
		if (box_cycle > 3.5) { // visible for 0.5 of every 4 units
			float box_x = 0.65;
			float box_y = floor_y;
			float box_w = 0.02;
			float box_h = 0.025;
			if (abs(p.x - box_x) < box_w && p.y > box_y && p.y < box_y + box_h) {
				float bx_shade = (p.x - box_x + box_w) / (box_w * 2.0);
				col = mix(vec3(0.3, 0.22, 0.1), vec3(0.45, 0.35, 0.18), bx_shade);
				// Box flaps at top
				if (p.y > box_y + box_h - 0.005) {
					col = mix(vec3(0.35, 0.25, 0.12), vec3(0.5, 0.38, 0.2), bx_shade);
				}
				// "THE ORANGE" text area
				if (abs(p.y - (box_y + 0.012)) < 0.004 && abs(p.x - box_x) < 0.012) {
					col *= 0.85;
				}
			}
		}
	}

	// ══════════════════════════════════════════════
	// GLOBAL: MGS green-gray color grade + snow particles
	// ══════════════════════════════════════════════

	// Snow particles drifting past (foreground, sparse)
	for (int i = 0; i < 12; i++) {
		float fi = float(i);
		float sx = fract(hash1(fi * 67.0) + t * 0.03 * (0.5 + hash1(fi * 23.0)));
		float sy = fract(hash1(fi * 43.0) - t * 0.015);
		float drift = sin(t * 0.5 + fi * 2.0) * 0.02;
		vec2 sc = floor(vec2(sx + drift, sy) * R);
		if (sc.x == cell.x && sc.y == cell.y) {
			col = mix(col, snow_col, 0.5 + hash1(fi * 91.0) * 0.3);
		}
	}

	// Overall MGS1 color grade — slight green desaturation
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(luma), col, 0.7); // desaturate
	col += green_tint * 0.3; // green tint
	col *= 0.95 + audio_brightness * 0.1;

	// CRT-like scanline hint (very subtle)
	float scanline = 0.97 + 0.03 * sin(cell.y * 3.14159);
	col *= scanline;

	ALBEDO = col;
}

shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

// AQUARIUM — tropical fish tank with plants, bubbles, sand, and caustics

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
	return mix(mix(hash(i), hash(i + vec2(1, 0)), f.x),
	           mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x), f.y);
}

float fbm(vec2 p) {
	float v = 0.0; float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.0; a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 uv = UV;
	float t = TIME;

	// ── Palette ──
	vec3 water_deep = vec3(0.01, 0.06, 0.12);
	vec3 water_mid = vec3(0.02, 0.10, 0.18);
	vec3 water_light = vec3(0.04, 0.16, 0.25);
	vec3 sand_dark = vec3(0.35, 0.28, 0.15);
	vec3 sand_light = vec3(0.55, 0.45, 0.25);
	vec3 plant_dark = vec3(0.02, 0.18, 0.05);
	vec3 plant_mid = vec3(0.04, 0.30, 0.08);
	vec3 plant_light = vec3(0.08, 0.45, 0.12);
	vec3 coral_pink = vec3(0.55, 0.15, 0.18);
	vec3 coral_orange = vec3(0.60, 0.30, 0.08);
	vec3 glass_edge = vec3(0.06, 0.12, 0.15);

	// Water background with gentle gradient
	float depth = 1.0 - uv.y;
	vec3 col = mix(water_light, water_deep, depth * 0.8);

	// Subtle water movement
	float water_warp = noise(vec2(uv.x * 3.0 + t * 0.1, uv.y * 2.0 + t * 0.05)) * 0.015;
	col += vec3(0.01, 0.03, 0.04) * water_warp * 5.0;

	// ══════════════════════════════════════════════
	// CAUSTICS — dancing light patterns from surface
	// ══════════════════════════════════════════════
	{
		float c1 = noise(vec2(uv.x * 8.0 + t * 0.3, uv.y * 6.0 + t * 0.15));
		float c2 = noise(vec2(uv.x * 12.0 - t * 0.2, uv.y * 8.0 + t * 0.25));
		float c3 = noise(vec2(uv.x * 6.0 + t * 0.15, uv.y * 10.0 - t * 0.1));
		float caustic = c1 * c2 + c2 * c3;
		caustic = smoothstep(0.15, 0.45, caustic);
		// Stronger on sand/bottom, fades with depth
		float caustic_str = caustic * (0.08 + 0.12 * (1.0 - uv.y));
		caustic_str *= 1.0 + audio_treble * 0.5; // shimmer with treble
		col += vec3(0.05, 0.12, 0.15) * caustic_str;
	}

	// ══════════════════════════════════════════════
	// SAND BED — bottom of tank
	// ══════════════════════════════════════════════
	float sand_level = 0.12 + noise(vec2(uv.x * 5.0, 0.0)) * 0.03;
	float sand_dune = noise(vec2(uv.x * 15.0, 1.0)) * 0.015;
	float sand_top = sand_level + sand_dune;

	if (uv.y < sand_top) {
		float sand_n = noise(vec2(uv.x * 80.0, uv.y * 80.0));
		float grain = noise(vec2(uv.x * 200.0, uv.y * 200.0));
		col = mix(sand_dark, sand_light, sand_n * 0.6 + grain * 0.2);
		// Ripple marks on sand
		float ripple = sin(uv.x * 60.0 + noise(vec2(uv.x * 10.0, 0.0)) * 5.0) * 0.5 + 0.5;
		col = mix(col, sand_dark, ripple * 0.15 * smoothstep(0.0, sand_top, uv.y));
		// Small pebbles
		for (int i = 0; i < 8; i++) {
			float fi = float(i);
			float px = hash1(fi * 73.0) * 0.9 + 0.05;
			float py = hash1(fi * 41.0) * sand_level * 0.6 + 0.01;
			float pr = 0.003 + hash1(fi * 59.0) * 0.004;
			float pd = length(vec2(uv.x - px, (uv.y - py) * 2.0));
			if (pd < pr) {
				float pshade = pd / pr;
				vec3 pebble_col = vec3(0.25 + hash1(fi * 31.0) * 0.2, 0.22 + hash1(fi * 17.0) * 0.15, 0.15);
				col = mix(pebble_col * (1.0 - pshade * 0.3), col, pshade);
			}
		}
	}

	// ══════════════════════════════════════════════
	// AQUATIC PLANTS — swaying kelp/grass
	// ══════════════════════════════════════════════
	for (int i = 0; i < 10; i++) {
		float fi = float(i);
		float base_x = 0.05 + hash1(fi * 67.0) * 0.9;
		float plant_h = 0.12 + hash1(fi * 89.0) * 0.2;
		float plant_w = 0.006 + hash1(fi * 37.0) * 0.008;

		if (uv.y < sand_top + plant_h && uv.y > sand_top * 0.8) {
			float grow = (uv.y - sand_top * 0.8) / plant_h;
			// Sway with time + audio
			float sway = sin(t * 0.8 + fi * 2.0 + grow * 3.0) * grow * 0.025;
			sway += sin(t * 1.3 + fi * 1.5) * grow * 0.01;
			sway += audio_bass * grow * 0.015; // react to bass

			float dx = abs(uv.x - base_x - sway);
			float width = plant_w * (1.0 - grow * 0.5); // taper toward top

			if (dx < width) {
				float shade = dx / width;
				float height_shade = grow;
				vec3 pc = mix(plant_dark, plant_light, height_shade * 0.7);
				// Leaf veins
				float vein = smoothstep(0.0, 0.3, shade);
				pc = mix(pc, plant_mid, vein * 0.3);
				// Edge transparency fade
				float alpha = smoothstep(width, width * 0.5, dx);
				col = mix(col, pc, alpha * 0.9);
			}

			// Side leaves
			for (int lf = 0; lf < 3; lf++) {
				float lfi = float(lf);
				float leaf_y = sand_top + (plant_h * (0.3 + lfi * 0.25));
				if (abs(uv.y - leaf_y) < 0.015) {
					float leaf_dir = (hash1(fi * 53.0 + lfi) > 0.5) ? 1.0 : -1.0;
					float leaf_sway = sway * 0.5;
					float leaf_x = base_x + leaf_sway + leaf_dir * 0.01;
					float leaf_dx = (uv.x - leaf_x) * leaf_dir;
					float leaf_dy = abs(uv.y - leaf_y);
					if (leaf_dx > 0.0 && leaf_dx < 0.02 && leaf_dy < 0.006 * (1.0 - leaf_dx / 0.02)) {
						vec3 lc = mix(plant_mid, plant_light, leaf_dx / 0.02);
						col = mix(col, lc, 0.85);
					}
				}
			}
		}
	}

	// ══════════════════════════════════════════════
	// CORAL — decorative clusters
	// ══════════════════════════════════════════════
	// Brain coral (left)
	{
		float cx = 0.18; float cy = sand_top + 0.02;
		float cr = 0.03;
		float cd = length(vec2((uv.x - cx) * 1.2, uv.y - cy));
		if (cd < cr && uv.y > sand_top * 0.7) {
			float brain = noise(vec2(uv.x * 80.0 + 10.0, uv.y * 80.0));
			float ridges = sin(brain * 20.0) * 0.5 + 0.5;
			vec3 cc = mix(coral_pink, coral_pink * 0.6, ridges);
			// Rounded shading
			float shade = cd / cr;
			cc *= 1.0 - shade * 0.4;
			col = mix(col, cc, smoothstep(cr, cr * 0.7, cd));
		}
	}
	// Branching coral (right)
	{
		float cx2 = 0.78; float cy2 = sand_top;
		for (int b = 0; b < 5; b++) {
			float fb = float(b);
			float angle = -0.3 + fb * 0.35;
			float branch_h = 0.04 + hash1(fb * 61.0) * 0.03;
			for (float seg = 0.0; seg < 1.0; seg += 0.02) {
				float bx = cx2 + sin(angle) * seg * branch_h;
				float by = cy2 + cos(angle) * seg * branch_h;
				float bw = 0.004 * (1.0 - seg * 0.6);
				float bd = length(vec2(uv.x - bx, uv.y - by));
				if (bd < bw) {
					float bshade = bd / bw;
					vec3 bc = mix(coral_orange, coral_orange * 1.3, 1.0 - bshade);
					bc *= 0.9 + audio_mid * 0.2;
					col = mix(col, bc, (1.0 - bshade) * 0.9);
				}
			}
		}
	}

	// ══════════════════════════════════════════════
	// TREASURE CHEST — half-buried in sand
	// ══════════════════════════════════════════════
	{
		float tx = 0.45; float ty = sand_top - 0.005;
		float tw = 0.025; float th = 0.02;
		// Chest body
		if (abs(uv.x - tx) < tw && uv.y > ty && uv.y < ty + th) {
			float chest_shade = (uv.x - tx + tw) / (tw * 2.0);
			col = mix(vec3(0.25, 0.12, 0.03), vec3(0.40, 0.20, 0.06), chest_shade);
			// Metal bands
			if (abs(uv.x - tx) < tw * 0.95) {
				float band = abs(fract((uv.x - tx + tw) / (tw * 0.5)) - 0.5);
				if (band > 0.4) col = vec3(0.35, 0.30, 0.10);
			}
			// Lock
			if (abs(uv.x - tx) < 0.005 && abs(uv.y - ty - th * 0.5) < 0.005) {
				col = vec3(0.50, 0.42, 0.12);
			}
		}
		// Lid (slightly open, glowing)
		float lid_open = 0.008 + sin(t * 0.5) * 0.002;
		if (abs(uv.x - tx) < tw && uv.y > ty + th && uv.y < ty + th + 0.008) {
			float lid_shade = (uv.x - tx + tw) / (tw * 2.0);
			col = mix(vec3(0.28, 0.14, 0.04), vec3(0.42, 0.22, 0.07), lid_shade);
		}
		// Gold glow from inside
		if (abs(uv.x - tx) < tw * 0.6 && uv.y > ty + th && uv.y < ty + th + lid_open) {
			float glow = (1.0 - abs(uv.x - tx) / (tw * 0.6));
			col = mix(col, vec3(0.7, 0.55, 0.1), glow * 0.6);
		}
	}

	// ══════════════════════════════════════════════
	// FISH — swimming tropical fish
	// ══════════════════════════════════════════════
	for (int i = 0; i < 8; i++) {
		float fi = float(i);
		float speed = 0.03 + hash1(fi * 73.0) * 0.04;
		float swim_y = 0.25 + hash1(fi * 41.0) * 0.55;
		float swim_dir = (hash1(fi * 97.0) > 0.5) ? 1.0 : -1.0;
		float phase = hash1(fi * 31.0) * 6.28;

		// Fish position — horizontal swimming with vertical bob
		float fx = fract(swim_dir * t * speed + hash1(fi * 53.0));
		float fy = swim_y + sin(t * 1.5 + phase) * 0.02;
		fy += sin(t * 0.4 + fi * 2.0) * 0.01; // gentle drift

		// Body dimensions
		float body_w = 0.018 + hash1(fi * 19.0) * 0.012;
		float body_h = body_w * 0.45;

		float dx = (uv.x - fx) * swim_dir; // flip based on direction
		float dy = uv.y - fy;

		// Elliptical body
		float body_d = (dx * dx) / (body_w * body_w) + (dy * dy) / (body_h * body_h);

		if (body_d < 1.0) {
			// Fish colors — each fish unique
			vec3 fish_col1;
			vec3 fish_col2;
			int fish_type = int(mod(fi, 4.0));
			if (fish_type == 0) { // clownfish
				fish_col1 = vec3(0.85, 0.35, 0.02);
				fish_col2 = vec3(0.95, 0.95, 0.95);
			} else if (fish_type == 1) { // blue tang
				fish_col1 = vec3(0.05, 0.20, 0.65);
				fish_col2 = vec3(0.60, 0.55, 0.05);
			} else if (fish_type == 2) { // angelfish
				fish_col1 = vec3(0.70, 0.65, 0.10);
				fish_col2 = vec3(0.10, 0.10, 0.10);
			} else { // neon tetra
				fish_col1 = vec3(0.05, 0.50, 0.70);
				fish_col2 = vec3(0.80, 0.15, 0.10);
			}

			// Stripe pattern
			float stripe = sin(dx / body_w * 12.0 + fi * 3.0);
			vec3 fc = mix(fish_col1, fish_col2, smoothstep(-0.2, 0.2, stripe));

			// Shading — darker on bottom
			fc *= 0.85 + dy / body_h * 0.15;
			// Belly highlight
			if (dy < -body_h * 0.3) fc = mix(fc, fc * 1.3, 0.3);

			col = mix(col, fc, smoothstep(1.0, 0.6, body_d));

			// Eye
			float eye_x = dx - body_w * 0.55;
			float eye_y = dy - body_h * 0.15;
			float eye_d = length(vec2(eye_x, eye_y));
			if (eye_d < 0.004) {
				col = vec3(0.02);
				if (eye_d < 0.002) col = vec3(0.15, 0.15, 0.2); // pupil highlight
			}
		}

		// Tail fin
		float tail_x = dx + body_w;
		float tail_w = body_w * 0.5;
		float tail_wag = sin(t * 8.0 + phase) * 0.003;
		if (tail_x > 0.0 && tail_x < tail_w) {
			float tail_spread = tail_x / tail_w;
			float tail_h_max = body_h * (0.3 + tail_spread * 0.9);
			if (abs(dy - tail_wag * tail_spread) < tail_h_max) {
				float tail_d = abs(dy - tail_wag * tail_spread) / tail_h_max;
				int fish_type2 = int(mod(fi, 4.0));
				vec3 tail_col;
				if (fish_type2 == 0) tail_col = vec3(0.80, 0.30, 0.02);
				else if (fish_type2 == 1) tail_col = vec3(0.04, 0.15, 0.50);
				else if (fish_type2 == 2) tail_col = vec3(0.60, 0.55, 0.08);
				else tail_col = vec3(0.04, 0.40, 0.60);
				col = mix(col, tail_col * 0.8, (1.0 - tail_d) * 0.7 * (1.0 - tail_spread * 0.3));
			}
		}

		// Dorsal fin (top)
		if (dx > -body_w * 0.3 && dx < body_w * 0.2 && dy > body_h * 0.5) {
			float fin_h = 0.008;
			float fin_shape = 1.0 - abs(dx / (body_w * 0.25));
			if (dy - body_h * 0.5 < fin_h * fin_shape && fin_shape > 0.0) {
				int fish_type3 = int(mod(fi, 4.0));
				vec3 fin_col;
				if (fish_type3 == 0) fin_col = vec3(0.85, 0.35, 0.02);
				else if (fish_type3 == 1) fin_col = vec3(0.05, 0.20, 0.65);
				else if (fish_type3 == 2) fin_col = vec3(0.60, 0.55, 0.08);
				else fin_col = vec3(0.05, 0.45, 0.65);
				col = mix(col, fin_col * 0.7, 0.6);
			}
		}
	}

	// ══════════════════════════════════════════════
	// BUBBLES — rising with audio
	// ══════════════════════════════════════════════
	for (int i = 0; i < 20; i++) {
		float fi = float(i);
		float bx = hash1(fi * 83.0) * 0.8 + 0.1;
		float bubble_speed = 0.04 + hash1(fi * 47.0) * 0.05;
		bubble_speed *= 1.0 + audio_bass * 0.5; // more bubbles with bass
		float by = fract(hash1(fi * 29.0) + t * bubble_speed);
		// Wobble sideways
		bx += sin(t * 2.0 + fi * 1.5) * 0.008;
		float br = 0.003 + hash1(fi * 61.0) * 0.005;
		// Grow as they rise
		br *= 0.7 + by * 0.5;

		float bd = length(vec2(uv.x - bx, uv.y - by));
		if (bd < br && by > sand_top) {
			// Bubble — transparent with highlight
			float rim = smoothstep(br * 0.5, br, bd);
			col = mix(col, col * 1.15 + vec3(0.02, 0.06, 0.08), rim * 0.5);
			// Specular highlight
			float highlight = length(vec2(uv.x - bx + br * 0.3, uv.y - by + br * 0.3));
			if (highlight < br * 0.3) {
				col = mix(col, vec3(0.5, 0.7, 0.8), (1.0 - highlight / (br * 0.3)) * 0.6);
			}
		}
	}

	// ══════════════════════════════════════════════
	// LIGHT RAYS — from surface
	// ══════════════════════════════════════════════
	{
		for (int i = 0; i < 5; i++) {
			float fi = float(i);
			float ray_x = 0.15 + fi * 0.18 + sin(t * 0.2 + fi) * 0.03;
			float ray_w = 0.015 + sin(t * 0.3 + fi * 2.0) * 0.005;
			float ray_d = abs(uv.x - ray_x);
			if (ray_d < ray_w) {
				float ray_str = (1.0 - ray_d / ray_w);
				ray_str *= ray_str;
				ray_str *= uv.y * 0.12; // stronger at top
				ray_str *= 0.7 + audio_brightness * 0.5;
				col += vec3(0.04, 0.08, 0.10) * ray_str;
			}
		}
	}

	// ══════════════════════════════════════════════
	// WATER SURFACE — top ripple line
	// ══════════════════════════════════════════════
	{
		float surface_y = 0.92;
		float ripple_offset = noise(vec2(uv.x * 10.0 + t * 0.5, t * 0.3)) * 0.01;
		float surface = surface_y + ripple_offset;
		if (uv.y > surface) {
			// Above surface — air/light
			col = mix(col, vec3(0.15, 0.25, 0.30), smoothstep(surface, surface + 0.03, uv.y));
		}
		// Surface highlight line
		if (abs(uv.y - surface) < 0.003) {
			float surf_bright = 0.5 + noise(vec2(uv.x * 20.0 + t, 0.0)) * 0.5;
			col = mix(col, vec3(0.3, 0.5, 0.55), surf_bright * 0.6);
		}
	}

	// ══════════════════════════════════════════════
	// GLASS EDGES — aquarium frame
	// ══════════════════════════════════════════════
	{
		float frame = 0.015;
		float edge_l = smoothstep(frame, 0.0, uv.x);
		float edge_r = smoothstep(frame, 0.0, 1.0 - uv.x);
		float edge_b = smoothstep(frame, 0.0, uv.y);
		float edge_t = smoothstep(frame, 0.0, 1.0 - uv.y);
		float edge = max(max(edge_l, edge_r), max(edge_b, edge_t));
		col = mix(col, glass_edge, edge * 0.7);
		// Glass reflection
		float refl = smoothstep(0.03, 0.0, uv.x) * 0.15;
		refl += smoothstep(0.03, 0.0, 1.0 - uv.x) * 0.08;
		col += vec3(0.08, 0.12, 0.14) * refl;
	}

	// ══════════════════════════════════════════════
	// GLOBAL: underwater color grade
	// ══════════════════════════════════════════════
	// Depth fog — darker at bottom
	col = mix(col, water_deep, (1.0 - uv.y) * 0.15);
	// Slight blue-green tint
	float luma = dot(col, vec3(0.299, 0.587, 0.114));
	col = mix(vec3(luma) * vec3(0.7, 0.9, 1.0), col, 0.8);
	// Audio energy brightness
	col *= 0.92 + audio_energy * 0.15;

	ALBEDO = col;
}

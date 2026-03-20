shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

// Final Fantasy victory screen — starfield swirl, fanfare energy, party silhouettes
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

uniform sampler2D sprite_sheet : filter_nearest;  // CC0 RPG sprite sheet (256x128)

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }

float noise(vec2 p) {
	vec2 i = floor(p); vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i+vec2(1,0)), f.x), mix(hash(i+vec2(0,1)), hash(i+vec2(1,1)), f.x), f.y);
}

vec2 px(vec2 uv, float r) { return floor(uv * r) / r; }

void fragment() {
	vec2 uv = UV;
	float R = 96.0;
	vec2 p = px(uv, R);
	vec2 cell = floor(uv * R);
	float ch = hash(cell);
	float t = TIME;

	// ── Deep blue/black background (FF victory blue) ──
	vec3 col = vec3(0.0, 0.0, 0.04);

	// ── Rotating star swirl (iconic FF victory background) ──
	vec2 center = vec2(0.5, 0.55);
	vec2 d = p - center;
	float r = length(d);
	float angle = atan(d.y, d.x);

	// Swirl rotation — audio drives speed
	float swirl_speed = 0.3 + audio_energy * 0.5;
	float swirl_angle = angle - t * swirl_speed + r * 4.0;

	// Radial rays — the spinning light beams
	float rays = sin(swirl_angle * 6.0) * 0.5 + 0.5;
	rays = step(0.55, rays); // hard pixel edge
	float ray_fade = smoothstep(0.5, 0.1, r) * smoothstep(0.0, 0.05, r);
	ray_fade = floor(ray_fade * 5.0) / 5.0; // quantize

	// Ray color — golden/white like FF fanfare
	vec3 ray_col = mix(vec3(0.6, 0.5, 0.1), vec3(1.0, 0.95, 0.6), ray_fade);
	ray_col += beat_kick * vec3(0.2, 0.15, 0.0);
	col += ray_col * rays * ray_fade * (0.3 + audio_energy * 0.3);

	// ── Stars scattered in the swirl ──
	for (int i = 0; i < 60; i++) {
		float fi = float(i);
		float s = hash(vec2(fi * 73.1, fi * 41.7));
		float s2 = hash(vec2(fi * 31.3, fi * 97.1));

		// Orbit around center
		float star_r = 0.05 + s * 0.42;
		float star_angle = s2 * 6.28 + t * (0.2 + s * 0.4) * swirl_speed;
		float star_x = center.x + cos(star_angle) * star_r;
		float star_y = center.y + sin(star_angle) * star_r * 0.7; // squished orbit

		vec2 scell = floor(vec2(star_x, star_y) * R);
		if (scell.x == cell.x && scell.y == cell.y) {
			float twinkle = sin(t * (3.0 + s * 5.0) + fi * 2.0) * 0.5 + 0.5;
			twinkle *= 0.5 + audio_treble * 0.5;
			float brightness = 0.5 + s * 0.5;
			vec3 star_col = mix(vec3(0.8, 0.8, 1.0), vec3(1.0, 0.9, 0.5), s);
			col = mix(col, star_col * brightness, twinkle);
		}
	}

	// ── "VICTORY" text area (top) ──
	// V
	float tx = 0.22; float ty = 0.88; float tw = 0.008; float th = 0.05;
	bool is_text = false;
	// V left stroke
	if (p.x > tx && p.x < tx + tw && p.y > ty - th && p.y < ty) is_text = true;
	if (p.x > tx + tw && p.x < tx + tw * 2.0 && p.y > ty - th && p.y < ty - th + tw * 2.0) is_text = true;
	// V right stroke
	if (p.x > tx + tw * 3.0 && p.x < tx + tw * 4.0 && p.y > ty - th && p.y < ty) is_text = true;
	if (p.x > tx + tw * 2.0 && p.x < tx + tw * 3.0 && p.y > ty - th && p.y < ty - th + tw * 2.0) is_text = true;
	tx += 0.045;
	// I
	if (p.x > tx + tw && p.x < tx + tw * 2.0 && p.y > ty - th && p.y < ty) is_text = true;
	tx += 0.03;
	// C
	if (p.x > tx && p.x < tx + tw && p.y > ty - th && p.y < ty) is_text = true;
	if (p.x > tx && p.x < tx + tw * 3.0 && p.y > ty - tw && p.y < ty) is_text = true;
	if (p.x > tx && p.x < tx + tw * 3.0 && p.y > ty - th && p.y < ty - th + tw) is_text = true;
	tx += 0.04;
	// T
	if (p.x > tx && p.x < tx + tw * 4.0 && p.y > ty - tw && p.y < ty) is_text = true;
	if (p.x > tx + tw * 1.5 && p.x < tx + tw * 2.5 && p.y > ty - th && p.y < ty) is_text = true;
	tx += 0.05;
	// O
	if (p.x > tx && p.x < tx + tw && p.y > ty - th && p.y < ty) is_text = true;
	if (p.x > tx + tw * 3.0 && p.x < tx + tw * 4.0 && p.y > ty - th && p.y < ty) is_text = true;
	if (p.x > tx && p.x < tx + tw * 4.0 && p.y > ty - tw && p.y < ty) is_text = true;
	if (p.x > tx && p.x < tx + tw * 4.0 && p.y > ty - th && p.y < ty - th + tw) is_text = true;
	tx += 0.05;
	// R
	if (p.x > tx && p.x < tx + tw && p.y > ty - th && p.y < ty) is_text = true;
	if (p.x > tx && p.x < tx + tw * 3.0 && p.y > ty - tw && p.y < ty) is_text = true;
	if (p.x > tx && p.x < tx + tw * 3.0 && p.y > ty - th * 0.5 - tw * 0.5 && p.y < ty - th * 0.5 + tw * 0.5) is_text = true;
	if (p.x > tx + tw * 2.0 && p.x < tx + tw * 3.0 && p.y > ty - th * 0.5 && p.y < ty) is_text = true;
	if (p.x > tx + tw * 2.0 && p.x < tx + tw * 3.0 && p.y > ty - th && p.y < ty - th * 0.5) is_text = true;
	tx += 0.04;
	// Y
	if (p.x > tx && p.x < tx + tw && p.y > ty - tw * 2.0 && p.y < ty) is_text = true;
	if (p.x > tx + tw * 3.0 && p.x < tx + tw * 4.0 && p.y > ty - tw * 2.0 && p.y < ty) is_text = true;
	if (p.x > tx + tw * 1.5 && p.x < tx + tw * 2.5 && p.y > ty - th && p.y < ty - tw) is_text = true;

	if (is_text) {
		// Pulsing golden text
		float text_pulse = 0.8 + 0.2 * sin(t * 2.0) + beat_kick * 0.3;
		col = vec3(1.0, 0.85, 0.2) * text_pulse;
	}

	// ── EXP / Gil counter area (bottom right) ──
	float box_x = 0.6; float box_y = 0.08;
	float box_w = 0.35; float box_h = 0.18;
	if (p.x > box_x && p.x < box_x + box_w && p.y > box_y && p.y < box_y + box_h) {
		// Dark blue UI box with border
		col = vec3(0.0, 0.0, 0.08);
		// Border
		if (p.x < box_x + 0.01 || p.x > box_x + box_w - 0.01 ||
			p.y < box_y + 0.01 || p.y > box_y + box_h - 0.01) {
			col = vec3(0.5, 0.5, 0.6);
		}
		// Inner white border
		float ib = 0.015;
		if ((p.x > box_x + ib - 0.005 && p.x < box_x + ib) ||
			(p.x > box_x + box_w - ib && p.x < box_x + box_w - ib + 0.005) ||
			(p.y > box_y + ib - 0.005 && p.y < box_y + ib) ||
			(p.y > box_y + box_h - ib && p.y < box_y + box_h - ib + 0.005)) {
			col = vec3(0.7, 0.7, 0.8);
		}

		// Scrolling numbers effect (EXP counting up)
		float num_y1 = box_y + 0.12;
		float num_y2 = box_y + 0.06;
		if (p.y > num_y1 - 0.008 && p.y < num_y1 + 0.008 && p.x > box_x + 0.05 && p.x < box_x + 0.3) {
			// Simulated number blocks
			float nx = floor((p.x - box_x - 0.05) * 200.0);
			float digit = floor(mod(nx * 0.3 + t * 15.0, 10.0));
			float on = step(0.3, hash(vec2(nx, digit)));
			col = mix(col, vec3(1.0, 1.0, 1.0), on * 0.9);
		}
		if (p.y > num_y2 - 0.008 && p.y < num_y2 + 0.008 && p.x > box_x + 0.05 && p.x < box_x + 0.25) {
			float nx = floor((p.x - box_x - 0.05) * 200.0);
			float digit = floor(mod(nx * 0.7 + t * 8.0, 10.0));
			float on = step(0.3, hash(vec2(nx + 100.0, digit)));
			col = mix(col, vec3(1.0, 0.85, 0.3), on * 0.9); // gold for Gil
		}

		// "EXP" label
		if (p.x > box_x + 0.02 && p.x < box_x + 0.045 && p.y > num_y1 - 0.006 && p.y < num_y1 + 0.006) {
			col = vec3(0.3, 0.8, 0.4); // green label
		}
		// "Gil" label
		if (p.x > box_x + 0.02 && p.x < box_x + 0.045 && p.y > num_y2 - 0.006 && p.y < num_y2 + 0.006) {
			col = vec3(1.0, 0.85, 0.3); // gold label
		}
	}

	// ── Party characters (texture-sampled from CC0 sprite sheet) ──
	// Sprite sheet: 256x128, 7 characters, each ~32x64 area with 16x16 frames
	// Layout: characters in columns, walk frames in rows
	// We sample 3 different characters and animate walk cycles

	// Helper: sample a sprite from the sheet
	// char_col = character column (0-6), frame = animation frame (0-2)
	// sheet is 256x128, each char block is ~36x64, frames are 16x16
	// Row 0 (top half): front-facing frames
	// Row 1 (bottom half): side/back frames
	{
		// Character positions on screen and which sprite to use
		// Red character (col 0), Gold character (col 1), Blue character (col 2)
		float char_xs[3];
		char_xs[0] = 0.22;  // left
		char_xs[1] = 0.42;  // center
		char_xs[2] = 0.60;  // right

		int char_ids[3];
		char_ids[0] = 0;  // red warrior
		char_ids[1] = 1;  // gold character
		char_ids[2] = 2;  // blue mage

		// base_male.png: 126x144, 7 cols x 8 rows, 18x18 frames, alpha transparent
		// Row 0: front idle+walk, Row 2: left, Row 4: right, Row 6: back
		// Cols: idle, walk1, walk2, walk3, walk4, walk5, walk6
		float FW = 18.0;  // frame width/height in pixels
		float SW = 126.0;  // sheet width
		float SH = 144.0;  // sheet height

		float spr_scale = 2.5 / R;  // each sprite pixel = 2.5 screen cells

		for (int c = 0; c < 3; c++) {
			float cx_pos = char_xs[c];
			float cy_pos = 0.30;
			if (c == 1) cy_pos += abs(sin(t * 3.0)) * 0.012;

			float sprite_w = FW * spr_scale;
			float sprite_h = FW * spr_scale;
			float lx = p.x - cx_pos;
			float ly = p.y - cy_pos;

			if (lx >= 0.0 && lx < sprite_w && ly >= 0.0 && ly < sprite_h) {
				int spx = int(lx / spr_scale);
				int spy = int(FW) - 1 - int(ly / spr_scale); // flip Y

				// Walk animation: cycle through columns 0-6
				int frame_col = int(mod(t * 4.0 + float(c) * 2.0, 7.0));
				// Each character uses a different row pair for variety
				int frame_row = c * 2;  // char 0=front, char 1=left, char 2=right

				float su = (float(frame_col) * FW + float(spx) + 0.5) / SW;
				float sv = (float(frame_row) * FW + float(spy) + 0.5) / SH;

				vec4 texel = texture(sprite_sheet, vec2(su, sv));

				if (texel.a > 0.3) {
					col = texel.rgb;
				}
			}
		}
	}

	// ── Victory sparkles / confetti ──
	for (int i = 0; i < 30; i++) {
		float fi = float(i);
		float s = hash(vec2(fi * 67.3, fi * 29.7));
		float s2 = hash(vec2(fi * 43.1, fi * 83.3));
		float sx = s;
		float sy = fract(0.8 - (s2 * 3.0 + t * (0.05 + s * 0.08)));
		float drift = sin(t * (1.0 + s * 2.0) + fi) * 0.03;

		vec2 scell = floor(vec2(sx + drift, sy) * R);
		if (scell.x == cell.x && scell.y == cell.y && sy > 0.15) {
			// Colored confetti — gold, white, blue
			vec3 conf_col;
			if (s < 0.33) conf_col = vec3(1.0, 0.85, 0.2);       // gold
			else if (s < 0.66) conf_col = vec3(0.9, 0.92, 1.0);   // white
			else conf_col = vec3(0.3, 0.5, 1.0);                    // blue
			float flash = 0.5 + 0.5 * sin(t * (4.0 + s * 3.0) + fi);
			col = mix(col, conf_col, flash * 0.8);
		}
	}

	// ── Ground line ──
	if (abs(p.y - 0.28) < 0.005) {
		col = mix(col, vec3(0.3, 0.3, 0.4), 0.5);
	}

	// ── Beat flash (fanfare accent) ──
	col += beat_snare * 0.08 * vec3(1.0, 0.9, 0.5);

	col *= 1.0 + audio_brightness * 0.3;

	ALBEDO = col;
}

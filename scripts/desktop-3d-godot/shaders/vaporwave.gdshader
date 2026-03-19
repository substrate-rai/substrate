shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

// Vaporwave — infinite grid floor + sunset gradient + VHS scanlines
// Reactivity: audio_mid → grid pulse, beat_intensity → chromatic flash
// Deep audio: sub_bass → floor heave, low_mid → line thickness, treble → scanlines
//             kick → sun pulse, snare → grid flash, hihat → star twinkle
//             presence → sun glow, warmth → sky temp, brightness → luminance, brilliance → grid shimmer

global uniform float audio_mid;
global uniform float audio_bass;
global uniform float audio_energy;
global uniform float beat_intensity;
global uniform vec3 cursor_world_pos;
global uniform float audio_treble;
global uniform float audio_sub_bass;
global uniform float audio_low_mid;
global uniform float audio_presence;
global uniform float audio_brilliance;
global uniform float beat_kick;
global uniform float beat_snare;
global uniform float beat_hihat;
global uniform float audio_warmth;
global uniform float audio_brightness;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = UV;

	// Split: top half = sky, bottom half = grid floor
	vec3 color = vec3(0.0);

	// Horizon line modulated by sub-bass (slight heave)
	float horizon = 0.45 + audio_sub_bass * 0.02;

	if (uv.y < horizon) {
		// ── Grid floor (perspective) ──
		float perspective = horizon - uv.y;
		float depth = 1.0 / max(perspective, 0.001);

		// Grid scrolling forward
		float grid_z = depth * 0.5 + TIME * 0.8;
		float grid_x = (uv.x - 0.5) * depth * 2.0;

		// Grid lines — low_mid thickens lines
		float line_thick = 0.02 * (1.0 + audio_low_mid * 2.0);
		float line_x = smoothstep(line_thick, 0.0, abs(fract(grid_x) - 0.5) - 0.47);
		float line_z = smoothstep(line_thick, 0.0, abs(fract(grid_z * 0.5) - 0.5) - 0.47);
		float grid = max(line_x, line_z);

		// Audio pulse on grid
		float pulse = 1.0 + audio_mid * 1.5;
		grid *= pulse;

		// Grid color — magenta/cyan
		vec3 grid_color = mix(vec3(1.0, 0.0, 0.8), vec3(0.0, 1.0, 1.0), fract(grid_z * 0.1));
		grid_color = mix(grid_color, vec3(1.0), beat_intensity * 0.5);

		// Snare flash — grid color toward white
		grid_color = mix(grid_color, vec3(1.0), beat_snare * 0.6);

		// Floor base color (dark purple)
		color = mix(vec3(0.05, 0.0, 0.1), grid_color, grid);

		// Brilliance — sparkling grid shimmer
		color += audio_brilliance * 0.2 * grid * sin(grid_z * 10.0 + TIME * 3.0);

		// Depth fog
		float fog = 1.0 - smoothstep(0.0, 25.0, depth);
		color *= fog;

	} else {
		// ── Sunset sky ──
		float sky_t = (uv.y - horizon) / (1.0 - horizon);

		// Gradient: horizon orange → magenta → deep purple → dark blue
		// Warmth shifts sky color temperature: warmer = more orange, cooler = more purple
		vec3 c1 = mix(vec3(0.8, 0.3, 0.6), vec3(1.0, 0.5, 0.1), 0.5 + audio_warmth * 0.5);  // horizon
		vec3 c2 = mix(vec3(0.6, 0.1, 0.7), vec3(1.0, 0.2, 0.4), audio_warmth * 0.4);          // mid warm
		vec3 c3 = vec3(0.3, 0.05, 0.4); // purple
		vec3 c4 = vec3(0.02, 0.0, 0.08); // dark top

		if (sky_t < 0.15) {
			color = mix(c1, c2, sky_t / 0.15);
		} else if (sky_t < 0.4) {
			color = mix(c2, c3, (sky_t - 0.15) / 0.25);
		} else {
			color = mix(c3, c4, (sky_t - 0.4) / 0.6);
		}

		// Sun disk — kick pulse expands and flashes
		vec2 sun_center = vec2(0.5, horizon + 0.03);
		float sun_radius = 0.08 + beat_kick * 0.03;
		float sun_dist = length((uv - sun_center) * vec2(1.0, 1.5));
		float sun = smoothstep(sun_radius, 0.0, sun_dist);
		// Horizontal stripe cutouts (retro sun)
		float stripes = step(0.5, fract(uv.y * 80.0));
		sun *= mix(1.0, stripes, smoothstep(0.0, sun_radius, sun_dist));
		color = mix(color, vec3(1.0, 0.85, 0.3), sun);

		// Kick bright flash on sun area
		color += beat_kick * 0.3 * vec3(1.0, 0.6, 0.3) * smoothstep(sun_radius * 2.0, 0.0, sun_dist);

		// Presence — sun glow halo
		color += audio_presence * 0.15 * vec3(1.0, 0.5, 0.3) * exp(-sun_dist * 8.0);

		// Stars in upper sky
		if (sky_t > 0.5) {
			float star = step(0.998, hash(floor(uv * 200.0)));
			float twinkle = 0.5 + 0.5 * sin(TIME * 3.0 + hash(floor(uv * 200.0)) * 100.0);
			// Hi-hat burst amplifies star twinkle
			float star_brightness = twinkle * (1.0 + beat_hihat * 3.0);
			color += vec3(star * star_brightness * 0.6);
		}
	}

	// ── VHS scanlines — treble modulates depth ──
	float scanline_depth = 0.05 * (1.0 + audio_treble * 1.5);
	float scanline = 1.0 - scanline_depth + scanline_depth * sin(uv.y * 800.0);
	color *= scanline;

	// ── Chromatic flash on beat ──
	if (beat_intensity > 0.3) {
		color += vec3(beat_intensity * 0.1, 0.0, beat_intensity * 0.15);
	}

	// ── Film grain ──
	float grain = (hash(uv + fract(TIME)) - 0.5) * 0.06;
	color += grain;

	// ── Overall luminance from audio brightness ──
	color *= (0.7 + audio_brightness * 0.6);

	ALBEDO = max(color, vec3(0.0));
	ALPHA = 1.0;
}

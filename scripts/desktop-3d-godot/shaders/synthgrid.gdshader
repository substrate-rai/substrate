shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

// Synthgrid — retro perspective grid with audio-reactive pillars of light
global uniform float audio_bass;
global uniform float audio_mid;
global uniform float audio_treble;
global uniform float audio_energy;
global uniform float beat_intensity;
global uniform float audio_sub_bass;
global uniform float audio_low_mid;
global uniform float audio_upper_mid;
global uniform float audio_presence;
global uniform float audio_brilliance;
global uniform float beat_kick;
global uniform float beat_snare;
global uniform float beat_hihat;
global uniform float audio_warmth;
global uniform float audio_brightness;
global uniform float audio_flux;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void fragment() {
	vec2 uv = (UV - 0.5) * 2.0;
	uv.x *= 1.777;

	// Perspective transform — looking down at a grid receding into distance
	float horizon = -0.1 + audio_sub_bass * 0.05;
	float perspective_y = uv.y - horizon;

	vec3 col = vec3(0.0);

	// Sky gradient — warmth shifts toward orange tones
	float sky = smoothstep(horizon, horizon + 0.8, uv.y);
	vec3 sky_cold = mix(vec3(0.15, 0.0, 0.3), vec3(0.0, 0.1, 0.3), audio_mid);
	vec3 sky_warm = mix(vec3(0.15, 0.0, 0.3), vec3(0.2, 0.05, 0.15), audio_warmth);
	vec3 sky_col = mix(
		vec3(0.02, 0.0, 0.08),
		mix(sky_cold, sky_warm, audio_warmth),
		sky
	);
	col = sky_col;

	// Sun — pulsing with energy, beat_kick flares it
	// Sun rises slowly over 60 seconds, audio energy lifts it further
	float rise = clamp(TIME / 60.0, 0.0, 1.0);
	vec2 sun_pos = vec2(0.0, mix(-0.3, 0.35, rise) + audio_energy * 0.05);
	float sun_r = length(uv - sun_pos);
	float sun_size = 0.25 + beat_intensity * 0.05 + beat_kick * 0.5;
	float sun = smoothstep(sun_size, 0.15, sun_r);
	// Horizontal scan lines through sun
	float scan = sin(uv.y * 80.0 + TIME * 2.0) * 0.5 + 0.5;
	scan = step(0.4, scan);
	// Sun color — warmth shifts toward orange
	vec3 sun_inner = mix(vec3(1.0, 0.8, 0.2), vec3(1.0, 0.6, 0.1), audio_warmth);
	vec3 sun_outer = mix(vec3(1.0, 0.2, 0.5), vec3(1.0, 0.4, 0.2), audio_warmth);
	vec3 sun_col = mix(sun_outer, sun_inner, smoothstep(0.25, 0.1, sun_r));
	float sun_flash = 1.0 + beat_intensity * 0.5 + beat_kick * 0.5;
	col += sun_col * sun * scan * sun_flash;
	// Sun glow — warmth shifts glow color
	vec3 glow_col = mix(vec3(1.0, 0.1, 0.4), vec3(1.0, 0.5, 0.1), audio_bass + audio_warmth * 0.5);
	col += glow_col * exp(-sun_r * 3.0) * 0.3;

	// Grid floor (below horizon)
	if (uv.y < horizon + 0.01) {
		float depth = -0.5 / (uv.y - horizon - 0.01);
		float grid_x = uv.x * depth;
		float grid_z = depth - TIME * (2.0 + audio_energy * 4.0 + audio_flux * 2.0);

		// Grid lines with brilliance shimmer
		float shimmer = 1.0 + audio_brilliance * sin(TIME * 8.0 + grid_x * 5.0 + grid_z * 3.0) * 0.5;
		float line_x = abs(fract(grid_x * 0.5) - 0.5);
		float line_z = abs(fract(grid_z * 0.3) - 0.5);
		float grid = smoothstep(0.02, 0.0, line_x) + smoothstep(0.02, 0.0, line_z);
		grid *= smoothstep(30.0, 2.0, depth);  // fade with distance
		grid *= shimmer;

		// Grid color — warmth shifts toward orange, snare flashes toward white
		vec3 grid_base = mix(vec3(0.0, 0.8, 1.0), vec3(1.0, 0.0, 0.8), audio_bass);
		grid_base = mix(grid_base, vec3(1.0, 0.5, 0.3), audio_warmth * 0.4);
		vec3 grid_col = mix(grid_base, vec3(1.0, 1.0, 1.0), beat_snare * 0.7);
		col += grid_col * grid * (0.4 + audio_energy * 0.6);

		// Audio pillars — vertical bars of light at grid intersections
		float pillar_radius = 0.1 + audio_presence * 0.08;
		float pillar_x = fract(grid_x * 0.5 + 0.5);
		float pillar_z = fract(grid_z * 0.3 + 0.5);
		float on_intersection = smoothstep(pillar_radius, 0.0, abs(pillar_x - 0.5)) * smoothstep(pillar_radius, 0.0, abs(pillar_z - 0.5));

		// Each pillar height driven by different audio band based on x position
		float band_select = fract(grid_x * 0.25);
		float pillar_intensity = 0.0;
		if (band_select < 0.25) pillar_intensity = audio_bass;
		else if (band_select < 0.5) pillar_intensity = audio_low_mid;
		else if (band_select < 0.75) pillar_intensity = audio_mid;
		else pillar_intensity = audio_treble;

		col += vec3(0.5, 0.2, 1.0) * on_intersection * pillar_intensity * smoothstep(20.0, 3.0, depth) * 2.0;

		// Beat flash on floor — snare adds white flash
		col += vec3(1.0, 0.3, 0.6) * beat_intensity * 0.15 * smoothstep(15.0, 1.0, depth);
		col += vec3(1.0, 1.0, 1.0) * beat_snare * 0.1 * smoothstep(15.0, 1.0, depth);
	}

	// Mountain silhouette at horizon
	float mountain_x = uv.x * 3.0;
	float mountain = sin(mountain_x * 2.0) * 0.03 + sin(mountain_x * 5.0) * 0.015 + sin(mountain_x * 11.0) * 0.008;
	float mountain_mask = smoothstep(horizon + mountain + 0.02, horizon + mountain, uv.y);
	col = mix(col, vec3(0.02, 0.0, 0.05), mountain_mask);

	// Vertical light beam from sun on beats
	float beam = exp(-uv.x * uv.x * 30.0) * beat_intensity;
	col += vec3(1.0, 0.4, 0.7) * beam * 0.3 * smoothstep(horizon, horizon + 0.5, uv.y);

	// Stars (only in sky) — hihat boosts twinkle
	vec2 star_uv = uv * 50.0;
	float sv = hash(floor(star_uv));
	if (sv > 0.99 && uv.y > horizon + 0.1) {
		vec2 sc = fract(star_uv) - 0.5;
		float twinkle = sin(TIME * 4.0 + sv * 50.0) * 0.4 + 0.6;
		float star_bright = 0.5 * (1.0 + beat_hihat * 4.0);
		col += vec3(0.8, 0.7, 1.0) * exp(-dot(sc, sc) * 100.0) * twinkle * star_bright;
	}

	// Overall luminance — audio_brightness drives it
	col *= (0.7 + audio_brightness * 0.6);

	ALBEDO = col;
}

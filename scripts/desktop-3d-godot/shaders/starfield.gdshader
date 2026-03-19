shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

// Starfield — parallax layers of stars rushing toward viewer
global uniform float audio_energy;
global uniform float beat_intensity;
global uniform float audio_treble;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec3 star_layer(vec2 uv, float speed, float density, float t) {
	uv *= density;
	vec2 id = floor(uv);
	vec2 gv = fract(uv) - 0.5;

	vec3 col = vec3(0.0);
	for (int y = -1; y <= 1; y++) {
		for (int x = -1; x <= 1; x++) {
			vec2 offset = vec2(float(x), float(y));
			float h = hash(id + offset);
			if (h < 0.15) {
				vec2 star_pos = vec2(h, fract(h * 127.1)) - 0.5;
				float d = length(gv - offset - star_pos);
				float brightness = h * 0.5 + 0.5;
				float twinkle = sin(t * (3.0 + h * 8.0) + h * 100.0) * 0.3 + 0.7;
				float star = exp(-d * d * 200.0) * brightness * twinkle;
				// Star color based on hash
				vec3 star_col = mix(vec3(0.8, 0.9, 1.0), vec3(1.0, 0.7, 0.4), fract(h * 43.7));
				col += star_col * star;
			}
		}
	}
	return col;
}

void fragment() {
	vec2 uv = UV - 0.5;
	uv.x *= 1.777;

	float t = TIME;
	float speed = 0.5 + audio_energy * 2.0;

	vec3 col = vec3(0.005, 0.002, 0.015); // deep space

	// 5 parallax layers moving at different speeds
	col += star_layer(uv + vec2(0.0, t * speed * 0.1), speed * 0.1, 8.0, t) * 0.3;
	col += star_layer(uv + vec2(0.0, t * speed * 0.25), speed * 0.25, 12.0, t) * 0.4;
	col += star_layer(uv + vec2(0.0, t * speed * 0.5), speed * 0.5, 18.0, t) * 0.6;
	col += star_layer(uv + vec2(0.0, t * speed * 0.8), speed * 0.8, 25.0, t) * 0.8;
	col += star_layer(uv + vec2(0.0, t * speed * 1.2), speed * 1.2, 35.0, t) * 1.0;

	// Beat burst — radial streaks
	float burst = beat_intensity * exp(-length(uv) * 3.0) * 0.8;
	col += vec3(0.5, 0.7, 1.0) * burst;

	// Subtle warp speed lines from treble
	float streaks = audio_treble * 0.3 * smoothstep(0.3, 0.0, abs(uv.x)) * smoothstep(0.5, 0.0, abs(uv.y));
	col += vec3(0.3, 0.5, 0.8) * streaks;

	// Central glow
	float center = exp(-length(uv) * 4.0) * 0.05;
	col += vec3(0.2, 0.3, 0.5) * center;

	ALBEDO = col;
}

shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

// Classic demoscene plasma — overlaid sine waves with audio-reactive color cycling
global uniform float audio_energy;
global uniform float beat_intensity;
global uniform float audio_bass;
global uniform float audio_mid;
global uniform float audio_treble;
global uniform float audio_sub_bass;
global uniform float audio_brilliance;
global uniform float audio_presence;
global uniform float beat_kick;
global uniform float beat_snare;
global uniform float beat_hihat;
global uniform float audio_warmth;
global uniform float audio_brightness;

void fragment() {
	vec2 uv = UV * 6.0;
	float t = TIME * (0.5 + audio_energy * 1.5);

	// Multiple overlapping sine waves — mid modulates the second wave frequency
	float v = sin(uv.x + t);
	v += sin(uv.y * (1.0 + audio_mid * 2.0) + t * 0.7);
	v += sin((uv.x + uv.y) + t * 0.5);
	v += sin(length(uv - vec2(3.0)) + t * 1.2);
	v += sin(length(uv - vec2(3.0, 0.0)) * 0.5 + t * 0.8);
	v *= 0.2; // normalize roughly to -1..1

	// Sub-bass: slow large-scale wave
	v += sin(uv.x * 1.0 + t * 0.3) * audio_sub_bass * 0.5;

	// Treble: fast high-frequency shimmer
	v += sin(uv.x * 20.0 + uv.y * 20.0 + t * 5.0) * audio_treble * 0.15;

	// Beat pulse (original)
	v += beat_intensity * 0.3 * sin(uv.x * 10.0 + uv.y * 10.0);

	// Color from sine palette — kick shifts color phase
	float phase = t * 0.3 + beat_kick * 1.0;
	vec3 col;
	col.r = sin(v * 3.14159 + phase) * 0.5 + 0.5;
	col.g = sin(v * 3.14159 + phase + 2.094) * 0.5 + 0.5;
	col.b = sin(v * 3.14159 + phase + 4.189) * 0.5 + 0.5;

	// Snare: secondary flash with inverted colors
	col = mix(col, vec3(1.0) - col, beat_snare * 0.6);

	// Bass pumps saturation
	col = mix(vec3(dot(col, vec3(0.299, 0.587, 0.114))), col, 1.0 + audio_bass * 0.5);

	// Hi-hat: fine sparkle overlay
	float sparkle = step(0.98, fract(sin(dot(floor(UV * 200.0), vec2(127.1, 311.7))) * 43758.5453)) * beat_hihat * 0.8;
	col += vec3(sparkle);

	// Warmth: shift red up, blue down
	col.r += audio_warmth * 0.15;
	col.b -= audio_warmth * 0.10;

	// Brightness: overall luminance modulation
	col *= 1.0 + audio_brightness * 0.4;

	ALBEDO = col;
}

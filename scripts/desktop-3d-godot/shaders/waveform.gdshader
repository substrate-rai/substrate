shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

// Waveform — layered audio bands as glowing mountain ranges
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

float hash(float p) {
	return fract(sin(p * 127.1) * 43758.5453);
}

float wave(float x, float freq, float phase, float amp) {
	return sin(x * freq + phase) * amp;
}

void fragment() {
	vec2 uv = (UV - 0.5) * 2.0;
	uv.x *= 1.777;

	vec3 col = vec3(0.01, 0.005, 0.02);

	// 7 audio bands as layered waveforms, back to front
	float bands[7] = float[](audio_sub_bass, audio_bass, audio_low_mid, audio_mid, audio_upper_mid, audio_presence, audio_treble);
	vec3 colors[7] = vec3[](
		vec3(0.8, 0.1, 0.1),   // sub bass — red
		vec3(1.0, 0.4, 0.1),   // bass — orange
		vec3(1.0, 0.8, 0.1),   // low mid — yellow
		vec3(0.1, 1.0, 0.4),   // mid — green
		vec3(0.1, 0.6, 1.0),   // upper mid — cyan
		vec3(0.4, 0.2, 1.0),   // presence — indigo
		vec3(0.8, 0.2, 1.0)    // treble — violet
	);

	for (int i = 0; i < 7; i++) {
		float fi = float(i);
		float base_y = -0.8 + fi * 0.23;  // vertical spacing
		float amplitude = bands[i] * 0.4 + 0.02;  // minimum visible wave

		// Composite wave from multiple harmonics
		float t = TIME * (0.5 + fi * 0.15);
		float w = 0.0;
		w += wave(uv.x, 3.0 + fi, t, amplitude);
		w += wave(uv.x, 7.0 + fi * 2.0, t * 1.3, amplitude * 0.5);
		w += wave(uv.x, 13.0 + fi * 3.0, t * 0.7, amplitude * 0.25);
		w += beat_intensity * wave(uv.x, 20.0, t * 3.0, 0.03);

		float wave_y = base_y + w;

		// Fill below wave
		float fill = smoothstep(wave_y + 0.01, wave_y - 0.02, uv.y);
		// Glow at wave edge
		float edge = exp(-pow((uv.y - wave_y) * 30.0, 2.0));

		// Depth fade — back layers dimmer
		float depth = 0.3 + float(i) / 7.0 * 0.7;

		vec3 band_col = colors[i];
		// Beat flash brightens everything
		band_col *= (1.0 + beat_intensity * 0.5);

		col = mix(col, band_col * depth * 0.15, fill * 0.6);
		col += band_col * edge * depth * (0.5 + bands[i] * 1.5);
	}

	// Ambient glow from total energy
	col += vec3(0.1, 0.05, 0.15) * audio_energy;

	// Particle sparkles on beats
	vec2 sp = uv * 30.0;
	float sv = hash(dot(floor(sp), vec2(127.1, 311.7)));
	if (sv > 0.97 && beat_intensity > 0.3) {
		vec2 sc = fract(sp) - 0.5;
		col += vec3(1.0, 0.9, 0.8) * exp(-dot(sc, sc) * 60.0) * beat_intensity;
	}

	ALBEDO = col;
}

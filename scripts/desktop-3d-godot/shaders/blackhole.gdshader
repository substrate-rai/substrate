shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

// Black hole — gravitational lensing + accretion disk (audio-reactive)
global uniform float audio_energy;
global uniform float beat_intensity;
global uniform float audio_bass;
global uniform float audio_mid;
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
global uniform float audio_flux;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1, 0)), f.x),
		mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), f.x),
		f.y
	);
}

mat2 rot2(float a) {
	float c = cos(a), s = sin(a);
	return mat2(vec2(c, s), vec2(-s, c));
}

void fragment() {
	vec2 uv = (UV - 0.5) * 2.0;
	uv.x *= 1.777;

	// Background stars — treble makes them sparkle brighter, hihat boosts sparkle
	float stars = 0.0;
	vec2 star_uv = uv * 60.0;
	float sv = hash(floor(star_uv));
	if (sv > 0.985) {
		vec2 sc = fract(star_uv) - 0.5;
		float twinkle = sin(TIME * (3.0 + sv * 6.0) + sv * 40.0) * 0.3 + 0.7;
		stars = exp(-dot(sc, sc) * 100.0) * twinkle * (1.0 + audio_treble * 2.0) * (1.0 + beat_hihat * 2.0);
	}

	vec3 col = vec3(0.005, 0.003, 0.01) + vec3(0.7, 0.8, 1.0) * stars * 0.4;

	float r = length(uv);
	float a = atan(uv.y, uv.x);

	// Gravitational lensing — warp UV toward center, bass pulses the warp
	float warp_strength = (0.3 + audio_bass * 0.4) / (r * r + 0.05);
	vec2 warped_uv = uv + normalize(uv) * warp_strength * (0.1 + beat_intensity * 0.08);

	// Lensed star background — hihat boosts sparkle
	float lensed_stars = 0.0;
	vec2 ls_uv = warped_uv * 40.0;
	float lsv = hash(floor(ls_uv));
	if (lsv > 0.98) {
		vec2 lsc = fract(ls_uv) - 0.5;
		lensed_stars = exp(-dot(lsc, lsc) * 80.0) * (1.0 + beat_hihat * 2.0);
	}
	col += vec3(0.6, 0.7, 1.0) * lensed_stars * smoothstep(0.2, 0.4, r);

	// Event horizon — black sphere, bass makes it breathe, kick makes it gulp
	float horizon_size = 0.18 + audio_sub_bass * 0.04 + beat_kick * 0.02;
	float horizon = smoothstep(horizon_size, horizon_size - 0.03, r);
	col *= (1.0 - horizon);

	// Accretion disk — spins faster with energy, mid drives turbulence
	// audio_flux adds disk spin speed variation
	float disk_r = r;
	float disk_a = a + TIME * (0.3 + audio_energy * 0.8) + audio_mid * 2.0;

	// Disk is a torus viewed at angle — use y-squished coordinates
	vec2 disk_uv = vec2(uv.x, uv.y * 2.5);
	float disk_dist = length(disk_uv);
	float disk_mask = smoothstep(0.15, 0.25, disk_dist) * smoothstep(0.8, 0.5, disk_dist);

	// Thin disk — only visible when y is near zero (edge-on)
	float disk_thin = exp(-uv.y * uv.y * 30.0);
	disk_mask *= disk_thin;

	// Disk texture — spiraling hot gas, energy drives speed
	// audio_flux boosts spin speed, audio_low_mid modulates turbulence
	float disk_angle = atan(disk_uv.y, disk_uv.x);
	float t_speed = TIME * (0.5 + audio_energy * 1.5) + audio_flux * 0.5;
	float turbulence_mod = 1.0 + audio_low_mid * 0.6;
	float spiral = noise(vec2(disk_angle * 3.0 + t_speed, disk_dist * 8.0 * turbulence_mod - TIME));
	spiral += noise(vec2(disk_angle * 6.0 - t_speed * 1.6, disk_dist * 15.0 * turbulence_mod + audio_mid * 3.0)) * 0.5;
	spiral += noise(vec2(disk_angle * 12.0 + TIME, disk_dist * 25.0 + audio_brilliance * 0.3)) * (audio_treble * 0.4 + audio_brilliance * 0.3);

	// Disk color — warmth shifts temperature (warm=orange, cool=blue)
	float disk_temp = smoothstep(0.7, 0.2, disk_dist) + audio_bass * 0.3;
	vec3 disk_hot = mix(vec3(1.0, 0.4, 0.1), vec3(1.0, 0.5, 0.05), audio_warmth);
	vec3 disk_warm = mix(vec3(1.0, 0.9, 0.7), vec3(1.0, 0.8, 0.5), audio_warmth);
	vec3 disk_col = mix(disk_hot, disk_warm, disk_temp);
	vec3 disk_inner = mix(vec3(0.5, 0.6, 1.0), vec3(0.6, 0.5, 0.9), audio_warmth);
	disk_col = mix(disk_col, disk_inner, smoothstep(0.2, 0.15, disk_dist) + audio_energy * 0.2);

	col += disk_col * disk_mask * spiral * (1.2 + audio_bass * 2.0 + beat_intensity * 1.5);

	// Photon ring — bright thin ring at event horizon edge, beats + snare make it flare
	float ring_r = 0.19 + audio_sub_bass * 0.04;
	float photon_ring = exp(-pow((r - ring_r) * 50.0, 2.0)) * (2.0 + beat_intensity * 4.0 + beat_snare * 2.0);
	vec3 ring_col = mix(vec3(1.0, 0.8, 0.5), vec3(0.6, 0.8, 1.0), audio_mid);
	col += ring_col * photon_ring;

	// Relativistic jet — treble drives intensity, beats make it flare, presence boosts glow
	float jet = exp(-uv.x * uv.x * (200.0 - audio_bass * 80.0)) * smoothstep(0.3, 0.8, abs(uv.y));
	vec3 jet_col = mix(vec3(0.3, 0.4, 1.0), vec3(0.7, 0.3, 1.0), audio_treble);
	float jet_intensity = (0.15 + audio_energy * 0.6 + beat_intensity * 0.4) * (1.0 + audio_presence * 0.5);
	col += jet_col * jet * jet_intensity;

	// Overall luminance — audio_brightness drives it
	col *= (0.7 + audio_brightness * 0.6);

	ALBEDO = col;
}

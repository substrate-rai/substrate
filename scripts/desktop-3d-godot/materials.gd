extends RefCounted
# materials.gd — Noise-textured material factories for Desktop 3D

static func make_ground_material(base_color: Color) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = base_color
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.03
	noise.fractal_octaves = 4
	# Albedo texture with color ramp so it stays in earth tones
	var albedo_noise = NoiseTexture2D.new()
	albedo_noise.noise = noise
	albedo_noise.width = 512
	albedo_noise.height = 512
	albedo_noise.seamless = true
	var ramp = Gradient.new()
	ramp.set_color(0, base_color.darkened(0.3))
	ramp.set_color(1, base_color.lightened(0.15))
	albedo_noise.color_ramp = ramp
	mat.albedo_texture = albedo_noise
	# Normal map for surface bumps
	var normal_noise = NoiseTexture2D.new()
	normal_noise.noise = noise
	normal_noise.width = 512
	normal_noise.height = 512
	normal_noise.seamless = true
	normal_noise.as_normal_map = true
	normal_noise.bump_strength = 6.0
	mat.normal_enabled = true
	mat.normal_texture = normal_noise
	mat.roughness = 0.9
	mat.uv1_scale = Vector3(8, 8, 8)
	return mat

static func make_stone_material(base_color: Color) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = base_color
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.cellular_distance_function = FastNoiseLite.DISTANCE_EUCLIDEAN
	noise.frequency = 0.08
	# Albedo variation with color ramp
	var albedo_noise = NoiseTexture2D.new()
	albedo_noise.noise = noise
	albedo_noise.width = 256
	albedo_noise.height = 256
	albedo_noise.seamless = true
	var ramp = Gradient.new()
	ramp.set_color(0, base_color.darkened(0.25))
	ramp.set_color(1, base_color.lightened(0.1))
	albedo_noise.color_ramp = ramp
	mat.albedo_texture = albedo_noise
	# Normal map for cracks
	var normal_tex = NoiseTexture2D.new()
	normal_tex.noise = noise
	normal_tex.width = 256
	normal_tex.height = 256
	normal_tex.seamless = true
	normal_tex.as_normal_map = true
	normal_tex.bump_strength = 8.0
	mat.normal_enabled = true
	mat.normal_texture = normal_tex
	mat.roughness = 0.85
	mat.uv1_scale = Vector3(3, 3, 3)
	return mat

static func make_bark_material(base_color: Color) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = base_color
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.15
	noise.fractal_type = FastNoiseLite.FRACTAL_RIDGED
	noise.fractal_octaves = 3
	# Albedo variation with color ramp
	var albedo_noise = NoiseTexture2D.new()
	albedo_noise.noise = noise
	albedo_noise.width = 256
	albedo_noise.height = 256
	albedo_noise.seamless = true
	var ramp = Gradient.new()
	ramp.set_color(0, base_color.darkened(0.2))
	ramp.set_color(1, base_color.lightened(0.1))
	albedo_noise.color_ramp = ramp
	mat.albedo_texture = albedo_noise
	# Normal map for ridges
	var normal_tex = NoiseTexture2D.new()
	normal_tex.noise = noise
	normal_tex.width = 256
	normal_tex.height = 256
	normal_tex.seamless = true
	normal_tex.as_normal_map = true
	normal_tex.bump_strength = 10.0
	mat.normal_enabled = true
	mat.normal_texture = normal_tex
	mat.roughness = 0.92
	mat.uv1_scale = Vector3(4, 4, 4)
	return mat

static func make_moss_material(base_color: Color) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = base_color
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.06
	noise.fractal_octaves = 3
	var albedo_noise = NoiseTexture2D.new()
	albedo_noise.noise = noise
	albedo_noise.width = 256
	albedo_noise.height = 256
	albedo_noise.seamless = true
	mat.albedo_texture = albedo_noise
	var normal_tex = NoiseTexture2D.new()
	normal_tex.noise = noise
	normal_tex.width = 256
	normal_tex.height = 256
	normal_tex.seamless = true
	normal_tex.as_normal_map = true
	normal_tex.bump_strength = 4.0
	mat.normal_enabled = true
	mat.normal_texture = normal_tex
	mat.roughness = 0.95
	mat.uv1_scale = Vector3(5, 5, 5)
	return mat

static func make_mud_material(base_color: Color) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = base_color
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.05
	noise.fractal_octaves = 2
	var albedo_noise = NoiseTexture2D.new()
	albedo_noise.noise = noise
	albedo_noise.width = 256
	albedo_noise.height = 256
	albedo_noise.seamless = true
	mat.albedo_texture = albedo_noise
	var normal_tex = NoiseTexture2D.new()
	normal_tex.noise = noise
	normal_tex.width = 256
	normal_tex.height = 256
	normal_tex.seamless = true
	normal_tex.as_normal_map = true
	normal_tex.bump_strength = 3.0
	mat.normal_enabled = true
	mat.normal_texture = normal_tex
	mat.roughness = 1.0
	mat.uv1_scale = Vector3(4, 4, 4)
	return mat

static func make_rusty_metal_material(base_color: Color) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = base_color
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_CELLULAR
	noise.cellular_distance_function = FastNoiseLite.DISTANCE_MANHATTAN
	noise.frequency = 0.12
	noise.fractal_octaves = 2
	var albedo_noise = NoiseTexture2D.new()
	albedo_noise.noise = noise
	albedo_noise.width = 256
	albedo_noise.height = 256
	albedo_noise.seamless = true
	var ramp = Gradient.new()
	ramp.set_color(0, base_color.darkened(0.3))
	ramp.set_color(1, Color(0.45, 0.25, 0.12))  # rust patches
	albedo_noise.color_ramp = ramp
	mat.albedo_texture = albedo_noise
	var normal_tex = NoiseTexture2D.new()
	normal_tex.noise = noise
	normal_tex.width = 256
	normal_tex.height = 256
	normal_tex.seamless = true
	normal_tex.as_normal_map = true
	normal_tex.bump_strength = 12.0
	mat.normal_enabled = true
	mat.normal_texture = normal_tex
	mat.metallic = 0.6
	mat.roughness = 0.75
	mat.uv1_scale = Vector3(3, 3, 3)
	return mat

static func make_overgrown_material(base_color: Color) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = base_color
	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.04
	noise.fractal_octaves = 4
	var albedo_noise = NoiseTexture2D.new()
	albedo_noise.noise = noise
	albedo_noise.width = 256
	albedo_noise.height = 256
	albedo_noise.seamless = true
	var ramp = Gradient.new()
	ramp.set_color(0, base_color)
	ramp.add_point(0.4, Color(0.08, 0.22, 0.06))  # moss patches
	ramp.set_color(2, Color(0.12, 0.28, 0.08))
	albedo_noise.color_ramp = ramp
	mat.albedo_texture = albedo_noise
	var normal_tex = NoiseTexture2D.new()
	normal_tex.noise = noise
	normal_tex.width = 256
	normal_tex.height = 256
	normal_tex.seamless = true
	normal_tex.as_normal_map = true
	normal_tex.bump_strength = 5.0
	mat.normal_enabled = true
	mat.normal_texture = normal_tex
	mat.roughness = 0.9
	mat.uv1_scale = Vector3(4, 4, 4)
	return mat

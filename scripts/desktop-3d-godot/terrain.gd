extends RefCounted
# terrain.gd — SurfaceTool procedural terrain generation

static func create_terrain(size: float, resolution: float, height_scale: float, seed_val: int = 0) -> MeshInstance3D:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)

	var noise = FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.015
	noise.fractal_octaves = 3
	noise.seed = seed_val

	var half = size / 2.0
	var steps = int(size / resolution)

	for z in range(steps):
		for x in range(steps):
			var x0 = -half + x * resolution
			var z0 = -half + z * resolution
			var x1 = x0 + resolution
			var z1 = z0 + resolution

			var y00 = noise.get_noise_2d(x0, z0) * height_scale
			var y10 = noise.get_noise_2d(x1, z0) * height_scale
			var y01 = noise.get_noise_2d(x0, z1) * height_scale
			var y11 = noise.get_noise_2d(x1, z1) * height_scale

			# Triangle 1
			st.set_uv(Vector2(x0 / size + 0.5, z0 / size + 0.5))
			st.add_vertex(Vector3(x0, y00, z0))
			st.set_uv(Vector2(x1 / size + 0.5, z0 / size + 0.5))
			st.add_vertex(Vector3(x1, y10, z0))
			st.set_uv(Vector2(x0 / size + 0.5, z1 / size + 0.5))
			st.add_vertex(Vector3(x0, y01, z1))

			# Triangle 2
			st.set_uv(Vector2(x1 / size + 0.5, z0 / size + 0.5))
			st.add_vertex(Vector3(x1, y10, z0))
			st.set_uv(Vector2(x1 / size + 0.5, z1 / size + 0.5))
			st.add_vertex(Vector3(x1, y11, z1))
			st.set_uv(Vector2(x0 / size + 0.5, z1 / size + 0.5))
			st.add_vertex(Vector3(x0, y01, z1))

	st.generate_normals()
	st.generate_tangents()

	var mi = MeshInstance3D.new()
	mi.mesh = st.commit()
	return mi

static func get_height_at(noise: FastNoiseLite, x: float, z: float, height_scale: float) -> float:
	return noise.get_noise_2d(x, z) * height_scale

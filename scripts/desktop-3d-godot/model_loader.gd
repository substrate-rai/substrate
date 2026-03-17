extends RefCounted
# model_loader.gd — Kenney GLB model loading, caching, and material override

const NATURE_PATH = "res://assets/models/nature-kit/Models/GLTF format/"
const GRAVEYARD_PATH = "res://assets/models/graveyard-kit/Models/GLB format/"
const SPACE_PATH = "res://assets/models/space-kit/Models/GLTF format/"

var model_cache: Dictionary = {}

func load_model(model_name: String, pos: Vector3, scale_val: float = 1.0, rot_y: float = 0.0, base_path: String = NATURE_PATH) -> Node3D:
	var scene = get_model(model_name, base_path)
	if scene == null:
		return null
	scene.position = pos
	scene.scale = Vector3.ONE * scale_val
	scene.rotation_degrees.y = rot_y
	return scene

func get_model(name: String, base_path: String = NATURE_PATH) -> Node3D:
	var key = base_path + name
	if not model_cache.has(key):
		var loaded = _load_glb(key)
		if loaded == null:
			return null
		model_cache[key] = loaded
	return model_cache[key].duplicate()

func _load_glb(path: String) -> Node3D:
	var doc = GLTFDocument.new()
	var state = GLTFState.new()
	var err = doc.append_from_file(path, state)
	if err != OK:
		push_error("Failed to load GLB: " + path)
		return null
	var scene = doc.generate_scene(state)
	return scene

static func override_materials(node: Node, min_roughness: float = 0.4):
	if node is MeshInstance3D:
		for i in node.get_surface_override_material_count():
			var mat = node.get_active_material(i)
			if mat is StandardMaterial3D:
				mat.roughness = max(mat.roughness, min_roughness)
	for child in node.get_children():
		override_materials(child, min_roughness)

static func tint_model(node: Node, color_multiplier: Color):
	if node is MeshInstance3D:
		for i in node.get_surface_override_material_count():
			var mat = node.get_active_material(i)
			if mat is StandardMaterial3D:
				var new_mat = mat.duplicate()
				new_mat.albedo_color = mat.albedo_color * color_multiplier
				node.set_surface_override_material(i, new_mat)
	for child in node.get_children():
		tint_model(child, color_multiplier)

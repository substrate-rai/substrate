extends Node3D

const Materials = preload("res://materials.gd")
const Terrain = preload("res://terrain.gd")
var model_loader = preload("res://model_loader.gd").new()

var server: TCPServer
var connections: Array = []
const PORT = 9877

var objects_container: Node3D
var spawned_items: Array = []
var sky_cycle_enabled: bool = false
var cloud_nodes: Array = []
var terrain_noise: FastNoiseLite  # shared for height queries

# Cursor tracking — reads mouse position even with passthrough
var cursor_world_pos: Vector3 = Vector3.ZERO
var cursor_tracking: bool = true

# Camera modes: orbit, follow_cursor, cinematic
var camera_mode: String = "orbit"
var camera_orbit_speed: float = 0.05
var camera_orbit_radius: float = 5.0
var camera_orbit_height: float = 2.5

# Ghost tracking (haunted_graveyard)
var ghost_node: Node3D = null

# Satellite dish tracking (space_outpost)
var dish_node: Node3D = null

# Day/night cycle (autumn_campsite)
var day_night_enabled: bool = false

# Flickering lights (abandoned_station)
var flicker_lights: Array = []

# ── Audio reactivity ──
var spectrum: AudioEffectSpectrumAnalyzerInstance = null
var audio_bass: float = 0.0
var audio_mid: float = 0.0
var audio_treble: float = 0.0
var audio_energy: float = 0.0
var beat_intensity: float = 0.0
var prev_bass: float = 0.0
var beat_cooldown: float = 0.0
const BEAT_THRESHOLD = 0.15
const BEAT_COOLDOWN_TIME = 0.12
const MIN_DB = -60.0
const ATTACK = 0.4    # fast rise
const DECAY = 0.07    # slow fall

# ── Sensor data (UDP from daemon) ──
var sensor_udp: PacketPeerUDP = null
var cpu_temp: float = 0.0
var gpu_temp: float = 0.0
var gpu_util: float = 0.0
var ram_pct: float = 0.0
var bat_pct: float = 100.0
var net_rx: float = 0.0
var net_tx: float = 0.0
var weather_code: int = 0
var weather_wind: float = 0.0
var weather_precip: float = 0.0
var notify_flash: float = 0.0
var focused_app: String = ""

# ── Idle detection ──
var idle_time: float = 0.0
var prev_cursor_pos: Vector3 = Vector3.ZERO
var idle_threshold: float = 300.0  # 5 minutes
var pre_idle_camera_mode: String = "orbit"
var is_idle: bool = false

# ── Scene auto-rotation ──
var auto_rotate_enabled: bool = false
var auto_rotate_interval: float = 3600.0  # 1 hour
var last_auto_rotate_hour: int = -1
var current_scene_name: String = ""

# ── Scene transitions ──
var fade_quad: MeshInstance3D = null
var is_transitioning: bool = false

# ── Weather particles overlay ──
var weather_particles: GPUParticles3D = null
var current_weather_preset: String = ""

# ── Screen edge effects ──
var edge_cooldown: float = 0.0
var was_at_edge: bool = false

# ── Scene lists ──
const REACTIVE_SCENES = ["haunted_graveyard", "space_outpost", "autumn_campsite", "abandoned_station"]
const ALL_SCENES = ["full_scene", "abyss_scene", "crystal_cave", "neon_city", "volcanic", "zen_garden", "fairy_garden", "haunted_graveyard", "space_outpost", "autumn_campsite", "abandoned_station"]
const TIME_SCENES = {
	"morning": ["fairy_garden", "autumn_campsite", "zen_garden"],
	"day": ["zen_garden", "crystal_cave", "fairy_garden"],
	"evening": ["autumn_campsite", "haunted_graveyard", "neon_city"],
	"night": ["haunted_graveyard", "space_outpost", "abandoned_station"],
	"late_night": ["space_outpost", "abyss_scene", "abandoned_station"],
}

func _ready():
	# Opaque live wallpaper — borderless, below all windows, above KDE wallpaper
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS, true)
	DisplayServer.window_set_mouse_passthrough(PackedVector2Array())

	# Fullscreen first so it covers the whole screen
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

	# Then set window state — BELOW keeps it under all windows but ABOVE the wallpaper
	# (DESKTOP type goes UNDER KDE's wallpaper, which hides our scene)
	var wid = DisplayServer.window_get_native_handle(DisplayServer.WINDOW_HANDLE)
	if wid:
		OS.execute("xprop", PackedStringArray([
			"-id", str(wid), "-f", "_NET_WM_STATE", "32a",
			"-set", "_NET_WM_STATE",
			"_NET_WM_STATE_BELOW,_NET_WM_STATE_STICKY,_NET_WM_STATE_SKIP_TASKBAR,_NET_WM_STATE_SKIP_PAGER"
		]))
		print("Desktop layer set for window ", wid)
	objects_container = $Objects

	server = TCPServer.new()
	var err = server.listen(PORT, "127.0.0.1")
	if err == OK:
		print("Desktop 3D TCP server listening on 127.0.0.1:", PORT)
	else:
		push_error("Failed to start TCP server: ", err)

	# ── Audio capture setup ──
	# Create a Capture bus with SpectrumAnalyzer
	var bus_idx = AudioServer.bus_count
	AudioServer.add_bus(bus_idx)
	AudioServer.set_bus_name(bus_idx, "Capture")
	AudioServer.set_bus_volume_db(bus_idx, -80.0)  # mute playback (we just analyze)
	AudioServer.set_bus_send(bus_idx, "Master")
	# Add spectrum analyzer effect
	var analyzer = AudioEffectSpectrumAnalyzer.new()
	analyzer.fft_size = AudioEffectSpectrumAnalyzer.FFT_SIZE_1024
	analyzer.buffer_length = 0.5
	AudioServer.add_bus_effect(bus_idx, analyzer)
	# Create microphone player
	var mic_player = AudioStreamPlayer.new()
	mic_player.stream = AudioStreamMicrophone.new()
	mic_player.bus = "Capture"
	mic_player.autoplay = true
	add_child(mic_player)
	# Get analyzer instance
	spectrum = AudioServer.get_bus_effect_instance(bus_idx, 0) as AudioEffectSpectrumAnalyzerInstance
	# Try to select PipeWire monitor source
	var devices = AudioServer.get_input_device_list()
	for d in devices:
		if "monitor" in d.to_lower() or "substrate" in d.to_lower():
			AudioServer.input_device = d
			print("Audio capture device: ", d)
			break
	if spectrum:
		print("Audio spectrum analyzer ready")
	else:
		print("WARNING: Audio spectrum analyzer not available")

	# ── Sensor UDP listener ──
	sensor_udp = PacketPeerUDP.new()
	var udp_err = sensor_udp.bind(9778)
	if udp_err == OK:
		print("Sensor UDP listener on port 9778")
	else:
		push_warning("Failed to bind sensor UDP: ", udp_err)

	# ── Fade transition quad (child of Camera3D, near clip) ──
	fade_quad = MeshInstance3D.new()
	fade_quad.mesh = QuadMesh.new()
	fade_quad.mesh.size = Vector2(4, 3)
	var fade_mat = StandardMaterial3D.new()
	fade_mat.albedo_color = Color(0, 0, 0, 0)
	fade_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fade_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fade_mat.no_depth_test = true
	fade_quad.material_override = fade_mat
	fade_quad.position = Vector3(0, 0, -0.5)
	fade_quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	$Camera3D.add_child(fade_quad)

func _process(delta):
	if server and server.is_connection_available():
		var peer = server.take_connection()
		connections.append({"peer": peer, "buffer": ""})

	var to_remove = []
	for i in range(connections.size()):
		var conn = connections[i]
		var peer = conn["peer"]
		if peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
			to_remove.append(i)
			continue
		if peer.get_available_bytes() > 0:
			var data = peer.get_utf8_string(peer.get_available_bytes())
			conn["buffer"] += data
			var result = try_parse_json(conn["buffer"])
			if result != null:
				conn["buffer"] = ""
				var reply = handle_command(result)
				var response_bytes = (JSON.stringify(reply) + "\
").to_utf8_buffer()
				peer.put_data(response_bytes)
				to_remove.append(i)

	to_remove.reverse()
	for i in to_remove:
		connections.remove_at(i)

	# ── Cursor tracking ──
	if cursor_tracking:
		var mouse_screen = DisplayServer.mouse_get_position()
		var cam = $Camera3D as Camera3D
		# Project screen position to world at y=0 plane
		cursor_world_pos = cam.project_position(Vector2(mouse_screen.x, mouse_screen.y), 8.0)
		RenderingServer.global_shader_parameter_set("cursor_world_pos", cursor_world_pos)

	# ── Audio spectrum analysis ──
	if spectrum:
		var raw_bass = _get_band_energy(20.0, 300.0)
		var raw_mid = _get_band_energy(300.0, 4000.0)
		var raw_treble = _get_band_energy(4000.0, 16000.0)
		var raw_energy = (raw_bass + raw_mid + raw_treble) / 3.0

		# Smooth with asymmetric attack/decay
		audio_bass = _smooth(audio_bass, raw_bass, delta)
		audio_mid = _smooth(audio_mid, raw_mid, delta)
		audio_treble = _smooth(audio_treble, raw_treble, delta)
		audio_energy = _smooth(audio_energy, raw_energy, delta)

		# Beat detection — onset in bass band
		beat_cooldown = max(0.0, beat_cooldown - delta)
		if raw_bass - prev_bass > BEAT_THRESHOLD and beat_cooldown <= 0.0:
			beat_intensity = 1.0
			beat_cooldown = BEAT_COOLDOWN_TIME
		else:
			beat_intensity = max(0.0, beat_intensity - delta * 6.0)  # fast decay
		prev_bass = raw_bass

		# Push to global shader params
		RenderingServer.global_shader_parameter_set("audio_bass", audio_bass)
		RenderingServer.global_shader_parameter_set("audio_mid", audio_mid)
		RenderingServer.global_shader_parameter_set("audio_treble", audio_treble)
		RenderingServer.global_shader_parameter_set("audio_energy", audio_energy)
		RenderingServer.global_shader_parameter_set("beat_intensity", beat_intensity)

	# ── Sensor data (UDP) ──
	if sensor_udp:
		while sensor_udp.get_available_packet_count() > 0:
			var packet = sensor_udp.get_packet()
			var text = packet.get_string_from_utf8()
			var parsed = try_parse_json(text)
			if parsed:
				cpu_temp = float(parsed.get("cpu_temp", 0))
				gpu_temp = float(parsed.get("gpu_temp", 0))
				gpu_util = float(parsed.get("gpu_util", 0))
				ram_pct = float(parsed.get("ram_pct", 0))
				bat_pct = float(parsed.get("bat_pct", 100))
				net_rx = float(parsed.get("net_rx", 0))
				net_tx = float(parsed.get("net_tx", 0))
				weather_code = int(parsed.get("weather_code", 0))
				weather_wind = float(parsed.get("weather_wind", 0))
				weather_precip = float(parsed.get("weather_precip", 0))
				var raw_notify = float(parsed.get("notify", 0))
				notify_flash = max(notify_flash, raw_notify)

		# Compute derived values for shaders
		# system_heat: 0.0 (cool) to 1.0 (hot) based on GPU+CPU temp
		var avg_temp = (cpu_temp + gpu_temp) / 2.0
		var heat = clamp((avg_temp - 40.0) / 50.0, 0.0, 1.0)  # 40C=cool, 90C=max
		RenderingServer.global_shader_parameter_set("system_heat", heat)

		# system_load: 0.0-1.0 from GPU util + RAM
		var load_val = clamp((gpu_util + ram_pct) / 200.0, 0.0, 1.0)
		RenderingServer.global_shader_parameter_set("system_load", load_val)

		# weather_intensity: precipitation + wind mapped to 0-1
		var weather_i = clamp(weather_precip / 5.0 + weather_wind / 40.0, 0.0, 1.0)
		RenderingServer.global_shader_parameter_set("weather_intensity", weather_i)

		# Notification flash decay
		notify_flash = max(0.0, notify_flash - delta * 3.0)
		RenderingServer.global_shader_parameter_set("notify_flash", notify_flash)

	# Animate
	var t = Time.get_ticks_msec() / 1000.0

	# Camera — mode-based
	match camera_mode:
		"orbit":
			$Camera3D.position.x = camera_orbit_radius * cos(t * camera_orbit_speed)
			$Camera3D.position.z = camera_orbit_radius * sin(t * camera_orbit_speed)
			$Camera3D.position.y = camera_orbit_height + sin(t * 0.08) * 0.5
			$Camera3D.look_at(Vector3(0, 0.8, 0))
		"follow_cursor":
			$Camera3D.position.x = camera_orbit_radius * cos(t * camera_orbit_speed)
			$Camera3D.position.z = camera_orbit_radius * sin(t * camera_orbit_speed)
			$Camera3D.position.y = camera_orbit_height + sin(t * 0.08) * 0.5
			# Subtle parallax: blend between center and cursor
			var look_target = Vector3(0, 0.8, 0).lerp(cursor_world_pos * 0.15, 0.3)
			$Camera3D.look_at(look_target)
		"cinematic":
			# Slow sweeping path
			var ct = t * 0.02
			$Camera3D.position.x = 6.0 * cos(ct) + 2.0 * sin(ct * 2.3)
			$Camera3D.position.z = 6.0 * sin(ct) + 1.5 * cos(ct * 1.7)
			$Camera3D.position.y = 2.0 + 1.5 * sin(ct * 0.5)
			$Camera3D.look_at(Vector3(sin(ct * 0.3), 0.5, cos(ct * 0.3)))

	# ── Ghost follows cursor (haunted_graveyard) ──
	if ghost_node and is_instance_valid(ghost_node):
		var ghost_target = Vector3(cursor_world_pos.x * 0.6, ghost_node.position.y, cursor_world_pos.z * 0.6)
		ghost_node.position = ghost_node.position.lerp(ghost_target, delta * 0.5)
		ghost_node.position.y = 0.3 + sin(t * 0.8) * 0.2  # hovering bob

	# ── Satellite dish tracks cursor (space_outpost) ──
	if dish_node and is_instance_valid(dish_node):
		var dish_target = Vector3(cursor_world_pos.x, max(cursor_world_pos.y, 0.5), cursor_world_pos.z)
		dish_node.look_at(dish_target)

	# ── Flickering lights (abandoned_station) ──
	for fl in flicker_lights:
		if is_instance_valid(fl):
			var cursor_dist = fl.global_position.distance_to(cursor_world_pos)
			var proximity = 1.0 - clamp(cursor_dist / 5.0, 0.0, 1.0)
			# Near cursor: stable. Far: flickery.
			var flicker_chance = lerp(0.3, 0.0, proximity)
			if randf() < flicker_chance * delta * 10.0:
				fl.light_energy = randf_range(0.0, 0.3)
			else:
				fl.light_energy = lerp(fl.light_energy, lerp(0.5, 1.2, proximity), delta * 3.0)

	# ── Day/night cycle (autumn_campsite) ──
	if day_night_enabled:
		var hour_info = Time.get_datetime_dict_from_system()
		var hour_f = float(hour_info["hour"]) + float(hour_info["minute"]) / 60.0
		# Map 0-24 to sun cycle: 6am=sunrise, 12=noon, 18=sunset, 0=midnight
		var sun_t = (hour_f - 6.0) / 12.0  # 0 at 6am, 1 at 6pm
		sun_t = clamp(sun_t, -0.5, 1.5)
		var day_factor = clamp(sin(sun_t * PI), 0.0, 1.0)
		var env = $WorldEnvironment.environment as Environment
		var sky_mat = env.sky.sky_material as ProceduralSkyMaterial
		# Interpolate sky between night and day
		sky_mat.sky_top_color = Color(0.05, 0.02, 0.1).lerp(Color(0.45, 0.6, 0.85), day_factor)
		sky_mat.sky_horizon_color = Color(0.1, 0.05, 0.08).lerp(Color(0.85, 0.65, 0.4), day_factor)
		sky_mat.sky_energy_multiplier = lerp(0.3, 3.5, day_factor)
		$MoonLight.light_energy = lerp(0.15, 1.0, day_factor)
		$MoonLight.light_color = Color(0.4, 0.45, 0.7).lerp(Color(1.0, 0.88, 0.55), day_factor)

	# Animate sky cycle + clouds
	if sky_cycle_enabled:
		var env = $WorldEnvironment.environment as Environment
		var sky_mat = env.sky.sky_material as ProceduralSkyMaterial
		# Slow color breathing — 5 min full cycle
		var cycle = t * 0.0035
		var warm = 0.5 + 0.5 * sin(cycle)  # 0-1, warm↔cool
		sky_mat.sky_top_color = Color(
			lerp(0.35, 0.5, warm),
			lerp(0.45, 0.4, warm),
			lerp(0.75, 0.55, warm)
		)
		sky_mat.sky_horizon_color = Color(
			lerp(0.7, 0.9, warm),
			lerp(0.5, 0.55, warm),
			lerp(0.4, 0.3, warm)
		)
		sky_mat.ground_horizon_color = Color(
			lerp(0.45, 0.6, warm),
			lerp(0.38, 0.42, warm),
			lerp(0.28, 0.2, warm)
		)
		sky_mat.sky_energy_multiplier = lerp(3.0, 4.0, warm)
		# Sunlight warmth follows sky
		$MoonLight.light_color = Color(
			lerp(0.9, 1.0, warm),
			lerp(0.82, 0.85, warm),
			lerp(0.6, 0.45, warm)
		)
		$MoonLight.light_energy = lerp(0.7, 0.95, warm)
		# Drift clouds
		for cloud in cloud_nodes:
			if is_instance_valid(cloud):
				cloud.position.x += 0.15 * delta
				cloud.position.z += 0.03 * delta
				# Wrap around
				if cloud.position.x > 20:
					cloud.position.x = -20
				if cloud.position.z > 15:
					cloud.position.z = -15

	# Rotate and pulse objects
	for i in range(objects_container.get_child_count()):
		var child = objects_container.get_child(i)
		_animate_recursive(child, t, i)

	# ── Idle detection ──
	var cursor_delta = cursor_world_pos.distance_to(prev_cursor_pos)
	prev_cursor_pos = cursor_world_pos
	if cursor_delta < 0.001:
		idle_time += delta
	else:
		if is_idle:
			# Wake up — restore camera
			is_idle = false
			camera_mode = pre_idle_camera_mode
		idle_time = 0.0
	if idle_time >= idle_threshold and not is_idle:
		is_idle = true
		pre_idle_camera_mode = camera_mode
		camera_mode = "cinematic"
	var idle_factor = clamp(idle_time / idle_threshold, 0.0, 1.0)
	RenderingServer.global_shader_parameter_set("idle_factor", idle_factor)

	# ── Auto-rotation by time of day ──
	if auto_rotate_enabled:
		var hour_now = Time.get_datetime_dict_from_system()["hour"]
		if hour_now != last_auto_rotate_hour:
			last_auto_rotate_hour = hour_now
			var period = _get_time_period(hour_now)
			var candidates = TIME_SCENES.get(period, ALL_SCENES)
			var pick = candidates[randi() % candidates.size()]
			if pick != current_scene_name:
				_transition_to_scene(pick)

	# ── Weather-driven particle overlay ──
	var target_preset = _weather_code_to_preset(weather_code)
	if target_preset != current_weather_preset:
		_set_weather_particles(target_preset)

	# ── Screen edge particle bursts ──
	edge_cooldown = max(0.0, edge_cooldown - delta)
	var screen_size = DisplayServer.screen_get_size()
	var mouse = DisplayServer.mouse_get_position()
	var margin = 20
	var at_edge = (mouse.x < margin or mouse.x > screen_size.x - margin or mouse.y < margin or mouse.y > screen_size.y - margin)
	if at_edge and not was_at_edge and edge_cooldown <= 0.0:
		_spawn_edge_burst(cursor_world_pos)
		edge_cooldown = 1.5
	was_at_edge = at_edge

func _animate_recursive(node: Node, t: float, idx: int):
	if node is MeshInstance3D:
		var mat = node.material_override as StandardMaterial3D
		if mat and mat.emission_enabled:
			if not node.has_meta("base_emission"):
				node.set_meta("base_emission", mat.emission_energy_multiplier)
			var base = node.get_meta("base_emission")
			mat.emission_energy_multiplier = base * (0.7 + 0.3 * sin(t * 1.2 + node.get_instance_id() * 0.001))

	for child in node.get_children():
		_animate_recursive(child, t, idx)

func try_parse_json(text: String):
	var json = JSON.new()
	if json.parse(text) == OK:
		return json.data
	return null

func handle_command(msg: Dictionary) -> Dictionary:
	var type = msg.get("type", "unknown")
	var params = msg.get("params", {})

	match type:
		"status":
			return {"status": "ok", "backend": "godot4-forward+", "renderer": "vulkan", "objects": spawned_items.size(), "items": spawned_items}
		"clear":
			for child in objects_container.get_children():
				child.queue_free()
			spawned_items.clear()
			sky_cycle_enabled = false
			cloud_nodes.clear()
			return {"status": "ok", "message": "Scene cleared"}
		"mushroom":
			create_mushroom(params)
			return {"status": "ok", "message": "Created mushroom", "objects": spawned_items.size()}
		"spore_cluster":
			create_spore_cluster(params)
			return {"status": "ok", "message": "Created spore_cluster", "objects": spawned_items.size()}
		"tree":
			create_tree(params)
			return {"status": "ok", "message": "Created tree", "objects": spawned_items.size()}
		"forest_floor":
			create_forest_floor(params)
			return {"status": "ok", "message": "Created forest_floor", "objects": spawned_items.size()}
		"full_scene":
			create_full_scene(params)
			return {"status": "ok", "message": "Created full_scene", "objects": spawned_items.size()}
		"load_model":
			var path = params.get("path", "")
			if path == "":
				return {"status": "error", "message": "Missing path parameter"}
			load_gltf_model(path, params)
			return {"status": "ok", "message": "Loading model from " + path}
		"mecha":
			create_mecha(params)
			return {"status": "ok", "message": "Created mecha", "objects": spawned_items.size()}
		"abyss_scene":
			create_abyss_scene(params)
			return {"status": "ok", "message": "Created abyss_scene", "objects": spawned_items.size()}
		"jellyfish":
			create_jellyfish(params)
			return {"status": "ok", "message": "Created jellyfish", "objects": spawned_items.size()}
		"coral":
			create_coral(params)
			return {"status": "ok", "message": "Created coral", "objects": spawned_items.size()}
		"vent":
			create_hydrothermal_vent(params)
			return {"status": "ok", "message": "Created vent", "objects": spawned_items.size()}
		"anglerfish":
			create_anglerfish(params)
			return {"status": "ok", "message": "Created anglerfish", "objects": spawned_items.size()}
		"ruin":
			create_sunken_ruin(params)
			return {"status": "ok", "message": "Created ruin", "objects": spawned_items.size()}
		"bloom":
			var env = $WorldEnvironment.environment as Environment
			if params.has("strength"): env.glow_strength = float(params["strength"])
			if params.has("intensity"): env.glow_intensity = float(params["intensity"])
			return {"status": "ok", "message": "Bloom updated"}
		"sky":
			var top = Color.html(params.get("top", "#0d0328"))
			var horizon = Color.html(params.get("horizon", "#0a1e0f"))
			var energy = float(params.get("energy", 1.0))
			var env = $WorldEnvironment.environment as Environment
			var sky_mat = env.sky.sky_material as ProceduralSkyMaterial
			sky_mat.sky_top_color = top
			sky_mat.sky_horizon_color = horizon
			sky_mat.ground_horizon_color = horizon.darkened(0.3)
			sky_mat.ground_bottom_color = top.darkened(0.5)
			sky_mat.sky_energy_multiplier = energy
			return {"status": "ok", "message": "Sky updated"}
		"particles":
			var preset = params.get("preset", "fireflies")
			create_particles(preset, params)
			return {"status": "ok", "message": "Particles: " + preset}
		"crystal_cave":
			apply_crystal_environment()
			create_crystal_cave(params)
			return {"status": "ok", "message": "Crystal cave scene loaded", "objects": spawned_items.size()}
		"neon_city":
			apply_neon_environment()
			create_neon_city(params)
			return {"status": "ok", "message": "Neon city scene loaded", "objects": spawned_items.size()}
		"volcanic":
			apply_volcanic_environment()
			create_volcanic_scene(params)
			return {"status": "ok", "message": "Volcanic scene loaded", "objects": spawned_items.size()}
		"zen_garden":
			apply_zen_environment()
			create_zen_garden(params)
			return {"status": "ok", "message": "Zen garden scene loaded", "objects": spawned_items.size()}
		"fairy_garden":
			apply_fairy_environment()
			create_fairy_garden(params)
			return {"status": "ok", "message": "Fairy garden growing...", "objects": spawned_items.size()}
		"haunted_graveyard":
			apply_graveyard_environment()
			create_haunted_graveyard(params)
			return {"status": "ok", "message": "Haunted graveyard loaded", "objects": spawned_items.size()}
		"space_outpost":
			apply_space_environment()
			create_space_outpost(params)
			return {"status": "ok", "message": "Space outpost loaded", "objects": spawned_items.size()}
		"autumn_campsite":
			apply_autumn_environment()
			create_autumn_campsite(params)
			return {"status": "ok", "message": "Autumn campsite loaded", "objects": spawned_items.size()}
		"abandoned_station":
			apply_station_environment()
			create_abandoned_station(params)
			return {"status": "ok", "message": "Abandoned station loaded", "objects": spawned_items.size()}
		"camera":
			var mode = params.get("mode", "orbit")
			if mode == "cycle":
				var modes = ["orbit", "follow_cursor", "cinematic"]
				var idx = modes.find(camera_mode)
				camera_mode = modes[(idx + 1) % modes.size()]
				return {"status": "ok", "message": "Camera mode: " + camera_mode}
			if mode in ["orbit", "follow_cursor", "cinematic"]:
				camera_mode = mode
				return {"status": "ok", "message": "Camera mode: " + mode}
			return {"status": "error", "message": "Unknown camera mode: " + mode}
		"cursor":
			var enabled = params.get("enabled", true)
			cursor_tracking = enabled
			return {"status": "ok", "message": "Cursor tracking: " + str(enabled)}
		"auto_rotate":
			auto_rotate_enabled = params.get("enabled", true)
			if params.has("interval"):
				auto_rotate_interval = float(params["interval"])
			return {"status": "ok", "message": "Auto-rotate: " + str(auto_rotate_enabled)}
		"transition":
			var scene_name = params.get("scene", "")
			if scene_name in ALL_SCENES:
				_transition_to_scene(scene_name)
				return {"status": "ok", "message": "Transitioning to " + scene_name}
			return {"status": "error", "message": "Unknown scene: " + scene_name}
		"spawn":
			var model_name = params.get("model", "")
			var kit = params.get("kit", "nature")
			if model_name == "":
				return {"status": "error", "message": "Missing model parameter"}
			_spawn_cross_kit(model_name, kit, params)
			return {"status": "ok", "message": "Spawned " + model_name + " from " + kit}
		"hologram_display":
			_create_performance_hologram(params)
			return {"status": "ok", "message": "Performance hologram created"}
		"idle":
			if params.has("threshold"):
				idle_threshold = float(params["threshold"])
			return {"status": "ok", "message": "Idle threshold: " + str(idle_threshold) + "s"}
		_:
			return {"status": "error", "message": "Unknown command: " + type}

# ── GLTF Model Loading ──────────────────────────────────────────────────────

func load_gltf_model(path: String, params: Dictionary):
	var loader = GLTFDocument.new()
	var state = GLTFState.new()
	var err = loader.append_from_file(path, state)
	if err != OK:
		push_error("Failed to load GLTF: " + path)
		return
	var scene = loader.generate_scene(state)
	var x = float(params.get("x", 0))
	var y = float(params.get("y", 0))
	var sc = float(params.get("scale", 1.0))
	scene.position = Vector3(x, 0, y)
	scene.scale = Vector3.ONE * sc
	objects_container.add_child(scene)
	spawned_items.append({"type": "model", "path": path, "x": x, "y": y})

	# Auto-play animations if present
	var anim_player = scene.find_child("AnimationPlayer", true, false)
	if anim_player and anim_player.get_animation_list().size() > 0:
		anim_player.play(anim_player.get_animation_list()[0])

# ── Materials (PBR for Forward+) ─────────────────────────────────────────────

func make_emissive_mat(color_hex: String, strength: float = 3.0) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	var c = Color.html(color_hex)
	mat.albedo_color = c.darkened(0.7)
	mat.metallic = 0.2
	mat.roughness = 0.6
	mat.emission_enabled = true
	mat.emission = c
	mat.emission_energy_multiplier = strength
	return mat

func make_translucent_mat(color_hex: String, strength: float = 3.0) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	var c = Color.html(color_hex)
	mat.albedo_color = c.darkened(0.6)
	mat.albedo_color.a = 0.85
	mat.metallic = 0.1
	mat.roughness = 0.5
	mat.emission_enabled = true
	mat.emission = c
	mat.emission_energy_multiplier = strength
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return mat

func make_dark_mat(color_hex: String = "#080810") -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color.html(color_hex)
	mat.metallic = 0.0
	mat.roughness = 0.9
	return mat

func make_metallic_mat(color_hex: String) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color.html(color_hex)
	mat.metallic = 0.85
	mat.roughness = 0.25
	mat.emission_enabled = false
	return mat

func make_organic_mat(color_hex: String) -> StandardMaterial3D:
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color.html(color_hex)
	mat.metallic = 0.0
	mat.roughness = 0.8
	mat.subsurf_scatter_enabled = true
	mat.subsurf_scatter_strength = 0.5
	return mat

# ── Generators ───────────────────────────────────────────────────────────────

func create_mushroom(params: Dictionary):
	var color = params.get("color", "#00ffaa")
	var x = float(params.get("x", 0))
	var y = float(params.get("y", 0))
	var emission = float(params.get("emission", 3.0))
	var sc = float(params.get("scale", 1.0))
	var group = Node3D.new()
	group.name = "Mushroom"
	var rng = RandomNumberGenerator.new()
	rng.seed = 42 + int(x * 100 + y * 37)

	# Stem — tapered cylinder
	var stem_mesh = CylinderMesh.new()
	stem_mesh.top_radius = 0.09
	stem_mesh.bottom_radius = 0.15
	stem_mesh.height = 1.2
	stem_mesh.radial_segments = 16
	var stem = MeshInstance3D.new()
	stem.mesh = stem_mesh
	stem.material_override = make_organic_mat("#1a1210")
	stem.position.y = 0.6
	group.add_child(stem)

	# Stem veins — 4 emissive cylinders spiraling up
	for v in range(4):
		var vein_angle = (float(v) / 4.0) * TAU
		for seg in range(6):
			var t = float(seg) / 5.0
			var vein_mesh = CylinderMesh.new()
			vein_mesh.top_radius = 0.006
			vein_mesh.bottom_radius = 0.006
			vein_mesh.height = 0.22
			var vein = MeshInstance3D.new()
			vein.mesh = vein_mesh
			vein.material_override = make_emissive_mat(color, emission * 0.3)
			var r = 0.13 * (1.0 - t * 0.3)
			vein.position = Vector3(cos(vein_angle + t * 1.5) * r, 0.1 + t * 1.0, sin(vein_angle + t * 1.5) * r)
			group.add_child(vein)

	# Cap — flattened sphere
	var cap_mesh = SphereMesh.new()
	cap_mesh.radius = 0.55
	cap_mesh.height = 0.44
	cap_mesh.radial_segments = 48
	cap_mesh.rings = 24
	var cap = MeshInstance3D.new()
	cap.mesh = cap_mesh
	cap.material_override = make_translucent_mat(color, emission)
	cap.position.y = 1.2
	group.add_child(cap)

	# Cap spots — brighter emission patches
	for s in range(8):
		var theta = rng.randf() * PI * 0.35
		var phi = rng.randf() * TAU
		var spot_mesh = SphereMesh.new()
		var sr = 0.03 + rng.randf() * 0.04
		spot_mesh.radius = sr
		spot_mesh.height = sr * 2
		var spot = MeshInstance3D.new()
		spot.mesh = spot_mesh
		spot.material_override = make_emissive_mat(color, emission * 1.5)
		spot.position = Vector3(
			sin(theta) * cos(phi) * 0.52,
			1.2 + cos(theta) * 0.22,
			sin(theta) * sin(phi) * 0.52
		)
		group.add_child(spot)

	# Multiple gill rings
	for g in range(3):
		var gill_mesh = TorusMesh.new()
		gill_mesh.inner_radius = 0.27 + g * 0.06
		gill_mesh.outer_radius = 0.30 + g * 0.06
		var gills = MeshInstance3D.new()
		gills.mesh = gill_mesh
		gills.material_override = make_emissive_mat(color, emission * (0.6 - g * 0.15))
		gills.position.y = 1.02 - g * 0.03
		group.add_child(gills)

	# Dripping spore drops
	for d in range(6):
		var da = (float(d) / 6.0) * TAU
		var drop_mesh = SphereMesh.new()
		drop_mesh.radius = 0.012
		drop_mesh.height = 0.024
		var drop = MeshInstance3D.new()
		drop.mesh = drop_mesh
		drop.material_override = make_emissive_mat(color, emission * 0.8)
		drop.position = Vector3(cos(da) * 0.35, 0.95 - rng.randf() * 0.15, sin(da) * 0.35)
		group.add_child(drop)

	# Point light
	var light = OmniLight3D.new()
	light.light_color = Color.html(color)
	light.light_energy = emission * 0.3
	light.omni_range = 3.0
	light.shadow_enabled = true
	light.position.y = 1.2
	group.add_child(light)

	group.scale = Vector3.ONE * sc
	group.position = Vector3(x, 0, y)
	objects_container.add_child(group)
	spawned_items.append({"type": "mushroom", "color": color, "x": x, "y": y})

func create_spore_cluster(params: Dictionary):
	var color = params.get("color", "#ff77ff")
	var x = float(params.get("x", 0))
	var y = float(params.get("y", 0))
	var emission = float(params.get("emission", 3.0))
	var group = Node3D.new()
	group.name = "SporeCluster"
	var rng = RandomNumberGenerator.new()
	rng.seed = 42

	# Central core
	var core_mesh = SphereMesh.new()
	core_mesh.radius = 0.2
	core_mesh.height = 0.4
	core_mesh.radial_segments = 24
	var core = MeshInstance3D.new()
	core.mesh = core_mesh
	core.material_override = make_organic_mat(Color.html(color).darkened(0.5).to_html())
	core.position.y = 0.3
	group.add_child(core)

	# 35 spores of varied sizes
	for i in range(35):
		var sx = (rng.randf() - 0.5) * 2.0
		var sy = rng.randf() * 2.0
		var sz = (rng.randf() - 0.5) * 2.0
		var r = 0.02 + rng.randf() * 0.1
		var strength = emission * (0.4 + rng.randf() * 1.2)
		var sphere = SphereMesh.new()
		sphere.radius = r
		sphere.height = r * 2
		sphere.radial_segments = 10
		var mi = MeshInstance3D.new()
		mi.mesh = sphere
		mi.material_override = make_emissive_mat(color, strength)
		mi.position = Vector3(sx, sy, sz)
		group.add_child(mi)

		# Connecting tendrils between some spores
		if rng.randf() > 0.7 and group.get_child_count() > 2:
			var prev = group.get_child(max(0, group.get_child_count() - 3))
			if prev is MeshInstance3D:
				var tendril_mesh = CylinderMesh.new()
				tendril_mesh.top_radius = 0.004
				tendril_mesh.bottom_radius = 0.004
				var dist = mi.position.distance_to(prev.position)
				tendril_mesh.height = dist
				var tendril = MeshInstance3D.new()
				tendril.mesh = tendril_mesh
				tendril.material_override = make_emissive_mat(color, strength * 0.3)
				tendril.position = (mi.position + prev.position) / 2
				tendril.look_at(mi.position)
				tendril.rotation.x += PI / 2
				group.add_child(tendril)

	# Point light
	var light = OmniLight3D.new()
	light.light_color = Color.html(color)
	light.light_energy = emission * 0.2
	light.omni_range = 4.0
	light.shadow_enabled = true
	light.position = Vector3(0, 1.0, 0)
	group.add_child(light)

	group.position = Vector3(x, 0, y)
	objects_container.add_child(group)
	spawned_items.append({"type": "spore_cluster", "color": color, "x": x, "y": y})

func create_tree(params: Dictionary):
	var color = params.get("color", "#77aaff")
	var x = float(params.get("x", 0))
	var y = float(params.get("y", 0))
	var emission = float(params.get("emission", 3.0))
	var group = Node3D.new()
	group.name = "Tree"
	var rng = RandomNumberGenerator.new()
	rng.seed = 42

	# Trunk — tapered with organic material
	var trunk_mesh = CylinderMesh.new()
	trunk_mesh.top_radius = 0.06
	trunk_mesh.bottom_radius = 0.16
	trunk_mesh.height = 2.2
	trunk_mesh.radial_segments = 16
	var trunk = MeshInstance3D.new()
	trunk.mesh = trunk_mesh
	trunk.material_override = make_organic_mat("#1a1210")
	trunk.position.y = 1.1
	group.add_child(trunk)

	# Roots
	for r in range(5):
		var root_angle = (float(r) / 5.0) * TAU + rng.randf() * 0.5
		var root_len = 0.5 + rng.randf() * 0.4
		var root_mesh = CylinderMesh.new()
		root_mesh.top_radius = 0.04
		root_mesh.bottom_radius = 0.02
		root_mesh.height = root_len
		var root = MeshInstance3D.new()
		root.mesh = root_mesh
		root.material_override = make_organic_mat("#0d0a08")
		root.position = Vector3(cos(root_angle) * root_len * 0.4, 0.0, sin(root_angle) * root_len * 0.4)
		root.rotation = Vector3(0, 0, PI * 0.35)
		root.rotation.y = -root_angle
		group.add_child(root)

	# 8 branches with tip clusters
	for i in range(8):
		var angle = (float(i) / 8.0) * TAU + (rng.randf() - 0.5) * 0.8
		var height = 0.8 + rng.randf() * 1.4
		var length = 0.4 + rng.randf() * 0.6

		var branch_mesh = CylinderMesh.new()
		branch_mesh.top_radius = 0.015
		branch_mesh.bottom_radius = 0.035
		branch_mesh.height = length
		var branch = MeshInstance3D.new()
		branch.mesh = branch_mesh
		branch.material_override = make_organic_mat("#1a1210")
		branch.position = Vector3(cos(angle) * 0.15, height, sin(angle) * 0.15)
		branch.rotation = Vector3((rng.randf() - 0.5) * 0.8, 0, (rng.randf() - 0.5) * 0.8)
		group.add_child(branch)

		# Tip cluster — 3 glowing spheres
		var tip_x = cos(angle) * (0.15 + length * 0.5)
		var tip_z = sin(angle) * (0.15 + length * 0.5)
		for t in range(3):
			var tip_mesh = SphereMesh.new()
			var tr = 0.03 + rng.randf() * 0.04
			tip_mesh.radius = tr
			tip_mesh.height = tr * 2
			var tip = MeshInstance3D.new()
			tip.mesh = tip_mesh
			tip.material_override = make_emissive_mat(color, emission * (0.6 + rng.randf() * 0.8))
			tip.position = Vector3(
				tip_x + (rng.randf() - 0.5) * 0.08,
				height + 0.1 + (rng.randf() - 0.5) * 0.08,
				tip_z + (rng.randf() - 0.5) * 0.08
			)
			group.add_child(tip)

	# Shelf fungi on trunk
	for f in range(4):
		var f_angle = rng.randf() * TAU
		var f_height = 0.3 + rng.randf() * 1.2
		var shelf_mesh = SphereMesh.new()
		shelf_mesh.radius = 0.1 + rng.randf() * 0.08
		shelf_mesh.height = 0.06
		shelf_mesh.is_hemisphere = true
		var shelf = MeshInstance3D.new()
		shelf.mesh = shelf_mesh
		shelf.material_override = make_emissive_mat(color, emission * 0.4)
		shelf.position = Vector3(cos(f_angle) * 0.16, f_height, sin(f_angle) * 0.16)
		shelf.rotation.z = PI * 0.1
		shelf.rotation.y = -f_angle
		group.add_child(shelf)

	# Spiral vine up trunk
	for v in range(30):
		var vt = float(v) / 29.0
		var v_angle = vt * TAU * 3
		var vr = 0.17 * (1.0 - vt * 0.4)
		var vine_mesh = SphereMesh.new()
		vine_mesh.radius = 0.005
		vine_mesh.height = 0.01
		var vine = MeshInstance3D.new()
		vine.mesh = vine_mesh
		vine.material_override = make_emissive_mat(color, emission * 0.3)
		vine.position = Vector3(cos(v_angle) * vr, vt * 2.2, sin(v_angle) * vr)
		group.add_child(vine)

	# Point light
	var light = OmniLight3D.new()
	light.light_color = Color.html(color)
	light.light_energy = emission * 0.3
	light.omni_range = 4.0
	light.shadow_enabled = true
	light.position = Vector3(0, 1.5, 0)
	group.add_child(light)

	group.position = Vector3(x, 0, y)
	objects_container.add_child(group)
	spawned_items.append({"type": "tree", "color": color, "x": x, "y": y})

func create_forest_floor(params: Dictionary):
	var color = params.get("color", "#00ffaa")
	var emission = float(params.get("emission", 3.0))
	var group = Node3D.new()
	group.name = "ForestFloor"
	var rng = RandomNumberGenerator.new()
	rng.seed = 42

	# Ground plane
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(10, 10)
	plane_mesh.subdivide_width = 64
	plane_mesh.subdivide_depth = 64
	var ground = MeshInstance3D.new()
	ground.mesh = plane_mesh
	ground.material_override = make_organic_mat("#0a0a0c")
	group.add_child(ground)

	# Glowing moss patches
	for m in range(12):
		var mx = (rng.randf() - 0.5) * 7
		var mz = (rng.randf() - 0.5) * 7
		var moss_mesh = PlaneMesh.new()
		moss_mesh.size = Vector2(0.3 + rng.randf() * 0.5, 0.3 + rng.randf() * 0.5)
		var moss = MeshInstance3D.new()
		moss.mesh = moss_mesh
		moss.material_override = make_emissive_mat(color, emission * (0.2 + rng.randf() * 0.4))
		moss.position = Vector3(mx, 0.01, mz)
		moss.rotation.y = rng.randf() * PI
		group.add_child(moss)

	# 50 scattered elements — tiny mushrooms, spheres, cones
	var element_colors = [color, "#ff77ff", "#77aaff", "#ffaa44"]
	for i in range(50):
		var gx = (rng.randf() - 0.5) * 8
		var gz = (rng.randf() - 0.5) * 8
		var gy = 0.01 + rng.randf() * 0.06
		var e_color = element_colors[rng.randi() % element_colors.size()]
		var strength = emission * (0.2 + rng.randf() * 0.8)

		var roll = rng.randf()
		if roll > 0.7:
			# Tiny mushroom
			var tiny = Node3D.new()
			var ts_mesh = CylinderMesh.new()
			ts_mesh.top_radius = 0.008
			ts_mesh.bottom_radius = 0.01
			ts_mesh.height = 0.06
			var ts = MeshInstance3D.new()
			ts.mesh = ts_mesh
			ts.material_override = make_organic_mat("#1a1210")
			ts.position.y = 0.03
			tiny.add_child(ts)
			var tc_mesh = SphereMesh.new()
			tc_mesh.radius = 0.025
			tc_mesh.height = 0.02
			var tc = MeshInstance3D.new()
			tc.mesh = tc_mesh
			tc.material_override = make_emissive_mat(e_color, strength)
			tc.position.y = 0.065
			tiny.add_child(tc)
			tiny.position = Vector3(gx, gy, gz)
			tiny.scale = Vector3.ONE * (0.8 + rng.randf() * 0.8)
			group.add_child(tiny)
		elif roll > 0.4:
			var sphere = SphereMesh.new()
			var r = 0.015 + rng.randf() * 0.03
			sphere.radius = r
			sphere.height = r * 2
			var mi = MeshInstance3D.new()
			mi.mesh = sphere
			mi.material_override = make_emissive_mat(e_color, strength)
			mi.position = Vector3(gx, gy, gz)
			group.add_child(mi)
		else:
			var cone = CylinderMesh.new()
			cone.top_radius = 0.0
			cone.bottom_radius = 0.02 + rng.randf() * 0.02
			cone.height = 0.05 + rng.randf() * 0.08
			var mi = MeshInstance3D.new()
			mi.mesh = cone
			mi.material_override = make_emissive_mat(e_color, strength)
			mi.position = Vector3(gx, gy, gz)
			group.add_child(mi)

	# Mycelium network — thin lines on ground
	for n in range(15):
		var nx = (rng.randf() - 0.5) * 6
		var nz = (rng.randf() - 0.5) * 6
		for seg in range(5):
			nx += (rng.randf() - 0.5) * 0.8
			nz += (rng.randf() - 0.5) * 0.8
			var net_mesh = CylinderMesh.new()
			net_mesh.top_radius = 0.003
			net_mesh.bottom_radius = 0.003
			net_mesh.height = 0.4 + rng.randf() * 0.4
			var net = MeshInstance3D.new()
			net.mesh = net_mesh
			net.material_override = make_emissive_mat(color, emission * 0.15)
			net.position = Vector3(nx, 0.003, nz)
			net.rotation.x = PI / 2
			net.rotation.y = rng.randf() * PI
			group.add_child(net)

	# Colored lights
	var light_data = [
		{"pos": Vector3(0, 0.5, 0), "color": color},
		{"pos": Vector3(3, 0.3, 2), "color": "#ff77ff"},
		{"pos": Vector3(-2, 0.4, -3), "color": "#77aaff"}
	]
	for ld in light_data:
		var light = OmniLight3D.new()
		light.light_color = Color.html(ld["color"])
		light.light_energy = emission * 0.15
		light.omni_range = 5.0
		light.shadow_enabled = true
		light.position = ld["pos"]
		group.add_child(light)

	objects_container.add_child(group)
	spawned_items.append({"type": "forest_floor", "color": color})

# ── Mecha Generator ──────────────────────────────────────────────────────────

func create_mecha(params: Dictionary):
	var color = params.get("color", "#00ffaa")
	var x = float(params.get("x", 0))
	var y = float(params.get("y", 0))
	var sc = float(params.get("scale", 1.0))
	var animation = params.get("animation", "idle")
	var group = Node3D.new()
	group.name = "Mecha"

	var armor_mat = make_metallic_mat(Color.html(color).darkened(0.3).to_html())
	var accent_mat = make_emissive_mat(color, 2.0)
	var joint_mat = make_metallic_mat("#1a1a1a")
	var visor_mat = make_emissive_mat(color, 5.0)

	# ── Torso ──
	var torso_mesh = BoxMesh.new()
	torso_mesh.size = Vector3(0.7, 0.8, 0.4)
	var torso = MeshInstance3D.new()
	torso.mesh = torso_mesh
	torso.material_override = armor_mat
	torso.position.y = 1.6
	group.add_child(torso)

	# Chest vents (emissive accents)
	for cv in range(3):
		var vent_mesh = BoxMesh.new()
		vent_mesh.size = Vector3(0.15, 0.03, 0.42)
		var vent = MeshInstance3D.new()
		vent.mesh = vent_mesh
		vent.material_override = accent_mat
		vent.position = Vector3(0, 1.45 + cv * 0.12, 0)
		group.add_child(vent)

	# Reactor core (center chest glow)
	var reactor_mesh = SphereMesh.new()
	reactor_mesh.radius = 0.08
	reactor_mesh.height = 0.16
	var reactor = MeshInstance3D.new()
	reactor.mesh = reactor_mesh
	reactor.material_override = make_emissive_mat(color, 8.0)
	reactor.position = Vector3(0, 1.7, 0.22)
	group.add_child(reactor)

	var reactor_light = OmniLight3D.new()
	reactor_light.light_color = Color.html(color)
	reactor_light.light_energy = 1.5
	reactor_light.omni_range = 2.0
	reactor_light.shadow_enabled = true
	reactor_light.position = reactor.position
	group.add_child(reactor_light)

	# ── Head ──
	var head_mesh = BoxMesh.new()
	head_mesh.size = Vector3(0.3, 0.25, 0.3)
	var head = MeshInstance3D.new()
	head.mesh = head_mesh
	head.material_override = armor_mat
	head.position.y = 2.2
	group.add_child(head)

	# Visor
	var visor_mesh_r = BoxMesh.new()
	visor_mesh_r.size = Vector3(0.32, 0.06, 0.05)
	var visor = MeshInstance3D.new()
	visor.mesh = visor_mesh_r
	visor.material_override = visor_mat
	visor.position = Vector3(0, 2.22, 0.16)
	group.add_child(visor)

	# Head crest / antenna
	var crest_mesh = BoxMesh.new()
	crest_mesh.size = Vector3(0.04, 0.2, 0.04)
	var crest = MeshInstance3D.new()
	crest.mesh = crest_mesh
	crest.material_override = accent_mat
	crest.position = Vector3(0, 2.45, 0)
	group.add_child(crest)

	# ── Shoulder armor ──
	for side in [-1, 1]:
		var shoulder_mesh = BoxMesh.new()
		shoulder_mesh.size = Vector3(0.35, 0.2, 0.45)
		var shoulder = MeshInstance3D.new()
		shoulder.mesh = shoulder_mesh
		shoulder.material_override = armor_mat
		shoulder.position = Vector3(side * 0.52, 1.95, 0)
		group.add_child(shoulder)

		# Shoulder accent
		var s_accent_mesh = BoxMesh.new()
		s_accent_mesh.size = Vector3(0.36, 0.03, 0.46)
		var s_accent = MeshInstance3D.new()
		s_accent.mesh = s_accent_mesh
		s_accent.material_override = accent_mat
		s_accent.position = Vector3(side * 0.52, 2.07, 0)
		group.add_child(s_accent)

	# ── Arms ──
	for side in [-1, 1]:
		# Upper arm
		var upper_mesh = BoxMesh.new()
		upper_mesh.size = Vector3(0.15, 0.4, 0.15)
		var upper = MeshInstance3D.new()
		upper.mesh = upper_mesh
		upper.material_override = armor_mat
		upper.position = Vector3(side * 0.52, 1.55, 0)
		group.add_child(upper)

		# Elbow joint
		var elbow_mesh = SphereMesh.new()
		elbow_mesh.radius = 0.08
		elbow_mesh.height = 0.16
		var elbow = MeshInstance3D.new()
		elbow.mesh = elbow_mesh
		elbow.material_override = joint_mat
		elbow.position = Vector3(side * 0.52, 1.3, 0)
		group.add_child(elbow)

		# Forearm
		var fore_mesh = BoxMesh.new()
		fore_mesh.size = Vector3(0.18, 0.35, 0.18)
		var forearm = MeshInstance3D.new()
		forearm.mesh = fore_mesh
		forearm.material_override = armor_mat
		forearm.position = Vector3(side * 0.52, 1.05, 0)
		group.add_child(forearm)

		# Forearm accent stripe
		var fa_mesh = BoxMesh.new()
		fa_mesh.size = Vector3(0.19, 0.03, 0.19)
		var fa = MeshInstance3D.new()
		fa.mesh = fa_mesh
		fa.material_override = accent_mat
		fa.position = Vector3(side * 0.52, 1.1, 0)
		group.add_child(fa)

		# Hand
		var hand_mesh = BoxMesh.new()
		hand_mesh.size = Vector3(0.12, 0.12, 0.08)
		var hand = MeshInstance3D.new()
		hand.mesh = hand_mesh
		hand.material_override = joint_mat
		hand.position = Vector3(side * 0.52, 0.82, 0)
		group.add_child(hand)

	# ── Waist ──
	var waist_mesh = BoxMesh.new()
	waist_mesh.size = Vector3(0.5, 0.15, 0.35)
	var waist = MeshInstance3D.new()
	waist.mesh = waist_mesh
	waist.material_override = joint_mat
	waist.position.y = 1.15
	group.add_child(waist)

	# Skirt armor plates
	for side in [-1, 0, 1]:
		var skirt_mesh = BoxMesh.new()
		skirt_mesh.size = Vector3(0.2, 0.2, 0.38)
		var skirt = MeshInstance3D.new()
		skirt.mesh = skirt_mesh
		skirt.material_override = armor_mat
		skirt.position = Vector3(side * 0.22, 1.0, 0)
		group.add_child(skirt)

	# ── Legs ──
	for side in [-1, 1]:
		# Thigh
		var thigh_mesh = BoxMesh.new()
		thigh_mesh.size = Vector3(0.2, 0.4, 0.2)
		var thigh = MeshInstance3D.new()
		thigh.mesh = thigh_mesh
		thigh.material_override = armor_mat
		thigh.position = Vector3(side * 0.2, 0.7, 0)
		group.add_child(thigh)

		# Knee joint
		var knee_mesh = SphereMesh.new()
		knee_mesh.radius = 0.1
		knee_mesh.height = 0.2
		var knee = MeshInstance3D.new()
		knee.mesh = knee_mesh
		knee.material_override = joint_mat
		knee.position = Vector3(side * 0.2, 0.45, 0)
		group.add_child(knee)

		# Shin
		var shin_mesh = BoxMesh.new()
		shin_mesh.size = Vector3(0.22, 0.4, 0.22)
		var shin = MeshInstance3D.new()
		shin.mesh = shin_mesh
		shin.material_override = armor_mat
		shin.position = Vector3(side * 0.2, 0.2, 0)
		group.add_child(shin)

		# Shin accent
		var sa_mesh = BoxMesh.new()
		sa_mesh.size = Vector3(0.23, 0.03, 0.23)
		var sa = MeshInstance3D.new()
		sa.mesh = sa_mesh
		sa.material_override = accent_mat
		sa.position = Vector3(side * 0.2, 0.3, 0)
		group.add_child(sa)

		# Foot
		var foot_mesh = BoxMesh.new()
		foot_mesh.size = Vector3(0.22, 0.1, 0.35)
		var foot = MeshInstance3D.new()
		foot.mesh = foot_mesh
		foot.material_override = armor_mat
		foot.position = Vector3(side * 0.2, -0.02, 0.05)
		group.add_child(foot)

	# ── Backpack / thruster unit ──
	var pack_mesh = BoxMesh.new()
	pack_mesh.size = Vector3(0.5, 0.6, 0.2)
	var pack = MeshInstance3D.new()
	pack.mesh = pack_mesh
	pack.material_override = armor_mat
	pack.position = Vector3(0, 1.7, -0.3)
	group.add_child(pack)

	# Thruster nozzles
	for side in [-1, 1]:
		var nozzle_mesh = CylinderMesh.new()
		nozzle_mesh.top_radius = 0.06
		nozzle_mesh.bottom_radius = 0.1
		nozzle_mesh.height = 0.2
		var nozzle = MeshInstance3D.new()
		nozzle.mesh = nozzle_mesh
		nozzle.material_override = joint_mat
		nozzle.position = Vector3(side * 0.15, 1.35, -0.35)
		group.add_child(nozzle)

		# Thruster glow
		var glow_mesh = SphereMesh.new()
		glow_mesh.radius = 0.05
		glow_mesh.height = 0.1
		var glow = MeshInstance3D.new()
		glow.mesh = glow_mesh
		glow.material_override = make_emissive_mat(color, 6.0)
		glow.position = Vector3(side * 0.15, 1.25, -0.35)
		group.add_child(glow)

	group.scale = Vector3.ONE * sc
	group.position = Vector3(x, 0, y)
	objects_container.add_child(group)
	spawned_items.append({"type": "mecha", "color": color, "x": x, "y": y, "animation": animation})

func create_full_scene(params: Dictionary):
	# Clear
	for child in objects_container.get_children():
		child.queue_free()
	spawned_items.clear()

	# Wait a frame for cleanup
	await get_tree().process_frame

	create_forest_floor({})
	create_mushroom({"color": "#00ffaa", "x": 0, "y": 0, "emission": 4.0, "scale": 1.3})
	create_mushroom({"color": "#00ffcc", "x": 1.2, "y": 0.8, "emission": 2.5, "scale": 0.6})
	create_mushroom({"color": "#00ff88", "x": -0.8, "y": 1.0, "emission": 3.0, "scale": 0.8})
	create_mushroom({"color": "#44ffaa", "x": 0.5, "y": -1.5, "emission": 2.0, "scale": 0.5})
	create_spore_cluster({"color": "#ff77ff", "x": 2.5, "y": 0})
	create_spore_cluster({"color": "#ff55dd", "x": -1.5, "y": -2.0, "emission": 2.0})
	create_tree({"color": "#77aaff", "x": -2.5, "y": 1.0})
	create_tree({"color": "#5599ff", "x": 3.0, "y": -2.0, "emission": 2.5})

# ── Abyss Scene (Underwater) ─────────────────────────────────────────────────

func apply_abyss_environment():
	var env = $WorldEnvironment.environment as Environment
	# Deep ocean sky
	var sky_mat = env.sky.sky_material as ProceduralSkyMaterial
	sky_mat.sky_top_color = Color(0.0, 0.01, 0.04)
	sky_mat.sky_horizon_color = Color(0.0, 0.03, 0.06)
	sky_mat.ground_bottom_color = Color(0.0, 0.0, 0.01)
	sky_mat.ground_horizon_color = Color(0.0, 0.02, 0.04)
	sky_mat.sky_energy_multiplier = 0.15
	# Ocean volumetric fog — thick blue-green murk
	env.volumetric_fog_density = 0.06
	env.volumetric_fog_albedo = Color(0.0, 0.03, 0.06)
	env.volumetric_fog_emission = Color(0.0, 0.008, 0.02)
	env.volumetric_fog_emission_energy = 0.3
	# Distance fog — deep blue
	env.fog_light_color = Color(0.0, 0.015, 0.04)
	env.fog_density = 0.025
	# Boost glow for underwater bioluminescence
	env.glow_intensity = 2.0
	env.glow_strength = 1.5
	env.glow_bloom = 0.5
	env.glow_hdr_threshold = 0.4
	# Dim ambient
	env.ambient_light_energy = 0.2
	# Moonlight becomes faint surface light
	$MoonLight.light_color = Color(0.2, 0.35, 0.5)
	$MoonLight.light_energy = 0.15

func apply_forest_environment():
	var env = $WorldEnvironment.environment as Environment
	var sky_mat = env.sky.sky_material as ProceduralSkyMaterial
	sky_mat.sky_top_color = Color(0.15, 0.06, 0.35)
	sky_mat.sky_horizon_color = Color(0.12, 0.25, 0.18)
	sky_mat.ground_bottom_color = Color(0.06, 0.06, 0.12)
	sky_mat.ground_horizon_color = Color(0.1, 0.18, 0.12)
	sky_mat.sky_energy_multiplier = 1.0
	env.volumetric_fog_density = 0.03
	env.volumetric_fog_albedo = Color(0.05, 0.1, 0.07)
	env.volumetric_fog_emission = Color(0.01, 0.04, 0.02)
	env.volumetric_fog_emission_energy = 0.8
	env.fog_light_color = Color(0.03, 0.06, 0.04)
	env.fog_density = 0.02
	env.glow_intensity = 1.5
	env.glow_strength = 1.2
	env.glow_bloom = 0.3
	env.glow_hdr_threshold = 0.6
	env.ambient_light_energy = 0.5
	$MoonLight.light_color = Color(0.6, 0.65, 0.8)
	$MoonLight.light_energy = 0.4

func create_abyss_scene(params: Dictionary):
	# Clear everything
	for child in objects_container.get_children():
		child.queue_free()
	spawned_items.clear()
	await get_tree().process_frame

	# Swap environment to deep ocean
	apply_abyss_environment()

	# Ocean floor
	create_sea_floor({})

	# Jellyfish — scattered at various heights
	create_jellyfish({"color": "#ff3388", "x": 0, "y": 0, "height": 3.5, "scale": 1.2})
	create_jellyfish({"color": "#33ccff", "x": 2.0, "y": 1.5, "height": 2.8, "scale": 0.7})
	create_jellyfish({"color": "#ff88ff", "x": -1.8, "y": -1.0, "height": 4.2, "scale": 0.9})
	create_jellyfish({"color": "#ffaa33", "x": 0.5, "y": 3.0, "height": 1.8, "scale": 0.5})
	create_jellyfish({"color": "#33ffcc", "x": -3.0, "y": 2.0, "height": 3.0, "scale": 0.6})
	create_jellyfish({"color": "#ff5555", "x": 3.5, "y": -1.5, "height": 5.0, "scale": 0.4})

	# Coral formations
	create_coral({"color": "#ff4466", "x": 1.5, "y": 1.0})
	create_coral({"color": "#ff8833", "x": -2.0, "y": -1.5})
	create_coral({"color": "#cc44ff", "x": 0.5, "y": -2.5})
	create_coral({"color": "#33ddff", "x": -1.0, "y": 2.5})

	# Hydrothermal vents
	create_hydrothermal_vent({"x": 3.0, "y": 0.5})
	create_hydrothermal_vent({"x": -3.5, "y": -2.0, "scale": 0.7})

	# Anglerfish lurking
	create_anglerfish({"x": -1.5, "y": 0.5})
	create_anglerfish({"x": 2.5, "y": -2.0, "scale": 0.6})

	# Sunken ruins
	create_sunken_ruin({"x": 0, "y": -1.0})
	create_sunken_ruin({"x": -3.0, "y": 1.5, "scale": 0.6})

	# Marine snow — drifting particles
	create_marine_snow({})

func create_sea_floor(params: Dictionary):
	var group = Node3D.new()
	group.name = "SeaFloor"
	var rng = RandomNumberGenerator.new()
	rng.seed = 99

	# Sandy ocean floor
	var floor_mesh = PlaneMesh.new()
	floor_mesh.size = Vector2(14, 14)
	floor_mesh.subdivide_width = 64
	floor_mesh.subdivide_depth = 64
	var floor_mi = MeshInstance3D.new()
	floor_mi.mesh = floor_mesh
	var floor_mat = StandardMaterial3D.new()
	floor_mat.albedo_color = Color(0.04, 0.05, 0.07)
	floor_mat.metallic = 0.0
	floor_mat.roughness = 0.95
	floor_mi.material_override = floor_mat
	group.add_child(floor_mi)

	# Sand ripples — slightly raised strips
	for i in range(20):
		var ripple_mesh = BoxMesh.new()
		ripple_mesh.size = Vector3(4.0 + rng.randf() * 3.0, 0.01, 0.08)
		var ripple = MeshInstance3D.new()
		ripple.mesh = ripple_mesh
		var ripple_mat = StandardMaterial3D.new()
		ripple_mat.albedo_color = Color(0.06, 0.07, 0.09)
		ripple_mat.roughness = 0.9
		ripple.material_override = ripple_mat
		ripple.position = Vector3((rng.randf() - 0.5) * 10, 0.005, -5 + i * 0.5 + rng.randf() * 0.3)
		ripple.rotation.y = (rng.randf() - 0.5) * 0.3
		group.add_child(ripple)

	# Bioluminescent patches on floor
	var bio_colors = ["#00ccff", "#33ffaa", "#ff33aa", "#ffcc00"]
	for i in range(18):
		var bx = (rng.randf() - 0.5) * 10
		var bz = (rng.randf() - 0.5) * 10
		var bc = bio_colors[rng.randi() % bio_colors.size()]
		var patch_mesh = PlaneMesh.new()
		patch_mesh.size = Vector2(0.2 + rng.randf() * 0.4, 0.2 + rng.randf() * 0.4)
		var patch = MeshInstance3D.new()
		patch.mesh = patch_mesh
		patch.material_override = make_emissive_mat(bc, 1.0 + rng.randf() * 2.0)
		patch.position = Vector3(bx, 0.01, bz)
		patch.rotation.y = rng.randf() * TAU
		group.add_child(patch)

	# Scattered rocks
	for i in range(15):
		var rx = (rng.randf() - 0.5) * 10
		var rz = (rng.randf() - 0.5) * 10
		var rock_mesh = SphereMesh.new()
		var rr = 0.1 + rng.randf() * 0.25
		rock_mesh.radius = rr
		rock_mesh.height = rr * (1.2 + rng.randf() * 0.8)
		var rock = MeshInstance3D.new()
		rock.mesh = rock_mesh
		var rock_mat = StandardMaterial3D.new()
		rock_mat.albedo_color = Color(0.05, 0.06, 0.08)
		rock_mat.roughness = 0.95
		rock_mat.metallic = 0.0
		rock.material_override = rock_mat
		rock.position = Vector3(rx, rr * 0.3, rz)
		rock.scale = Vector3(1.0 + rng.randf() * 0.5, 0.5 + rng.randf() * 0.5, 1.0 + rng.randf() * 0.5)
		group.add_child(rock)

	# Sea anemones — clusters of glowing tendrils
	for i in range(6):
		var ax = (rng.randf() - 0.5) * 8
		var az = (rng.randf() - 0.5) * 8
		var a_color = bio_colors[rng.randi() % bio_colors.size()]
		var anemone = Node3D.new()
		for t in range(12):
			var ta = (float(t) / 12.0) * TAU
			var tendril_mesh = CylinderMesh.new()
			tendril_mesh.top_radius = 0.005
			tendril_mesh.bottom_radius = 0.012
			var th = 0.15 + rng.randf() * 0.2
			tendril_mesh.height = th
			var tendril = MeshInstance3D.new()
			tendril.mesh = tendril_mesh
			tendril.material_override = make_emissive_mat(a_color, 2.0 + rng.randf() * 2.0)
			var spread = 0.06 + rng.randf() * 0.04
			tendril.position = Vector3(cos(ta) * spread, th * 0.5, sin(ta) * spread)
			tendril.rotation = Vector3((rng.randf() - 0.5) * 0.4, 0, (rng.randf() - 0.5) * 0.4)
			anemone.add_child(tendril)
		# Tip spheres
		for t in range(12):
			var ta = (float(t) / 12.0) * TAU
			var tip_mesh = SphereMesh.new()
			tip_mesh.radius = 0.01
			tip_mesh.height = 0.02
			var tip = MeshInstance3D.new()
			tip.mesh = tip_mesh
			tip.material_override = make_emissive_mat(a_color, 4.0)
			var spread = 0.06 + rng.randf() * 0.04
			tip.position = Vector3(cos(ta) * spread, 0.15 + rng.randf() * 0.15, sin(ta) * spread)
			anemone.add_child(tip)
		anemone.position = Vector3(ax, 0, az)
		group.add_child(anemone)

	objects_container.add_child(group)
	spawned_items.append({"type": "sea_floor"})

func create_jellyfish(params: Dictionary):
	var color = params.get("color", "#ff3388")
	var x = float(params.get("x", 0))
	var y = float(params.get("y", 0))
	var h = float(params.get("height", 3.0))
	var sc = float(params.get("scale", 1.0))
	var emission = float(params.get("emission", 4.0))
	var group = Node3D.new()
	group.name = "Jellyfish"
	var rng = RandomNumberGenerator.new()
	rng.seed = 42 + int(x * 77 + y * 33)

	# Bell — translucent dome
	var bell_mesh = SphereMesh.new()
	bell_mesh.radius = 0.4
	bell_mesh.height = 0.5
	bell_mesh.is_hemisphere = true
	bell_mesh.radial_segments = 32
	bell_mesh.rings = 16
	var bell = MeshInstance3D.new()
	bell.mesh = bell_mesh
	var bell_mat = StandardMaterial3D.new()
	var c = Color.html(color)
	bell_mat.albedo_color = Color(c.r * 0.3, c.g * 0.3, c.b * 0.3, 0.4)
	bell_mat.emission_enabled = true
	bell_mat.emission = c
	bell_mat.emission_energy_multiplier = emission * 0.6
	bell_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bell_mat.metallic = 0.0
	bell_mat.roughness = 0.3
	bell.material_override = bell_mat
	bell.position.y = 0
	bell.rotation.x = PI
	group.add_child(bell)

	# Inner bell glow — smaller solid sphere
	var inner_mesh = SphereMesh.new()
	inner_mesh.radius = 0.2
	inner_mesh.height = 0.3
	inner_mesh.radial_segments = 16
	var inner = MeshInstance3D.new()
	inner.mesh = inner_mesh
	inner.material_override = make_emissive_mat(color, emission * 1.2)
	inner.position.y = -0.05
	group.add_child(inner)

	# Oral arms — 4 thick short tentacles from center
	for i in range(4):
		var arm_angle = (float(i) / 4.0) * TAU
		var arm_mesh = CylinderMesh.new()
		arm_mesh.top_radius = 0.03
		arm_mesh.bottom_radius = 0.015
		arm_mesh.height = 0.5
		var arm = MeshInstance3D.new()
		arm.mesh = arm_mesh
		arm.material_override = make_emissive_mat(color, emission * 0.4)
		arm.position = Vector3(cos(arm_angle) * 0.08, -0.4, sin(arm_angle) * 0.08)
		arm.rotation = Vector3((rng.randf() - 0.5) * 0.3, 0, (rng.randf() - 0.5) * 0.3)
		group.add_child(arm)

	# Trailing tentacles — 8 long thin strands
	for i in range(8):
		var t_angle = (float(i) / 8.0) * TAU + rng.randf() * 0.3
		var spread = 0.25 + rng.randf() * 0.1
		var num_segs = 8 + rng.randi() % 6
		for seg in range(num_segs):
			var seg_t = float(seg) / float(num_segs)
			var seg_mesh = CylinderMesh.new()
			seg_mesh.top_radius = 0.004 * (1.0 - seg_t * 0.7)
			seg_mesh.bottom_radius = 0.004 * (1.0 - seg_t * 0.7)
			seg_mesh.height = 0.12
			var seg_mi = MeshInstance3D.new()
			seg_mi.mesh = seg_mesh
			var seg_strength = emission * (0.5 - seg_t * 0.3)
			seg_mi.material_override = make_emissive_mat(color, max(seg_strength, 0.3))
			var drift = seg_t * 0.15
			seg_mi.position = Vector3(
				cos(t_angle) * spread + (rng.randf() - 0.5) * drift,
				-0.15 - seg_t * 1.5,
				sin(t_angle) * spread + (rng.randf() - 0.5) * drift
			)
			group.add_child(seg_mi)

	# Bell rim ring
	var rim_mesh = TorusMesh.new()
	rim_mesh.inner_radius = 0.37
	rim_mesh.outer_radius = 0.41
	var rim = MeshInstance3D.new()
	rim.mesh = rim_mesh
	rim.material_override = make_emissive_mat(color, emission * 0.8)
	rim.position.y = -0.12
	group.add_child(rim)

	# Point light inside
	var light = OmniLight3D.new()
	light.light_color = c
	light.light_energy = emission * 0.25
	light.omni_range = 3.0
	light.shadow_enabled = true
	light.position.y = 0
	group.add_child(light)

	group.scale = Vector3.ONE * sc
	group.position = Vector3(x, h, y)
	objects_container.add_child(group)
	spawned_items.append({"type": "jellyfish", "color": color, "x": x, "y": y, "height": h})

func create_coral(params: Dictionary):
	var color = params.get("color", "#ff4466")
	var x = float(params.get("x", 0))
	var y = float(params.get("y", 0))
	var sc = float(params.get("scale", 1.0))
	var emission = float(params.get("emission", 2.5))
	var group = Node3D.new()
	group.name = "Coral"
	var rng = RandomNumberGenerator.new()
	rng.seed = 42 + int(x * 53 + y * 71)

	var c = Color.html(color)
	var dark_color = c.darkened(0.6).to_html()

	# Main trunk branches — 3-5 upward reaching
	var num_branches = 3 + rng.randi() % 3
	for b in range(num_branches):
		var b_angle = (float(b) / float(num_branches)) * TAU + rng.randf() * 0.5
		var b_height = 0.6 + rng.randf() * 0.8
		var b_lean = 0.2 + rng.randf() * 0.3

		# Branch trunk
		var trunk_mesh = CylinderMesh.new()
		trunk_mesh.top_radius = 0.03 + rng.randf() * 0.02
		trunk_mesh.bottom_radius = 0.06 + rng.randf() * 0.03
		trunk_mesh.height = b_height
		trunk_mesh.radial_segments = 8
		var trunk = MeshInstance3D.new()
		trunk.mesh = trunk_mesh
		trunk.material_override = make_organic_mat(dark_color)
		trunk.position = Vector3(cos(b_angle) * b_lean, b_height * 0.5, sin(b_angle) * b_lean)
		trunk.rotation = Vector3((rng.randf() - 0.5) * 0.4, 0, (rng.randf() - 0.5) * 0.4)
		group.add_child(trunk)

		# Sub-branches — 2-4 per trunk
		var num_sub = 2 + rng.randi() % 3
		for s in range(num_sub):
			var s_angle = rng.randf() * TAU
			var s_height_frac = 0.4 + rng.randf() * 0.5
			var sub_mesh = CylinderMesh.new()
			sub_mesh.top_radius = 0.01
			sub_mesh.bottom_radius = 0.025
			var sh = 0.2 + rng.randf() * 0.3
			sub_mesh.height = sh
			var sub = MeshInstance3D.new()
			sub.mesh = sub_mesh
			sub.material_override = make_emissive_mat(color, emission * (0.3 + rng.randf() * 0.4))
			sub.position = Vector3(
				cos(b_angle) * b_lean + cos(s_angle) * 0.08,
				b_height * s_height_frac + sh * 0.5,
				sin(b_angle) * b_lean + sin(s_angle) * 0.08
			)
			sub.rotation = Vector3((rng.randf() - 0.5) * 0.6, 0, (rng.randf() - 0.5) * 0.6)
			group.add_child(sub)

			# Tip polyp — small glowing sphere
			var polyp_mesh = SphereMesh.new()
			var pr = 0.015 + rng.randf() * 0.02
			polyp_mesh.radius = pr
			polyp_mesh.height = pr * 2
			var polyp = MeshInstance3D.new()
			polyp.mesh = polyp_mesh
			polyp.material_override = make_emissive_mat(color, emission * (0.8 + rng.randf() * 0.5))
			polyp.position = sub.position + Vector3(0, sh * 0.5, 0)
			group.add_child(polyp)

	# Base — encrusted rock
	var base_mesh = SphereMesh.new()
	base_mesh.radius = 0.2 + rng.randf() * 0.1
	base_mesh.height = 0.15
	var base = MeshInstance3D.new()
	base.mesh = base_mesh
	var base_mat = StandardMaterial3D.new()
	base_mat.albedo_color = Color(0.06, 0.07, 0.09)
	base_mat.roughness = 0.95
	base.material_override = base_mat
	base.position.y = 0.02
	group.add_child(base)

	# Glow light
	var light = OmniLight3D.new()
	light.light_color = c
	light.light_energy = emission * 0.15
	light.omni_range = 2.5
	light.position = Vector3(0, 0.5, 0)
	group.add_child(light)

	group.scale = Vector3.ONE * sc
	group.position = Vector3(x, 0, y)
	objects_container.add_child(group)
	spawned_items.append({"type": "coral", "color": color, "x": x, "y": y})

func create_hydrothermal_vent(params: Dictionary):
	var x = float(params.get("x", 0))
	var y = float(params.get("y", 0))
	var sc = float(params.get("scale", 1.0))
	var group = Node3D.new()
	group.name = "HydrothermalVent"
	var rng = RandomNumberGenerator.new()
	rng.seed = 42 + int(x * 41 + y * 59)

	# Chimney stack — rough dark cylinder
	var chimney_mesh = CylinderMesh.new()
	chimney_mesh.top_radius = 0.15
	chimney_mesh.bottom_radius = 0.35
	chimney_mesh.height = 2.0
	chimney_mesh.radial_segments = 12
	var chimney = MeshInstance3D.new()
	chimney.mesh = chimney_mesh
	var chimney_mat = StandardMaterial3D.new()
	chimney_mat.albedo_color = Color(0.08, 0.06, 0.04)
	chimney_mat.roughness = 1.0
	chimney_mat.metallic = 0.0
	chimney.material_override = chimney_mat
	chimney.position.y = 1.0
	group.add_child(chimney)

	# Mineral deposits — bumpy rings on chimney
	for i in range(5):
		var ring_mesh = TorusMesh.new()
		ring_mesh.inner_radius = 0.14 + i * 0.03
		ring_mesh.outer_radius = 0.2 + i * 0.04 + rng.randf() * 0.05
		var ring = MeshInstance3D.new()
		ring.mesh = ring_mesh
		var ring_mat = StandardMaterial3D.new()
		ring_mat.albedo_color = Color(0.12, 0.08, 0.03)
		ring_mat.roughness = 0.9
		ring.material_override = ring_mat
		ring.position.y = 0.3 + i * 0.35
		group.add_child(ring)

	# Vent opening — emissive top
	var vent_mesh = CylinderMesh.new()
	vent_mesh.top_radius = 0.18
	vent_mesh.bottom_radius = 0.15
	vent_mesh.height = 0.1
	var vent = MeshInstance3D.new()
	vent.mesh = vent_mesh
	vent.material_override = make_emissive_mat("#ff6622", 5.0)
	vent.position.y = 2.05
	group.add_child(vent)

	# Smoke plume — column of emissive spheres rising
	for i in range(20):
		var p_height = 2.1 + float(i) * 0.2
		var drift = float(i) * 0.02
		var plume_mesh = SphereMesh.new()
		var pr = 0.05 + float(i) * 0.015
		plume_mesh.radius = pr
		plume_mesh.height = pr * 2
		var plume = MeshInstance3D.new()
		plume.mesh = plume_mesh
		var strength = 3.0 * (1.0 - float(i) / 20.0)
		var plume_mat = StandardMaterial3D.new()
		var plume_color = Color(0.2, 0.1, 0.05).lerp(Color(0.05, 0.05, 0.08), float(i) / 20.0)
		plume_mat.albedo_color = Color(plume_color.r, plume_color.g, plume_color.b, 0.5 - float(i) * 0.02)
		plume_mat.emission_enabled = true
		plume_mat.emission = Color(1.0, 0.4, 0.1).lerp(Color(0.1, 0.1, 0.15), float(i) / 20.0)
		plume_mat.emission_energy_multiplier = strength
		plume_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		plume.material_override = plume_mat
		plume.position = Vector3((rng.randf() - 0.5) * drift * 2, p_height, (rng.randf() - 0.5) * drift * 2)
		group.add_child(plume)

	# Hot glow light
	var light = OmniLight3D.new()
	light.light_color = Color(1.0, 0.5, 0.15)
	light.light_energy = 2.0
	light.omni_range = 4.0
	light.shadow_enabled = true
	light.position = Vector3(0, 2.2, 0)
	group.add_child(light)

	# Secondary dim orange under-light
	var under_light = OmniLight3D.new()
	under_light.light_color = Color(1.0, 0.3, 0.05)
	under_light.light_energy = 0.5
	under_light.omni_range = 2.0
	under_light.position = Vector3(0, 0.5, 0)
	group.add_child(under_light)

	group.scale = Vector3.ONE * sc
	group.position = Vector3(x, 0, y)
	objects_container.add_child(group)
	spawned_items.append({"type": "vent", "x": x, "y": y})

func create_anglerfish(params: Dictionary):
	var x = float(params.get("x", 0))
	var y = float(params.get("y", 0))
	var sc = float(params.get("scale", 1.0))
	var group = Node3D.new()
	group.name = "Anglerfish"
	var rng = RandomNumberGenerator.new()
	rng.seed = 42

	# Body — dark elongated sphere
	var body_mesh = SphereMesh.new()
	body_mesh.radius = 0.3
	body_mesh.height = 0.5
	body_mesh.radial_segments = 16
	var body = MeshInstance3D.new()
	body.mesh = body_mesh
	var body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.02, 0.02, 0.03)
	body_mat.roughness = 0.95
	body_mat.metallic = 0.0
	body.material_override = body_mat
	body.position.y = 0.5
	body.scale = Vector3(1.0, 0.8, 1.4)
	group.add_child(body)

	# Jaw — lower box
	var jaw_mesh = BoxMesh.new()
	jaw_mesh.size = Vector3(0.25, 0.08, 0.2)
	var jaw = MeshInstance3D.new()
	jaw.mesh = jaw_mesh
	jaw.material_override = body_mat
	jaw.position = Vector3(0, 0.32, 0.2)
	jaw.rotation.x = 0.2
	group.add_child(jaw)

	# Teeth — tiny white cones
	for i in range(8):
		var ta = (float(i) / 8.0) * PI - PI * 0.5
		var tooth_mesh = CylinderMesh.new()
		tooth_mesh.top_radius = 0.0
		tooth_mesh.bottom_radius = 0.008
		tooth_mesh.height = 0.04 + rng.randf() * 0.03
		var tooth = MeshInstance3D.new()
		tooth.mesh = tooth_mesh
		var tooth_mat = StandardMaterial3D.new()
		tooth_mat.albedo_color = Color(0.6, 0.6, 0.5)
		tooth_mat.roughness = 0.4
		tooth.material_override = tooth_mat
		tooth.position = Vector3(cos(ta) * 0.1, 0.36, 0.28 + sin(ta) * 0.03)
		tooth.rotation.x = -0.3
		group.add_child(tooth)

	# Eye — small emissive sphere
	for side in [-1, 1]:
		var eye_mesh = SphereMesh.new()
		eye_mesh.radius = 0.03
		eye_mesh.height = 0.06
		var eye = MeshInstance3D.new()
		eye.mesh = eye_mesh
		eye.material_override = make_emissive_mat("#ffcc00", 3.0)
		eye.position = Vector3(side * 0.12, 0.55, 0.2)
		group.add_child(eye)

	# Illicium (fishing rod) — curved stalk from forehead
	for seg in range(8):
		var t = float(seg) / 7.0
		var stalk_mesh = CylinderMesh.new()
		stalk_mesh.top_radius = 0.004
		stalk_mesh.bottom_radius = 0.006
		stalk_mesh.height = 0.08
		var stalk = MeshInstance3D.new()
		stalk.mesh = stalk_mesh
		stalk.material_override = body_mat
		# Curve forward and up
		stalk.position = Vector3(0, 0.65 + t * 0.4, 0.15 + t * 0.3)
		group.add_child(stalk)

	# Esca (lure) — bright glowing sphere at tip
	var lure_mesh = SphereMesh.new()
	lure_mesh.radius = 0.05
	lure_mesh.height = 0.1
	var lure = MeshInstance3D.new()
	lure.mesh = lure_mesh
	lure.material_override = make_emissive_mat("#33ffcc", 10.0)
	lure.position = Vector3(0, 1.1, 0.5)
	group.add_child(lure)

	# Lure light — strong point light
	var lure_light = OmniLight3D.new()
	lure_light.light_color = Color(0.2, 1.0, 0.8)
	lure_light.light_energy = 2.5
	lure_light.omni_range = 3.5
	lure_light.shadow_enabled = true
	lure_light.position = lure.position
	group.add_child(lure_light)

	# Fins — small translucent paddles
	for side in [-1, 1]:
		var fin_mesh = SphereMesh.new()
		fin_mesh.radius = 0.1
		fin_mesh.height = 0.02
		var fin = MeshInstance3D.new()
		fin.mesh = fin_mesh
		var fin_mat = StandardMaterial3D.new()
		fin_mat.albedo_color = Color(0.03, 0.03, 0.04, 0.6)
		fin_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		fin_mat.roughness = 0.5
		fin.material_override = fin_mat
		fin.position = Vector3(side * 0.28, 0.5, -0.05)
		fin.rotation.z = side * 0.3
		group.add_child(fin)

	# Tail fin
	var tail_mesh = SphereMesh.new()
	tail_mesh.radius = 0.12
	tail_mesh.height = 0.02
	var tail = MeshInstance3D.new()
	tail.mesh = tail_mesh
	tail.material_override = body_mat
	tail.position = Vector3(0, 0.45, -0.35)
	group.add_child(tail)

	group.scale = Vector3.ONE * sc
	group.position = Vector3(x, 0.3, y)
	objects_container.add_child(group)
	spawned_items.append({"type": "anglerfish", "x": x, "y": y})

func create_sunken_ruin(params: Dictionary):
	var x = float(params.get("x", 0))
	var y = float(params.get("y", 0))
	var sc = float(params.get("scale", 1.0))
	var group = Node3D.new()
	group.name = "SunkenRuin"
	var rng = RandomNumberGenerator.new()
	rng.seed = 42 + int(x * 31 + y * 47)

	var stone_mat = StandardMaterial3D.new()
	stone_mat.albedo_color = Color(0.12, 0.13, 0.14)
	stone_mat.roughness = 0.9
	stone_mat.metallic = 0.0

	var mossy_mat = StandardMaterial3D.new()
	mossy_mat.albedo_color = Color(0.06, 0.1, 0.08)
	mossy_mat.roughness = 0.95

	# Standing columns — 3-4 broken pillars
	var num_cols = 3 + rng.randi() % 2
	for i in range(num_cols):
		var c_angle = (float(i) / float(num_cols)) * TAU + rng.randf() * 0.5
		var c_dist = 0.8 + rng.randf() * 0.5
		var c_height = 0.8 + rng.randf() * 1.2

		var col_mesh = CylinderMesh.new()
		col_mesh.top_radius = 0.08
		col_mesh.bottom_radius = 0.1
		col_mesh.height = c_height
		col_mesh.radial_segments = 12
		var col = MeshInstance3D.new()
		col.mesh = col_mesh
		col.material_override = stone_mat
		col.position = Vector3(cos(c_angle) * c_dist, c_height * 0.5, sin(c_angle) * c_dist)
		# Slight lean
		col.rotation = Vector3((rng.randf() - 0.5) * 0.15, 0, (rng.randf() - 0.5) * 0.15)
		group.add_child(col)

		# Column capital (top piece)
		var cap_mesh = BoxMesh.new()
		cap_mesh.size = Vector3(0.22, 0.06, 0.22)
		var cap = MeshInstance3D.new()
		cap.mesh = cap_mesh
		cap.material_override = stone_mat
		cap.position = Vector3(cos(c_angle) * c_dist, c_height + 0.03, sin(c_angle) * c_dist)
		group.add_child(cap)

	# Fallen column — lying on ground
	var fallen_mesh = CylinderMesh.new()
	fallen_mesh.top_radius = 0.09
	fallen_mesh.bottom_radius = 0.09
	fallen_mesh.height = 1.5
	var fallen = MeshInstance3D.new()
	fallen.mesh = fallen_mesh
	fallen.material_override = mossy_mat
	fallen.position = Vector3(0.3, 0.09, 0.5)
	fallen.rotation.z = PI / 2
	fallen.rotation.y = rng.randf() * PI
	group.add_child(fallen)

	# Stone arch fragment
	var arch_posts = [Vector3(-0.5, 0, -0.3), Vector3(0.5, 0, -0.3)]
	for ap in arch_posts:
		var post_mesh = BoxMesh.new()
		post_mesh.size = Vector3(0.15, 1.0, 0.15)
		var post = MeshInstance3D.new()
		post.mesh = post_mesh
		post.material_override = stone_mat
		post.position = ap + Vector3(0, 0.5, 0)
		group.add_child(post)

	# Arch lintel
	var lintel_mesh = BoxMesh.new()
	lintel_mesh.size = Vector3(1.2, 0.12, 0.18)
	var lintel = MeshInstance3D.new()
	lintel.mesh = lintel_mesh
	lintel.material_override = stone_mat
	lintel.position = Vector3(0, 1.06, -0.3)
	lintel.rotation.z = (rng.randf() - 0.5) * 0.1
	group.add_child(lintel)

	# Scattered rubble blocks
	for i in range(8):
		var rubble_mesh = BoxMesh.new()
		var rs = 0.05 + rng.randf() * 0.12
		rubble_mesh.size = Vector3(rs, rs * (0.5 + rng.randf()), rs * (0.8 + rng.randf() * 0.4))
		var rubble = MeshInstance3D.new()
		rubble.mesh = rubble_mesh
		rubble.material_override = stone_mat
		rubble.position = Vector3((rng.randf() - 0.5) * 2.0, rs * 0.25, (rng.randf() - 0.5) * 2.0)
		rubble.rotation = Vector3(rng.randf() * 0.5, rng.randf() * TAU, rng.randf() * 0.5)
		group.add_child(rubble)

	# Glowing runes on arch — small emissive squares
	var rune_colors = ["#33ccff", "#33ffaa", "#ff88ff"]
	for i in range(5):
		var rune_mesh = BoxMesh.new()
		rune_mesh.size = Vector3(0.03, 0.05, 0.01)
		var rune = MeshInstance3D.new()
		rune.mesh = rune_mesh
		var rc = rune_colors[rng.randi() % rune_colors.size()]
		rune.material_override = make_emissive_mat(rc, 3.0 + rng.randf() * 2.0)
		# Place on lintel face
		rune.position = Vector3(-0.4 + float(i) * 0.2, 1.06, -0.21)
		group.add_child(rune)

	# Faint light from runes
	var rune_light = OmniLight3D.new()
	rune_light.light_color = Color(0.2, 0.8, 1.0)
	rune_light.light_energy = 0.5
	rune_light.omni_range = 2.0
	rune_light.position = Vector3(0, 1.0, -0.3)
	group.add_child(rune_light)

	group.scale = Vector3.ONE * sc
	group.position = Vector3(x, 0, y)
	objects_container.add_child(group)
	spawned_items.append({"type": "ruin", "x": x, "y": y})

func create_marine_snow(params: Dictionary):
	var group = Node3D.new()
	group.name = "MarineSnow"
	var rng = RandomNumberGenerator.new()
	rng.seed = 77

	# 80 tiny drifting particles spread through the volume
	var particle_colors = ["#aaccff", "#88ffcc", "#ffddaa", "#ddddff"]
	for i in range(80):
		var px = (rng.randf() - 0.5) * 12
		var py = rng.randf() * 6.0
		var pz = (rng.randf() - 0.5) * 12
		var p_mesh = SphereMesh.new()
		var pr = 0.005 + rng.randf() * 0.01
		p_mesh.radius = pr
		p_mesh.height = pr * 2
		p_mesh.radial_segments = 6
		var p_mi = MeshInstance3D.new()
		p_mi.mesh = p_mesh
		var pc = particle_colors[rng.randi() % particle_colors.size()]
		p_mi.material_override = make_emissive_mat(pc, 0.5 + rng.randf() * 1.5)
		p_mi.position = Vector3(px, py, pz)
		group.add_child(p_mi)

	objects_container.add_child(group)
	spawned_items.append({"type": "marine_snow"})

# ── Particles (GPUParticles3D) ──────────────────────────────────────────────

func create_particles(preset: String, params: Dictionary):
	var particles = GPUParticles3D.new()
	var mat = ParticleProcessMaterial.new()

	match preset:
		"fireflies":
			particles.amount = 200
			mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			mat.emission_box_extents = Vector3(15, 5, 15)
			mat.gravity = Vector3(0, 0.1, 0)
			mat.initial_velocity_min = 0.2
			mat.initial_velocity_max = 0.5
			mat.scale_min = 0.02
			mat.scale_max = 0.06
			particles.lifetime = 8.0
			var mesh = SphereMesh.new()
			mesh.radius = 0.03
			mesh.height = 0.06
			mesh.material = make_emissive_mat("#aaffaa", 8.0)
			particles.draw_pass_1 = mesh
		"rain":
			particles.amount = 500
			mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			mat.emission_box_extents = Vector3(20, 0, 20)
			mat.gravity = Vector3(0, -12, 0)
			mat.initial_velocity_min = 8.0
			mat.initial_velocity_max = 12.0
			mat.direction = Vector3(0, -1, 0)
			mat.scale_min = 0.01
			mat.scale_max = 0.02
			particles.lifetime = 2.0
			particles.position.y = 10
			var mesh = CylinderMesh.new()
			mesh.top_radius = 0.005
			mesh.bottom_radius = 0.005
			mesh.height = 0.3
			mesh.material = make_translucent_mat("#8899cc", 0.4)
			particles.draw_pass_1 = mesh
		"embers":
			particles.amount = 150
			mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			mat.emission_box_extents = Vector3(10, 1, 10)
			mat.gravity = Vector3(0, 0.5, 0)
			mat.initial_velocity_min = 0.5
			mat.initial_velocity_max = 1.5
			mat.scale_min = 0.01
			mat.scale_max = 0.04
			particles.lifetime = 5.0
			var mesh = SphereMesh.new()
			mesh.radius = 0.02
			mesh.height = 0.04
			mesh.material = make_emissive_mat("#ff6622", 6.0)
			particles.draw_pass_1 = mesh
		"snow":
			particles.amount = 400
			mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
			mat.emission_box_extents = Vector3(20, 0, 20)
			mat.gravity = Vector3(0, -1.5, 0)
			mat.initial_velocity_min = 0.3
			mat.initial_velocity_max = 0.8
			mat.scale_min = 0.02
			mat.scale_max = 0.05
			particles.lifetime = 10.0
			particles.position.y = 10
			var mesh = SphereMesh.new()
			mesh.radius = 0.03
			mesh.height = 0.06
			mesh.material = make_translucent_mat("#ffffff", 0.8)
			particles.draw_pass_1 = mesh

	particles.process_material = mat
	objects_container.add_child(particles)
	spawned_items.append({"type": "particles", "preset": preset})

# ── Crystal Cave Scene ──────────────────────────────────────────────────────

func apply_crystal_environment():
	var env = $WorldEnvironment.environment as Environment
	var sky_mat = env.sky.sky_material as ProceduralSkyMaterial
	sky_mat.sky_top_color = Color(0.02, 0.01, 0.08)
	sky_mat.sky_horizon_color = Color(0.05, 0.03, 0.12)
	sky_mat.ground_bottom_color = Color(0.01, 0.01, 0.03)
	sky_mat.ground_horizon_color = Color(0.03, 0.02, 0.08)
	sky_mat.sky_energy_multiplier = 0.3
	env.volumetric_fog_enabled = false
	env.fog_density = 0.005
	env.fog_light_color = Color(0.1, 0.05, 0.2)
	env.ssr_enabled = true
	env.ssr_max_steps = 128
	env.glow_intensity = 2.5
	env.glow_bloom = 0.5
	env.sdfgi_enabled = true
	env.ambient_light_energy = 0.3
	$MoonLight.light_color = Color(0.4, 0.3, 0.7)
	$MoonLight.light_energy = 0.2

func create_crystal_cave(params: Dictionary):
	for child in objects_container.get_children():
		child.queue_free()
	spawned_items.clear()
	await get_tree().process_frame

	# Floor — dark rocky surface
	var floor_mesh = MeshInstance3D.new()
	floor_mesh.mesh = PlaneMesh.new()
	floor_mesh.mesh.size = Vector2(30, 30)
	floor_mesh.mesh.material = make_dark_mat("#0a0a14")
	floor_mesh.position = Vector3(0, -1, 0)
	objects_container.add_child(floor_mesh)

	# Crystal clusters
	var crystal_colors = ["#4488ff", "#aa44ff", "#44ffdd", "#ff44aa"]
	for i in range(20):
		var cx = randf_range(-12, 12)
		var cz = randf_range(-12, 12)
		create_crystal_cluster(Vector3(cx, -1, cz), crystal_colors[randi() % 4])

	# Large central crystal pillar
	create_crystal_pillar(Vector3(0, -1, -3), "#7744ff", 4.0)

	# Reflective pool
	var pool = MeshInstance3D.new()
	pool.mesh = PlaneMesh.new()
	pool.mesh.size = Vector2(8, 8)
	var pool_mat = StandardMaterial3D.new()
	pool_mat.albedo_color = Color(0.05, 0.08, 0.15)
	pool_mat.metallic = 1.0
	pool_mat.roughness = 0.05
	pool_mat.emission_enabled = true
	pool_mat.emission = Color(0.02, 0.04, 0.08)
	pool_mat.emission_energy_multiplier = 0.5
	pool.mesh.material = pool_mat
	pool.position = Vector3(5, -0.95, 3)
	objects_container.add_child(pool)

	spawned_items.append({"type": "scene", "name": "crystal_cave"})

func create_crystal_cluster(pos: Vector3, color: String):
	var cluster = Node3D.new()
	cluster.position = pos
	for j in range(randi_range(3, 7)):
		var crystal = MeshInstance3D.new()
		var prism = CylinderMesh.new()
		prism.top_radius = 0.0
		prism.bottom_radius = randf_range(0.08, 0.2)
		prism.height = randf_range(0.5, 2.0)
		prism.radial_segments = 6
		crystal.mesh = prism
		crystal.mesh.material = make_emissive_mat(color, randf_range(2.0, 6.0))
		crystal.position = Vector3(randf_range(-0.3, 0.3), prism.height / 2, randf_range(-0.3, 0.3))
		crystal.rotation_degrees = Vector3(randf_range(-15, 15), randf_range(0, 360), randf_range(-15, 15))
		cluster.add_child(crystal)
	objects_container.add_child(cluster)

func create_crystal_pillar(pos: Vector3, color: String, height: float):
	var pillar = Node3D.new()
	pillar.position = pos
	for i in range(5):
		var shard = MeshInstance3D.new()
		var prism = CylinderMesh.new()
		prism.top_radius = 0.0
		prism.bottom_radius = randf_range(0.15, 0.4)
		prism.height = height * randf_range(0.6, 1.0)
		prism.radial_segments = 6
		shard.mesh = prism
		shard.mesh.material = make_emissive_mat(color, 4.0)
		shard.position = Vector3(randf_range(-0.2, 0.2), prism.height / 2, randf_range(-0.2, 0.2))
		shard.rotation_degrees.x = randf_range(-10, 10)
		shard.rotation_degrees.z = randf_range(-10, 10)
		pillar.add_child(shard)
	objects_container.add_child(pillar)

# ── Neon City Scene ─────────────────────────────────────────────────────────

func apply_neon_environment():
	var env = $WorldEnvironment.environment as Environment
	var sky_mat = env.sky.sky_material as ProceduralSkyMaterial
	sky_mat.sky_top_color = Color(0.01, 0.01, 0.03)
	sky_mat.sky_horizon_color = Color(0.05, 0.02, 0.08)
	sky_mat.ground_bottom_color = Color(0.02, 0.02, 0.04)
	sky_mat.ground_horizon_color = Color(0.04, 0.02, 0.06)
	sky_mat.sky_energy_multiplier = 0.5
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.06
	env.volumetric_fog_albedo = Color(0.03, 0.01, 0.05)
	env.volumetric_fog_emission = Color(0.02, 0.01, 0.03)
	env.volumetric_fog_emission_energy = 1.0
	env.ssr_enabled = true
	env.ssr_max_steps = 96
	env.glow_intensity = 2.0
	env.glow_bloom = 0.4
	env.glow_hdr_threshold = 0.4
	env.sdfgi_enabled = true
	env.ambient_light_energy = 0.5
	$MoonLight.light_color = Color(0.4, 0.35, 0.6)
	$MoonLight.light_energy = 0.4

func create_neon_city(params: Dictionary):
	for child in objects_container.get_children():
		child.queue_free()
	spawned_items.clear()
	await get_tree().process_frame

	# Wet street — reflective ground with slight texture variation
	var street = MeshInstance3D.new()
	street.mesh = PlaneMesh.new()
	street.mesh.size = Vector2(40, 40)
	var street_mat = StandardMaterial3D.new()
	street_mat.albedo_color = Color(0.06, 0.06, 0.08)
	street_mat.metallic = 0.85
	street_mat.roughness = 0.15
	street.mesh.material = street_mat
	street.position = Vector3(0, -1, 0)
	objects_container.add_child(street)

	# Sidewalk curbs — raised strips along center corridor
	for side in [-3.0, 3.0]:
		var curb = MeshInstance3D.new()
		curb.mesh = BoxMesh.new()
		curb.mesh.size = Vector3(0.3, 0.15, 30)
		var curb_mat = StandardMaterial3D.new()
		curb_mat.albedo_color = Color(0.15, 0.14, 0.18)
		curb_mat.roughness = 0.7
		curb.mesh.material = curb_mat
		curb.position = Vector3(side, -0.92, -5)
		objects_container.add_child(curb)

	# Puddles — reflective patches on street
	for i in range(6):
		var puddle = MeshInstance3D.new()
		puddle.mesh = PlaneMesh.new()
		puddle.mesh.size = Vector2(randf_range(1, 3), randf_range(1, 2))
		var puddle_mat = StandardMaterial3D.new()
		puddle_mat.albedo_color = Color(0.03, 0.03, 0.06)
		puddle_mat.metallic = 1.0
		puddle_mat.roughness = 0.02
		puddle.mesh.material = puddle_mat
		puddle.position = Vector3(randf_range(-10, 10), -0.98, randf_range(-8, 5))
		objects_container.add_child(puddle)

	# Buildings with neon trim + windows
	var neon_colors = ["#ff0066", "#00ffaa", "#4488ff", "#ff6600", "#aa00ff", "#ffff00"]
	for i in range(25):
		var bx = randf_range(-15, 15)
		var bz = randf_range(-15, 5)
		if abs(bx) < 3 and abs(bz) < 5:
			continue
		var h = randf_range(2, 8)
		var w = randf_range(1, 3)
		var d = randf_range(1, 3)
		var nc = neon_colors[randi() % neon_colors.size()]
		create_neon_building(Vector3(bx, -1, bz), w, h, d, nc)

	# Neon signs — floating emissive quads
	for i in range(10):
		var sign_node = MeshInstance3D.new()
		sign_node.mesh = QuadMesh.new()
		sign_node.mesh.size = Vector2(randf_range(0.5, 1.5), randf_range(0.3, 0.6))
		sign_node.mesh.material = make_emissive_mat(neon_colors[randi() % neon_colors.size()], 8.0)
		sign_node.position = Vector3(randf_range(-12, 12), randf_range(1, 5), randf_range(-10, 3))
		sign_node.rotation_degrees.y = randf_range(-30, 30)
		objects_container.add_child(sign_node)

	# Street lamps along corridor
	for i in range(6):
		var lz = -10 + i * 4.0
		for side in [-2.5, 2.5]:
			var pole = MeshInstance3D.new()
			pole.mesh = CylinderMesh.new()
			pole.mesh.top_radius = 0.03
			pole.mesh.bottom_radius = 0.05
			pole.mesh.height = 3.0
			var pole_mat = StandardMaterial3D.new()
			pole_mat.albedo_color = Color(0.12, 0.12, 0.15)
			pole_mat.metallic = 0.7
			pole_mat.roughness = 0.4
			pole.mesh.material = pole_mat
			pole.position = Vector3(side, 0.5, lz)
			objects_container.add_child(pole)
			# Lamp head
			var lamp = MeshInstance3D.new()
			lamp.mesh = SphereMesh.new()
			lamp.mesh.radius = 0.1
			lamp.mesh.height = 0.15
			lamp.mesh.material = make_emissive_mat(neon_colors[randi() % neon_colors.size()], 4.0)
			lamp.position = Vector3(side, 2.1, lz)
			objects_container.add_child(lamp)

	spawned_items.append({"type": "scene", "name": "neon_city"})

func create_neon_building(pos: Vector3, w: float, h: float, d: float, neon_color: String):
	var building = Node3D.new()
	building.position = pos

	# Main body — visible concrete
	var body = MeshInstance3D.new()
	body.mesh = BoxMesh.new()
	body.mesh.size = Vector3(w, h, d)
	var body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.12, 0.11, 0.16)
	body_mat.metallic = 0.15
	body_mat.roughness = 0.75
	body.mesh.material = body_mat
	body.position.y = h / 2
	building.add_child(body)

	# Neon trim strips along edges
	for edge_y in [h * 0.3, h * 0.6, h * 0.9]:
		var strip = MeshInstance3D.new()
		strip.mesh = BoxMesh.new()
		strip.mesh.size = Vector3(w + 0.05, 0.05, d + 0.05)
		strip.mesh.material = make_emissive_mat(neon_color, 5.0)
		strip.position.y = edge_y
		building.add_child(strip)

	# Windows — small emissive quads on front face
	var win_colors = ["#ffcc66", "#aabbcc", "#334455"]
	var rows = int(h / 0.6)
	var cols = int(w / 0.5)
	for row in range(rows):
		for col in range(cols):
			if randf() > 0.6:
				continue  # not every window lit
			var win = MeshInstance3D.new()
			win.mesh = QuadMesh.new()
			win.mesh.size = Vector2(0.2, 0.3)
			var wc = win_colors[randi() % win_colors.size()]
			var we = 1.5 if wc == "#334455" else 2.5
			win.mesh.material = make_emissive_mat(wc, we)
			win.position = Vector3(
				-w / 2 + 0.3 + col * 0.5,
				0.4 + row * 0.6,
				d / 2 + 0.01
			)
			building.add_child(win)

	# Roof detail — antenna or AC unit
	if randf() > 0.5:
		var antenna = MeshInstance3D.new()
		antenna.mesh = CylinderMesh.new()
		antenna.mesh.top_radius = 0.01
		antenna.mesh.bottom_radius = 0.02
		antenna.mesh.height = 0.8
		var ant_mat = StandardMaterial3D.new()
		ant_mat.albedo_color = Color(0.2, 0.2, 0.25)
		ant_mat.metallic = 0.6
		antenna.mesh.material = ant_mat
		antenna.position = Vector3(randf_range(-w/3, w/3), h + 0.4, randf_range(-d/3, d/3))
		building.add_child(antenna)
		# Blinking light on antenna
		var blink = MeshInstance3D.new()
		blink.mesh = SphereMesh.new()
		blink.mesh.radius = 0.03
		blink.mesh.height = 0.06
		blink.mesh.material = make_emissive_mat("#ff0000", 6.0)
		blink.position = antenna.position + Vector3(0, 0.45, 0)
		building.add_child(blink)
	else:
		var ac = MeshInstance3D.new()
		ac.mesh = BoxMesh.new()
		ac.mesh.size = Vector3(0.4, 0.25, 0.3)
		var ac_mat = StandardMaterial3D.new()
		ac_mat.albedo_color = Color(0.18, 0.18, 0.2)
		ac_mat.metallic = 0.4
		ac_mat.roughness = 0.6
		ac.mesh.material = ac_mat
		ac.position = Vector3(randf_range(-w/3, w/3), h + 0.12, randf_range(-d/3, d/3))
		building.add_child(ac)

	objects_container.add_child(building)

# ── Volcanic Scene ──────────────────────────────────────────────────────────

func apply_volcanic_environment():
	var env = $WorldEnvironment.environment as Environment
	var sky_mat = env.sky.sky_material as ProceduralSkyMaterial
	sky_mat.sky_top_color = Color(0.03, 0.01, 0.01)
	sky_mat.sky_horizon_color = Color(0.3, 0.08, 0.02)
	sky_mat.ground_bottom_color = Color(0.05, 0.02, 0.01)
	sky_mat.ground_horizon_color = Color(0.2, 0.06, 0.02)
	sky_mat.sky_energy_multiplier = 1.5
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.04
	env.volumetric_fog_albedo = Color(0.08, 0.03, 0.01)
	env.volumetric_fog_emission = Color(0.06, 0.02, 0.005)
	env.volumetric_fog_emission_energy = 0.8
	env.glow_intensity = 2.0
	env.glow_bloom = 0.4
	env.glow_hdr_threshold = 0.5
	env.sdfgi_enabled = true
	env.ssr_enabled = true
	env.ambient_light_energy = 0.4
	$MoonLight.light_color = Color(0.6, 0.3, 0.15)
	$MoonLight.light_energy = 0.3

func create_volcanic_scene(params: Dictionary):
	for child in objects_container.get_children():
		child.queue_free()
	spawned_items.clear()
	await get_tree().process_frame

	# Ground — dark basalt
	var ground = MeshInstance3D.new()
	ground.mesh = PlaneMesh.new()
	ground.mesh.size = Vector2(30, 30)
	ground.mesh.material = make_dark_mat("#0a0806")
	ground.position = Vector3(0, -1, 0)
	objects_container.add_child(ground)

	# Lava rivers — emissive orange strips
	for i in range(5):
		var lava = MeshInstance3D.new()
		lava.mesh = PlaneMesh.new()
		lava.mesh.size = Vector2(randf_range(0.8, 2.0), randf_range(8, 20))
		lava.mesh.material = make_emissive_mat("#ff4400", 8.0)
		lava.position = Vector3(randf_range(-10, 10), -0.95, randf_range(-8, 8))
		lava.rotation_degrees.y = randf_range(-30, 30)
		objects_container.add_child(lava)

	# Obsidian spires — dark metallic jagged columns
	for i in range(15):
		var spire = MeshInstance3D.new()
		var prism = CylinderMesh.new()
		prism.top_radius = 0.0
		prism.bottom_radius = randf_range(0.2, 0.6)
		prism.height = randf_range(1.5, 5.0)
		prism.radial_segments = randi_range(4, 6)
		spire.mesh = prism
		spire.mesh.material = make_metallic_mat("#1a1a22")
		spire.position = Vector3(randf_range(-12, 12), -1 + prism.height / 2, randf_range(-12, 8))
		spire.rotation_degrees = Vector3(randf_range(-8, 8), randf_range(0, 360), randf_range(-8, 8))
		objects_container.add_child(spire)

	# Volcanic vents — glowing cones
	for i in range(4):
		var vent = MeshInstance3D.new()
		var cone = CylinderMesh.new()
		cone.top_radius = 0.3
		cone.bottom_radius = 0.8
		cone.height = 1.0
		vent.mesh = cone
		vent.mesh.material = make_emissive_mat("#ff6600", 4.0)
		vent.position = Vector3(randf_range(-8, 8), -0.5, randf_range(-8, 5))
		objects_container.add_child(vent)

	# Auto-add ember particles
	create_particles("embers", {})

	spawned_items.append({"type": "scene", "name": "volcanic"})

# ── Zen Garden Scene ────────────────────────────────────────────────────────

func apply_zen_environment():
	var env = $WorldEnvironment.environment as Environment
	var sky_mat = env.sky.sky_material as ProceduralSkyMaterial
	sky_mat.sky_top_color = Color(0.3, 0.35, 0.55)
	sky_mat.sky_horizon_color = Color(0.6, 0.45, 0.35)
	sky_mat.ground_bottom_color = Color(0.15, 0.12, 0.1)
	sky_mat.ground_horizon_color = Color(0.4, 0.3, 0.25)
	sky_mat.sky_energy_multiplier = 2.5
	env.volumetric_fog_enabled = false
	env.fog_enabled = true
	env.fog_density = 0.008
	env.fog_light_color = Color(0.5, 0.45, 0.4)
	env.glow_intensity = 1.0
	env.glow_bloom = 0.15
	env.ssr_enabled = true
	env.ssr_max_steps = 64
	env.sdfgi_enabled = true
	env.ambient_light_energy = 0.8
	$MoonLight.light_color = Color(0.9, 0.8, 0.65)
	$MoonLight.light_energy = 0.6

func create_zen_garden(params: Dictionary):
	for child in objects_container.get_children():
		child.queue_free()
	spawned_items.clear()
	await get_tree().process_frame

	# Sand ground — warm beige
	var sand = MeshInstance3D.new()
	sand.mesh = PlaneMesh.new()
	sand.mesh.size = Vector2(25, 25)
	var sand_mat = StandardMaterial3D.new()
	sand_mat.albedo_color = Color(0.75, 0.68, 0.55)
	sand_mat.metallic = 0.0
	sand_mat.roughness = 0.9
	sand.mesh.material = sand_mat
	sand.position = Vector3(0, -1, 0)
	objects_container.add_child(sand)

	# Stepping stones
	var stone_positions = [Vector3(-2, -0.9, 1), Vector3(-1, -0.9, 0), Vector3(0, -0.9, -1), Vector3(1.5, -0.9, -1.5), Vector3(3, -0.9, -1)]
	for pos in stone_positions:
		var stone = MeshInstance3D.new()
		var cyl = CylinderMesh.new()
		cyl.top_radius = randf_range(0.3, 0.5)
		cyl.bottom_radius = randf_range(0.35, 0.55)
		cyl.height = 0.12
		stone.mesh = cyl
		stone.mesh.material = make_organic_mat("#555550")
		stone.position = pos
		objects_container.add_child(stone)

	# Bamboo cluster
	for i in range(12):
		var bamboo = MeshInstance3D.new()
		var cyl = CylinderMesh.new()
		cyl.top_radius = 0.03
		cyl.bottom_radius = 0.04
		cyl.height = randf_range(3, 5)
		bamboo.mesh = cyl
		bamboo.mesh.material = make_organic_mat("#446633")
		var bx = randf_range(-8, -6)
		bamboo.position = Vector3(bx, -1 + cyl.height / 2, randf_range(-3, 3))
		objects_container.add_child(bamboo)

	# Water feature — reflective pool
	var pool = MeshInstance3D.new()
	pool.mesh = PlaneMesh.new()
	pool.mesh.size = Vector2(5, 4)
	var water_mat = StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.1, 0.15, 0.2)
	water_mat.metallic = 0.95
	water_mat.roughness = 0.05
	pool.mesh.material = water_mat
	pool.position = Vector3(4, -0.95, 2)
	objects_container.add_child(pool)

	# Stone lantern
	var lantern_base = Vector3(2, -1, 3)
	var base = MeshInstance3D.new()
	base.mesh = CylinderMesh.new()
	base.mesh.top_radius = 0.15
	base.mesh.bottom_radius = 0.2
	base.mesh.height = 0.4
	base.mesh.material = make_organic_mat("#888880")
	base.position = lantern_base + Vector3(0, 0.2, 0)
	objects_container.add_child(base)

	var lamp = MeshInstance3D.new()
	lamp.mesh = BoxMesh.new()
	lamp.mesh.size = Vector3(0.25, 0.25, 0.25)
	lamp.mesh.material = make_emissive_mat("#ffcc66", 3.0)
	lamp.position = lantern_base + Vector3(0, 0.55, 0)
	objects_container.add_child(lamp)

	var roof = MeshInstance3D.new()
	roof.mesh = CylinderMesh.new()
	roof.mesh.top_radius = 0.0
	roof.mesh.bottom_radius = 0.3
	roof.mesh.height = 0.2
	roof.mesh.radial_segments = 4
	roof.mesh.material = make_organic_mat("#666660")
	roof.position = lantern_base + Vector3(0, 0.8, 0)
	objects_container.add_child(roof)

	# Bonsai tree
	var trunk = MeshInstance3D.new()
	trunk.mesh = CylinderMesh.new()
	trunk.mesh.top_radius = 0.05
	trunk.mesh.bottom_radius = 0.08
	trunk.mesh.height = 0.6
	trunk.mesh.material = make_organic_mat("#553322")
	trunk.position = Vector3(-3, -0.7, -4)
	objects_container.add_child(trunk)

	var canopy = MeshInstance3D.new()
	canopy.mesh = SphereMesh.new()
	canopy.mesh.radius = 0.4
	canopy.mesh.height = 0.5
	canopy.mesh.material = make_organic_mat("#335522")
	canopy.position = Vector3(-3, -0.15, -4)
	objects_container.add_child(canopy)

	# Large rocks
	for i in range(5):
		var rock = MeshInstance3D.new()
		rock.mesh = SphereMesh.new()
		rock.mesh.radius = randf_range(0.2, 0.5)
		rock.mesh.height = randf_range(0.3, 0.7)
		rock.mesh.material = make_organic_mat("#4a4a45")
		rock.position = Vector3(randf_range(-5, 5), -0.85, randf_range(-5, 5))
		objects_container.add_child(rock)

	spawned_items.append({"type": "scene", "name": "zen_garden"})

# ── Fairy Garden Scene ──────────────────────────────────────────────────────

func apply_fairy_environment():
	var env = $WorldEnvironment.environment as Environment
	var sky_mat = env.sky.sky_material as ProceduralSkyMaterial
	sky_mat.sky_top_color = Color(0.4, 0.5, 0.85)
	sky_mat.sky_horizon_color = Color(0.85, 0.6, 0.45)
	sky_mat.ground_bottom_color = Color(0.2, 0.25, 0.12)
	sky_mat.ground_horizon_color = Color(0.55, 0.45, 0.3)
	sky_mat.sky_energy_multiplier = 3.5
	# Tonemap: AgX for better hue preservation
	env.tonemap_mode = 4  # AGX
	env.tonemap_exposure = 1.0
	# Ambient: sky-driven
	env.ambient_light_source = 1  # SKY
	env.ambient_light_sky_contribution = 0.7
	env.ambient_light_energy = 1.1
	env.ambient_light_color = Color(0.95, 0.9, 0.75)
	# SDFGI + SSAO + SSIL
	env.sdfgi_enabled = true
	env.sdfgi_use_occlusion = true
	env.sdfgi_energy = 0.8
	env.ssao_enabled = true
	env.ssao_radius = 1.0
	env.ssao_intensity = 3.0
	env.ssil_enabled = true
	env.ssil_radius = 10.0
	# SSR
	env.ssr_enabled = true
	env.ssr_max_steps = 64
	# Volumetric fog
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.008
	env.volumetric_fog_albedo = Color(0.25, 0.2, 0.12)
	env.volumetric_fog_emission = Color(0.12, 0.08, 0.03)
	env.volumetric_fog_emission_energy = 0.3
	# Depth fog with aerial perspective
	env.fog_enabled = true
	env.fog_density = 0.003
	env.fog_light_color = Color(0.7, 0.55, 0.35)
	env.fog_aerial_perspective = 1.0
	env.fog_sky_affect = 0.0
	# Glow — subtle bloom
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.1
	env.glow_strength = 0.8
	env.glow_hdr_threshold = 0.8
	# Sun
	$MoonLight.light_color = Color(1.0, 0.88, 0.55)
	$MoonLight.light_energy = 0.9

func create_fairy_garden(params: Dictionary):
	for child in objects_container.get_children():
		child.queue_free()
	spawned_items.clear()
	await get_tree().process_frame

	var grow_queue: Array = []

	# ── Terrain (SurfaceTool rolling hills) ──
	terrain_noise = FastNoiseLite.new()
	terrain_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	terrain_noise.frequency = 0.015
	terrain_noise.fractal_octaves = 3
	terrain_noise.seed = 42
	var terrain_mi = Terrain.create_terrain(25.0, 0.5, 0.4, 42)
	terrain_mi.material_override = Materials.make_ground_material(Color(0.2, 0.3, 0.14))
	terrain_mi.position = Vector3(0, -1, 0)
	objects_container.add_child(terrain_mi)

	# ── Kenney rocks (real 3D models) ──
	var rock_models = ["rock_largeA.glb", "rock_largeB.glb", "rock_largeC.glb", "rock_smallA.glb", "rock_smallB.glb", "rock_smallC.glb", "rock_smallD.glb"]
	for i in range(14):
		var rx = randf_range(-7, 7)
		var rz = randf_range(-7, 7)
		var ry = _terrain_y(rx, rz)
		var model_name = rock_models[randi() % rock_models.size()]
		var rock = model_loader.load_model(model_name, Vector3(rx, ry, rz), randf_range(0.3, 1.2), randf_range(0, 360))
		if rock:
			_apply_material_recursive(rock, Materials.make_stone_material(Color(randf_range(0.25, 0.45), randf_range(0.25, 0.42), randf_range(0.22, 0.38))))
			objects_container.add_child(rock)

	# ── Log with bark texture ──
	var log_node = MeshInstance3D.new()
	log_node.mesh = CylinderMesh.new()
	log_node.mesh.top_radius = 0.2
	log_node.mesh.bottom_radius = 0.27
	log_node.mesh.height = 2.8
	log_node.mesh.radial_segments = 16
	log_node.material_override = Materials.make_bark_material(Color(0.25, 0.18, 0.1))
	log_node.position = Vector3(3, -0.75, 1)
	log_node.rotation_degrees = Vector3(0, 35, 85)
	objects_container.add_child(log_node)

	# ── Pond with water shader ──
	var pond = MeshInstance3D.new()
	var pond_mesh = PlaneMesh.new()
	pond_mesh.size = Vector2(3.5, 3)
	pond_mesh.subdivide_width = 32
	pond_mesh.subdivide_depth = 32
	pond.mesh = pond_mesh
	var water_shader = load("res://shaders/reactive_water.gdshader")
	var water_mat = ShaderMaterial.new()
	water_mat.shader = water_shader
	water_mat.set_shader_parameter("water_color", Color(0.06, 0.15, 0.12))
	water_mat.set_shader_parameter("wave_speed", 1.5)
	water_mat.set_shader_parameter("wave_strength", 0.02)
	water_mat.set_shader_parameter("metallic", 0.7)
	water_mat.set_shader_parameter("roughness", 0.05)
	pond.material_override = water_mat
	pond.position = Vector3(-3, -0.96, -2)
	objects_container.add_child(pond)
	# Pond mud rim
	var rim = MeshInstance3D.new()
	rim.mesh = TorusMesh.new()
	rim.mesh.inner_radius = 1.3
	rim.mesh.outer_radius = 1.6
	rim.material_override = Materials.make_mud_material(Color(0.16, 0.14, 0.08))
	rim.position = Vector3(-3, -0.97, -2)
	rim.scale = Vector3(1.2, 0.1, 1.0)
	objects_container.add_child(rim)
	# Border stones (Kenney)
	var border_stones = ["rock_smallA.glb", "rock_smallB.glb", "rock_smallC.glb", "rock_smallD.glb"]
	for ps in range(12):
		var pa = (float(ps) / 12.0) * TAU
		var bx = -3 + cos(pa) * 1.5
		var bz = -2 + sin(pa) * 1.2
		var bs_model = border_stones[randi() % border_stones.size()]
		var pstone = model_loader.load_model(bs_model, Vector3(bx, -0.92, bz), randf_range(0.15, 0.35), randf_range(0, 360))
		if pstone:
			_apply_material_recursive(pstone, Materials.make_stone_material(Color(0.35 + randf() * 0.15, 0.33 + randf() * 0.1, 0.28)))
			objects_container.add_child(pstone)
	# Lily pads
	for lp in range(6):
		var pad = MeshInstance3D.new()
		pad.mesh = CylinderMesh.new()
		pad.mesh.top_radius = randf_range(0.1, 0.2)
		pad.mesh.bottom_radius = pad.mesh.top_radius
		pad.mesh.height = 0.008
		var pad_mat = StandardMaterial3D.new()
		pad_mat.albedo_color = Color(0.15 + randf() * 0.1, 0.35 + randf() * 0.15, 0.1)
		pad_mat.roughness = 0.8
		pad.mesh.material = pad_mat
		pad.position = Vector3(-3 + randf_range(-1.2, 1.2), -0.94, -2 + randf_range(-1, 1))
		objects_container.add_child(pad)
		if randf() > 0.5:
			var lily = MeshInstance3D.new()
			lily.mesh = SphereMesh.new()
			lily.mesh.radius = 0.035
			lily.mesh.height = 0.025
			var lily_mat = StandardMaterial3D.new()
			lily_mat.albedo_color = Color(0.95, 0.85, 0.88)
			lily_mat.roughness = 0.4
			lily.mesh.material = lily_mat
			lily.position = pad.position + Vector3(0, 0.015, 0)
			objects_container.add_child(lily)

	# ── MultiMesh Grass (5000 blades, 1 draw call) ──
	var grass_mmi = _create_grass_multimesh(8.0, 2000)
	grass_mmi.position.y = -1
	objects_container.add_child(grass_mmi)

	# ── Kenney mushrooms (real 3D models) — scattered + fairy ring ──
	var shroom_models = ["mushroom_red.glb", "mushroom_redGroup.glb", "mushroom_redTall.glb", "mushroom_tan.glb", "mushroom_tanGroup.glb", "mushroom_tanTall.glb"]
	for i in range(8):
		var mx = randf_range(-7, 7)
		var mz = randf_range(-7, 7)
		var my = _terrain_y(mx, mz)
		var smodel = shroom_models[randi() % shroom_models.size()]
		var shroom_node = model_loader.load_model(smodel, Vector3(mx, my, mz), randf_range(0.8, 2.5), randf_range(0, 360))
		if shroom_node:
			shroom_node.scale = Vector3.ZERO
			objects_container.add_child(shroom_node)
			grow_queue.append({"node": shroom_node, "time": randf_range(5, 12), "dur": randf_range(1.5, 2.5), "trans": Tween.TRANS_ELASTIC})

	# Fairy ring (Kenney red mushrooms)
	var ring_center = Vector3(1, -1, -1)
	for i in range(8):
		var angle = (float(i) / 8.0) * TAU
		var frx = ring_center.x + cos(angle) * 1.6
		var frz = ring_center.z + sin(angle) * 1.6
		var fry = _terrain_y(frx, frz)
		var ring_shroom = model_loader.load_model("mushroom_redTall.glb", Vector3(frx, fry, frz), randf_range(1.0, 1.8), randf_range(0, 360))
		if ring_shroom:
			ring_shroom.scale = Vector3.ZERO
			objects_container.add_child(ring_shroom)
			grow_queue.append({"node": ring_shroom, "time": 7 + i * 0.6, "dur": 1.2, "trans": Tween.TRANS_ELASTIC})

	# ── Kenney trees ──
	var tree_models = ["tree_default.glb", "tree_detailed.glb", "tree_oak.glb", "tree_fat.glb", "tree_cone.glb"]
	for i in range(6):
		var tx = randf_range(-9, 9)
		var tz = randf_range(-9, 9)
		# Skip pond area
		if Vector2(tx, tz).distance_to(Vector2(-3, -2)) < 2.5:
			continue
		var ty = _terrain_y(tx, tz)
		var tmodel = tree_models[randi() % tree_models.size()]
		var tree_node = model_loader.load_model(tmodel, Vector3(tx, ty, tz), randf_range(0.8, 1.5), randf_range(0, 360))
		if tree_node:
			tree_node.scale = Vector3.ZERO
			objects_container.add_child(tree_node)
			grow_queue.append({"node": tree_node, "time": randf_range(3, 8), "dur": randf_range(2.0, 3.0), "trans": Tween.TRANS_BACK})

	# ── Kenney flowers ──
	var flower_models = ["flower_redA.glb", "flower_redB.glb", "flower_yellowA.glb", "flower_yellowB.glb", "flower_purpleA.glb", "flower_purpleB.glb"]
	for i in range(20):
		var fx = randf_range(-7, 7)
		var fz = randf_range(-7, 7)
		if Vector2(fx, fz).distance_to(Vector2(-3, -2)) < 2.0:
			continue
		var fy = _terrain_y(fx, fz)
		var fmodel = flower_models[randi() % flower_models.size()]
		var flower_node = model_loader.load_model(fmodel, Vector3(fx, fy, fz), randf_range(0.8, 2.0), randf_range(0, 360))
		if flower_node:
			flower_node.scale = Vector3.ZERO
			objects_container.add_child(flower_node)
			grow_queue.append({"node": flower_node, "time": randf_range(10, 20), "dur": randf_range(1.5, 2.5), "trans": Tween.TRANS_BACK})

	# ── Kenney bushes / ferns ──
	var bush_models = ["plant_bushDetailed.glb", "plant_bush.glb", "plant_bushSmall.glb"]
	for i in range(8):
		var bx = randf_range(-8, 8)
		var bz = randf_range(-8, 8)
		if Vector2(bx, bz).distance_to(Vector2(-3, -2)) < 2.0:
			continue
		var by = _terrain_y(bx, bz)
		var bmodel = bush_models[randi() % bush_models.size()]
		var bush_node = model_loader.load_model(bmodel, Vector3(bx, by, bz), randf_range(0.6, 1.5), randf_range(0, 360))
		if bush_node:
			bush_node.scale = Vector3.ZERO
			objects_container.add_child(bush_node)
			grow_queue.append({"node": bush_node, "time": randf_range(3, 6), "dur": randf_range(1.5, 2.5), "trans": Tween.TRANS_BACK})

	# ── Vines on log (14-20s) ──
	for i in range(10):
		var vine = Node3D.new()
		vine.scale = Vector3.ZERO
		var vt = float(i) / 10.0
		var vine_angle = vt * TAU * 1.8
		vine.position = Vector3(3 + cos(vine_angle) * 0.28, -0.75 + vt * 0.45, 1 + sin(vine_angle) * 0.28)
		var seg = MeshInstance3D.new()
		seg.mesh = CylinderMesh.new()
		seg.mesh.top_radius = 0.004
		seg.mesh.bottom_radius = 0.009
		seg.mesh.height = 0.18
		var vine_mat = Materials.make_moss_material(Color(0.12, 0.3, 0.08))
		seg.material_override = vine_mat
		vine.add_child(seg)
		var vleaf = MeshInstance3D.new()
		vleaf.mesh = SphereMesh.new()
		vleaf.mesh.radius = 0.022
		vleaf.mesh.height = 0.005
		var vl_mat = StandardMaterial3D.new()
		vl_mat.albedo_color = Color(0.18, 0.38, 0.1)
		vl_mat.roughness = 0.75
		vleaf.mesh.material = vl_mat
		vleaf.position = Vector3(randf_range(-0.03, 0.03), 0.09, randf_range(-0.03, 0.03))
		vine.add_child(vleaf)
		objects_container.add_child(vine)
		grow_queue.append({"node": vine, "time": 14 + i * 0.6, "dur": 0.8, "trans": Tween.TRANS_QUAD})

	# ── Fairy dust particles (22s+) ──
	var fairy_dust = GPUParticles3D.new()
	fairy_dust.amount = 120
	fairy_dust.emitting = false
	var dust_pmat = ParticleProcessMaterial.new()
	dust_pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	dust_pmat.emission_box_extents = Vector3(8, 3, 8)
	dust_pmat.gravity = Vector3(0, 0.12, 0)
	dust_pmat.initial_velocity_min = 0.08
	dust_pmat.initial_velocity_max = 0.3
	dust_pmat.scale_min = 0.008
	dust_pmat.scale_max = 0.03
	fairy_dust.lifetime = 6.0
	var dust_mesh = SphereMesh.new()
	dust_mesh.radius = 0.012
	dust_mesh.height = 0.024
	var dust_draw_mat = StandardMaterial3D.new()
	dust_draw_mat.albedo_color = Color(1, 0.95, 0.8)
	dust_draw_mat.emission_enabled = true
	dust_draw_mat.emission = Color(1, 0.92, 0.7)
	dust_draw_mat.emission_energy_multiplier = 3.0
	dust_mesh.material = dust_draw_mat
	fairy_dust.draw_pass_1 = dust_mesh
	fairy_dust.process_material = dust_pmat
	fairy_dust.position.y = 0.5
	objects_container.add_child(fairy_dust)

	# ── Butterflies (24s+) ──
	for b in range(5):
		var butterfly = Node3D.new()
		butterfly.scale = Vector3.ZERO
		butterfly.position = Vector3(randf_range(-5, 5), randf_range(0.2, 1.5), randf_range(-5, 5))
		var wing_c = [Color(1, 0.7, 0.87), Color(0.7, 0.87, 1), Color(1, 0.87, 0.7), Color(0.87, 0.7, 1)][randi() % 4]
		for side in [-1.0, 1.0]:
			var wing = MeshInstance3D.new()
			wing.mesh = SphereMesh.new()
			wing.mesh.radius = 0.028
			wing.mesh.height = 0.004
			var w_mat = StandardMaterial3D.new()
			w_mat.albedo_color = wing_c
			w_mat.roughness = 0.3
			w_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			w_mat.albedo_color.a = 0.8
			wing.mesh.material = w_mat
			wing.position.x = side * 0.022
			butterfly.add_child(wing)
		var body_m = MeshInstance3D.new()
		body_m.mesh = CylinderMesh.new()
		body_m.mesh.top_radius = 0.002
		body_m.mesh.bottom_radius = 0.002
		body_m.mesh.height = 0.035
		var bm_mat = StandardMaterial3D.new()
		bm_mat.albedo_color = Color(0.15, 0.12, 0.1)
		bm_mat.roughness = 0.8
		body_m.mesh.material = bm_mat
		body_m.rotation_degrees.x = 90
		butterfly.add_child(body_m)
		objects_container.add_child(butterfly)
		grow_queue.append({"node": butterfly, "time": 24 + b * 0.8, "dur": 0.8, "trans": Tween.TRANS_BACK})

	# Lights
	var ring_light = OmniLight3D.new()
	ring_light.light_color = Color(1.0, 0.92, 0.75)
	ring_light.light_energy = 0.5
	ring_light.omni_range = 3.5
	ring_light.position = ring_center + Vector3(0, 1, 0)
	objects_container.add_child(ring_light)

	var pond_light = OmniLight3D.new()
	pond_light.light_color = Color(0.65, 0.85, 0.75)
	pond_light.light_energy = 0.3
	pond_light.omni_range = 2.5
	pond_light.position = Vector3(-3, 0.3, -2)
	objects_container.add_child(pond_light)

	# ── Process growth via timer loop ──
	grow_queue.sort_custom(func(a, b): return a["time"] < b["time"])
	var start_time = Time.get_ticks_msec() / 1000.0
	var dust_started = false
	while grow_queue.size() > 0 or not dust_started:
		await get_tree().process_frame
		var now = Time.get_ticks_msec() / 1000.0 - start_time
		while grow_queue.size() > 0 and grow_queue[0]["time"] <= now:
			var item = grow_queue.pop_front()
			var tw = create_tween()
			tw.tween_property(item["node"], "scale", Vector3.ONE, item["dur"]).set_ease(Tween.EASE_OUT).set_trans(item["trans"])
		if now >= 22 and not dust_started:
			fairy_dust.emitting = true
			dust_started = true
		if now > 35:
			break

	# ── Billboard clouds with shader ──
	cloud_nodes.clear()
	var cloud_shader = load("res://shaders/cloud.gdshader")
	var cloud_noise_tex = NoiseTexture2D.new()
	var cn = FastNoiseLite.new()
	cn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	cn.frequency = 0.02
	cn.fractal_octaves = 4
	cloud_noise_tex.noise = cn
	cloud_noise_tex.width = 256
	cloud_noise_tex.height = 256
	cloud_noise_tex.seamless = true
	for i in range(12):
		var cloud = MeshInstance3D.new()
		cloud.mesh = QuadMesh.new()
		cloud.mesh.size = Vector2(randf_range(3, 7), randf_range(1.5, 3))
		var c_mat = ShaderMaterial.new()
		c_mat.shader = cloud_shader
		c_mat.set_shader_parameter("cloud_color", Color(0.95, 0.93, 0.88))
		c_mat.set_shader_parameter("alpha_base", randf_range(0.2, 0.45))
		c_mat.set_shader_parameter("noise_tex", cloud_noise_tex)
		cloud.material_override = c_mat
		cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cloud.position = Vector3(randf_range(-20, 20), randf_range(6, 10), randf_range(-15, 10))
		objects_container.add_child(cloud)
		cloud_nodes.append(cloud)

	sky_cycle_enabled = true
	spawned_items.append({"type": "scene", "name": "fairy_garden"})

# ── HAUNTED GRAVEYARD ────────────────────────────────────────────────────────

func apply_graveyard_environment():
	var env = $WorldEnvironment.environment as Environment
	var sky_mat = env.sky.sky_material as ProceduralSkyMaterial
	sky_mat.sky_top_color = Color(0.12, 0.04, 0.2)
	sky_mat.sky_horizon_color = Color(0.15, 0.08, 0.22)
	sky_mat.ground_bottom_color = Color(0.02, 0.02, 0.05)
	sky_mat.ground_horizon_color = Color(0.08, 0.05, 0.12)
	sky_mat.sky_energy_multiplier = 0.6
	env.tonemap_mode = 3  # Filmic
	env.tonemap_exposure = 1.0
	env.ambient_light_source = 1
	env.ambient_light_energy = 0.3
	env.ambient_light_color = Color(0.3, 0.25, 0.45)
	env.sdfgi_enabled = true
	env.sdfgi_use_occlusion = true
	env.sdfgi_energy = 0.5
	env.ssao_enabled = true
	env.ssao_radius = 1.5
	env.ssao_intensity = 3.0
	env.ssr_enabled = true
	env.ssr_max_steps = 64
	# Green volumetric fog
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.04
	env.volumetric_fog_albedo = Color(0.08, 0.15, 0.06)
	env.volumetric_fog_emission = Color(0.02, 0.06, 0.02)
	env.volumetric_fog_emission_energy = 0.5
	env.fog_enabled = true
	env.fog_density = 0.015
	env.fog_light_color = Color(0.06, 0.1, 0.05)
	# Glow for candles/pumpkins
	env.glow_enabled = true
	env.glow_intensity = 1.8
	env.glow_bloom = 0.4
	env.glow_strength = 1.3
	env.glow_hdr_threshold = 0.5
	# Cold moonlight
	$MoonLight.light_color = Color(0.55, 0.6, 0.85)
	$MoonLight.light_energy = 0.35
	$MoonLight.shadow_enabled = true

func create_haunted_graveyard(params: Dictionary):
	for child in objects_container.get_children():
		child.queue_free()
	spawned_items.clear()
	ghost_node = null
	sky_cycle_enabled = false
	day_night_enabled = false
	flicker_lights.clear()
	await get_tree().process_frame

	var ML = preload("res://model_loader.gd")

	# Terrain — dark earth
	terrain_noise = FastNoiseLite.new()
	terrain_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	terrain_noise.frequency = 0.02
	terrain_noise.fractal_octaves = 3
	terrain_noise.seed = 666
	var terrain_mi = Terrain.create_terrain(20.0, 0.5, 0.3, 666)
	terrain_mi.material_override = Materials.make_ground_material(Color(0.12, 0.1, 0.08))
	terrain_mi.position = Vector3(0, -1, 0)
	objects_container.add_child(terrain_mi)

	# ── Stone walls forming graveyard border ──
	var wall_positions = [
		{"model": "stone-wall.glb", "pos": Vector3(-6, -1, -5), "rot": 0},
		{"model": "stone-wall.glb", "pos": Vector3(-4, -1, -5), "rot": 0},
		{"model": "stone-wall.glb", "pos": Vector3(-2, -1, -5), "rot": 0},
		{"model": "stone-wall-column.glb", "pos": Vector3(-7, -1, -5), "rot": 0},
		{"model": "stone-wall.glb", "pos": Vector3(-7, -1, -3), "rot": 90},
		{"model": "stone-wall.glb", "pos": Vector3(-7, -1, -1), "rot": 90},
	]
	for wp in wall_positions:
		var wall = model_loader.load_model(wp["model"], wp["pos"], 1.0, wp["rot"], ML.GRAVEYARD_PATH)
		if wall:
			_apply_material_recursive(wall, Materials.make_stone_material(Color(0.3, 0.28, 0.25)))
			objects_container.add_child(wall)

	# ── Iron fences ──
	for i in range(5):
		var fence = model_loader.load_model("iron-fence.glb", Vector3(0 + i * 2, -1, -5), 1.0, 0, ML.GRAVEYARD_PATH)
		if fence:
			objects_container.add_child(fence)

	# ── Gravestones scattered ──
	var gravestone_models = ["gravestone-cross.glb", "gravestone-round.glb", "gravestone-bevel.glb", "gravestone-decorative.glb", "gravestone-broken.glb", "gravestone-wide.glb"]
	for i in range(18):
		var gx = randf_range(-5, 5)
		var gz = randf_range(-4, 4)
		var gy = _terrain_y(gx, gz)
		var gmodel = gravestone_models[randi() % gravestone_models.size()]
		var stone = model_loader.load_model(gmodel, Vector3(gx, gy, gz), randf_range(0.8, 1.2), randf_range(-15, 15), ML.GRAVEYARD_PATH)
		if stone:
			objects_container.add_child(stone)

	# ── Crypts ──
	var crypt = model_loader.load_model("crypt-large.glb", Vector3(-5, -1, 2), 1.0, -30, ML.GRAVEYARD_PATH)
	if crypt:
		_apply_material_recursive(crypt, Materials.make_stone_material(Color(0.28, 0.26, 0.24)))
		objects_container.add_child(crypt)
	var crypt2 = model_loader.load_model("crypt-small.glb", Vector3(5, -1, 0), 1.0, 45, ML.GRAVEYARD_PATH)
	if crypt2:
		objects_container.add_child(crypt2)

	# ── Crooked pines ──
	for i in range(4):
		var px = randf_range(-8, 8)
		var pz = randf_range(-6, 6)
		var py = _terrain_y(px, pz)
		var pine_name = ["pine-crooked.glb", "pine.glb", "pine-fall-crooked.glb"][randi() % 3]
		var pine = model_loader.load_model(pine_name, Vector3(px, py, pz), randf_range(0.8, 1.5), randf_range(0, 360), ML.GRAVEYARD_PATH)
		if pine:
			objects_container.add_child(pine)

	# ── Pumpkins with proximity glow ──
	var pumpkin_models = ["pumpkin-carved.glb", "pumpkin-tall-carved.glb", "pumpkin.glb"]
	var glow_shader = load("res://shaders/proximity_glow.gdshader")
	for i in range(8):
		var px = randf_range(-5, 5)
		var pz = randf_range(-4, 4)
		var py = _terrain_y(px, pz)
		var pmodel = pumpkin_models[randi() % pumpkin_models.size()]
		var pumpkin = model_loader.load_model(pmodel, Vector3(px, py, pz), randf_range(0.6, 1.2), randf_range(0, 360), ML.GRAVEYARD_PATH)
		if pumpkin:
			if "carved" in pmodel and glow_shader:
				var glow_mat = ShaderMaterial.new()
				glow_mat.shader = glow_shader
				glow_mat.set_shader_parameter("base_emission", Color(1.0, 0.5, 0.1))
				glow_mat.set_shader_parameter("base_strength", 1.5)
				glow_mat.set_shader_parameter("max_strength", 6.0)
				glow_mat.set_shader_parameter("glow_radius", 4.0)
				glow_mat.set_shader_parameter("albedo", Color(0.6, 0.3, 0.05))
				_apply_material_recursive(pumpkin, glow_mat)
			objects_container.add_child(pumpkin)
			# Small light near carved pumpkins
			if "carved" in pmodel:
				var plight = OmniLight3D.new()
				plight.light_color = Color(1.0, 0.6, 0.15)
				plight.light_energy = 0.6
				plight.omni_range = 2.5
				plight.position = Vector3(px, py + 0.3, pz)
				objects_container.add_child(plight)

	# ── Candles with proximity glow ──
	for i in range(6):
		var cx = randf_range(-4, 4)
		var cz = randf_range(-3, 3)
		var cy = _terrain_y(cx, cz)
		var candle = model_loader.load_model("candle-multiple.glb", Vector3(cx, cy, cz), randf_range(0.8, 1.2), randf_range(0, 360), ML.GRAVEYARD_PATH)
		if candle:
			if glow_shader:
				var glow_mat = ShaderMaterial.new()
				glow_mat.shader = glow_shader
				glow_mat.set_shader_parameter("base_emission", Color(1.0, 0.8, 0.3))
				glow_mat.set_shader_parameter("base_strength", 2.0)
				glow_mat.set_shader_parameter("max_strength", 7.0)
				glow_mat.set_shader_parameter("glow_radius", 3.5)
				glow_mat.set_shader_parameter("albedo", Color(0.9, 0.85, 0.7))
				_apply_material_recursive(candle, glow_mat)
			objects_container.add_child(candle)

	# ── Coffins ──
	var coffin = model_loader.load_model("coffin-old.glb", Vector3(2, -1, 3), 1.0, 20, ML.GRAVEYARD_PATH)
	if coffin:
		objects_container.add_child(coffin)
	var coffin2 = model_loader.load_model("coffin.glb", Vector3(-2, -1, 4), 1.0, -60, ML.GRAVEYARD_PATH)
	if coffin2:
		objects_container.add_child(coffin2)

	# ── Lanterns ──
	for i in range(3):
		var lx = randf_range(-5, 5)
		var lz = randf_range(-4, 4)
		var ly = _terrain_y(lx, lz)
		var lantern = model_loader.load_model("lantern-candle.glb", Vector3(lx, ly, lz), 1.0, 0, ML.GRAVEYARD_PATH)
		if lantern:
			objects_container.add_child(lantern)

	# ── Ghost — follows cursor ──
	var ghost = model_loader.load_model("character-ghost.glb", Vector3(0, 0.3, 0), 1.2, 0, ML.GRAVEYARD_PATH)
	if ghost:
		# Make ghost translucent and glowing
		var ghost_mat = StandardMaterial3D.new()
		ghost_mat.albedo_color = Color(0.7, 0.85, 0.75, 0.5)
		ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		ghost_mat.emission_enabled = true
		ghost_mat.emission = Color(0.5, 0.9, 0.6)
		ghost_mat.emission_energy_multiplier = 2.0
		_apply_material_recursive(ghost, ghost_mat)
		objects_container.add_child(ghost)
		ghost_node = ghost
		# Ghost light
		var ghost_light = OmniLight3D.new()
		ghost_light.light_color = Color(0.5, 0.9, 0.6)
		ghost_light.light_energy = 0.4
		ghost_light.omni_range = 3.0
		ghost.add_child(ghost_light)

	# ── Skeleton ──
	var skel = model_loader.load_model("character-skeleton.glb", Vector3(4, -1, -2), 1.0, -45, ML.GRAVEYARD_PATH)
	if skel:
		objects_container.add_child(skel)

	# ── Ground fog (billboard quads) ──
	var fog_shader = load("res://shaders/ground_fog.gdshader")
	if fog_shader:
		for i in range(20):
			var fog = MeshInstance3D.new()
			fog.mesh = QuadMesh.new()
			fog.mesh.size = Vector2(randf_range(3, 6), randf_range(1.0, 2.0))
			var fog_mat = ShaderMaterial.new()
			fog_mat.shader = fog_shader
			fog_mat.set_shader_parameter("fog_color", Color(0.1, 0.2, 0.08))
			fog_mat.set_shader_parameter("fog_alpha", randf_range(0.2, 0.4))
			fog_mat.set_shader_parameter("cursor_clear_radius", 3.0)
			fog.material_override = fog_mat
			fog.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			fog.position = Vector3(randf_range(-8, 8), -0.6 + randf_range(-0.2, 0.2), randf_range(-6, 6))
			objects_container.add_child(fog)

	# ── Lights (max 4 shadow-casting) ──
	var moon_accent = OmniLight3D.new()
	moon_accent.light_color = Color(0.4, 0.5, 0.8)
	moon_accent.light_energy = 0.3
	moon_accent.omni_range = 12.0
	moon_accent.position = Vector3(0, 5, 0)
	objects_container.add_child(moon_accent)

	spawned_items.append({"type": "scene", "name": "haunted_graveyard"})

# ── SPACE OUTPOST ────────────────────────────────────────────────────────────

func apply_space_environment():
	var env = $WorldEnvironment.environment as Environment
	var sky_mat = env.sky.sky_material as ProceduralSkyMaterial
	sky_mat.sky_top_color = Color(0.0, 0.0, 0.02)
	sky_mat.sky_horizon_color = Color(0.0, 0.02, 0.04)
	sky_mat.ground_bottom_color = Color(0.0, 0.0, 0.0)
	sky_mat.ground_horizon_color = Color(0.0, 0.01, 0.02)
	sky_mat.sky_energy_multiplier = 0.15
	env.tonemap_mode = 3
	env.tonemap_exposure = 1.0
	env.ambient_light_source = 3
	env.ambient_light_energy = 0.2
	env.ambient_light_color = Color(0.1, 0.2, 0.25)
	env.sdfgi_enabled = true
	env.sdfgi_use_occlusion = true
	env.sdfgi_energy = 0.4
	env.ssao_enabled = true
	env.ssao_radius = 1.0
	env.ssao_intensity = 2.5
	env.ssr_enabled = true
	env.ssr_max_steps = 64
	# No atmosphere — minimal fog
	env.volumetric_fog_enabled = false
	env.fog_enabled = false
	# Strong glow for outpost lights
	env.glow_enabled = true
	env.glow_intensity = 2.0
	env.glow_bloom = 0.5
	env.glow_strength = 1.5
	env.glow_hdr_threshold = 0.4
	# Dim distant star light
	$MoonLight.light_color = Color(0.7, 0.75, 0.85)
	$MoonLight.light_energy = 0.2
	$MoonLight.shadow_enabled = true

func create_space_outpost(params: Dictionary):
	for child in objects_container.get_children():
		child.queue_free()
	spawned_items.clear()
	ghost_node = null
	dish_node = null
	sky_cycle_enabled = false
	day_night_enabled = false
	flicker_lights.clear()
	await get_tree().process_frame

	var ML = preload("res://model_loader.gd")

	# ── Ground — barren crater terrain ──
	terrain_noise = FastNoiseLite.new()
	terrain_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	terrain_noise.frequency = 0.025
	terrain_noise.fractal_octaves = 2
	terrain_noise.seed = 99
	var terrain_mi = Terrain.create_terrain(20.0, 0.5, 0.2, 99)
	terrain_mi.material_override = Materials.make_ground_material(Color(0.15, 0.14, 0.13))
	terrain_mi.position = Vector3(0, -1, 0)
	objects_container.add_child(terrain_mi)

	# ── Corridors forming outpost structure ──
	var corridor_layout = [
		{"model": "corridor.glb", "pos": Vector3(0, -1, 0), "rot": 0},
		{"model": "corridor.glb", "pos": Vector3(2, -1, 0), "rot": 0},
		{"model": "corridor_corner.glb", "pos": Vector3(4, -1, 0), "rot": 0},
		{"model": "corridor.glb", "pos": Vector3(4, -1, 2), "rot": 90},
		{"model": "corridor_open.glb", "pos": Vector3(-2, -1, 0), "rot": 0},
		{"model": "corridor_split.glb", "pos": Vector3(0, -1, -2), "rot": 0},
		{"model": "corridor_window.glb", "pos": Vector3(2, -1, -2), "rot": 0},
	]
	for cl in corridor_layout:
		var corr = model_loader.load_model(cl["model"], cl["pos"], 1.0, cl["rot"], ML.SPACE_PATH)
		if corr:
			objects_container.add_child(corr)

	# ── Hangars ──
	var hangar = model_loader.load_model("hangar_largeA.glb", Vector3(-5, -1, 3), 1.0, 0, ML.SPACE_PATH)
	if hangar:
		objects_container.add_child(hangar)
	var hangar2 = model_loader.load_model("hangar_smallA.glb", Vector3(6, -1, -3), 1.0, 90, ML.SPACE_PATH)
	if hangar2:
		objects_container.add_child(hangar2)

	# ── Satellite dish — tracks cursor ──
	var dish = model_loader.load_model("satelliteDish_large.glb", Vector3(-3, -1, -4), 1.2, 0, ML.SPACE_PATH)
	if dish:
		objects_container.add_child(dish)
		dish_node = dish

	# ── Generators and pipes ──
	var gen = model_loader.load_model("machine_generatorLarge.glb", Vector3(6, -1, 2), 1.0, 0, ML.SPACE_PATH)
	if gen:
		objects_container.add_child(gen)
	for i in range(4):
		var pipe = model_loader.load_model("pipe_straight.glb", Vector3(5, -0.5, -1 + i), 1.0, 0, ML.SPACE_PATH)
		if pipe:
			objects_container.add_child(pipe)

	# ── Crystal rocks with emission ──
	var crystal_models = ["rock_crystals.glb", "rock_crystalsLargeA.glb", "rock_crystalsLargeB.glb"]
	var glow_shader = load("res://shaders/proximity_glow.gdshader")
	for i in range(6):
		var cx = randf_range(-7, 7)
		var cz = randf_range(-6, 6)
		var cy = _terrain_y(cx, cz)
		var cmodel = crystal_models[randi() % crystal_models.size()]
		var crystal = model_loader.load_model(cmodel, Vector3(cx, cy, cz), randf_range(0.8, 1.5), randf_range(0, 360), ML.SPACE_PATH)
		if crystal and glow_shader:
			var glow_mat = ShaderMaterial.new()
			glow_mat.shader = glow_shader
			glow_mat.set_shader_parameter("base_emission", Color(0.2, 0.8, 1.0))
			glow_mat.set_shader_parameter("base_strength", 0.5)
			glow_mat.set_shader_parameter("max_strength", 4.0)
			glow_mat.set_shader_parameter("glow_radius", 5.0)
			glow_mat.set_shader_parameter("albedo", Color(0.1, 0.15, 0.2))
			_apply_material_recursive(crystal, glow_mat)
			objects_container.add_child(crystal)
		elif crystal:
			objects_container.add_child(crystal)

	# ── Craters ──
	for i in range(3):
		var crater = model_loader.load_model("craterLarge.glb", Vector3(randf_range(-7, 7), -1, randf_range(-6, 6)), randf_range(0.8, 1.5), randf_range(0, 360), ML.SPACE_PATH)
		if crater:
			objects_container.add_child(crater)

	# ── Rover ──
	var rover = model_loader.load_model("rover.glb", Vector3(3, -1, 4), 1.0, -30, ML.SPACE_PATH)
	if rover:
		objects_container.add_child(rover)

	# ── Astronaut ──
	var astro = model_loader.load_model("astronautA.glb", Vector3(1, -1, 3), 1.0, 45, ML.SPACE_PATH)
	if astro:
		objects_container.add_child(astro)

	# ── Rockets ──
	var rocket_base = model_loader.load_model("rocket_baseA.glb", Vector3(-6, -1, -2), 1.2, 0, ML.SPACE_PATH)
	if rocket_base:
		objects_container.add_child(rocket_base)
	var rocket_top = model_loader.load_model("rocket_topA.glb", Vector3(-6, 0.5, -2), 1.2, 0, ML.SPACE_PATH)
	if rocket_top:
		objects_container.add_child(rocket_top)

	# ── Desk with hologram screen ──
	var desk = model_loader.load_model("desk_computerScreen.glb", Vector3(1, -1, -1), 1.0, 0, ML.SPACE_PATH)
	if desk:
		objects_container.add_child(desk)
	# Hologram overlay
	var holo_shader = load("res://shaders/hologram.gdshader")
	if holo_shader:
		for i in range(3):
			var screen = MeshInstance3D.new()
			screen.mesh = QuadMesh.new()
			screen.mesh.size = Vector2(0.5, 0.4)
			var holo_mat = ShaderMaterial.new()
			holo_mat.shader = holo_shader
			var holo_color = [Color(0.0, 0.8, 1.0), Color(0.0, 1.0, 0.5), Color(1.0, 0.5, 0.0)][i]
			holo_mat.set_shader_parameter("holo_color", holo_color)
			holo_mat.set_shader_parameter("scanline_density", 80.0)
			holo_mat.set_shader_parameter("base_alpha", 0.6)
			screen.material_override = holo_mat
			screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			screen.position = Vector3(0.5 + i * 1.5, 0.2, -1.5)
			screen.rotation_degrees.y = randf_range(-10, 10)
			objects_container.add_child(screen)

	# ── Dust particles blowing away from cursor ──
	var dust = GPUParticles3D.new()
	dust.amount = 200
	dust.emitting = true
	var dust_pmat = ParticleProcessMaterial.new()
	dust_pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	dust_pmat.emission_box_extents = Vector3(10, 0.5, 10)
	dust_pmat.gravity = Vector3(0, -0.2, 0)
	dust_pmat.initial_velocity_min = 0.1
	dust_pmat.initial_velocity_max = 0.5
	dust_pmat.direction = Vector3(1, 0.2, 0)
	dust_pmat.spread = 45.0
	dust_pmat.scale_min = 0.003
	dust_pmat.scale_max = 0.01
	dust.lifetime = 5.0
	dust.process_material = dust_pmat
	var dust_mesh = SphereMesh.new()
	dust_mesh.radius = 0.008
	dust_mesh.height = 0.016
	var dust_mat = StandardMaterial3D.new()
	dust_mat.albedo_color = Color(0.6, 0.55, 0.5)
	dust_mat.roughness = 1.0
	dust_mesh.material = dust_mat
	dust.draw_pass_1 = dust_mesh
	dust.position.y = -0.5
	objects_container.add_child(dust)

	# ── Outpost lights ──
	var outpost_lights = [
		{"pos": Vector3(0, 1, 0), "color": Color(1.0, 0.7, 0.3), "energy": 0.8, "range": 5.0},
		{"pos": Vector3(-5, 1.5, 3), "color": Color(0.3, 0.8, 1.0), "energy": 0.6, "range": 4.0},
		{"pos": Vector3(6, 0.5, 0), "color": Color(1.0, 0.5, 0.2), "energy": 0.5, "range": 3.0},
	]
	for ol in outpost_lights:
		var light = OmniLight3D.new()
		light.light_color = ol["color"]
		light.light_energy = ol["energy"]
		light.omni_range = ol["range"]
		light.shadow_enabled = true
		light.position = ol["pos"]
		objects_container.add_child(light)

	# Stars (tiny emissive spheres in sky dome)
	for i in range(80):
		var star = MeshInstance3D.new()
		star.mesh = SphereMesh.new()
		star.mesh.radius = randf_range(0.01, 0.04)
		star.mesh.height = star.mesh.radius * 2
		var star_mat = StandardMaterial3D.new()
		star_mat.emission_enabled = true
		star_mat.emission = Color(1, 1, randf_range(0.8, 1.0))
		star_mat.emission_energy_multiplier = randf_range(2.0, 5.0)
		star_mat.albedo_color = Color(0.1, 0.1, 0.1)
		star.material_override = star_mat
		star.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var theta = randf() * TAU
		var phi = randf() * PI * 0.5
		var r = 25.0
		star.position = Vector3(cos(theta) * cos(phi) * r, sin(phi) * r + 5, sin(theta) * cos(phi) * r)
		objects_container.add_child(star)

	spawned_items.append({"type": "scene", "name": "space_outpost"})

# ── AUTUMN CAMPSITE ──────────────────────────────────────────────────────────

func apply_autumn_environment():
	var env = $WorldEnvironment.environment as Environment
	var sky_mat = env.sky.sky_material as ProceduralSkyMaterial
	sky_mat.sky_top_color = Color(0.45, 0.55, 0.8)
	sky_mat.sky_horizon_color = Color(0.85, 0.6, 0.35)
	sky_mat.ground_bottom_color = Color(0.2, 0.15, 0.08)
	sky_mat.ground_horizon_color = Color(0.55, 0.4, 0.22)
	sky_mat.sky_energy_multiplier = 3.0
	env.tonemap_mode = 4  # AGX
	env.tonemap_exposure = 1.0
	env.ambient_light_source = 1
	env.ambient_light_sky_contribution = 0.7
	env.ambient_light_energy = 1.0
	env.ambient_light_color = Color(0.95, 0.85, 0.65)
	env.sdfgi_enabled = true
	env.sdfgi_use_occlusion = true
	env.sdfgi_energy = 0.7
	env.ssao_enabled = true
	env.ssao_radius = 1.0
	env.ssao_intensity = 2.5
	env.ssil_enabled = true
	env.ssil_radius = 8.0
	env.ssr_enabled = true
	env.ssr_max_steps = 64
	# Warm golden fog
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.006
	env.volumetric_fog_albedo = Color(0.25, 0.18, 0.08)
	env.volumetric_fog_emission = Color(0.1, 0.06, 0.02)
	env.volumetric_fog_emission_energy = 0.3
	env.fog_enabled = true
	env.fog_density = 0.004
	env.fog_light_color = Color(0.7, 0.5, 0.3)
	env.fog_aerial_perspective = 0.8
	# Warm glow
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.15
	env.glow_strength = 0.9
	env.glow_hdr_threshold = 0.7
	# Golden sunlight
	$MoonLight.light_color = Color(1.0, 0.85, 0.5)
	$MoonLight.light_energy = 0.9
	$MoonLight.shadow_enabled = true

func create_autumn_campsite(params: Dictionary):
	for child in objects_container.get_children():
		child.queue_free()
	spawned_items.clear()
	ghost_node = null
	dish_node = null
	sky_cycle_enabled = false
	flicker_lights.clear()
	await get_tree().process_frame

	var ML = preload("res://model_loader.gd")

	# Enable real-clock day/night
	day_night_enabled = true

	# ── Terrain — rolling hills ──
	terrain_noise = FastNoiseLite.new()
	terrain_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	terrain_noise.frequency = 0.012
	terrain_noise.fractal_octaves = 4
	terrain_noise.seed = 314
	var terrain_mi = Terrain.create_terrain(25.0, 0.5, 0.5, 314)
	terrain_mi.material_override = Materials.make_ground_material(Color(0.25, 0.2, 0.1))
	terrain_mi.position = Vector3(0, -1, 0)
	objects_container.add_child(terrain_mi)

	# ── Fall trees (11 variants!) ──
	var fall_trees = ["tree_blocks_fall.glb", "tree_cone_fall.glb", "tree_default_fall.glb", "tree_detailed_fall.glb", "tree_fat_fall.glb", "tree_oak_fall.glb", "tree_plateau_fall.glb", "tree_simple_fall.glb", "tree_small_fall.glb", "tree_tall_fall.glb", "tree_thin_fall.glb"]
	for i in range(15):
		var tx = randf_range(-9, 9)
		var tz = randf_range(-9, 9)
		# Skip campsite center
		if Vector2(tx, tz).distance_to(Vector2(0, 0)) < 3.0:
			continue
		var ty = _terrain_y(tx, tz)
		var tmodel = fall_trees[randi() % fall_trees.size()]
		var tree_node = model_loader.load_model(tmodel, Vector3(tx, ty, tz), randf_range(0.7, 1.5), randf_range(0, 360))
		if tree_node:
			objects_container.add_child(tree_node)

	# ── Campfire (center) ──
	var campfire = model_loader.load_model("campfire_stones.glb", Vector3(0, -1, 0), 1.2, 0)
	if campfire:
		objects_container.add_child(campfire)
	var logs = model_loader.load_model("campfire_logs.glb", Vector3(0, -0.95, 0), 1.2, 0)
	if logs:
		objects_container.add_child(logs)

	# Fire particles
	var fire = GPUParticles3D.new()
	fire.amount = 150
	fire.emitting = true
	var fire_pmat = ParticleProcessMaterial.new()
	fire_pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	fire_pmat.emission_sphere_radius = 0.3
	fire_pmat.gravity = Vector3(0, 2.5, 0)
	fire_pmat.initial_velocity_min = 0.3
	fire_pmat.initial_velocity_max = 1.0
	fire_pmat.direction = Vector3(0, 1, 0)
	fire_pmat.spread = 15.0
	fire_pmat.scale_min = 0.02
	fire_pmat.scale_max = 0.06
	fire.lifetime = 1.5
	fire.process_material = fire_pmat
	var fire_mesh = SphereMesh.new()
	fire_mesh.radius = 0.025
	fire_mesh.height = 0.05
	var fire_mat = StandardMaterial3D.new()
	fire_mat.emission_enabled = true
	fire_mat.emission = Color(1.0, 0.5, 0.1)
	fire_mat.emission_energy_multiplier = 5.0
	fire_mat.albedo_color = Color(1.0, 0.3, 0.0)
	fire_mesh.material = fire_mat
	fire.draw_pass_1 = fire_mesh
	fire.position = Vector3(0, -0.7, 0)
	objects_container.add_child(fire)

	# Campfire light
	var fire_light = OmniLight3D.new()
	fire_light.light_color = Color(1.0, 0.6, 0.2)
	fire_light.light_energy = 1.2
	fire_light.omni_range = 6.0
	fire_light.shadow_enabled = true
	fire_light.position = Vector3(0, 0.2, 0)
	objects_container.add_child(fire_light)

	# ── Tent ──
	var tent = model_loader.load_model("tent_detailedOpen.glb", Vector3(3, -1, 2), 1.0, -45)
	if tent:
		objects_container.add_child(tent)

	# ── Canoe by the water ──
	var canoe = model_loader.load_model("canoe.glb", Vector3(-5, -0.95, -3), 1.0, 30)
	if canoe:
		objects_container.add_child(canoe)
	var paddle = model_loader.load_model("canoe_paddle.glb", Vector3(-4.5, -0.85, -2.8), 1.0, 25)
	if paddle:
		objects_container.add_child(paddle)

	# ── Stumps and logs ──
	var stump_models = ["stump_old.glb", "stump_round.glb", "stump_roundDetailed.glb"]
	for i in range(5):
		var sx = randf_range(-6, 6)
		var sz = randf_range(-6, 6)
		if Vector2(sx, sz).distance_to(Vector2(0, 0)) < 2.5:
			continue
		var sy = _terrain_y(sx, sz)
		var smodel = stump_models[randi() % stump_models.size()]
		var stump = model_loader.load_model(smodel, Vector3(sx, sy, sz), randf_range(0.8, 1.3), randf_range(0, 360))
		if stump:
			_apply_material_recursive(stump, Materials.make_bark_material(Color(0.22, 0.15, 0.08)))
			objects_container.add_child(stump)

	var log_stack = model_loader.load_model("log_stack.glb", Vector3(2, -1, -1), 1.0, 20)
	if log_stack:
		objects_container.add_child(log_stack)

	# ── Bridge over creek ──
	var bridge = model_loader.load_model("bridge_wood.glb", Vector3(-3, -1, 0), 1.0, 0)
	if bridge:
		objects_container.add_child(bridge)

	# ── Creek with reactive water ──
	var creek = MeshInstance3D.new()
	var creek_mesh = PlaneMesh.new()
	creek_mesh.size = Vector2(8, 2)
	creek_mesh.subdivide_width = 48
	creek_mesh.subdivide_depth = 16
	creek.mesh = creek_mesh
	var water_shader = load("res://shaders/reactive_water.gdshader")
	if water_shader:
		var water_mat = ShaderMaterial.new()
		water_mat.shader = water_shader
		water_mat.set_shader_parameter("water_color", Color(0.06, 0.12, 0.1))
		water_mat.set_shader_parameter("wave_speed", 1.2)
		water_mat.set_shader_parameter("wave_strength", 0.015)
		water_mat.set_shader_parameter("ripple_radius", 3.0)
		water_mat.set_shader_parameter("ripple_strength", 0.03)
		water_mat.set_shader_parameter("ripple_frequency", 8.0)
		creek.material_override = water_mat
	creek.position = Vector3(-3, -0.95, -3)
	creek.rotation_degrees.y = 15
	objects_container.add_child(creek)

	# ── Reactive grass (MultiMesh with cursor push) ──
	var grass_mmi = _create_reactive_grass_multimesh(8.0, 2000)
	grass_mmi.position.y = -1
	objects_container.add_child(grass_mmi)

	# ── Mushrooms under trees ──
	var shroom_models = ["mushroom_red.glb", "mushroom_tan.glb", "mushroom_tanGroup.glb"]
	for i in range(6):
		var mx = randf_range(-8, 8)
		var mz = randf_range(-8, 8)
		if Vector2(mx, mz).distance_to(Vector2(0, 0)) < 2.5:
			continue
		var my = _terrain_y(mx, mz)
		var smodel = shroom_models[randi() % shroom_models.size()]
		var shroom = model_loader.load_model(smodel, Vector3(mx, my, mz), randf_range(0.5, 1.5), randf_range(0, 360))
		if shroom:
			objects_container.add_child(shroom)

	# ── Falling leaves ──
	var leaves = GPUParticles3D.new()
	leaves.amount = 100
	leaves.emitting = true
	var leaf_pmat = ParticleProcessMaterial.new()
	leaf_pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	leaf_pmat.emission_box_extents = Vector3(10, 1, 10)
	leaf_pmat.gravity = Vector3(0, -0.5, 0)
	leaf_pmat.initial_velocity_min = 0.2
	leaf_pmat.initial_velocity_max = 0.8
	leaf_pmat.direction = Vector3(0.3, -1, 0.1)
	leaf_pmat.spread = 30.0
	leaf_pmat.scale_min = 0.01
	leaf_pmat.scale_max = 0.03
	leaf_pmat.angular_velocity_min = -90
	leaf_pmat.angular_velocity_max = 90
	leaves.lifetime = 8.0
	leaves.process_material = leaf_pmat
	var leaf_mesh = PlaneMesh.new()
	leaf_mesh.size = Vector2(0.03, 0.025)
	var leaf_mat = StandardMaterial3D.new()
	leaf_mat.albedo_color = Color(0.85, 0.45, 0.12)
	leaf_mat.roughness = 0.8
	leaf_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	leaf_mesh.material = leaf_mat
	leaves.draw_pass_1 = leaf_mesh
	leaves.position = Vector3(0, 4, 0)
	objects_container.add_child(leaves)

	# ── Clouds ──
	cloud_nodes.clear()
	var cloud_shader = load("res://shaders/cloud.gdshader")
	var cloud_noise_tex = NoiseTexture2D.new()
	var cn = FastNoiseLite.new()
	cn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	cn.frequency = 0.02
	cn.fractal_octaves = 4
	cloud_noise_tex.noise = cn
	cloud_noise_tex.width = 256
	cloud_noise_tex.height = 256
	cloud_noise_tex.seamless = true
	for i in range(8):
		var cloud = MeshInstance3D.new()
		cloud.mesh = QuadMesh.new()
		cloud.mesh.size = Vector2(randf_range(3, 6), randf_range(1.5, 2.5))
		var c_mat = ShaderMaterial.new()
		c_mat.shader = cloud_shader
		c_mat.set_shader_parameter("cloud_color", Color(0.95, 0.92, 0.85))
		c_mat.set_shader_parameter("alpha_base", randf_range(0.25, 0.5))
		c_mat.set_shader_parameter("noise_tex", cloud_noise_tex)
		cloud.material_override = c_mat
		cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		cloud.position = Vector3(randf_range(-18, 18), randf_range(6, 10), randf_range(-12, 10))
		objects_container.add_child(cloud)
		cloud_nodes.append(cloud)

	sky_cycle_enabled = true
	spawned_items.append({"type": "scene", "name": "autumn_campsite"})

# ── ABANDONED STATION ────────────────────────────────────────────────────────

func apply_station_environment():
	var env = $WorldEnvironment.environment as Environment
	var sky_mat = env.sky.sky_material as ProceduralSkyMaterial
	sky_mat.sky_top_color = Color(0.05, 0.12, 0.1)
	sky_mat.sky_horizon_color = Color(0.1, 0.15, 0.08)
	sky_mat.ground_bottom_color = Color(0.02, 0.05, 0.04)
	sky_mat.ground_horizon_color = Color(0.06, 0.1, 0.06)
	sky_mat.sky_energy_multiplier = 0.4
	env.tonemap_mode = 3  # Filmic
	env.tonemap_exposure = 1.1
	env.ambient_light_source = 3
	env.ambient_light_energy = 0.25
	env.ambient_light_color = Color(0.15, 0.2, 0.18)
	env.sdfgi_enabled = true
	env.sdfgi_use_occlusion = true
	env.sdfgi_energy = 0.5
	env.ssao_enabled = true
	env.ssao_radius = 1.5
	env.ssao_intensity = 3.0
	env.ssr_enabled = true
	env.ssr_max_steps = 64
	# Teal-green haze
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.03
	env.volumetric_fog_albedo = Color(0.06, 0.12, 0.08)
	env.volumetric_fog_emission = Color(0.02, 0.05, 0.03)
	env.volumetric_fog_emission_energy = 0.4
	env.fog_enabled = true
	env.fog_density = 0.01
	env.fog_light_color = Color(0.08, 0.12, 0.08)
	# Glow for holograms and bio-light
	env.glow_enabled = true
	env.glow_intensity = 1.5
	env.glow_bloom = 0.3
	env.glow_strength = 1.2
	env.glow_hdr_threshold = 0.5
	# Broken light shafts — dim directional
	$MoonLight.light_color = Color(0.5, 0.65, 0.55)
	$MoonLight.light_energy = 0.3
	$MoonLight.shadow_enabled = true

func create_abandoned_station(params: Dictionary):
	for child in objects_container.get_children():
		child.queue_free()
	spawned_items.clear()
	ghost_node = null
	dish_node = null
	sky_cycle_enabled = false
	day_night_enabled = false
	flicker_lights.clear()
	await get_tree().process_frame

	var ML = preload("res://model_loader.gd")

	# ── Floor — cracked overgrown surface ──
	terrain_noise = FastNoiseLite.new()
	terrain_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	terrain_noise.frequency = 0.03
	terrain_noise.fractal_octaves = 2
	terrain_noise.seed = 404
	var terrain_mi = Terrain.create_terrain(18.0, 0.5, 0.15, 404)
	terrain_mi.material_override = Materials.make_overgrown_material(Color(0.2, 0.18, 0.15))
	terrain_mi.position = Vector3(0, -1, 0)
	objects_container.add_child(terrain_mi)

	# ── Space corridors (broken station) ──
	var station_layout = [
		{"model": "corridor.glb", "pos": Vector3(-2, -1, 0), "rot": 0, "kit": "space"},
		{"model": "corridor_open.glb", "pos": Vector3(0, -1, 0), "rot": 0, "kit": "space"},
		{"model": "corridor_corner.glb", "pos": Vector3(2, -1, 0), "rot": 0, "kit": "space"},
		{"model": "corridor_window.glb", "pos": Vector3(2, -1, 2), "rot": 90, "kit": "space"},
		{"model": "corridor_end.glb", "pos": Vector3(-4, -1, 0), "rot": 180, "kit": "space"},
	]
	for sl in station_layout:
		var piece = model_loader.load_model(sl["model"], sl["pos"], 1.0, sl["rot"], ML.SPACE_PATH)
		if piece:
			_apply_material_recursive(piece, Materials.make_rusty_metal_material(Color(0.25, 0.2, 0.18)))
			objects_container.add_child(piece)

	# ── Nature overgrowth (bushes, mushrooms breaking through) ──
	var bush_models = ["plant_bushDetailed.glb", "plant_bush.glb", "plant_bushLarge.glb", "plant_bushSmall.glb"]
	for i in range(10):
		var bx = randf_range(-6, 6)
		var bz = randf_range(-5, 5)
		var by = _terrain_y(bx, bz)
		var bmodel = bush_models[randi() % bush_models.size()]
		var bush = model_loader.load_model(bmodel, Vector3(bx, by, bz), randf_range(0.5, 1.5), randf_range(0, 360))
		if bush:
			objects_container.add_child(bush)

	var shroom_models = ["mushroom_red.glb", "mushroom_redTall.glb", "mushroom_tan.glb", "mushroom_tanTall.glb"]
	for i in range(8):
		var mx = randf_range(-5, 5)
		var mz = randf_range(-4, 4)
		var my = _terrain_y(mx, mz)
		var smodel = shroom_models[randi() % shroom_models.size()]
		var shroom = model_loader.load_model(smodel, Vector3(mx, my, mz), randf_range(0.6, 2.0), randf_range(0, 360))
		if shroom:
			objects_container.add_child(shroom)

	# ── Graveyard debris (scattered among ruins) ──
	var debris_models = ["debris.glb", "debris-wood.glb", "rocks.glb"]
	for i in range(6):
		var dx = randf_range(-5, 5)
		var dz = randf_range(-4, 4)
		var dy = _terrain_y(dx, dz)
		var dmodel = debris_models[randi() % debris_models.size()]
		var debris = model_loader.load_model(dmodel, Vector3(dx, dy, dz), randf_range(0.5, 1.2), randf_range(0, 360), ML.GRAVEYARD_PATH)
		if debris:
			objects_container.add_child(debris)

	# ── Desk with hologram screens ──
	var desk = model_loader.load_model("desk_computer.glb", Vector3(0, -1, -1.5), 1.0, 0, ML.SPACE_PATH)
	if desk:
		_apply_material_recursive(desk, Materials.make_rusty_metal_material(Color(0.22, 0.2, 0.18)))
		objects_container.add_child(desk)

	var holo_shader = load("res://shaders/hologram.gdshader")
	if holo_shader:
		for i in range(2):
			var screen = MeshInstance3D.new()
			screen.mesh = QuadMesh.new()
			screen.mesh.size = Vector2(0.4, 0.35)
			var holo_mat = ShaderMaterial.new()
			holo_mat.shader = holo_shader
			var holo_color = [Color(0.0, 0.7, 0.4), Color(0.2, 0.5, 0.8)][i]
			holo_mat.set_shader_parameter("holo_color", holo_color)
			holo_mat.set_shader_parameter("scanline_density", 60.0)
			holo_mat.set_shader_parameter("base_alpha", 0.5)
			holo_mat.set_shader_parameter("flicker_speed", 12.0)
			screen.material_override = holo_mat
			screen.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			screen.position = Vector3(-0.3 + i * 0.7, 0.1, -1.8)
			objects_container.add_child(screen)

	# ── Flickering lights (cursor-reactive) ──
	var light_positions = [
		Vector3(-2, 1.2, 0), Vector3(1, 1.5, 0.5), Vector3(3, 0.8, 2),
		Vector3(-1, 1.0, -2), Vector3(4, 1.3, -1),
	]
	for lp in light_positions:
		var fl = OmniLight3D.new()
		fl.light_color = Color(randf_range(0.6, 1.0), randf_range(0.7, 0.9), randf_range(0.5, 0.8))
		fl.light_energy = 0.5
		fl.omni_range = 3.0
		fl.shadow_enabled = (flicker_lights.size() < 3)  # only first 3 cast shadows
		fl.position = lp
		objects_container.add_child(fl)
		flicker_lights.append(fl)

	# ── Vines growing over surfaces (TIME-based mesh) ──
	for i in range(12):
		var vine = MeshInstance3D.new()
		vine.mesh = CylinderMesh.new()
		vine.mesh.top_radius = 0.005
		vine.mesh.bottom_radius = 0.012
		vine.mesh.height = randf_range(0.4, 1.2)
		vine.material_override = Materials.make_moss_material(Color(0.1, 0.25, 0.06))
		vine.position = Vector3(randf_range(-4, 4), randf_range(-0.5, 0.8), randf_range(-3, 3))
		vine.rotation_degrees = Vector3(randf_range(-20, 20), randf_range(0, 360), randf_range(-30, 30))
		objects_container.add_child(vine)

	# ── Graveyard iron fence fragments ──
	for i in range(3):
		var fence = model_loader.load_model("iron-fence-damaged.glb", Vector3(randf_range(-5, 5), -1, randf_range(-4, 4)), randf_range(0.8, 1.2), randf_range(0, 360), ML.GRAVEYARD_PATH)
		if fence:
			objects_container.add_child(fence)

	# ── Barrels (space kit) ──
	var barrel = model_loader.load_model("barrels.glb", Vector3(3, -1, -2), 1.0, 15, ML.SPACE_PATH)
	if barrel:
		_apply_material_recursive(barrel, Materials.make_rusty_metal_material(Color(0.3, 0.22, 0.18)))
		objects_container.add_child(barrel)

	# ── Ground fog ──
	var fog_shader = load("res://shaders/ground_fog.gdshader")
	if fog_shader:
		for i in range(15):
			var fog = MeshInstance3D.new()
			fog.mesh = QuadMesh.new()
			fog.mesh.size = Vector2(randf_range(2, 5), randf_range(0.8, 1.5))
			var fog_mat = ShaderMaterial.new()
			fog_mat.shader = fog_shader
			fog_mat.set_shader_parameter("fog_color", Color(0.08, 0.15, 0.1))
			fog_mat.set_shader_parameter("fog_alpha", randf_range(0.15, 0.35))
			fog_mat.set_shader_parameter("cursor_clear_radius", 2.5)
			fog.material_override = fog_mat
			fog.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			fog.position = Vector3(randf_range(-7, 7), -0.5 + randf_range(-0.15, 0.15), randf_range(-5, 5))
			objects_container.add_child(fog)

	spawned_items.append({"type": "scene", "name": "abandoned_station"})

# ── Helper: reactive grass multimesh ──
func _create_reactive_grass_multimesh(area_size: float, count: int) -> MultiMeshInstance3D:
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = count
	var blade = PlaneMesh.new()
	blade.size = Vector2(0.06, 0.25)
	blade.orientation = PlaneMesh.FACE_Z
	blade.subdivide_width = 0
	blade.subdivide_depth = 1
	var grass_shader_res = load("res://shaders/reactive_grass.gdshader")
	var blade_mat: Material
	if grass_shader_res:
		var smat = ShaderMaterial.new()
		smat.shader = grass_shader_res
		smat.set_shader_parameter("top_color", Color(0.5, 0.55, 0.2))
		smat.set_shader_parameter("bottom_color", Color(0.25, 0.3, 0.08))
		smat.set_shader_parameter("wind_strength", 0.12)
		smat.set_shader_parameter("wind_speed", 0.6)
		smat.set_shader_parameter("cursor_push_radius", 3.0)
		smat.set_shader_parameter("cursor_push_strength", 0.4)
		blade_mat = smat
	else:
		var gmat = StandardMaterial3D.new()
		gmat.albedo_color = Color(0.35, 0.4, 0.12)
		gmat.roughness = 0.7
		gmat.cull_mode = BaseMaterial3D.CULL_DISABLED
		blade_mat = gmat
	blade.material = blade_mat
	mm.mesh = blade
	for i in count:
		var xform = Transform3D()
		xform = xform.rotated(Vector3.UP, randf() * TAU)
		var s = randf_range(0.6, 1.4)
		xform = xform.scaled(Vector3(s, s, s))
		var gx = randf_range(-area_size, area_size)
		var gz = randf_range(-area_size, area_size)
		# Skip campfire center
		if Vector2(gx, gz).distance_to(Vector2(0, 0)) < 2.5:
			xform.origin = Vector3(gx, -99, gz)
		else:
			xform.origin = Vector3(gx, _terrain_y(gx, gz) + 1.0, gz)
		mm.set_instance_transform(i, xform)
	var mmi = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi

# ── Scene transition (fade to black) ──
func _transition_to_scene(scene_name: String):
	if is_transitioning:
		return
	is_transitioning = true
	# Fade out
	var tw = create_tween()
	tw.tween_method(_set_fade_alpha, 0.0, 1.0, 0.5)
	tw.tween_callback(func():
		handle_command({"type": scene_name, "params": {}})
		current_scene_name = scene_name
	)
	tw.tween_method(_set_fade_alpha, 1.0, 0.0, 0.5)
	tw.tween_callback(func(): is_transitioning = false)

func _set_fade_alpha(alpha: float):
	if fade_quad:
		var mat = fade_quad.material_override as StandardMaterial3D
		if mat:
			mat.albedo_color.a = alpha

# ── Time-of-day helper ──
func _get_time_period(hour: int) -> String:
	if hour >= 6 and hour < 10:
		return "morning"
	elif hour >= 10 and hour < 17:
		return "day"
	elif hour >= 17 and hour < 21:
		return "evening"
	elif hour >= 21 or hour < 1:
		return "night"
	else:
		return "late_night"

# ── Weather particle overlay ──
func _weather_code_to_preset(code: int) -> String:
	if code >= 95:
		return "rain"  # thunderstorm
	elif code >= 80:
		return "rain"  # rain showers
	elif code >= 71 and code <= 77:
		return "snow"
	elif code >= 61 and code <= 67:
		return "rain"
	elif code >= 51 and code <= 57:
		return "rain"  # drizzle
	elif code >= 45 and code <= 48:
		return ""  # fog handled by volumetric fog
	return ""

func _set_weather_particles(preset: String):
	# Remove existing weather particles
	if weather_particles and is_instance_valid(weather_particles):
		weather_particles.queue_free()
		weather_particles = null
	current_weather_preset = preset
	if preset == "":
		return

	weather_particles = GPUParticles3D.new()
	weather_particles.emitting = true
	var pmat = ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pmat.emission_box_extents = Vector3(12, 0.5, 12)

	if preset == "rain":
		weather_particles.amount = 300
		weather_particles.lifetime = 2.0
		pmat.gravity = Vector3(weather_wind * 0.1, -8.0, 0)
		pmat.initial_velocity_min = 2.0
		pmat.initial_velocity_max = 5.0
		pmat.direction = Vector3(0, -1, 0)
		pmat.spread = 5.0
		pmat.scale_min = 0.003
		pmat.scale_max = 0.005
		var mesh = CylinderMesh.new()
		mesh.top_radius = 0.002
		mesh.bottom_radius = 0.002
		mesh.height = 0.08
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.6, 0.7, 0.85, 0.5)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh.material = mat
		weather_particles.draw_pass_1 = mesh
	elif preset == "snow":
		weather_particles.amount = 150
		weather_particles.lifetime = 6.0
		pmat.gravity = Vector3(weather_wind * 0.05, -0.8, 0)
		pmat.initial_velocity_min = 0.1
		pmat.initial_velocity_max = 0.5
		pmat.direction = Vector3(0, -1, 0)
		pmat.spread = 25.0
		pmat.scale_min = 0.005
		pmat.scale_max = 0.015
		pmat.angular_velocity_min = -30
		pmat.angular_velocity_max = 30
		var mesh = SphereMesh.new()
		mesh.radius = 0.01
		mesh.height = 0.02
		var mat = StandardMaterial3D.new()
		mat.albedo_color = Color(0.95, 0.97, 1.0, 0.8)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh.material = mat
		weather_particles.draw_pass_1 = mesh

	weather_particles.process_material = pmat
	weather_particles.position = Vector3(0, 5, 0)
	add_child(weather_particles)  # parent to root, not objects_container (persists across scenes)

# ── Screen edge particle burst ──
func _spawn_edge_burst(pos: Vector3):
	var burst = GPUParticles3D.new()
	burst.amount = 40
	burst.one_shot = true
	burst.emitting = true
	burst.lifetime = 1.5
	var pmat = ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pmat.emission_sphere_radius = 0.3
	pmat.gravity = Vector3(0, -1, 0)
	pmat.initial_velocity_min = 1.0
	pmat.initial_velocity_max = 3.0
	pmat.spread = 180.0
	pmat.scale_min = 0.005
	pmat.scale_max = 0.02
	burst.process_material = pmat
	var mesh = SphereMesh.new()
	mesh.radius = 0.015
	mesh.height = 0.03
	var mat = StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission = Color(0.5, 1.0, 0.8)
	mat.emission_energy_multiplier = 3.0
	mat.albedo_color = Color(0.2, 0.5, 0.4)
	mesh.material = mat
	burst.draw_pass_1 = mesh
	burst.position = pos
	objects_container.add_child(burst)
	# Auto-free after lifetime
	var timer = get_tree().create_timer(2.0)
	timer.timeout.connect(func(): if is_instance_valid(burst): burst.queue_free())

# ── Cross-kit model spawning ──
func _spawn_cross_kit(model_name: String, kit: String, params: Dictionary):
	var ML = preload("res://model_loader.gd")
	var kit_path = ML.NATURE_PATH
	match kit:
		"graveyard": kit_path = ML.GRAVEYARD_PATH
		"space": kit_path = ML.SPACE_PATH
	var x = float(params.get("x", 0))
	var y = float(params.get("y", 0))
	var z = float(params.get("z", 0))
	var sc = float(params.get("scale", 1.0))
	var rot = float(params.get("rotation", 0))
	var node = model_loader.load_model(model_name, Vector3(x, y, z), sc, rot, kit_path)
	if not node:
		return
	# Apply optional shader
	var shader_name = params.get("shader", "")
	if shader_name == "proximity_glow":
		var glow_shader = load("res://shaders/proximity_glow.gdshader")
		if glow_shader:
			var glow_mat = ShaderMaterial.new()
			glow_mat.shader = glow_shader
			var glow_color = Color.html(params.get("glow_color", "#00ffaa"))
			glow_mat.set_shader_parameter("base_emission", glow_color)
			glow_mat.set_shader_parameter("base_strength", 1.5)
			glow_mat.set_shader_parameter("max_strength", 5.0)
			glow_mat.set_shader_parameter("glow_radius", 4.0)
			glow_mat.set_shader_parameter("albedo", glow_color.darkened(0.7))
			_apply_material_recursive(node, glow_mat)
	elif shader_name == "hologram":
		var holo_shader = load("res://shaders/hologram.gdshader")
		if holo_shader:
			var holo_mat = ShaderMaterial.new()
			holo_mat.shader = holo_shader
			holo_mat.set_shader_parameter("holo_color", Color.html(params.get("glow_color", "#00ccff")))
			_apply_material_recursive(node, holo_mat)
	objects_container.add_child(node)
	spawned_items.append({"type": "spawn", "model": model_name, "kit": kit, "x": x, "z": z})

# ── Performance hologram display ──
func _create_performance_hologram(params: Dictionary):
	var x = float(params.get("x", 0))
	var y = float(params.get("y", 1.2))
	var z = float(params.get("z", -2))
	var group = Node3D.new()
	group.name = "PerfHologram"
	group.position = Vector3(x, y, z)

	# Background quad with hologram shader
	var bg = MeshInstance3D.new()
	bg.mesh = QuadMesh.new()
	bg.mesh.size = Vector2(1.0, 0.6)
	var holo_shader = load("res://shaders/hologram.gdshader")
	if holo_shader:
		var holo_mat = ShaderMaterial.new()
		holo_mat.shader = holo_shader
		holo_mat.set_shader_parameter("holo_color", Color(0.0, 0.8, 0.5))
		holo_mat.set_shader_parameter("scanline_density", 60.0)
		holo_mat.set_shader_parameter("base_alpha", 0.4)
		bg.material_override = holo_mat
	bg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	group.add_child(bg)

	# Label3D nodes for metrics
	var labels = {
		"fps": {"text": "FPS: --", "pos": Vector3(-0.35, 0.15, 0.01)},
		"gpu": {"text": "GPU: --°C", "pos": Vector3(-0.35, 0.05, 0.01)},
		"cpu": {"text": "CPU: --°C", "pos": Vector3(-0.35, -0.05, 0.01)},
		"ram": {"text": "RAM: --%", "pos": Vector3(-0.35, -0.15, 0.01)},
		"vram": {"text": "VRAM: -- MB", "pos": Vector3(0.15, 0.15, 0.01)},
		"bat": {"text": "BAT: --%", "pos": Vector3(0.15, 0.05, 0.01)},
	}
	for key in labels:
		var label = Label3D.new()
		label.name = "PerfLabel_" + key
		label.text = labels[key]["text"]
		label.position = labels[key]["pos"]
		label.font_size = 24
		label.modulate = Color(0.0, 1.0, 0.6, 0.9)
		label.outline_modulate = Color(0, 0, 0, 0)
		label.no_depth_test = true
		label.billboard = BaseMaterial3D.BILLBOARD_DISABLED
		group.add_child(label)
		label.set_meta("perf_key", key)

	objects_container.add_child(group)
	spawned_items.append({"type": "hologram_display"})

	# Update labels in a timer (10 FPS, not every frame)
	var update_timer = Timer.new()
	update_timer.wait_time = 0.1
	update_timer.autostart = true
	update_timer.timeout.connect(func():
		if not is_instance_valid(group):
			update_timer.queue_free()
			return
		for child in group.get_children():
			if child is Label3D and child.has_meta("perf_key"):
				match child.get_meta("perf_key"):
					"fps": child.text = "FPS: " + str(Engine.get_frames_per_second())
					"gpu": child.text = "GPU: " + str(int(gpu_temp)) + "°C"
					"cpu": child.text = "CPU: " + str(int(cpu_temp)) + "°C"
					"ram": child.text = "RAM: " + str(int(ram_pct)) + "%"
					"vram": child.text = "VRAM: " + str(int(gpu_util)) + "%"
					"bat": child.text = "BAT: " + str(int(bat_pct)) + "%"
	)
	add_child(update_timer)

# ── Helper: audio spectrum band energy ──
func _get_band_energy(from_hz: float, to_hz: float) -> float:
	if not spectrum:
		return 0.0
	var mag = spectrum.get_magnitude_for_frequency_range(from_hz, to_hz)
	return clamp((MIN_DB + linear_to_db(mag.length())) / abs(MIN_DB), 0.0, 1.0)

# ── Helper: asymmetric smoothing (fast attack, slow decay) ──
func _smooth(current: float, target: float, delta: float) -> float:
	var rate = ATTACK if target > current else DECAY
	return lerp(current, target, 1.0 - exp(-rate * delta * 60.0))

# ── Helper: apply material to all MeshInstance3D children ──
func _apply_material_recursive(node: Node, mat: Material):
	if node is MeshInstance3D:
		node.material_override = mat
	for child in node.get_children():
		_apply_material_recursive(child, mat)

# ── Helper: terrain height query ──
func _terrain_y(x: float, z: float) -> float:
	if terrain_noise:
		return terrain_noise.get_noise_2d(x, z) * 0.4 - 1.0
	return -1.0

# ── Helper: MultiMesh grass ──
func _create_grass_multimesh(area_size: float, count: int) -> MultiMeshInstance3D:
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = count
	var blade = PlaneMesh.new()
	blade.size = Vector2(0.06, 0.25)
	blade.orientation = PlaneMesh.FACE_Z
	blade.subdivide_width = 0
	blade.subdivide_depth = 1
	# Grass shader with wind sway
	var grass_shader_res = load("res://shaders/reactive_grass.gdshader")
	var blade_mat: Material
	if grass_shader_res:
		var smat = ShaderMaterial.new()
		smat.shader = grass_shader_res
		smat.set_shader_parameter("top_color", Color(0.35, 0.6, 0.18))
		smat.set_shader_parameter("bottom_color", Color(0.15, 0.3, 0.06))
		smat.set_shader_parameter("wind_strength", 0.15)
		smat.set_shader_parameter("wind_speed", 0.8)
		blade_mat = smat
	else:
		var gmat = StandardMaterial3D.new()
		gmat.albedo_color = Color(0.18, 0.38, 0.08)
		gmat.roughness = 0.7
		gmat.cull_mode = BaseMaterial3D.CULL_DISABLED
		blade_mat = gmat
	blade.material = blade_mat
	mm.mesh = blade
	for i in count:
		var xform = Transform3D()
		xform = xform.rotated(Vector3.UP, randf() * TAU)
		var s = randf_range(0.6, 1.4)
		xform = xform.scaled(Vector3(s, s, s))
		var gx = randf_range(-area_size, area_size)
		var gz = randf_range(-area_size, area_size)
		# Skip pond area
		if Vector2(gx, gz).distance_to(Vector2(-3, -2)) < 2.0:
			xform.origin = Vector3(gx, -99, gz)  # hide off-screen
		else:
			xform.origin = Vector3(gx, _terrain_y(gx, gz) + 1.0, gz)
		mm.set_instance_transform(i, xform)
	var mmi = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi
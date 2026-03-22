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

# Flying vehicles (neon_city)
var neon_city_vehicles: Array = []

# ── Audio reactivity ──
var mic_player: AudioStreamPlayer = null  # stored for periodic restart (bug #80173)
var audio_restart_timer: float = 0.0
var audio_debug_timer: float = 0.0
const AUDIO_RESTART_INTERVAL = 1800.0  # restart audio capture every 30 min to prevent drift
var spectrum: AudioEffectSpectrumAnalyzerInstance = null
var audio_bass: float = 0.0
var audio_mid: float = 0.0
var audio_treble: float = 0.0
var audio_energy: float = 0.0
var beat_intensity: float = 0.0
var prev_bass: float = 0.0
var beat_cooldown: float = 0.0
const BEAT_COOLDOWN_TIME = 0.12
const MIN_DB = -60.0

# Per-band smoothing rates (attack=fast rise, decay=slow fall)
# Tuned per frequency: bass is slow (stable displacement), treble is fast (sparkle)
const ATTACK_DEFAULT = 0.4
const DECAY_DEFAULT = 0.07
# Per-band attack/decay rates (separate flat dicts to avoid nested dict parse issues)
var _band_attack: Dictionary = {"sub_bass": 0.15, "bass": 0.3, "low_mid": 0.35, "mid": 0.5, "upper_mid": 0.6, "treble": 0.8, "presence": 0.7, "brilliance": 0.9, "energy": 0.3}
var _band_decay: Dictionary = {"sub_bass": 0.03, "bass": 0.05, "low_mid": 0.06, "mid": 0.08, "upper_mid": 0.10, "treble": 0.12, "presence": 0.11, "brilliance": 0.15, "energy": 0.05}

# Extended audio bands (7-band)
var audio_sub_bass: float = 0.0     # 20-60 Hz
var audio_low_mid: float = 0.0     # 250-500 Hz
var audio_upper_mid: float = 0.0   # 2-4 kHz
var audio_presence: float = 0.0    # 4-6 kHz
var audio_brilliance: float = 0.0  # 6-20 kHz

# Multi-band beat detection
var beat_kick: float = 0.0    # sub_bass onset
var beat_snare: float = 0.0   # mid onset
var beat_hihat: float = 0.0   # treble onset

# Composite audio signals
var audio_warmth: float = 0.0     # bass×0.4 + low_mid×0.4 + sub_bass×0.2
var audio_brightness: float = 0.0 # treble×0.3 + brilliance×0.4 + presence×0.3
var audio_flux: float = 0.0       # spectral flux (rate of spectral change)

# VRAM watchdog
var gpu_vram_used: float = 0.0
var gpu_vram_total: float = 8192.0
var vram_warning_logged: bool = false

# Git activity
var git_commits_1h: float = 0.0

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

# ── Focus mode ──
var focus_level: float = 0.0  # 0 = unfocused, 1 = deep focus
const FOCUS_APPS = ["kitty", "alacritty", "konsole", "wezterm", "foot", "xterm", "gnome-terminal", "code", "cursor", "neovim", "vim", "emacs", "godot"]

# ── Events ──
var ollama_active: bool = false
var ollama_check_timer: float = 0.0
var commit_burst_timer: float = 0.0

# ── Pomodoro ──
var pomodoro_active: bool = false
var pomodoro_remaining: float = 0.0
var pomodoro_total: float = 1500.0  # 25 min

# ── Scene auto-rotation ──
var auto_rotate_enabled: bool = false
var auto_rotate_interval: float = 3600.0  # 1 hour
var last_auto_rotate_hour: int = -1
var current_scene_name: String = ""

# ── Scene transitions ──
var fade_quad: MeshInstance3D = null
var is_transitioning: bool = false

# ── Frame feedback (Butterchurn-style ping-pong warp) ──
var feedback_enabled: bool = false
var feedback_canvas: CanvasLayer = null
var feedback_vp: Array = [null, null]       # two SubViewports — true ping-pong
var feedback_mat: Array = [null, null]       # shader materials (VP0 reads VP1, VP1 reads VP0)
var feedback_rects: Array = [null, null]     # ColorRects inside each viewport
var feedback_display_rect: TextureRect = null
var feedback_write_idx: int = 0              # alternates 0/1 each frame

# ── Audio-reactive bloom ──
var bloom_reactive_enabled: bool = true
var bloom_base_intensity: float = 1.0
var bloom_base_strength: float = 0.8
var bloom_base_bloom: float = 0.2

# ── Weather particles overlay ──
var weather_particles: GPUParticles3D = null
var current_weather_preset: String = ""

# ── Screen edge effects ──
var edge_cooldown: float = 0.0
var was_at_edge: bool = false

# ── Post-processing overlay ──
var postfx_canvas: CanvasLayer = null
var postfx_rect: ColorRect = null
var current_postfx: String = ""

# ── Art scene state ──
var attractor_mesh: ImmediateMesh = null
var attractor_instance: MeshInstance3D = null
var attractor_points: Array = []
var visualizer_bars: MultiMeshInstance3D = null
var vine_meshes: Array = []
var vine_growing: bool = false
var fluid_particles: GPUParticles3D = null
var lsystem_growing: bool = false

# ── Scene lists ──
const REACTIVE_SCENES = ["haunted_graveyard", "space_outpost", "autumn_campsite", "abandoned_station"]
const ART_SCENES = ["fractal", "aurora", "matrix_rain", "mycelium", "attractor", "galaxy", "visualizer", "lsystem", "vine_garden", "fluid", "fire", "victory", "vaporwave", "domain_warp", "ocean", "cloudscape", "physarum", "plasma", "kaleidoscope", "tunnel", "starfield", "julia", "lava", "nebula", "lightning", "blackhole", "metaballs", "menger", "supernova", "synthgrid", "waveform", "castlevania", "mgs", "aquarium", "neon_city_pixel", "sdf_world", "reaction_diffusion", "sacred_geometry", "visionary", "mandala", "metatron", "burning_ship", "newton", "sierpinski", "apollonian", "collatz", "riemann_zeta", "kleinian", "kerr_blackhole", "spiral_waves", "arnold_tongues", "standard_map", "elliptic_finite", "goldbach", "hopf", "wigner", "tropical", "padic", "seifert", "loss_landscape", "schmidt", "modular_forms", "attractor_density", "penrose", "horseshoe", "dirac", "conformal", "mertens", "braid", "symplectic", "sol_geometry", "dyson", "homoclinic", "optimal_transport", "ricci_flow", "neural_ode", "navier_stokes", "yang_mills", "lorenz_knot", "langlands", "prime_gaps", "spectral", "schrodinger", "lenia", "calabi_yau", "apollonian3d", "dual_quat_julia", "hyper_mandelbrot", "eisenstein", "persistence", "legendrian", "bicomplex", "polytope5d"]
const ALL_SCENES = ["full_scene", "abyss_scene", "crystal_cave", "neon_city", "volcanic", "zen_garden", "fairy_garden", "haunted_graveyard", "space_outpost", "autumn_campsite", "abandoned_station", "fractal", "aurora", "matrix_rain", "mycelium", "attractor", "galaxy", "visualizer", "lsystem", "vine_garden", "fluid", "fire", "victory", "vaporwave", "domain_warp", "ocean", "cloudscape", "physarum", "plasma", "kaleidoscope", "tunnel", "starfield", "julia", "lava", "nebula", "lightning", "blackhole", "metaballs", "menger", "supernova", "synthgrid", "waveform", "castlevania", "mgs", "aquarium", "neon_city_pixel", "sdf_world", "reaction_diffusion", "sacred_geometry", "visionary", "mandala", "metatron", "burning_ship", "newton", "sierpinski", "apollonian", "collatz", "riemann_zeta", "kleinian", "kerr_blackhole", "spiral_waves", "arnold_tongues", "standard_map", "elliptic_finite", "goldbach", "hopf", "wigner", "tropical", "padic", "seifert", "loss_landscape", "schmidt", "modular_forms", "attractor_density", "penrose", "horseshoe", "dirac", "conformal", "mertens", "braid", "symplectic", "sol_geometry", "dyson", "homoclinic", "optimal_transport", "ricci_flow", "neural_ode", "navier_stokes", "yang_mills", "lorenz_knot", "langlands", "prime_gaps", "spectral", "schrodinger", "lenia", "calabi_yau", "apollonian3d", "dual_quat_julia", "hyper_mandelbrot", "eisenstein", "persistence", "legendrian", "bicomplex", "polytope5d"]
const TIME_SCENES = {
	"morning": ["fairy_garden", "autumn_campsite", "zen_garden"],
	"day": ["zen_garden", "crystal_cave", "fairy_garden"],
	"evening": ["autumn_campsite", "haunted_graveyard", "neon_city"],
	"night": ["haunted_graveyard", "space_outpost", "abandoned_station"],
	"late_night": ["space_outpost", "abyss_scene", "abandoned_station"],
}
const SEASON_SCENES = {
	"spring": ["fairy_garden", "zen_garden", "crystal_cave"],
	"summer": ["fairy_garden", "zen_garden", "space_outpost"],
	"autumn": ["autumn_campsite", "haunted_graveyard", "volcanic"],
	"winter": ["space_outpost", "abyss_scene", "abandoned_station", "crystal_cave"],
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

	# ── Audio capture ──
	# Audio analysis is handled externally by substrate_sensors.py (pw-record + FFT).
	# Audio levels arrive via UDP sensor packets (audio_bass, audio_mid, etc.).
	_setup_museum_overlay()
	# This bypasses Godot's AudioStreamMicrophone which doesn't work reliably
	# with PipeWire monitor sources on Linux.
	print("Audio: using external sensor daemon (pw-record → UDP)")

	# ── Sensor UDP listener ──
	sensor_udp = PacketPeerUDP.new()
	var udp_err = sensor_udp.bind(9778)
	if udp_err == OK:
		print("Sensor UDP listener on port 9778")
	else:
		push_warning("Failed to bind sensor UDP: ", udp_err)

	# ── Shader pre-warming (compile all pipelines to prevent first-load stutter) ──
	_prewarm_shaders()

	# ── Frame feedback (disabled by default — enable via TCP "feedback" command) ──
	# _setup_feedback()

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
				var reply = await handle_command(result)
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

	# ── Sensor data (1Hz) + Audio (30Hz) via UDP ──
	# Audio arrives at 30Hz from audio thread, sensors at 1Hz from main loop
	if sensor_udp:
		while sensor_udp.get_available_packet_count() > 0:
			var packet = sensor_udp.get_packet()
			var text = packet.get_string_from_utf8()
			var parsed = try_parse_json(text)
			if parsed:
				var ptype = parsed.get("t", "")
				if ptype == "audio" or parsed.has("audio_bass"):
					# Audio packet (30Hz) — per-band smoothing
					audio_bass = _smooth_band("bass", audio_bass, float(parsed.get("audio_bass", 0)), delta)
					audio_mid = _smooth_band("mid", audio_mid, float(parsed.get("audio_mid", 0)), delta)
					audio_treble = _smooth_band("treble", audio_treble, float(parsed.get("audio_treble", 0)), delta)
					audio_energy = _smooth_band("energy", audio_energy, float(parsed.get("audio_energy", 0)), delta)
					audio_sub_bass = _smooth_band("sub_bass", audio_sub_bass, float(parsed.get("audio_sub_bass", 0)), delta)
					audio_low_mid = _smooth_band("low_mid", audio_low_mid, float(parsed.get("audio_low_mid", 0)), delta)
					audio_upper_mid = _smooth_band("upper_mid", audio_upper_mid, float(parsed.get("audio_upper_mid", 0)), delta)
					audio_presence = _smooth_band("presence", audio_presence, float(parsed.get("audio_presence", 0)), delta)
					audio_brilliance = _smooth_band("brilliance", audio_brilliance, float(parsed.get("audio_brilliance", 0)), delta)
					# Beat signals — instant attack (no smoothing)
					beat_intensity = float(parsed.get("audio_beat", 0))
					beat_kick = float(parsed.get("beat_kick", 0))
					beat_snare = float(parsed.get("beat_snare", 0))
					beat_hihat = float(parsed.get("beat_hihat", 0))
					audio_flux = float(parsed.get("audio_flux", 0))
				if ptype == "sensors" or parsed.has("cpu_temp"):
					# Sensor packet (1Hz)
					cpu_temp = float(parsed.get("cpu_temp", cpu_temp))
					gpu_temp = float(parsed.get("gpu_temp", gpu_temp))
					gpu_util = float(parsed.get("gpu_util", gpu_util))
					ram_pct = float(parsed.get("ram_pct", ram_pct))
					bat_pct = float(parsed.get("bat_pct", bat_pct))
					net_rx = float(parsed.get("net_rx", net_rx))
					net_tx = float(parsed.get("net_tx", net_tx))
					weather_code = int(parsed.get("weather_code", weather_code))
					weather_wind = float(parsed.get("weather_wind", weather_wind))
					weather_precip = float(parsed.get("weather_precip", weather_precip))
					var raw_notify = float(parsed.get("notify", 0))
					notify_flash = max(notify_flash, raw_notify)
					gpu_vram_used = float(parsed.get("gpu_vram", gpu_vram_used))
					gpu_vram_total = float(parsed.get("gpu_vram_total", gpu_vram_total))
					git_commits_1h = float(parsed.get("git_commits_1h", git_commits_1h))

		# Compute composite audio signals
		audio_warmth = audio_bass * 0.4 + audio_low_mid * 0.4 + audio_sub_bass * 0.2
		audio_brightness = audio_treble * 0.3 + audio_brilliance * 0.4 + audio_presence * 0.3

		# Push audio to shader globals
		RenderingServer.global_shader_parameter_set("audio_bass", audio_bass)
		RenderingServer.global_shader_parameter_set("audio_mid", audio_mid)
		RenderingServer.global_shader_parameter_set("audio_treble", audio_treble)
		RenderingServer.global_shader_parameter_set("audio_energy", audio_energy)
		RenderingServer.global_shader_parameter_set("beat_intensity", beat_intensity)
		RenderingServer.global_shader_parameter_set("audio_sub_bass", audio_sub_bass)
		RenderingServer.global_shader_parameter_set("audio_low_mid", audio_low_mid)
		RenderingServer.global_shader_parameter_set("audio_upper_mid", audio_upper_mid)
		RenderingServer.global_shader_parameter_set("audio_presence", audio_presence)
		RenderingServer.global_shader_parameter_set("audio_brilliance", audio_brilliance)
		RenderingServer.global_shader_parameter_set("beat_kick", beat_kick)
		RenderingServer.global_shader_parameter_set("beat_snare", beat_snare)
		RenderingServer.global_shader_parameter_set("beat_hihat", beat_hihat)
		RenderingServer.global_shader_parameter_set("audio_warmth", audio_warmth)
		RenderingServer.global_shader_parameter_set("audio_brightness", audio_brightness)
		RenderingServer.global_shader_parameter_set("audio_flux", audio_flux)

		# Push VRAM and git to shader globals
		RenderingServer.global_shader_parameter_set("gpu_vram_used", gpu_vram_used)
		RenderingServer.global_shader_parameter_set("gpu_vram_total", gpu_vram_total)
		RenderingServer.global_shader_parameter_set("git_commits_1h", git_commits_1h)

		# VRAM watchdog — warn if > 90%
		if gpu_vram_total > 0:
			var vram_pct = gpu_vram_used / gpu_vram_total
			if vram_pct > 0.9 and not vram_warning_logged:
				push_warning("VRAM usage above 90%: ", gpu_vram_used, "/", gpu_vram_total, " MB")
				vram_warning_logged = true
			elif vram_pct < 0.85:
				vram_warning_logged = false

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
		"static":
			pass  # camera position set once, no per-frame update

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

	# ── Flying vehicles (neon_city) ──
	for vehicle in neon_city_vehicles:
		if is_instance_valid(vehicle):
			var spd = vehicle.get_meta("speed")
			var dir = vehicle.get_meta("dir")
			var base_y = vehicle.get_meta("base_y")
			vehicle.position.x += spd * dir * delta
			vehicle.position.y = base_y + sin(t * 0.8 + vehicle.get_instance_id() * 0.5) * 0.3
			if vehicle.position.x > 18:
				vehicle.position.x = -18
			elif vehicle.position.x < -18:
				vehicle.position.x = 18

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

	# ── Moon phase — real lunar cycle affects moonlight ──
	if not day_night_enabled and not sky_cycle_enabled:
		var moon = _get_moon_phase()
		$MoonLight.light_energy = lerp($MoonLight.light_energy, lerp(0.1, 0.9, moon), delta * 0.1)
		# Full moon = slightly blue, new moon = dim warm
		$MoonLight.light_color = Color(0.5, 0.55, 0.75).lerp(Color(0.7, 0.7, 0.9), moon)

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

	# ── Art scene updates ──
	_update_visualizer()
	_update_fluid_attractor()

	# ── Frame feedback warp ──
	_update_feedback()

	# ── Audio-reactive bloom (multi-resolution glow) ──
	_update_bloom()

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
		# Don't override static camera (shader scenes need it locked)
		if camera_mode != "static":
			camera_mode = "cinematic"
	var idle_factor = clamp(idle_time / idle_threshold, 0.0, 1.0)
	RenderingServer.global_shader_parameter_set("idle_factor", idle_factor)

	# ── Focus mode — serene when in terminals/editors ──
	var in_focus_app = false
	for app in FOCUS_APPS:
		if app in focused_app:
			in_focus_app = true
			break
	var focus_target = 1.0 if in_focus_app else 0.0
	focus_level = lerp(focus_level, focus_target, delta * 0.3)  # slow transition
	RenderingServer.global_shader_parameter_set("focus_level", focus_level)

	# ── Adaptive frame rate — save GPU when fully idle ──
	if is_idle and focus_level > 0.8:
		Engine.max_fps = 15  # idle AND in another app — minimal
	elif is_idle:
		Engine.max_fps = 30  # idle but visible
	else:
		Engine.max_fps = 0   # uncapped (vsync handles it)

	# ── Auto-rotation by time of day ──
	if auto_rotate_enabled:
		var hour_now = Time.get_datetime_dict_from_system()["hour"]
		if hour_now != last_auto_rotate_hour:
			last_auto_rotate_hour = hour_now
			var period = _get_time_period(hour_now)
			var season = _get_season()
			# Intersect time-of-day candidates with seasonal candidates
			var time_candidates = TIME_SCENES.get(period, ALL_SCENES)
			var season_candidates = SEASON_SCENES.get(season, ALL_SCENES)
			var candidates = []
			for c in time_candidates:
				if c in season_candidates:
					candidates.append(c)
			if candidates.is_empty():
				candidates = time_candidates  # fallback to time-based
			var pick = candidates[randi() % candidates.size()]
			if pick != current_scene_name:
				_transition_to_scene_dissolve(pick)

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

	# ── Ollama neural pulse ──
	if ollama_active:
		var pulse = 0.5 + 0.5 * sin(t * 3.0)
		RenderingServer.global_shader_parameter_set("neural_pulse", pulse)
	else:
		RenderingServer.global_shader_parameter_set("neural_pulse", 0.0)

	# ── Commit burst decay ──
	if commit_burst_timer > 0:
		commit_burst_timer = max(0.0, commit_burst_timer - delta)

	# ── Pomodoro timer ──
	if pomodoro_active:
		pomodoro_remaining -= delta
		if pomodoro_remaining <= 0:
			pomodoro_active = false
			pomodoro_remaining = 0
			# Flash on completion
			notify_flash = 1.0
		var progress = 1.0 - clamp(pomodoro_remaining / max(pomodoro_total, 1.0), 0.0, 1.0)
		RenderingServer.global_shader_parameter_set("pomodoro_progress", progress)
	else:
		RenderingServer.global_shader_parameter_set("pomodoro_progress", 0.0)

func _animate_recursive(node: Node, t: float, idx: int):
	if node is MeshInstance3D:
		var mat = node.material_override as StandardMaterial3D
		if not mat and node.mesh:
			mat = node.mesh.material as StandardMaterial3D
		if mat and mat.emission_enabled:
			if not node.has_meta("base_emission"):
				node.set_meta("base_emission", mat.emission_energy_multiplier)
			var base = node.get_meta("base_emission")
			if node.has_meta("blink_rate"):
				var rate = node.get_meta("blink_rate")
				mat.emission_energy_multiplier = base if sin(t * rate + node.get_instance_id() * 0.1) > 0.0 else 0.1
			else:
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
			neon_city_vehicles.clear()
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
			apply_forest_environment()
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
			if params.has("strength"):
				bloom_base_strength = float(params["strength"])
				env.glow_strength = bloom_base_strength
			if params.has("intensity"):
				bloom_base_intensity = float(params["intensity"])
				env.glow_intensity = bloom_base_intensity
			if params.has("bloom"):
				bloom_base_bloom = float(params["bloom"])
				env.glow_bloom = bloom_base_bloom
			if params.has("reactive"):
				bloom_reactive_enabled = str(params["reactive"]).to_lower() != "false" and str(params["reactive"]) != "0"
			return {"status": "ok", "message": "Bloom updated (reactive=" + str(bloom_reactive_enabled) + ")"}
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
		"fractal":
			apply_dark_environment()
			create_shader_scene("res://shaders/fractal.gdshader", params)
			return {"status": "ok", "message": "Fractal scene loaded"}
		"aurora":
			apply_dark_environment()
			create_shader_scene("res://shaders/aurora.gdshader", params)
			return {"status": "ok", "message": "Aurora scene loaded"}
		"matrix_rain":
			apply_dark_environment()
			create_shader_scene("res://shaders/matrix_rain.gdshader", params)
			return {"status": "ok", "message": "Matrix rain loaded"}
		"mycelium":
			apply_dark_environment()
			create_shader_scene("res://shaders/mycelium.gdshader", params)
			return {"status": "ok", "message": "Mycelium network loaded"}
		"attractor":
			apply_dark_environment()
			create_attractor_scene(params)
			return {"status": "ok", "message": "Strange attractor loaded", "objects": spawned_items.size()}
		"galaxy":
			apply_dark_environment()
			create_galaxy_scene(params)
			return {"status": "ok", "message": "Galaxy scene loaded", "objects": spawned_items.size()}
		"visualizer":
			apply_dark_environment()
			create_visualizer_scene(params)
			return {"status": "ok", "message": "Music visualizer loaded", "objects": spawned_items.size()}
		"lsystem":
			apply_fairy_environment()
			create_lsystem_scene(params)
			return {"status": "ok", "message": "L-system garden growing..."}
		"vine_garden":
			apply_fairy_environment()
			create_vine_garden(params)
			return {"status": "ok", "message": "Vine garden growing..."}
		"fluid":
			apply_dark_environment()
			create_fluid_scene(params)
			return {"status": "ok", "message": "Fluid scene loaded"}
		"fire":
			apply_dark_environment()
			var env_f = $WorldEnvironment.environment as Environment
			env_f.glow_enabled = false  # pixel art needs hard edges, no bloom
			create_shader_scene("res://shaders/fire.gdshader", params)
			return {"status": "ok", "message": "Fire scene loaded"}
		"castlevania":
			apply_dark_environment()
			var env_cv = $WorldEnvironment.environment as Environment
			env_cv.glow_enabled = false
			create_shader_scene("res://shaders/castlevania.gdshader", params)
			return {"status": "ok", "message": "Castlevania hallway loaded"}
		"mgs":
			apply_dark_environment()
			var env_mgs = $WorldEnvironment.environment as Environment
			env_mgs.glow_enabled = false
			create_shader_scene("res://shaders/mgs.gdshader", params)
			return {"status": "ok", "message": "Shadow Moses loaded"}
		"aquarium":
			apply_dark_environment()
			var env_aq = $WorldEnvironment.environment as Environment
			env_aq.glow_enabled = false
			create_shader_scene("res://shaders/aquarium.gdshader", params)
			return {"status": "ok", "message": "Aquarium loaded"}
		"neon_city_pixel":
			apply_dark_environment()
			var env_ncp = $WorldEnvironment.environment as Environment
			env_ncp.glow_enabled = false
			create_shader_scene("res://shaders/neon_city.gdshader", params)
			return {"status": "ok", "message": "Neon city pixel loaded"}
		"victory":
			apply_dark_environment()
			var env_v = $WorldEnvironment.environment as Environment
			env_v.glow_enabled = false
			create_shader_scene("res://shaders/victory.gdshader", params)
			return {"status": "ok", "message": "Victory scene loaded"}
		"vaporwave":
			apply_dark_environment()
			create_shader_scene("res://shaders/vaporwave.gdshader", params)
			return {"status": "ok", "message": "Vaporwave scene loaded"}
		"domain_warp":
			apply_dark_environment()
			create_shader_scene("res://shaders/domain_warp.gdshader", params)
			return {"status": "ok", "message": "Domain warp scene loaded"}
		"ocean":
			apply_dark_environment()
			create_ocean_scene(params)
			return {"status": "ok", "message": "Ocean scene loaded"}
		"cloudscape":
			apply_dark_environment()
			create_shader_scene("res://shaders/cloudscape_fog.gdshader", params)
			return {"status": "ok", "message": "Cloudscape scene loaded"}
		"physarum":
			apply_dark_environment()
			create_shader_scene("res://shaders/physarum_render.gdshader", params)
			return {"status": "ok", "message": "Physarum scene loaded"}
		"plasma":
			apply_dark_environment()
			create_shader_scene("res://shaders/plasma.gdshader", params)
			return {"status": "ok", "message": "Plasma scene loaded"}
		"kaleidoscope":
			apply_dark_environment()
			create_shader_scene("res://shaders/kaleidoscope.gdshader", params)
			return {"status": "ok", "message": "Kaleidoscope scene loaded"}
		"tunnel":
			apply_dark_environment()
			create_shader_scene("res://shaders/tunnel.gdshader", params)
			return {"status": "ok", "message": "Tunnel scene loaded"}
		"starfield":
			apply_dark_environment()
			create_shader_scene("res://shaders/starfield.gdshader", params)
			return {"status": "ok", "message": "Starfield scene loaded"}
		"julia":
			apply_dark_environment()
			create_shader_scene("res://shaders/julia.gdshader", params)
			return {"status": "ok", "message": "Julia set scene loaded"}
		"lava":
			apply_dark_environment()
			create_shader_scene("res://shaders/lava.gdshader", params)
			return {"status": "ok", "message": "Lava scene loaded"}
		"nebula":
			apply_dark_environment()
			create_shader_scene("res://shaders/nebula.gdshader", params)
			return {"status": "ok", "message": "Nebula scene loaded"}
		"lightning":
			apply_dark_environment()
			create_shader_scene("res://shaders/lightning.gdshader", params)
			return {"status": "ok", "message": "Lightning scene loaded"}
		"blackhole":
			apply_dark_environment()
			create_shader_scene("res://shaders/blackhole.gdshader", params)
			return {"status": "ok", "message": "Black hole scene loaded"}
		"metaballs":
			apply_dark_environment()
			create_shader_scene("res://shaders/metaballs.gdshader", params)
			return {"status": "ok", "message": "Metaballs scene loaded"}
		"menger":
			apply_dark_environment()
			create_shader_scene("res://shaders/menger.gdshader", params)
			return {"status": "ok", "message": "Menger sponge scene loaded"}
		"supernova":
			apply_dark_environment()
			create_shader_scene("res://shaders/supernova.gdshader", params)
			return {"status": "ok", "message": "Supernova scene loaded"}
		"synthgrid":
			apply_dark_environment()
			create_shader_scene("res://shaders/synthgrid.gdshader", params)
			return {"status": "ok", "message": "Synthgrid scene loaded"}
		"waveform":
			apply_dark_environment()
			create_shader_scene("res://shaders/waveform.gdshader", params)
			return {"status": "ok", "message": "Waveform scene loaded"}
		"sdf_world":
			apply_dark_environment()
			create_shader_scene("res://shaders/sdf_world.gdshader", params)
			return {"status": "ok", "message": "SDF world loaded"}
		"reaction_diffusion":
			apply_dark_environment()
			create_shader_scene("res://shaders/reaction_diffusion.gdshader", params)
			return {"status": "ok", "message": "Reaction-diffusion loaded"}
		"sacred_geometry":
			apply_dark_environment()
			create_shader_scene("res://shaders/sacred_geometry.gdshader", params)
			return {"status": "ok", "message": "Sacred geometry loaded"}
		"visionary":
			apply_dark_environment()
			create_shader_scene("res://shaders/visionary.gdshader", params)
			return {"status": "ok", "message": "Visionary art loaded"}
		"mandala":
			apply_dark_environment()
			create_shader_scene("res://shaders/mandala.gdshader", params)
			return {"status": "ok", "message": "Mandala loaded"}
		"metatron":
			apply_dark_environment()
			create_shader_scene("res://shaders/metatron.gdshader", params)
			return {"status": "ok", "message": "Metatron's Cube loaded"}
		"burning_ship":
			apply_dark_environment()
			create_shader_scene("res://shaders/burning_ship.gdshader", params)
			return {"status": "ok", "message": "Burning Ship fractal loaded"}
		"newton":
			apply_dark_environment()
			create_shader_scene("res://shaders/newton.gdshader", params)
			return {"status": "ok", "message": "Newton fractal loaded"}
		"sierpinski":
			apply_dark_environment()
			create_shader_scene("res://shaders/sierpinski.gdshader", params)
			return {"status": "ok", "message": "Sierpinski fractal loaded"}
		"apollonian":
			apply_dark_environment()
			create_shader_scene("res://shaders/apollonian.gdshader", params)
			return {"status": "ok", "message": "Apollonian gasket loaded"}
		"collatz":
			apply_dark_environment()
			create_shader_scene("res://shaders/collatz.gdshader", params)
			return {"status": "ok", "message": "Collatz fractal loaded"}
		"riemann_zeta":
			apply_dark_environment()
			create_shader_scene("res://shaders/riemann_zeta.gdshader", params)
			return {"status": "ok", "message": "Riemann zeta loaded"}
		"kleinian":
			apply_dark_environment()
			create_shader_scene("res://shaders/kleinian.gdshader", params)
			return {"status": "ok", "message": "Kleinian limit set loaded"}
		"kerr_blackhole":
			apply_dark_environment()
			create_shader_scene("res://shaders/kerr_blackhole.gdshader", params)
			return {"status": "ok", "message": "Kerr black hole loaded"}
		"spiral_waves":
			apply_dark_environment()
			create_shader_scene("res://shaders/spiral_waves.gdshader", params)
			return {"status": "ok", "message": "Spiral waves loaded"}
		"arnold_tongues":
			apply_dark_environment()
			create_shader_scene("res://shaders/arnold_tongues.gdshader", params)
			return {"status": "ok", "message": "Arnold tongues loaded"}
		"standard_map":
			apply_dark_environment()
			create_shader_scene("res://shaders/standard_map.gdshader", params)
			return {"status": "ok", "message": "Standard map loaded"}
		"elliptic_finite":
			apply_dark_environment()
			create_shader_scene("res://shaders/elliptic_finite.gdshader", params)
			return {"status": "ok", "message": "Elliptic curves loaded"}
		"goldbach":
			apply_dark_environment()
			create_shader_scene("res://shaders/goldbach.gdshader", params)
			return {"status": "ok", "message": "Goldbach comet loaded"}
		"hopf":
			apply_dark_environment()
			create_shader_scene("res://shaders/hopf.gdshader", params)
			return {"status": "ok", "message": "Hopf fibration loaded"}
		"wigner":
			apply_dark_environment()
			create_shader_scene("res://shaders/wigner.gdshader", params)
			return {"status": "ok", "message": "Wigner function loaded"}
		"tropical":
			apply_dark_environment()
			create_shader_scene("res://shaders/tropical.gdshader", params)
			return {"status": "ok", "message": "Tropical geometry loaded"}
		"padic":
			apply_dark_environment()
			create_shader_scene("res://shaders/padic.gdshader", params)
			return {"status": "ok", "message": "P-adic space loaded"}
		"seifert":
			apply_dark_environment()
			create_shader_scene("res://shaders/seifert.gdshader", params)
			return {"status": "ok", "message": "Seifert surface loaded"}
		"loss_landscape":
			apply_dark_environment()
			create_shader_scene("res://shaders/loss_landscape.gdshader", params)
			return {"status": "ok", "message": "Loss landscape loaded"}
		"schmidt":
			apply_dark_environment()
			create_shader_scene("res://shaders/schmidt.gdshader", params)
			return {"status": "ok", "message": "Schmidt arrangement loaded"}
		"modular_forms":
			apply_dark_environment()
			create_shader_scene("res://shaders/modular_forms.gdshader", params)
			return {"status": "ok", "message": "Modular forms loaded"}
		"attractor_density":
			apply_dark_environment()
			create_shader_scene("res://shaders/attractor_density.gdshader", params)
			return {"status": "ok", "message": "Attractor density loaded"}
		"penrose":
			apply_dark_environment()
			create_shader_scene("res://shaders/penrose.gdshader", params)
			return {"status": "ok", "message": "Penrose tiling loaded"}
		"horseshoe":
			apply_dark_environment()
			create_shader_scene("res://shaders/horseshoe.gdshader", params)
			return {"status": "ok", "message": "Smale horseshoe loaded"}
		"dirac":
			apply_dark_environment()
			create_shader_scene("res://shaders/dirac.gdshader", params)
			return {"status": "ok", "message": "Dirac equation loaded"}
		"conformal":
			apply_dark_environment()
			create_shader_scene("res://shaders/conformal.gdshader", params)
			return {"status": "ok", "message": "Conformal map loaded"}
		"mertens":
			apply_dark_environment()
			create_shader_scene("res://shaders/mertens.gdshader", params)
			return {"status": "ok", "message": "Mertens function loaded"}
		"braid":
			apply_dark_environment()
			create_shader_scene("res://shaders/braid.gdshader", params)
			return {"status": "ok", "message": "Braid group loaded"}
		"symplectic":
			apply_dark_environment()
			create_shader_scene("res://shaders/symplectic.gdshader", params)
			return {"status": "ok", "message": "Symplectic billiards loaded"}
		"sol_geometry":
			apply_dark_environment()
			create_shader_scene("res://shaders/sol_geometry.gdshader", params)
			return {"status": "ok", "message": "Sol geometry loaded"}
		"dyson":
			apply_dark_environment()
			create_shader_scene("res://shaders/dyson.gdshader", params)
			return {"status": "ok", "message": "Dyson Brownian motion loaded"}
		"homoclinic":
			apply_dark_environment()
			create_shader_scene("res://shaders/homoclinic.gdshader", params)
			return {"status": "ok", "message": "Homoclinic tangle loaded"}
		"optimal_transport":
			apply_dark_environment()
			create_shader_scene("res://shaders/optimal_transport.gdshader", params)
			return {"status": "ok", "message": "Optimal transport loaded"}
		"ricci_flow":
			apply_dark_environment()
			create_shader_scene("res://shaders/ricci_flow.gdshader", params)
			return {"status": "ok", "message": "Ricci flow loaded"}
		"neural_ode":
			apply_dark_environment()
			create_shader_scene("res://shaders/neural_ode.gdshader", params)
			return {"status": "ok", "message": "Neural ODE loaded"}
		"navier_stokes":
			apply_dark_environment()
			create_shader_scene("res://shaders/navier_stokes.gdshader", params)
			return {"status": "ok", "message": "Navier-Stokes loaded"}
		"yang_mills":
			apply_dark_environment()
			create_shader_scene("res://shaders/yang_mills.gdshader", params)
			return {"status": "ok", "message": "Yang-Mills loaded"}
		"lorenz_knot":
			apply_dark_environment()
			create_shader_scene("res://shaders/lorenz_knot.gdshader", params)
			return {"status": "ok", "message": "Lorenz knot loaded"}
		"langlands":
			apply_dark_environment()
			create_shader_scene("res://shaders/langlands.gdshader", params)
			return {"status": "ok", "message": "Langlands program loaded"}
		"prime_gaps":
			apply_dark_environment()
			create_shader_scene("res://shaders/prime_gaps.gdshader", params)
			return {"status": "ok", "message": "Prime gaps loaded"}
		"spectral":
			apply_dark_environment()
			create_shader_scene("res://shaders/spectral.gdshader", params)
			return {"status": "ok", "message": "Spectral geometry loaded"}
		"schrodinger":
			apply_dark_environment()
			create_shader_scene("res://shaders/schrodinger.gdshader", params)
			return {"status": "ok", "message": "Schrodinger equation loaded"}
		"lenia":
			apply_dark_environment()
			create_shader_scene("res://shaders/lenia.gdshader", params)
			return {"status": "ok", "message": "Lenia loaded"}
		"calabi_yau":
			apply_dark_environment()
			create_shader_scene("res://shaders/calabi_yau.gdshader", params)
			return {"status": "ok", "message": "Calabi-Yau loaded"}
		"apollonian3d":
			apply_dark_environment()
			create_shader_scene("res://shaders/apollonian3d.gdshader", params)
			return {"status": "ok", "message": "Apollonian 3D loaded"}
		"dual_quat_julia":
			apply_dark_environment()
			create_shader_scene("res://shaders/dual_quat_julia.gdshader", params)
			return {"status": "ok", "message": "Dual quaternion Julia loaded"}
		"hyper_mandelbrot":
			apply_dark_environment()
			create_shader_scene("res://shaders/hyper_mandelbrot.gdshader", params)
			return {"status": "ok", "message": "Hyperbolic Mandelbrot loaded"}
		"eisenstein":
			apply_dark_environment()
			create_shader_scene("res://shaders/eisenstein.gdshader", params)
			return {"status": "ok", "message": "Eisenstein primes loaded"}
		"persistence":
			apply_dark_environment()
			create_shader_scene("res://shaders/persistence.gdshader", params)
			return {"status": "ok", "message": "Persistent homology loaded"}
		"legendrian":
			apply_dark_environment()
			create_shader_scene("res://shaders/legendrian.gdshader", params)
			return {"status": "ok", "message": "Legendrian knots loaded"}
		"bicomplex":
			apply_dark_environment()
			create_shader_scene("res://shaders/bicomplex.gdshader", params)
			return {"status": "ok", "message": "Bicomplex Mandelbrot loaded"}
		"polytope5d":
			apply_dark_environment()
			create_shader_scene("res://shaders/polytope5d.gdshader", params)
			return {"status": "ok", "message": "5D polytope loaded"}
		"museum_narration":
			if museum_chapter:
				museum_chapter.text = params.get("chapter", "")
				museum_chapter.modulate.a = 1.0
			return {"status": "ok", "message": "Narration updated"}
		"postfx":
			var effect = params.get("effect", "none")
			toggle_postfx(effect)
			return {"status": "ok", "message": "Post-FX: " + effect}
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
			var ct_val = params.get("enabled", true)
			cursor_tracking = str(ct_val).to_lower() != "false" and str(ct_val) != "0"
			return {"status": "ok", "message": "Cursor tracking: " + str(cursor_tracking)}
		"auto_rotate":
			var ar_val = params.get("enabled", true)
			auto_rotate_enabled = str(ar_val).to_lower() != "false" and str(ar_val) != "0"
			if params.has("interval"):
				auto_rotate_interval = float(params["interval"])
			return {"status": "ok", "message": "Auto-rotate: " + str(auto_rotate_enabled)}
		"transition":
			var scene_name = params.get("scene", "")
			if scene_name in ALL_SCENES:
				_transition_to_scene_dissolve(scene_name)
				return {"status": "ok", "message": "Transitioning to " + scene_name}
			return {"status": "error", "message": "Unknown scene: " + scene_name}
		"feedback":
			var fb_val = params.get("enabled", true)
			var enable = str(fb_val).to_lower() != "false" and str(fb_val) != "0"
			if enable and not feedback_enabled:
				_setup_feedback()
			elif not enable and feedback_enabled:
				_teardown_feedback()
			if params.has("fade"):
				var fade_v = float(params["fade"])
				for i in range(2):
					if feedback_mat[i]:
						feedback_mat[i].set_shader_parameter("fade", fade_v)
			if params.has("opacity"):
				if feedback_display_rect:
					feedback_display_rect.modulate.a = float(params["opacity"])
			return {"status": "ok", "message": "Feedback: " + str(feedback_enabled)}
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
		"event":
			var event_name = params.get("event", "")
			match event_name:
				"commit":
					commit_burst_timer = 1.0
					_spawn_commit_burst()
					return {"status": "ok", "message": "Commit burst!"}
				"ollama_start":
					ollama_active = true
					return {"status": "ok", "message": "Ollama active"}
				"ollama_stop":
					ollama_active = false
					return {"status": "ok", "message": "Ollama stopped"}
				_:
					return {"status": "error", "message": "Unknown event: " + event_name}
		"screenshot":
			var path = params.get("path", "user://screenshot.png")
			await RenderingServer.frame_post_draw
			var img = get_viewport().get_texture().get_image()
			img.save_png(path)
			return {"status": "ok", "message": "Screenshot saved to " + path, "path": path}
		"pomodoro":
			var action = params.get("action", "start")
			match action:
				"start":
					pomodoro_active = true
					pomodoro_remaining = float(params.get("duration", 1500))  # 25 min default
					pomodoro_total = pomodoro_remaining
					return {"status": "ok", "message": "Pomodoro started: " + str(int(pomodoro_remaining)) + "s"}
				"stop":
					pomodoro_active = false
					return {"status": "ok", "message": "Pomodoro stopped"}
				"status":
					return {"status": "ok", "active": pomodoro_active, "remaining": int(pomodoro_remaining), "total": int(pomodoro_total)}
				_:
					return {"status": "error", "message": "Unknown pomodoro action: " + action}
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

	# Mushrooms with point lights
	var mushroom_data = [
		{"color": "#00ffaa", "x": 0, "y": 0, "emission": 4.0, "scale": 1.3},
		{"color": "#00ffcc", "x": 1.2, "y": 0.8, "emission": 2.5, "scale": 0.6},
		{"color": "#00ff88", "x": -0.8, "y": 1.0, "emission": 3.0, "scale": 0.8},
		{"color": "#44ffaa", "x": 0.5, "y": -1.5, "emission": 2.0, "scale": 0.5},
		{"color": "#00ffdd", "x": -2.0, "y": -0.5, "emission": 3.5, "scale": 0.7},
		{"color": "#33ffaa", "x": 1.8, "y": -2.5, "emission": 2.0, "scale": 0.4},
		{"color": "#00ffaa", "x": -3.0, "y": 2.5, "emission": 2.5, "scale": 0.9},
		{"color": "#66ffcc", "x": 3.5, "y": 1.5, "emission": 1.8, "scale": 0.5},
	]
	for md in mushroom_data:
		create_mushroom(md)
		var ml = OmniLight3D.new()
		ml.light_color = Color.html(md["color"])
		ml.light_energy = float(md["emission"]) * 0.4
		ml.omni_range = 3.0 * float(md["scale"])
		ml.omni_attenuation = 1.5
		ml.position = Vector3(float(md["x"]), 0.3 * float(md["scale"]), float(md["y"]))
		objects_container.add_child(ml)

	# Spore clusters with glow
	create_spore_cluster({"color": "#ff77ff", "x": 2.5, "y": 0})
	create_spore_cluster({"color": "#ff55dd", "x": -1.5, "y": -2.0, "emission": 2.0})
	create_spore_cluster({"color": "#ff88cc", "x": 0.0, "y": 3.0, "emission": 2.5})
	for sp in [Vector3(2.5, 0.5, 0), Vector3(-1.5, 0.5, -2.0), Vector3(0, 0.5, 3.0)]:
		var sl = OmniLight3D.new()
		sl.light_color = Color.html("#ff77ff")
		sl.light_energy = 1.5
		sl.omni_range = 3.0
		sl.position = sp
		objects_container.add_child(sl)

	# Trees
	create_tree({"color": "#77aaff", "x": -2.5, "y": 1.0})
	create_tree({"color": "#5599ff", "x": 3.0, "y": -2.0, "emission": 2.5})
	create_tree({"color": "#88bbff", "x": -4.0, "y": -3.0, "emission": 2.0})

	# Firefly particles
	create_particles("fireflies", {})

# ── Abyss Scene (Underwater) ─────────────────────────────────────────────────

func apply_abyss_environment():
	var env = $WorldEnvironment.environment as Environment
	# Deep ocean sky
	var sky_mat = env.sky.sky_material as ProceduralSkyMaterial
	sky_mat.sky_top_color = Color(0.0, 0.01, 0.04)
	sky_mat.sky_horizon_color = Color(0.0, 0.03, 0.06)
	sky_mat.ground_bottom_color = Color(0.0, 0.0, 0.01)
	sky_mat.ground_horizon_color = Color(0.0, 0.02, 0.04)
	sky_mat.sky_energy_multiplier = 0.4
	# Ocean volumetric fog — blue-green murk
	env.volumetric_fog_density = 0.04
	env.volumetric_fog_albedo = Color(0.0, 0.04, 0.08)
	env.volumetric_fog_emission = Color(0.0, 0.012, 0.03)
	env.volumetric_fog_emission_energy = 0.5
	# Distance fog — deep blue
	env.fog_light_color = Color(0.0, 0.03, 0.06)
	env.fog_density = 0.02
	# Boost glow for underwater bioluminescence
	env.glow_intensity = 2.0
	env.glow_strength = 1.5
	env.glow_bloom = 0.5
	env.glow_hdr_threshold = 0.4
	# Ambient — enough to see the ocean floor and coral
	env.ambient_light_energy = 0.6
	# Surface light filtering down
	$MoonLight.light_color = Color(0.2, 0.35, 0.5)
	$MoonLight.light_energy = 0.4

func apply_forest_environment():
	var env = $WorldEnvironment.environment as Environment
	var sky_mat = env.sky.sky_material as ProceduralSkyMaterial
	sky_mat.sky_top_color = Color(0.15, 0.06, 0.35)
	sky_mat.sky_horizon_color = Color(0.12, 0.25, 0.18)
	sky_mat.ground_bottom_color = Color(0.06, 0.06, 0.12)
	sky_mat.ground_horizon_color = Color(0.1, 0.18, 0.12)
	sky_mat.sky_energy_multiplier = 1.5
	env.volumetric_fog_density = 0.02
	env.volumetric_fog_albedo = Color(0.05, 0.1, 0.07)
	env.volumetric_fog_emission = Color(0.01, 0.04, 0.02)
	env.volumetric_fog_emission_energy = 0.8
	env.fog_light_color = Color(0.03, 0.06, 0.04)
	env.fog_density = 0.015
	env.glow_intensity = 1.5
	env.glow_strength = 1.2
	env.glow_bloom = 0.3
	env.glow_hdr_threshold = 0.6
	env.ambient_light_energy = 1.0
	$MoonLight.light_color = Color(0.6, 0.65, 0.8)
	$MoonLight.light_energy = 0.8

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

	# Jellyfish — scattered at various heights, with point lights
	var jf_data = [
		{"color": "#ff3388", "x": 0, "y": 0, "height": 3.5, "scale": 1.2},
		{"color": "#33ccff", "x": 2.0, "y": 1.5, "height": 2.8, "scale": 0.7},
		{"color": "#ff88ff", "x": -1.8, "y": -1.0, "height": 4.2, "scale": 0.9},
		{"color": "#ffaa33", "x": 0.5, "y": 3.0, "height": 1.8, "scale": 0.5},
		{"color": "#33ffcc", "x": -3.0, "y": 2.0, "height": 3.0, "scale": 0.6},
		{"color": "#ff5555", "x": 3.5, "y": -1.5, "height": 5.0, "scale": 0.4},
		{"color": "#44aaff", "x": -4.0, "y": -3.0, "height": 2.5, "scale": 0.8},
		{"color": "#ff66aa", "x": 4.0, "y": 2.5, "height": 4.0, "scale": 0.5},
	]
	for jd in jf_data:
		create_jellyfish(jd)
		var jl = OmniLight3D.new()
		jl.light_color = Color.html(jd["color"])
		jl.light_energy = 1.5 * float(jd["scale"])
		jl.omni_range = 4.0
		jl.omni_attenuation = 1.8
		jl.position = Vector3(float(jd["x"]), float(jd["height"]), float(jd["y"]))
		objects_container.add_child(jl)

	# Coral formations
	create_coral({"color": "#ff4466", "x": 1.5, "y": 1.0})
	create_coral({"color": "#ff8833", "x": -2.0, "y": -1.5})
	create_coral({"color": "#cc44ff", "x": 0.5, "y": -2.5})
	create_coral({"color": "#33ddff", "x": -1.0, "y": 2.5})
	create_coral({"color": "#ff66cc", "x": 3.0, "y": -3.0})
	create_coral({"color": "#44ffaa", "x": -3.5, "y": 0.5})

	# Hydrothermal vents with glow lights
	create_hydrothermal_vent({"x": 3.0, "y": 0.5})
	create_hydrothermal_vent({"x": -3.5, "y": -2.0, "scale": 0.7})
	create_hydrothermal_vent({"x": 0.0, "y": -4.0, "scale": 0.5})
	for vp in [Vector3(3.0, 0.5, 0.5), Vector3(-3.5, 0.5, -2.0), Vector3(0.0, 0.3, -4.0)]:
		var vl = OmniLight3D.new()
		vl.light_color = Color.html("#ff6633")
		vl.light_energy = 2.0
		vl.omni_range = 4.0
		vl.position = vp
		objects_container.add_child(vl)

	# Anglerfish lurking
	create_anglerfish({"x": -1.5, "y": 0.5})
	create_anglerfish({"x": 2.5, "y": -2.0, "scale": 0.6})
	create_anglerfish({"x": -4.0, "y": -3.5, "scale": 0.5})

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
	sky_mat.sky_top_color = Color(0.03, 0.02, 0.10)
	sky_mat.sky_horizon_color = Color(0.06, 0.04, 0.15)
	sky_mat.ground_bottom_color = Color(0.02, 0.02, 0.05)
	sky_mat.ground_horizon_color = Color(0.04, 0.03, 0.10)
	sky_mat.sky_energy_multiplier = 0.6
	env.volumetric_fog_enabled = false
	env.fog_density = 0.005
	env.fog_light_color = Color(0.1, 0.05, 0.2)
	env.ssr_enabled = true
	env.ssr_max_steps = 128
	env.glow_intensity = 2.5
	env.glow_bloom = 0.5
	env.sdfgi_enabled = true
	env.ambient_light_energy = 0.7
	$MoonLight.light_color = Color(0.4, 0.3, 0.7)
	$MoonLight.light_energy = 0.5

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

	# Crystal clusters — with point lights to illuminate surroundings
	var crystal_colors = ["#4488ff", "#aa44ff", "#44ffdd", "#ff44aa"]
	for i in range(30):
		var cx = randf_range(-12, 12)
		var cz = randf_range(-12, 12)
		var cc = crystal_colors[randi() % 4]
		create_crystal_cluster(Vector3(cx, -1, cz), cc)
		# Every 3rd cluster gets a point light
		if i % 3 == 0:
			var cl = OmniLight3D.new()
			cl.light_color = Color.html(cc)
			cl.light_energy = 1.5
			cl.omni_range = 5.0
			cl.omni_attenuation = 1.5
			cl.position = Vector3(cx, 0.5, cz)
			objects_container.add_child(cl)

	# Large central crystal pillar — with strong light
	create_crystal_pillar(Vector3(0, -1, -3), "#7744ff", 4.0)
	var pillar_light = OmniLight3D.new()
	pillar_light.light_color = Color.html("#7744ff")
	pillar_light.light_energy = 3.0
	pillar_light.omni_range = 8.0
	pillar_light.omni_attenuation = 1.2
	pillar_light.position = Vector3(0, 2.0, -3)
	objects_container.add_child(pillar_light)

	# Stalactites hanging from ceiling
	for i in range(15):
		var stalactite = MeshInstance3D.new()
		var prism = CylinderMesh.new()
		prism.top_radius = randf_range(0.05, 0.15)
		prism.bottom_radius = 0.0
		prism.height = randf_range(0.8, 2.5)
		prism.radial_segments = 5
		stalactite.mesh = prism
		var st_color = crystal_colors[randi() % 4]
		stalactite.mesh.material = make_emissive_mat(st_color, randf_range(0.5, 2.0))
		stalactite.position = Vector3(randf_range(-10, 10), 6 + randf_range(0, 2), randf_range(-10, 8))
		stalactite.rotation_degrees.z = 180  # hang down
		objects_container.add_child(stalactite)

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

	# Sparkle particles — crystal dust floating
	var sparkle = GPUParticles3D.new()
	sparkle.amount = 120
	var sp_mat = ParticleProcessMaterial.new()
	sp_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	sp_mat.emission_box_extents = Vector3(12, 5, 12)
	sp_mat.gravity = Vector3(0, -0.05, 0)
	sp_mat.initial_velocity_min = 0.05
	sp_mat.initial_velocity_max = 0.15
	sp_mat.scale_min = 0.01
	sp_mat.scale_max = 0.03
	sparkle.lifetime = 12.0
	var sp_mesh = SphereMesh.new()
	sp_mesh.radius = 0.015
	sp_mesh.height = 0.03
	sp_mesh.material = make_emissive_mat("#aabbff", 6.0)
	sparkle.draw_pass_1 = sp_mesh
	sparkle.process_material = sp_mat
	objects_container.add_child(sparkle)

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
	sky_mat.sky_top_color = Color(0.06, 0.04, 0.14)
	sky_mat.sky_horizon_color = Color(0.14, 0.06, 0.22)
	sky_mat.ground_bottom_color = Color(0.04, 0.04, 0.08)
	sky_mat.ground_horizon_color = Color(0.10, 0.05, 0.16)
	sky_mat.sky_energy_multiplier = 1.2
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.03
	env.volumetric_fog_albedo = Color(0.06, 0.03, 0.10)
	env.volumetric_fog_emission = Color(0.06, 0.03, 0.08)
	env.volumetric_fog_emission_energy = 1.2
	env.ssr_enabled = true
	env.ssr_max_steps = 96
	env.glow_intensity = 2.0
	env.glow_bloom = 0.35
	env.glow_hdr_threshold = 1.2
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_ADDITIVE
	env.sdfgi_enabled = true
	env.ambient_light_energy = 0.9
	$MoonLight.light_color = Color(0.4, 0.35, 0.6)
	$MoonLight.light_energy = 0.7

func create_neon_city(params: Dictionary):
	for child in objects_container.get_children():
		child.queue_free()
	spawned_items.clear()
	flicker_lights.clear()
	neon_city_vehicles.clear()
	await get_tree().process_frame

	# Wet street — reflective ground
	var street = MeshInstance3D.new()
	street.mesh = PlaneMesh.new()
	street.mesh.size = Vector2(40, 40)
	var street_mat = StandardMaterial3D.new()
	street_mat.albedo_color = Color(0.12, 0.11, 0.15)
	street_mat.metallic = 0.0
	street_mat.roughness = 0.08
	street.mesh.material = street_mat
	street.position = Vector3(0, -1, 0)
	objects_container.add_child(street)

	# Sidewalk curbs — raised strips along center corridor
	for side in [-3.0, 3.0]:
		var curb = MeshInstance3D.new()
		curb.mesh = BoxMesh.new()
		curb.mesh.size = Vector3(0.3, 0.15, 30)
		var curb_mat = StandardMaterial3D.new()
		curb_mat.albedo_color = Color(0.25, 0.23, 0.28)
		curb_mat.roughness = 0.6
		curb.mesh.material = curb_mat
		curb.position = Vector3(side, -0.92, -5)
		objects_container.add_child(curb)

	# Sidewalks — slightly raised lighter concrete
	for side_sw in [-4.5, 4.5]:
		var sidewalk = MeshInstance3D.new()
		sidewalk.mesh = BoxMesh.new()
		sidewalk.mesh.size = Vector3(3.0, 0.05, 30)
		var sw_mat = StandardMaterial3D.new()
		sw_mat.albedo_color = Color(0.18, 0.17, 0.22)
		sw_mat.roughness = 0.8
		sidewalk.mesh.material = sw_mat
		sidewalk.position = Vector3(side_sw, -0.95, -5)
		objects_container.add_child(sidewalk)

	# Puddles — reflective patches concentrated in center corridor for SSR
	for i in range(12):
		var puddle = MeshInstance3D.new()
		puddle.mesh = PlaneMesh.new()
		puddle.mesh.size = Vector2(randf_range(1.5, 4), randf_range(1, 3))
		var puddle_mat = StandardMaterial3D.new()
		puddle_mat.albedo_color = Color(0.03, 0.03, 0.06)
		puddle_mat.metallic = 0.0
		puddle_mat.roughness = 0.05
		puddle.mesh.material = puddle_mat
		puddle.position = Vector3(randf_range(-2.5, 2.5), -0.98, randf_range(-10, 5))
		objects_container.add_child(puddle)

	# Road markings — dashed center line
	for seg in range(12):
		var dash = MeshInstance3D.new()
		dash.mesh = BoxMesh.new()
		dash.mesh.size = Vector3(0.12, 0.01, 0.8)
		dash.mesh.material = make_emissive_mat("#ccaa33", 1.5)
		dash.position = Vector3(0, -0.98, -10 + seg * 1.5)
		objects_container.add_child(dash)
	# Crosswalk — 5 parallel strips
	for cw in range(5):
		var cw_strip = MeshInstance3D.new()
		cw_strip.mesh = BoxMesh.new()
		cw_strip.mesh.size = Vector3(4.0, 0.01, 0.2)
		cw_strip.mesh.material = make_emissive_mat("#ccaa33", 1.2)
		cw_strip.position = Vector3(0, -0.98, -2.0 + cw * 0.5)
		objects_container.add_child(cw_strip)

	# Traffic lights at crosswalk
	for tl_side in [-2.8, 2.8]:
		var tl_pole = MeshInstance3D.new()
		tl_pole.mesh = CylinderMesh.new()
		tl_pole.mesh.top_radius = 0.03
		tl_pole.mesh.bottom_radius = 0.04
		tl_pole.mesh.height = 3.5
		var tl_pole_mat = StandardMaterial3D.new()
		tl_pole_mat.albedo_color = Color(0.12, 0.12, 0.15)
		tl_pole_mat.metallic = 0.6
		tl_pole_mat.roughness = 0.4
		tl_pole.mesh.material = tl_pole_mat
		tl_pole.position = Vector3(tl_side, 0.75, -2.0)
		objects_container.add_child(tl_pole)
		# Housing
		var tl_box = MeshInstance3D.new()
		tl_box.mesh = BoxMesh.new()
		tl_box.mesh.size = Vector3(0.15, 0.4, 0.12)
		var tl_box_mat = StandardMaterial3D.new()
		tl_box_mat.albedo_color = Color(0.08, 0.08, 0.1)
		tl_box_mat.metallic = 0.3
		tl_box.mesh.material = tl_box_mat
		tl_box.position = Vector3(tl_side, 2.6, -2.0)
		objects_container.add_child(tl_box)
		# Light spheres (red/yellow/green — only red emissive)
		var tl_colors = [
			{"color": "#ff0000", "energy": 5.0, "y_off": 0.12},
			{"color": "#ffaa00", "energy": 0.3, "y_off": 0.0},
			{"color": "#00ff00", "energy": 0.3, "y_off": -0.12},
		]
		for tld in tl_colors:
			var tl_light = MeshInstance3D.new()
			tl_light.mesh = SphereMesh.new()
			tl_light.mesh.radius = 0.03
			tl_light.mesh.height = 0.06
			tl_light.mesh.material = make_emissive_mat(tld["color"], tld["energy"])
			tl_light.position = Vector3(tl_side, 2.6 + tld["y_off"], -2.0 + 0.07)
			objects_container.add_child(tl_light)

	# Street props — vending machines, crates, dumpsters on sidewalks
	var prop_defs = [
		{"type": "vending", "size": Vector3(0.5, 1.2, 0.4)},
		{"type": "vending", "size": Vector3(0.5, 1.2, 0.4)},
		{"type": "crate", "size": Vector3(0.4, 0.4, 0.4)},
		{"type": "crate", "size": Vector3(0.5, 0.3, 0.5)},
		{"type": "dumpster", "size": Vector3(0.8, 0.6, 0.5)},
		{"type": "dumpster", "size": Vector3(0.7, 0.5, 0.5)},
	]
	for pi in range(prop_defs.size()):
		var pdef = prop_defs[pi]
		var prop = MeshInstance3D.new()
		prop.mesh = BoxMesh.new()
		prop.mesh.size = pdef["size"]
		var prop_mat = StandardMaterial3D.new()
		prop_mat.roughness = 0.7
		if pdef["type"] == "vending":
			prop_mat.albedo_color = Color(0.1, 0.1, 0.15)
			prop_mat.metallic = 0.5
		elif pdef["type"] == "dumpster":
			prop_mat.albedo_color = Color(0.15, 0.18, 0.12)
			prop_mat.metallic = 0.4
		else:
			prop_mat.albedo_color = Color(0.2, 0.15, 0.1)
			prop_mat.metallic = 0.1
		prop.mesh.material = prop_mat
		var prop_side = -4.5 if pi % 2 == 0 else 4.5
		prop.position = Vector3(prop_side + randf_range(-0.5, 0.5), -1.0 + pdef["size"].y / 2, -8 + pi * 3.0)
		objects_container.add_child(prop)
		# Vending machines get a glowing front panel
		if pdef["type"] == "vending":
			var glow_panel = MeshInstance3D.new()
			glow_panel.mesh = QuadMesh.new()
			glow_panel.mesh.size = Vector2(pdef["size"].x * 0.7, pdef["size"].y * 0.6)
			var vend_colors = ["#00ffaa", "#ff6600", "#4488ff", "#ff0066"]
			glow_panel.mesh.material = make_emissive_mat(vend_colors[randi() % vend_colors.size()], 4.0)
			glow_panel.position = prop.position + Vector3(0, 0.1, pdef["size"].z / 2 + 0.01)
			if prop_side > 0:
				glow_panel.rotation_degrees.y = 180
			objects_container.add_child(glow_panel)

	# Phone booths on sidewalks
	for pb_x in [-4.3, 4.5]:
		var pb_frame = MeshInstance3D.new()
		pb_frame.mesh = BoxMesh.new()
		pb_frame.mesh.size = Vector3(0.5, 1.6, 0.5)
		var pb_mat = StandardMaterial3D.new()
		pb_mat.albedo_color = Color(0.1, 0.1, 0.14)
		pb_mat.metallic = 0.5
		pb_mat.roughness = 0.5
		pb_frame.mesh.material = pb_mat
		pb_frame.position = Vector3(pb_x, -0.2, -4.0)
		objects_container.add_child(pb_frame)
		# Translucent side panels
		for pb_face_z in [-0.26, 0.26]:
			var pb_panel = MeshInstance3D.new()
			pb_panel.mesh = QuadMesh.new()
			pb_panel.mesh.size = Vector2(0.45, 1.4)
			pb_panel.mesh.material = make_translucent_mat("#4466aa", 0.3)
			pb_panel.position = Vector3(pb_x, -0.2, -4.0 + pb_face_z)
			objects_container.add_child(pb_panel)
		# Interior emissive glow
		var pb_glow = MeshInstance3D.new()
		pb_glow.mesh = BoxMesh.new()
		pb_glow.mesh.size = Vector3(0.3, 0.8, 0.3)
		pb_glow.mesh.material = make_emissive_mat("#4488ff", 2.0)
		pb_glow.position = Vector3(pb_x, -0.1, -4.0)
		objects_container.add_child(pb_glow)

	# Manhole covers — metallic circles on street
	for mi in range(3):
		var manhole = MeshInstance3D.new()
		manhole.mesh = CylinderMesh.new()
		manhole.mesh.top_radius = 0.35
		manhole.mesh.bottom_radius = 0.35
		manhole.mesh.height = 0.02
		var mh_mat = StandardMaterial3D.new()
		mh_mat.albedo_color = Color(0.15, 0.15, 0.18)
		mh_mat.metallic = 0.8
		mh_mat.roughness = 0.3
		manhole.mesh.material = mh_mat
		manhole.position = Vector3(randf_range(-1.5, 1.5), -0.98, -6 + mi * 5.0)
		objects_container.add_child(manhole)

	# Storm drain grates along curbs
	for sdi in range(6):
		var sd_side = -3.0 if sdi % 2 == 0 else 3.0
		var sd_grate = MeshInstance3D.new()
		sd_grate.mesh = BoxMesh.new()
		sd_grate.mesh.size = Vector3(0.4, 0.02, 0.25)
		var sd_mat = StandardMaterial3D.new()
		sd_mat.albedo_color = Color(0.08, 0.08, 0.1)
		sd_mat.metallic = 0.7
		sd_mat.roughness = 0.5
		sd_grate.mesh.material = sd_mat
		sd_grate.position = Vector3(sd_side, -0.98, -9 + sdi * 3.5)
		objects_container.add_child(sd_grate)
		# 40% chance: faint green sewer glow underneath
		if randf() < 0.4:
			var sewer_glow = MeshInstance3D.new()
			sewer_glow.mesh = BoxMesh.new()
			sewer_glow.mesh.size = Vector3(0.35, 0.01, 0.2)
			sewer_glow.mesh.material = make_emissive_mat("#22ff44", 2.0)
			sewer_glow.position = Vector3(sd_side, -1.0, -9 + sdi * 3.5)
			objects_container.add_child(sewer_glow)

	# Buildings with neon trim + windows
	var neon_colors = ["#ff0066", "#00ffaa", "#4488ff", "#ff6600", "#aa00ff", "#ffff00"]
	for i in range(25):
		var bx = randf_range(-15, 15)
		var bz = randf_range(-15, 5)
		if abs(bx) < 3.5 and abs(bz) < 5:
			continue
		var h = randf_range(2, 8)
		var w = randf_range(1, 3)
		var d = randf_range(1, 3)
		var nc = neon_colors[randi() % neon_colors.size()]
		create_neon_building(Vector3(bx, -1, bz), w, h, d, nc)

	# Building-mounted neon signs — perpendicular to faces with brackets + lights
	for i in range(12):
		var sign_node = MeshInstance3D.new()
		sign_node.mesh = QuadMesh.new()
		var sw = randf_range(0.6, 1.8)
		var sh = randf_range(0.3, 0.7)
		sign_node.mesh.size = Vector2(sw, sh)
		var sign_color = neon_colors[randi() % neon_colors.size()]
		sign_node.mesh.material = make_emissive_mat(sign_color, 8.0)
		var sx = randf_range(-12, 12)
		var sy = randf_range(1.5, 5)
		var sz = randf_range(-10, 3)
		# Mount perpendicular to building — face outward toward street
		sign_node.rotation_degrees.y = 90 if abs(sx) > 0 else 0
		sign_node.position = Vector3(sx, sy, sz)
		objects_container.add_child(sign_node)
		# Mounting bracket
		var bracket = MeshInstance3D.new()
		bracket.mesh = BoxMesh.new()
		bracket.mesh.size = Vector3(0.05, sh * 0.3, 0.3)
		var brk_mat = StandardMaterial3D.new()
		brk_mat.albedo_color = Color(0.15, 0.15, 0.18)
		brk_mat.metallic = 0.6
		brk_mat.roughness = 0.4
		bracket.mesh.material = brk_mat
		bracket.position = Vector3(sx, sy, sz)
		objects_container.add_child(bracket)
		# OmniLight for sign glow
		var sign_light = OmniLight3D.new()
		sign_light.light_color = Color.html(sign_color)
		sign_light.light_energy = 1.5
		sign_light.omni_range = 3.0
		sign_light.omni_attenuation = 1.8
		sign_light.position = Vector3(sx, sy, sz)
		objects_container.add_child(sign_light)
		# Sign flicker patterns — some get cursor-reactive flicker, some are dim/dead
		var flicker_roll = randf()
		if flicker_roll < 0.3:
			flicker_lights.append(sign_light)
		elif flicker_roll < 0.45:
			var dim_mat = sign_node.mesh.material as StandardMaterial3D
			if dim_mat:
				dim_mat.emission_energy_multiplier = 1.5

	# Holographic billboards — 4 large hologram shader panels on building sides
	var holo_shader = load("res://shaders/hologram.gdshader")
	var holo_colors = [
		Color(0.0, 1.0, 0.7),   # cyan-green
		Color(1.0, 0.0, 0.4),   # hot pink
		Color(0.3, 0.5, 1.0),   # blue
		Color(1.0, 0.4, 0.0),   # orange
	]
	var holo_positions = [
		Vector3(-8, 3.5, -6),
		Vector3(9, 4.0, -3),
		Vector3(-7, 2.5, 2),
		Vector3(10, 3.0, -9),
	]
	for hi in range(4):
		var holo_quad = MeshInstance3D.new()
		holo_quad.mesh = QuadMesh.new()
		holo_quad.mesh.size = Vector2(2.5, 1.5)
		var holo_mat = ShaderMaterial.new()
		holo_mat.shader = holo_shader
		holo_mat.set_shader_parameter("holo_color", Vector3(holo_colors[hi].r, holo_colors[hi].g, holo_colors[hi].b))
		holo_mat.set_shader_parameter("scanline_density", 60.0)
		holo_mat.set_shader_parameter("base_alpha", 0.6)
		holo_mat.set_shader_parameter("flicker_speed", 10.0)
		holo_quad.mesh.material = holo_mat
		holo_quad.position = holo_positions[hi]
		objects_container.add_child(holo_quad)
		# Face toward center street (must be in tree for look_at)
		holo_quad.look_at(Vector3(0, holo_positions[hi].y, holo_positions[hi].z), Vector3.UP)
		# OmniLight casting billboard color
		var holo_light = OmniLight3D.new()
		holo_light.light_color = holo_colors[hi]
		holo_light.light_energy = 2.0
		holo_light.omni_range = 5.0
		holo_light.omni_attenuation = 1.5
		holo_light.position = holo_positions[hi] + Vector3(0, 0, 0.5)
		objects_container.add_child(holo_light)

	# Dramatic spotlight beams from building tops through fog
	var spot_configs = [
		{"pos": Vector3(-6, 7, -8), "color": Color(1.0, 0.2, 0.6), "angle": Vector3(35, 20, 0)},
		{"pos": Vector3(8, 6, -5), "color": Color(0.2, 0.5, 1.0), "angle": Vector3(40, -15, 0)},
		{"pos": Vector3(-4, 8, 2), "color": Color(0.6, 0.2, 1.0), "angle": Vector3(45, 10, 0)},
	]
	for sc in spot_configs:
		var spot = SpotLight3D.new()
		spot.light_color = sc["color"]
		spot.light_energy = 3.0
		spot.spot_range = 15.0
		spot.spot_angle = 25.0
		spot.shadow_enabled = false
		spot.position = sc["pos"]
		spot.rotation_degrees = sc["angle"]
		objects_container.add_child(spot)

	# Street lamps along corridor — with OmniLights that illuminate the wet street
	var lamp_positions_left: Array = []
	var lamp_positions_right: Array = []
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
			var nc_lamp = neon_colors[randi() % neon_colors.size()]
			var lamp = MeshInstance3D.new()
			lamp.mesh = SphereMesh.new()
			lamp.mesh.radius = 0.1
			lamp.mesh.height = 0.15
			lamp.mesh.material = make_emissive_mat(nc_lamp, 4.0)
			lamp.position = Vector3(side, 2.1, lz)
			objects_container.add_child(lamp)
			# Point light — illuminates street and building faces
			var ll = OmniLight3D.new()
			ll.light_color = Color.html(nc_lamp)
			ll.light_energy = 2.5
			ll.omni_range = 6.0
			ll.omni_attenuation = 1.5
			ll.position = Vector3(side, 2.0, lz)
			objects_container.add_child(ll)
			# Collect lamp-top positions for power lines
			var lamp_top = Vector3(side, 2.1, lz)
			if side < 0:
				lamp_positions_left.append(lamp_top)
			else:
				lamp_positions_right.append(lamp_top)

	# Power lines between lamp poles — 2 sagging cables per span
	var cable_mat = StandardMaterial3D.new()
	cable_mat.albedo_color = Color(0.06, 0.06, 0.08)
	cable_mat.roughness = 0.8
	for lamp_arr in [lamp_positions_left, lamp_positions_right]:
		for li in range(lamp_arr.size() - 1):
			var p1 = lamp_arr[li]
			var p2 = lamp_arr[li + 1]
			var mid = (p1 + p2) / 2.0
			mid.y -= 0.3  # sag
			# Two cables per span with slight horizontal offset
			for cable_off in [-0.04, 0.04]:
				var offset = Vector3(cable_off, 0, 0)
				# Segment 1: p1 to mid
				var seg1 = MeshInstance3D.new()
				seg1.mesh = CylinderMesh.new()
				seg1.mesh.top_radius = 0.008
				seg1.mesh.bottom_radius = 0.008
				var s1_len = p1.distance_to(mid)
				seg1.mesh.height = s1_len
				seg1.mesh.material = cable_mat
				seg1.position = (p1 + mid) / 2.0 + offset
				objects_container.add_child(seg1)
				seg1.look_at(mid + offset, Vector3.UP)
				seg1.rotation.x += PI / 2
				# Segment 2: mid to p2
				var seg2 = MeshInstance3D.new()
				seg2.mesh = CylinderMesh.new()
				seg2.mesh.top_radius = 0.008
				seg2.mesh.bottom_radius = 0.008
				var s2_len = mid.distance_to(p2)
				seg2.mesh.height = s2_len
				seg2.mesh.material = cable_mat
				seg2.position = (mid + p2) / 2.0 + offset
				objects_container.add_child(seg2)
				seg2.look_at(p2 + offset, Vector3.UP)
				seg2.rotation.x += PI / 2

	# Street-level fog — ground_fog shader quads, purple/teal tinted
	var fog_shader = load("res://shaders/ground_fog.gdshader")
	var fog_configs = [
		{"color": Vector3(0.15, 0.08, 0.25), "z": -3.0},
		{"color": Vector3(0.08, 0.2, 0.22), "z": -7.0},
		{"color": Vector3(0.12, 0.06, 0.2), "z": 1.0},
		{"color": Vector3(0.06, 0.18, 0.2), "z": -11.0},
	]
	for fc in fog_configs:
		var fog_quad = MeshInstance3D.new()
		fog_quad.mesh = QuadMesh.new()
		fog_quad.mesh.size = Vector2(12, 5)
		var fog_mat = ShaderMaterial.new()
		fog_mat.shader = fog_shader
		fog_mat.set_shader_parameter("fog_color", fc["color"])
		fog_mat.set_shader_parameter("fog_alpha", 0.25)
		fog_mat.set_shader_parameter("cursor_clear_radius", 3.0)
		fog_mat.set_shader_parameter("noise_scale", 2.5)
		fog_quad.mesh.material = fog_mat
		fog_quad.position = Vector3(0, -0.7, fc["z"])
		fog_quad.rotation_degrees.x = -90
		objects_container.add_child(fog_quad)

	# Rain — heavier 800-drop emitter with wind angle
	var rain = GPUParticles3D.new()
	rain.amount = 800
	var rain_mat = ParticleProcessMaterial.new()
	rain_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	rain_mat.emission_box_extents = Vector3(20, 0, 20)
	rain_mat.gravity = Vector3(0.5, -14, 0)
	rain_mat.initial_velocity_min = 10.0
	rain_mat.initial_velocity_max = 14.0
	rain_mat.direction = Vector3(0.05, -1, 0)
	rain_mat.scale_min = 0.01
	rain_mat.scale_max = 0.025
	rain.lifetime = 1.8
	rain.position.y = 10
	rain.process_material = rain_mat
	var rain_mesh = CylinderMesh.new()
	rain_mesh.top_radius = 0.005
	rain_mesh.bottom_radius = 0.005
	rain_mesh.height = 0.45
	rain_mesh.material = make_translucent_mat("#99aadd", 0.5)
	rain.draw_pass_1 = rain_mesh
	objects_container.add_child(rain)

	# Steam vents — 3 small upward particle emitters at ground level
	for sv in range(3):
		var steam = GPUParticles3D.new()
		steam.amount = 30
		var steam_mat = ParticleProcessMaterial.new()
		steam_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
		steam_mat.gravity = Vector3(0, 0.3, 0)
		steam_mat.initial_velocity_min = 0.3
		steam_mat.initial_velocity_max = 0.8
		steam_mat.direction = Vector3(0, 1, 0)
		steam_mat.spread = 15.0
		steam_mat.scale_min = 0.03
		steam_mat.scale_max = 0.08
		steam.lifetime = 3.0
		steam.process_material = steam_mat
		var steam_mesh = SphereMesh.new()
		steam_mesh.radius = 0.06
		steam_mesh.height = 0.12
		steam_mesh.material = make_translucent_mat("#8888aa", 0.3)
		steam.draw_pass_1 = steam_mesh
		steam.position = Vector3(randf_range(-2, 2), -0.9, -6 + sv * 5.0)
		objects_container.add_child(steam)

	# Sidewalk debris — scattered paper/trash via MultiMesh (1 draw call)
	var debris = _create_street_debris_multimesh(60)
	objects_container.add_child(debris)

	# Flying vehicles — drifting overhead
	for vi in range(4):
		var vehicle = Node3D.new()
		var v_y = randf_range(4.0, 8.0)
		vehicle.position = Vector3(randf_range(-15, 15), v_y, randf_range(-8, 3))
		# Body
		var v_body = MeshInstance3D.new()
		v_body.mesh = BoxMesh.new()
		v_body.mesh.size = Vector3(0.3, 0.1, 0.6)
		var v_body_mat = StandardMaterial3D.new()
		v_body_mat.albedo_color = Color(0.12, 0.12, 0.18)
		v_body_mat.metallic = 0.6
		v_body_mat.roughness = 0.3
		v_body.mesh.material = v_body_mat
		vehicle.add_child(v_body)
		# Canopy — translucent top
		var v_canopy = MeshInstance3D.new()
		v_canopy.mesh = BoxMesh.new()
		v_canopy.mesh.size = Vector3(0.2, 0.06, 0.25)
		v_canopy.mesh.material = make_translucent_mat("#6688cc", 0.4)
		v_canopy.position = Vector3(0, 0.08, -0.05)
		vehicle.add_child(v_canopy)
		# Thruster glow — rear
		var v_thruster = MeshInstance3D.new()
		v_thruster.mesh = BoxMesh.new()
		v_thruster.mesh.size = Vector3(0.15, 0.04, 0.05)
		var thruster_colors = ["#00ffaa", "#ff6600", "#4488ff", "#ff0066"]
		v_thruster.mesh.material = make_emissive_mat(thruster_colors[vi], 6.0)
		v_thruster.position = Vector3(0, -0.02, 0.33)
		vehicle.add_child(v_thruster)
		# Headlight — front
		var v_headlight = MeshInstance3D.new()
		v_headlight.mesh = BoxMesh.new()
		v_headlight.mesh.size = Vector3(0.1, 0.03, 0.03)
		v_headlight.mesh.material = make_emissive_mat("#ffffff", 4.0)
		v_headlight.position = Vector3(0, -0.01, -0.32)
		vehicle.add_child(v_headlight)
		# Metadata for animation
		vehicle.set_meta("speed", randf_range(1.5, 4.0))
		vehicle.set_meta("dir", 1.0 if randf() > 0.5 else -1.0)
		vehicle.set_meta("base_y", v_y)
		objects_container.add_child(vehicle)
		neon_city_vehicles.append(vehicle)

	spawned_items.append({"type": "scene", "name": "neon_city"})

	# Camera — elevated enough to see vehicles overhead + street below
	camera_mode = "orbit"
	camera_orbit_radius = 7.5
	camera_orbit_height = 5.0
	camera_orbit_speed = 0.03

func create_neon_building(pos: Vector3, w: float, h: float, d: float, neon_color: String):
	var building = Node3D.new()
	building.position = pos

	# Main body — varied concrete tones
	var concrete_tones = [
		Color(0.22, 0.20, 0.28),
		Color(0.18, 0.17, 0.24),
		Color(0.25, 0.22, 0.26),
		Color(0.20, 0.20, 0.22),
	]
	var body = MeshInstance3D.new()
	body.mesh = BoxMesh.new()
	body.mesh.size = Vector3(w, h, d)
	var body_mat = StandardMaterial3D.new()
	body_mat.albedo_color = concrete_tones[randi() % concrete_tones.size()]
	body_mat.metallic = 0.15
	body_mat.roughness = 0.75
	body.mesh.material = body_mat
	body.position.y = h / 2
	building.add_child(body)

	# Horizontal neon trim strips along edges
	for edge_y in [h * 0.3, h * 0.6, h * 0.9]:
		var strip = MeshInstance3D.new()
		strip.mesh = BoxMesh.new()
		strip.mesh.size = Vector3(w + 0.05, 0.05, d + 0.05)
		strip.mesh.material = make_emissive_mat(neon_color, 5.0)
		strip.position.y = edge_y
		building.add_child(strip)

	# Vertical neon edge strips — 1-2 on building corners
	var vert_count = 1 + randi() % 2
	var corners = [
		Vector3(-w / 2 - 0.02, h / 2, d / 2),
		Vector3(w / 2 + 0.02, h / 2, -d / 2),
		Vector3(-w / 2 - 0.02, h / 2, -d / 2),
		Vector3(w / 2 + 0.02, h / 2, d / 2),
	]
	corners.shuffle()
	for vi in range(vert_count):
		var vstrip = MeshInstance3D.new()
		vstrip.mesh = BoxMesh.new()
		vstrip.mesh.size = Vector3(0.04, h, 0.04)
		vstrip.mesh.material = make_emissive_mat(neon_color, 4.0)
		vstrip.position = corners[vi]
		building.add_child(vstrip)

	# Windows — emissive quads on all four faces
	var win_colors = ["#ffcc66", "#eeddaa", "#aabbcc", "#88ccff"]
	var rows = int(h / 0.6)
	var cols_fb = int(w / 0.5)
	var cols_lr = int(d / 0.5)
	for row in range(rows):
		# Front/back windows
		for col in range(cols_fb):
			if randf() > 0.8:
				continue
			var wc = win_colors[randi() % win_colors.size()]
			var wx = -w / 2 + 0.3 + col * 0.5
			var wy = 0.4 + row * 0.6
			# Front face
			var win = MeshInstance3D.new()
			win.mesh = QuadMesh.new()
			win.mesh.size = Vector2(0.2, 0.3)
			win.mesh.material = make_emissive_mat(wc, 3.0)
			win.position = Vector3(wx, wy, d / 2 + 0.01)
			building.add_child(win)
			# Back face
			if randf() > 0.4:
				var win_b = MeshInstance3D.new()
				win_b.mesh = QuadMesh.new()
				win_b.mesh.size = Vector2(0.2, 0.3)
				win_b.mesh.material = make_emissive_mat(wc, 3.0)
				win_b.position = Vector3(wx, wy, -d / 2 - 0.01)
				building.add_child(win_b)
		# Left/right side windows
		for col in range(cols_lr):
			if randf() > 0.75:
				continue
			var wc = win_colors[randi() % win_colors.size()]
			var wz = -d / 2 + 0.3 + col * 0.5
			var wy = 0.4 + row * 0.6
			# Left face
			var win_l = MeshInstance3D.new()
			win_l.mesh = QuadMesh.new()
			win_l.mesh.size = Vector2(0.2, 0.3)
			win_l.mesh.material = make_emissive_mat(wc, 3.0)
			win_l.position = Vector3(-w / 2 - 0.01, wy, wz)
			win_l.rotation_degrees.y = 90
			building.add_child(win_l)
			# Right face
			if randf() > 0.4:
				var win_r = MeshInstance3D.new()
				win_r.mesh = QuadMesh.new()
				win_r.mesh.size = Vector2(0.2, 0.3)
				win_r.mesh.material = make_emissive_mat(wc, 3.0)
				win_r.position = Vector3(w / 2 + 0.01, wy, wz)
				win_r.rotation_degrees.y = -90
				building.add_child(win_r)

	# Ground-floor shopfronts (30% of buildings) — warm glow + awning
	if randf() < 0.3:
		var shop_colors = ["#ffaa44", "#ff8833", "#ffcc55"]
		var shop_color = shop_colors[randi() % shop_colors.size()]
		# Emissive storefront panel
		var shop = MeshInstance3D.new()
		shop.mesh = QuadMesh.new()
		shop.mesh.size = Vector2(w * 0.8, 0.6)
		shop.mesh.material = make_emissive_mat(shop_color, 4.0)
		shop.position = Vector3(0, 0.35, d / 2 + 0.02)
		building.add_child(shop)
		# Awning above storefront
		var awning = MeshInstance3D.new()
		awning.mesh = BoxMesh.new()
		awning.mesh.size = Vector3(w * 0.9, 0.03, 0.4)
		var awning_mat = StandardMaterial3D.new()
		awning_mat.albedo_color = Color(0.3, 0.12, 0.1)
		awning_mat.roughness = 0.8
		awning.mesh.material = awning_mat
		awning.position = Vector3(0, 0.7, d / 2 + 0.2)
		building.add_child(awning)
		# OmniLight at street level
		var shop_light = OmniLight3D.new()
		shop_light.light_color = Color.html(shop_color)
		shop_light.light_energy = 1.5
		shop_light.omni_range = 3.0
		shop_light.omni_attenuation = 1.8
		shop_light.position = Vector3(0, 0.3, d / 2 + 0.5)
		building.add_child(shop_light)

	# Balcony ledges (40% of buildings) — protruding shelves between floors
	if randf() < 0.4:
		var balcony_rows = int(h / 1.2)
		for br in range(min(balcony_rows, 4)):
			var ledge = MeshInstance3D.new()
			ledge.mesh = BoxMesh.new()
			ledge.mesh.size = Vector3(w * 0.6, 0.06, 0.25)
			var ledge_mat = StandardMaterial3D.new()
			ledge_mat.albedo_color = Color(0.2, 0.2, 0.25)
			ledge_mat.metallic = 0.2
			ledge_mat.roughness = 0.7
			ledge.mesh.material = ledge_mat
			var ledge_face = d / 2 + 0.12 if randf() > 0.5 else -(d / 2 + 0.12)
			ledge.position = Vector3(0, 0.8 + br * 1.2, ledge_face)
			building.add_child(ledge)

	# Fire escape ladders (40% of tall buildings)
	if h > 3.0 and randf() < 0.4:
		var fe_face_z = d / 2 + 0.05 if randf() > 0.5 else -(d / 2 + 0.05)
		var fe_x = randf_range(-w / 4, w / 4)
		var fe_mat = StandardMaterial3D.new()
		fe_mat.albedo_color = Color(0.15, 0.15, 0.18)
		fe_mat.metallic = 0.6
		fe_mat.roughness = 0.5
		# Vertical rails
		for rail_off in [-0.12, 0.12]:
			var rail = MeshInstance3D.new()
			rail.mesh = CylinderMesh.new()
			rail.mesh.top_radius = 0.012
			rail.mesh.bottom_radius = 0.012
			rail.mesh.height = min(h, 6.0)
			rail.mesh.material = fe_mat
			rail.position = Vector3(fe_x + rail_off, min(h, 6.0) / 2.0, fe_face_z)
			building.add_child(rail)
		# Rungs
		var rung_count = min(int(h / 0.5), 12)
		for ri in range(rung_count):
			var rung = MeshInstance3D.new()
			rung.mesh = CylinderMesh.new()
			rung.mesh.top_radius = 0.008
			rung.mesh.bottom_radius = 0.008
			rung.mesh.height = 0.24
			rung.mesh.material = fe_mat
			rung.position = Vector3(fe_x, 0.4 + ri * 0.5, fe_face_z)
			rung.rotation_degrees.z = 90
			building.add_child(rung)
			# Landing platform every 3rd rung
			if ri > 0 and ri % 3 == 0:
				var landing = MeshInstance3D.new()
				landing.mesh = BoxMesh.new()
				landing.mesh.size = Vector3(0.35, 0.02, 0.2)
				landing.mesh.material = fe_mat
				landing.position = Vector3(fe_x, 0.4 + ri * 0.5, fe_face_z)
				building.add_child(landing)

	# Roof detail — 4 types: antenna, AC unit, satellite dish, water tank
	var roof_type = randi() % 4
	var roof_x = randf_range(-w / 3, w / 3)
	var roof_z = randf_range(-d / 3, d / 3)
	if roof_type == 0:
		# Antenna with blinking light
		var antenna = MeshInstance3D.new()
		antenna.mesh = CylinderMesh.new()
		antenna.mesh.top_radius = 0.01
		antenna.mesh.bottom_radius = 0.02
		antenna.mesh.height = 0.8
		var ant_mat = StandardMaterial3D.new()
		ant_mat.albedo_color = Color(0.2, 0.2, 0.25)
		ant_mat.metallic = 0.6
		antenna.mesh.material = ant_mat
		antenna.position = Vector3(roof_x, h + 0.4, roof_z)
		building.add_child(antenna)
		var blink = MeshInstance3D.new()
		blink.mesh = SphereMesh.new()
		blink.mesh.radius = 0.03
		blink.mesh.height = 0.06
		blink.mesh.material = make_emissive_mat("#ff0000", 6.0)
		blink.position = Vector3(roof_x, h + 0.85, roof_z)
		blink.set_meta("blink_rate", randf_range(2.0, 5.0))
		building.add_child(blink)
	elif roof_type == 1:
		# AC unit
		var ac = MeshInstance3D.new()
		ac.mesh = BoxMesh.new()
		ac.mesh.size = Vector3(0.4, 0.25, 0.3)
		var ac_mat = StandardMaterial3D.new()
		ac_mat.albedo_color = Color(0.18, 0.18, 0.2)
		ac_mat.metallic = 0.4
		ac_mat.roughness = 0.6
		ac.mesh.material = ac_mat
		ac.position = Vector3(roof_x, h + 0.12, roof_z)
		building.add_child(ac)
	elif roof_type == 2:
		# Satellite dish
		var dish_base = MeshInstance3D.new()
		dish_base.mesh = CylinderMesh.new()
		dish_base.mesh.top_radius = 0.03
		dish_base.mesh.bottom_radius = 0.04
		dish_base.mesh.height = 0.3
		var dish_base_mat = StandardMaterial3D.new()
		dish_base_mat.albedo_color = Color(0.2, 0.2, 0.25)
		dish_base_mat.metallic = 0.5
		dish_base.mesh.material = dish_base_mat
		dish_base.position = Vector3(roof_x, h + 0.15, roof_z)
		building.add_child(dish_base)
		var dish = MeshInstance3D.new()
		dish.mesh = SphereMesh.new()
		dish.mesh.radius = 0.2
		dish.mesh.height = 0.1
		var dish_mat = StandardMaterial3D.new()
		dish_mat.albedo_color = Color(0.25, 0.25, 0.3)
		dish_mat.metallic = 0.7
		dish_mat.roughness = 0.3
		dish.mesh.material = dish_mat
		dish.position = Vector3(roof_x, h + 0.35, roof_z)
		dish.rotation_degrees.x = 30
		building.add_child(dish)
	else:
		# Water tank
		var tank = MeshInstance3D.new()
		tank.mesh = CylinderMesh.new()
		tank.mesh.top_radius = 0.2
		tank.mesh.bottom_radius = 0.2
		tank.mesh.height = 0.4
		var tank_mat = StandardMaterial3D.new()
		tank_mat.albedo_color = Color(0.16, 0.16, 0.2)
		tank_mat.metallic = 0.3
		tank_mat.roughness = 0.7
		tank.mesh.material = tank_mat
		tank.position = Vector3(roof_x, h + 0.2, roof_z)
		building.add_child(tank)
		# Pipes extending from tank toward building edge
		var pipe_mat = StandardMaterial3D.new()
		pipe_mat.albedo_color = Color(0.14, 0.14, 0.18)
		pipe_mat.metallic = 0.5
		pipe_mat.roughness = 0.5
		# Pipe along X axis
		var pipe_x = MeshInstance3D.new()
		pipe_x.mesh = CylinderMesh.new()
		pipe_x.mesh.top_radius = 0.025
		pipe_x.mesh.bottom_radius = 0.025
		pipe_x.mesh.height = w / 3.0
		pipe_x.mesh.material = pipe_mat
		pipe_x.position = Vector3(roof_x + w / 6.0, h + 0.1, roof_z)
		pipe_x.rotation_degrees.z = 90
		building.add_child(pipe_x)
		# Pipe along Z axis
		var pipe_z = MeshInstance3D.new()
		pipe_z.mesh = CylinderMesh.new()
		pipe_z.mesh.top_radius = 0.025
		pipe_z.mesh.bottom_radius = 0.025
		pipe_z.mesh.height = d / 3.0
		pipe_z.mesh.material = pipe_mat
		pipe_z.position = Vector3(roof_x, h + 0.1, roof_z + d / 6.0)
		pipe_z.rotation_degrees.x = 90
		building.add_child(pipe_z)

	objects_container.add_child(building)

# ── Volcanic Scene ──────────────────────────────────────────────────────────

func apply_volcanic_environment():
	var env = $WorldEnvironment.environment as Environment
	var sky_mat = env.sky.sky_material as ProceduralSkyMaterial
	sky_mat.sky_top_color = Color(0.05, 0.02, 0.02)
	sky_mat.sky_horizon_color = Color(0.35, 0.10, 0.03)
	sky_mat.ground_bottom_color = Color(0.08, 0.04, 0.02)
	sky_mat.ground_horizon_color = Color(0.25, 0.08, 0.03)
	sky_mat.sky_energy_multiplier = 2.0
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.03
	env.volumetric_fog_albedo = Color(0.10, 0.04, 0.02)
	env.volumetric_fog_emission = Color(0.08, 0.03, 0.01)
	env.volumetric_fog_emission_energy = 1.0
	env.glow_intensity = 2.0
	env.glow_bloom = 0.4
	env.glow_hdr_threshold = 0.5
	env.sdfgi_enabled = true
	env.ssr_enabled = true
	env.ambient_light_energy = 0.8
	$MoonLight.light_color = Color(0.6, 0.3, 0.15)
	$MoonLight.light_energy = 0.6

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

	# Lava rivers — emissive orange strips with point lights
	for i in range(7):
		var lava = MeshInstance3D.new()
		lava.mesh = PlaneMesh.new()
		var lava_w = randf_range(0.8, 2.0)
		var lava_l = randf_range(8, 20)
		lava.mesh.size = Vector2(lava_w, lava_l)
		lava.mesh.material = make_emissive_mat("#ff4400", 8.0)
		var lava_x = randf_range(-10, 10)
		var lava_z = randf_range(-8, 8)
		lava.position = Vector3(lava_x, -0.95, lava_z)
		lava.rotation_degrees.y = randf_range(-30, 30)
		objects_container.add_child(lava)
		# Lava glow — lights up surroundings orange
		var ll = OmniLight3D.new()
		ll.light_color = Color.html("#ff4400")
		ll.light_energy = 3.0
		ll.omni_range = 6.0
		ll.omni_attenuation = 1.5
		ll.position = Vector3(lava_x, 0.5, lava_z)
		objects_container.add_child(ll)

	# Obsidian spires — dark metallic jagged columns
	for i in range(20):
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

	# Volcanic vents — glowing cones with lights
	for i in range(5):
		var vent = MeshInstance3D.new()
		var cone = CylinderMesh.new()
		cone.top_radius = 0.3
		cone.bottom_radius = 0.8
		cone.height = 1.0
		vent.mesh = cone
		vent.mesh.material = make_emissive_mat("#ff6600", 4.0)
		var vx = randf_range(-8, 8)
		var vz = randf_range(-8, 5)
		vent.position = Vector3(vx, -0.5, vz)
		objects_container.add_child(vent)
		# Vent glow
		var vl = OmniLight3D.new()
		vl.light_color = Color.html("#ff6600")
		vl.light_energy = 4.0
		vl.omni_range = 5.0
		vl.omni_attenuation = 1.3
		vl.position = Vector3(vx, 0.5, vz)
		objects_container.add_child(vl)

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

	# Lantern warm glow — illuminates surrounding stones and water
	var lantern_light = OmniLight3D.new()
	lantern_light.light_color = Color.html("#ffcc66")
	lantern_light.light_energy = 2.5
	lantern_light.omni_range = 6.0
	lantern_light.omni_attenuation = 1.5
	lantern_light.position = lantern_base + Vector3(0, 0.6, 0)
	objects_container.add_child(lantern_light)

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

	# Fireflies for evening atmosphere
	create_particles("fireflies", {})

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
		if objects_container.get_child_count() == 0:
			break
		var now = Time.get_ticks_msec() / 1000.0 - start_time
		while grow_queue.size() > 0 and grow_queue[0]["time"] <= now:
			var item = grow_queue.pop_front()
			if not is_instance_valid(item["node"]):
				continue
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
	env.ambient_light_energy = 0.6
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
	env.volumetric_fog_density = 0.03
	env.volumetric_fog_albedo = Color(0.08, 0.15, 0.06)
	env.volumetric_fog_emission = Color(0.02, 0.06, 0.02)
	env.volumetric_fog_emission_energy = 0.5
	env.fog_enabled = true
	env.fog_density = 0.012
	env.fog_light_color = Color(0.06, 0.1, 0.05)
	# Glow for candles/pumpkins
	env.glow_enabled = true
	env.glow_intensity = 1.8
	env.glow_bloom = 0.4
	env.glow_strength = 1.3
	env.glow_hdr_threshold = 0.5
	# Cold moonlight — bright enough to see gravestones
	$MoonLight.light_color = Color(0.55, 0.6, 0.85)
	$MoonLight.light_energy = 0.7
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

	# Graveyard mist — low-hanging fog particles
	var mist = GPUParticles3D.new()
	mist.amount = 100
	var mist_mat = ParticleProcessMaterial.new()
	mist_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	mist_mat.emission_box_extents = Vector3(10, 0.3, 10)
	mist_mat.gravity = Vector3(0, 0, 0)
	mist_mat.initial_velocity_min = 0.1
	mist_mat.initial_velocity_max = 0.3
	mist_mat.scale_min = 0.3
	mist_mat.scale_max = 0.8
	mist.lifetime = 15.0
	mist.position.y = -0.3
	var mist_mesh = SphereMesh.new()
	mist_mesh.radius = 0.5
	mist_mesh.height = 0.2
	mist_mesh.material = make_translucent_mat("#8899aa", 0.08)
	mist.draw_pass_1 = mist_mesh
	mist.process_material = mist_mat
	objects_container.add_child(mist)

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
	env.ambient_light_energy = 0.5
	env.ambient_light_color = Color(0.1, 0.2, 0.25)
	env.sdfgi_enabled = true
	env.sdfgi_use_occlusion = true
	env.sdfgi_energy = 0.6
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
	# Starlight — bright enough to see outpost structures
	$MoonLight.light_color = Color(0.7, 0.75, 0.85)
	$MoonLight.light_energy = 0.6
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
	env.ambient_light_energy = 0.6
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
	# Broken light shafts
	$MoonLight.light_color = Color(0.5, 0.65, 0.55)
	$MoonLight.light_energy = 0.6
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

	# Spore particles — bioluminescent spores drifting through overgrown corridors
	var spores = GPUParticles3D.new()
	spores.amount = 80
	var spore_mat = ParticleProcessMaterial.new()
	spore_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	spore_mat.emission_box_extents = Vector3(8, 3, 8)
	spore_mat.gravity = Vector3(0, 0.08, 0)
	spore_mat.initial_velocity_min = 0.05
	spore_mat.initial_velocity_max = 0.2
	spore_mat.scale_min = 0.01
	spore_mat.scale_max = 0.03
	spores.lifetime = 10.0
	var spore_mesh = SphereMesh.new()
	spore_mesh.radius = 0.015
	spore_mesh.height = 0.03
	spore_mesh.material = make_emissive_mat("#66ffaa", 5.0)
	spores.draw_pass_1 = spore_mesh
	spores.process_material = spore_mat
	objects_container.add_child(spores)

	spawned_items.append({"type": "scene", "name": "abandoned_station"})

# ── Helper: reactive grass multimesh ──
func _create_street_debris_multimesh(count: int) -> MultiMeshInstance3D:
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.instance_count = count
	var piece = PlaneMesh.new()
	piece.size = Vector2(0.08, 0.08)
	var debris_mat = StandardMaterial3D.new()
	debris_mat.albedo_color = Color(0.2, 0.18, 0.15)
	debris_mat.roughness = 0.9
	debris_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	piece.material = debris_mat
	mm.mesh = piece
	for i in count:
		var xform = Transform3D()
		xform = xform.rotated(Vector3.UP, randf() * TAU)
		var s = randf_range(0.5, 1.5)
		xform = xform.scaled(Vector3(s, s, s))
		# Place on sidewalks (|x| > 3.2)
		var dx = randf_range(3.3, 6.0) * (1.0 if randf() > 0.5 else -1.0)
		var dz = randf_range(-12.0, 6.0)
		xform.origin = Vector3(dx, -0.97, dz)
		mm.set_instance_transform(i, xform)
	var mmi = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mmi

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
		@warning_ignore("redundant_await")
		await handle_command({"type": scene_name, "params": {}})
		current_scene_name = scene_name
	)
	tw.tween_method(_set_fade_alpha, 1.0, 0.0, 0.5)
	tw.tween_callback(func(): is_transitioning = false)

func _set_fade_alpha(alpha: float):
	if fade_quad:
		var mat = fade_quad.material_override as StandardMaterial3D
		if mat:
			mat.albedo_color.a = alpha

# ── Moon phase helper ──
func _get_moon_phase() -> float:
	# Synodic month calculation — returns 0.0 (new moon) to 1.0 (full) and back
	var dt = Time.get_datetime_dict_from_system()
	# Days since known new moon (Jan 6 2000 18:14 UTC)
	var y = dt["year"]
	var m = dt["month"]
	var d = dt["day"]
	# Julian day approximation
	var jd = 367 * y - int(7 * (y + int((m + 9) / 12)) / 4) + int(275 * m / 9) + d + 1721013.5
	var days_since = jd - 2451550.1  # Known new moon epoch
	var phase = fmod(days_since, 29.530588853) / 29.530588853  # 0-1 through full cycle
	# Convert to 0 (new) → 1 (full) → 0 (new): use sine-like mapping
	return 0.5 - 0.5 * cos(phase * TAU)

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

func _get_season() -> String:
	var month = Time.get_datetime_dict_from_system()["month"]
	if month >= 3 and month <= 5:
		return "spring"
	elif month >= 6 and month <= 8:
		return "summer"
	elif month >= 9 and month <= 11:
		return "autumn"
	else:
		return "winter"

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
	# SAFETY: destroy+recreate pattern avoids bug #54478 (VRAM leak on process_material reassignment).
	# Do NOT reuse GPUParticles3D by reassigning process_material — always queue_free() and create new.
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

# ── Commit burst effect ──
func _spawn_commit_burst():
	# Celebratory explosion at scene center
	var burst = GPUParticles3D.new()
	burst.amount = 100
	burst.one_shot = true
	burst.emitting = true
	burst.lifetime = 2.5
	burst.explosiveness = 0.9
	var pmat = ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pmat.emission_sphere_radius = 0.5
	pmat.gravity = Vector3(0, -2, 0)
	pmat.initial_velocity_min = 2.0
	pmat.initial_velocity_max = 5.0
	pmat.spread = 180.0
	pmat.scale_min = 0.008
	pmat.scale_max = 0.03
	pmat.color = Color(0.2, 1.0, 0.6)  # green = success
	var color_ramp = Gradient.new()
	color_ramp.set_color(0, Color(0.2, 1.0, 0.6))
	color_ramp.set_color(1, Color(1.0, 0.8, 0.2, 0.0))
	var curve = GradientTexture1D.new()
	curve.gradient = color_ramp
	pmat.color_ramp = curve
	burst.process_material = pmat
	var mesh = SphereMesh.new()
	mesh.radius = 0.02
	mesh.height = 0.04
	var mat = StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission = Color(0.3, 1.0, 0.7)
	mat.emission_energy_multiplier = 5.0
	mat.albedo_color = Color(0.1, 0.5, 0.3)
	mesh.material = mat
	burst.draw_pass_1 = mesh
	burst.position = Vector3(0, 1, 0)
	objects_container.add_child(burst)
	# Also flash notification
	notify_flash = 0.8
	# Auto-free
	var timer = get_tree().create_timer(3.5)
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
	var color_hex = params.get("color", "#00cc80")
	var holo_color = Color.html(color_hex)
	var scanlines = float(params.get("scanlines", 60.0))
	var alpha = float(params.get("alpha", 0.4))
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
		holo_mat.set_shader_parameter("holo_color", holo_color)
		holo_mat.set_shader_parameter("scanline_density", scanlines)
		holo_mat.set_shader_parameter("base_alpha", alpha)
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
	# Label color matches hologram tint
	var label_color = Color(holo_color.r * 1.2, holo_color.g * 1.2, holo_color.b * 1.2, 0.9)
	for key in labels:
		var label = Label3D.new()
		label.name = "PerfLabel_" + key
		label.text = labels[key]["text"]
		label.position = labels[key]["pos"]
		label.font_size = 24
		label.modulate = label_color
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
	var rate = ATTACK_DEFAULT if target > current else DECAY_DEFAULT
	return lerp(current, target, 1.0 - exp(-rate * delta * 60.0))

# ── Helper: per-band smoothing with tuned rates ──
func _smooth_band(band_name: String, current: float, target: float, delta: float) -> float:
	var attack = _band_attack.get(band_name, ATTACK_DEFAULT)
	var decay = _band_decay.get(band_name, DECAY_DEFAULT)
	var rate = attack if target > current else decay
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

# ══════════════════════════════════════════════════════════════════════════════
# ART SCENES — Shader-based, procedural geometry, interactive
# ══════════════════════════════════════════════════════════════════════════════

# ── Dark environment for shader/art scenes ───────────────────────────────────

func apply_dark_environment():
	# Restore perspective projection (shader scenes may have set orthographic)
	$Camera3D.projection = Camera3D.PROJECTION_PERSPECTIVE
	var env = $WorldEnvironment.environment as Environment
	var sky_mat = env.sky.sky_material as ProceduralSkyMaterial
	sky_mat.sky_top_color = Color(0.01, 0.005, 0.02)
	sky_mat.sky_horizon_color = Color(0.02, 0.01, 0.03)
	sky_mat.ground_horizon_color = Color(0.01, 0.005, 0.015)
	sky_mat.ground_bottom_color = Color(0.005, 0.002, 0.01)
	sky_mat.sky_energy_multiplier = 0.1
	env.ambient_light_color = Color(0.02, 0.01, 0.03)
	env.ambient_light_energy = 0.1
	$MoonLight.light_energy = 0.1
	env.glow_enabled = true
	env.glow_intensity = 1.5
	env.glow_strength = 1.0
	env.glow_bloom = 0.3
	bloom_base_intensity = 1.5
	bloom_base_strength = 1.0
	bloom_base_bloom = 0.3
	env.volumetric_fog_enabled = false
	env.fog_enabled = false

# ── Full-screen shader scene (fractal, aurora, matrix, mycelium) ─────────────

func create_shader_scene(shader_path: String, params: Dictionary):
	for child in objects_container.get_children():
		child.queue_free()
	spawned_items.clear()
	_clear_postfx()

	var shader = load(shader_path)
	if not shader:
		push_error("Failed to load shader: " + shader_path)
		return

	# Create a large quad facing the camera
	var quad = MeshInstance3D.new()
	var qm = QuadMesh.new()
	qm.size = Vector2(20, -11.25)  # 16:9 aspect, negative flips UV.y
	quad.mesh = qm

	var mat = ShaderMaterial.new()
	mat.shader = shader

	# Load sprite sheet at runtime (not imported by Godot, so use Image.load_from_file)
	var sprite_path = ProjectSettings.globalize_path("res://sprites/rpg_16x16.png")
	var sprite_img = Image.load_from_file(sprite_path)
	if sprite_img:
		var sprite_tex = ImageTexture.create_from_image(sprite_img)
		mat.set_shader_parameter("sprite_sheet", sprite_tex)
		mat.set_shader_parameter("sheet_size", Vector2(float(sprite_img.get_width()), float(sprite_img.get_height())))
		mat.set_shader_parameter("tile_size", Vector2(16.0, 16.0))
		print("Sprite sheet loaded: ", sprite_img.get_width(), "x", sprite_img.get_height(), " format=", sprite_img.get_format())
	else:
		push_warning("Could not load sprite sheet from: " + sprite_path)

	quad.material_override = mat
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	quad.position = Vector3(0, 2.5, 0)

	objects_container.add_child(quad)
	spawned_items.append({"type": "scene", "name": shader_path.get_file().get_basename()})
	show_museum_info(shader_path.get_file().get_basename())

	# Lock camera to face the quad — orthographic eliminates perspective tilt
	camera_mode = "static"
	$Camera3D.projection = Camera3D.PROJECTION_ORTHOGONAL
	$Camera3D.size = 11.25  # match quad height
	$Camera3D.position = Vector3(0, 2.5, 8)
	$Camera3D.look_at(Vector3(0, 2.5, 0))

# ── Strange Attractor (Lorenz system) ────────────────────────────────────────

func create_attractor_scene(params: Dictionary):
	for child in objects_container.get_children():
		child.queue_free()
	spawned_items.clear()

	var attractor_type = params.get("type", "lorenz")
	var point_count = int(params.get("points", 50000))
	var color = Color.html(params.get("color", "#00ffaa"))

	# Compute attractor points
	var points: PackedVector3Array = PackedVector3Array()
	var x = 0.1
	var y = 0.0
	var z = 0.0
	var dt = 0.005

	for i in point_count:
		var dx: float
		var dy: float
		var dz: float
		if attractor_type == "rossler":
			dx = -(y + z)
			dy = x + 0.2 * y
			dz = 0.2 + z * (x - 5.7)
		else:  # lorenz
			dx = 10.0 * (y - x)
			dy = x * (28.0 - z) - y
			dz = x * y - (8.0 / 3.0) * z
		x += dx * dt
		y += dy * dt
		z += dz * dt
		points.append(Vector3(x * 0.1, z * 0.1 - 1.5, y * 0.1))

	# Draw with MultiMesh spheres
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	var sphere_count = mini(point_count, 30000)
	mm.instance_count = sphere_count

	var sphere = SphereMesh.new()
	sphere.radius = 0.015
	sphere.height = 0.03
	sphere.radial_segments = 4
	sphere.rings = 2
	var mat = StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sphere.material = mat
	mm.mesh = sphere

	var step_size = maxi(1, points.size() / sphere_count)
	for i in sphere_count:
		var idx = mini(i * step_size, points.size() - 1)
		var xform = Transform3D()
		xform.origin = points[idx]
		mm.set_instance_transform(i, xform)
		# Color gradient along the path
		var t = float(i) / float(sphere_count)
		var c = color.lerp(Color(1, 0.3, 0.9), t * 0.6)
		c = c.lerp(Color(0.3, 0.6, 1.0), sin(t * TAU * 3.0) * 0.3 + 0.3)
		mm.set_instance_color(i, c)

	var mmi = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	objects_container.add_child(mmi)
	spawned_items.append({"type": "scene", "name": "attractor"})

	# Slow rotation
	camera_mode = "orbit"
	camera_orbit_speed = 0.03
	camera_orbit_radius = 6.0
	camera_orbit_height = 2.0

# ── Galaxy Scene ─────────────────────────────────────────────────────────────

func create_galaxy_scene(params: Dictionary):
	for child in objects_container.get_children():
		child.queue_free()
	spawned_items.clear()

	var arm_count = int(params.get("arms", 4))
	var star_count = int(params.get("stars", 20000))
	var color = Color.html(params.get("color", "#8888ff"))

	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.instance_count = star_count

	var star_mesh = SphereMesh.new()
	star_mesh.radius = 0.02
	star_mesh.height = 0.04
	star_mesh.radial_segments = 4
	star_mesh.rings = 2
	var mat = StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 3.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	star_mesh.material = mat
	mm.mesh = star_mesh

	for i in star_count:
		var t = randf()
		var arm = randi() % arm_count
		var arm_angle = float(arm) / float(arm_count) * TAU

		# Logarithmic spiral
		var r = t * 5.0
		var theta = arm_angle + t * 3.0 + randf_range(-0.3, 0.3)

		# Spread increases with radius
		var spread = t * 0.8
		var px = r * cos(theta) + randf_range(-spread, spread)
		var pz = r * sin(theta) + randf_range(-spread, spread)
		var py = randf_range(-0.1, 0.1) * (1.0 - t * 0.5)

		var xform = Transform3D()
		var s = randf_range(0.5, 1.5)
		xform = xform.scaled(Vector3(s, s, s))
		xform.origin = Vector3(px, py + 3.0, pz)
		mm.set_instance_transform(i, xform)

		var star_color: Color
		if t < 0.2:
			star_color = Color(1.0, 0.9, 0.6)
		else:
			star_color = color.lerp(Color(0.9, 0.9, 1.0), randf() * 0.5)
		star_color.a = 1.0
		mm.set_instance_color(i, star_color)

	var mmi = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	objects_container.add_child(mmi)

	# Central glow
	var core_light = OmniLight3D.new()
	core_light.light_color = Color(1, 0.9, 0.7)
	core_light.light_energy = 3.0
	core_light.omni_range = 4.0
	core_light.position = Vector3(0, 3.0, 0)
	objects_container.add_child(core_light)

	# Dust nebula particles
	var dust = GPUParticles3D.new()
	dust.amount = 500
	dust.lifetime = 8.0
	dust.visibility_aabb = AABB(Vector3(-8, -2, -8), Vector3(16, 6, 16))
	var dust_mat = ParticleProcessMaterial.new()
	dust_mat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	dust_mat.emission_sphere_radius = 6.0
	dust_mat.gravity = Vector3.ZERO
	dust_mat.initial_velocity_min = 0.05
	dust_mat.initial_velocity_max = 0.15
	dust_mat.angular_velocity_min = -10
	dust_mat.angular_velocity_max = 10
	dust_mat.scale_min = 0.3
	dust_mat.scale_max = 1.5
	dust_mat.color = Color(0.4, 0.4, 0.8, 0.15)
	dust.process_material = dust_mat
	var dust_mesh = QuadMesh.new()
	dust_mesh.size = Vector2(0.2, 0.2)
	var dm = StandardMaterial3D.new()
	dm.albedo_color = Color(0.5, 0.5, 0.9, 0.2)
	dm.emission_enabled = true
	dm.emission = Color(0.3, 0.3, 0.8)
	dm.emission_energy_multiplier = 0.5
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	dust_mesh.material = dm
	dust.draw_pass_1 = dust_mesh
	dust.position = Vector3(0, 3, 0)
	objects_container.add_child(dust)

	spawned_items.append({"type": "scene", "name": "galaxy"})
	camera_mode = "orbit"
	camera_orbit_speed = 0.02
	camera_orbit_radius = 8.0
	camera_orbit_height = 5.0

# ── Music Visualizer ─────────────────────────────────────────────────────────

func create_visualizer_scene(params: Dictionary):
	for child in objects_container.get_children():
		child.queue_free()
	spawned_items.clear()

	var bar_count = int(params.get("bars", 64))
	var ring_radius = float(params.get("radius", 3.0))
	var color = Color.html(params.get("color", "#00ffaa"))

	# Ring of bars
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.instance_count = bar_count

	var bar = BoxMesh.new()
	bar.size = Vector3(0.15, 1.0, 0.15)
	var mat = StandardMaterial3D.new()
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.0
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bar.material = mat
	mm.mesh = bar

	for i in bar_count:
		var angle = float(i) / float(bar_count) * TAU
		var xform = Transform3D()
		xform.origin = Vector3(cos(angle) * ring_radius, 2.5, sin(angle) * ring_radius)
		mm.set_instance_transform(i, xform)
		var t = float(i) / float(bar_count)
		mm.set_instance_color(i, color.lerp(Color(1, 0.3, 0.9), t))

	var mmi = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	objects_container.add_child(mmi)

	visualizer_bars = mmi

	# Center light
	var center = OmniLight3D.new()
	center.light_color = color
	center.light_energy = 2.0
	center.omni_range = 5.0
	center.position = Vector3(0, 2.5, 0)
	objects_container.add_child(center)

	# Ground mirror disc
	var disc = MeshInstance3D.new()
	var disc_mesh = CylinderMesh.new()
	disc_mesh.top_radius = ring_radius + 1.0
	disc_mesh.bottom_radius = ring_radius + 1.0
	disc_mesh.height = 0.05
	disc.mesh = disc_mesh
	var disc_mat = StandardMaterial3D.new()
	disc_mat.albedo_color = Color(0.05, 0.05, 0.08)
	disc_mat.metallic = 0.8
	disc_mat.roughness = 0.1
	disc.material_override = disc_mat
	disc.position = Vector3(0, 1.95, 0)
	objects_container.add_child(disc)

	spawned_items.append({"type": "scene", "name": "visualizer"})
	camera_mode = "orbit"
	camera_orbit_speed = 0.04
	camera_orbit_radius = 6.0
	camera_orbit_height = 4.0

# ── L-System Tree Scene ──────────────────────────────────────────────────────

func create_lsystem_scene(params: Dictionary):
	for child in objects_container.get_children():
		child.queue_free()
	spawned_items.clear()

	var tree_count = int(params.get("trees", 5))
	var color = Color.html(params.get("color", "#00cc66"))

	for t_idx in tree_count:
		var tx = randf_range(-4, 4)
		var tz = randf_range(-4, 4)
		var base_pos = Vector3(tx, 0, tz)
		_grow_lsystem_tree(base_pos, color, int(params.get("depth", 5)))

	# Ground
	var ground = MeshInstance3D.new()
	var gm = PlaneMesh.new()
	gm.size = Vector2(12, 12)
	ground.mesh = gm
	var gmat = StandardMaterial3D.new()
	gmat.albedo_color = Color(0.08, 0.15, 0.05)
	gmat.roughness = 0.95
	ground.material_override = gmat
	objects_container.add_child(ground)

	spawned_items.append({"type": "scene", "name": "lsystem"})
	camera_mode = "orbit"
	camera_orbit_radius = 7.0
	camera_orbit_height = 3.5

func _grow_lsystem_tree(pos: Vector3, color: Color, depth: int):
	var segments: Array = []
	_lsystem_branch(pos, Vector3.UP, 1.5, 0.08, depth, segments)

	for seg in segments:
		var cyl = MeshInstance3D.new()
		var cm = CylinderMesh.new()
		var start: Vector3 = seg["start"]
		var end_pt: Vector3 = seg["end"]
		var dir = end_pt - start
		var seg_length = dir.length()
		if seg_length < 0.001:
			continue
		cm.top_radius = seg["radius"] * 0.6
		cm.bottom_radius = seg["radius"]
		cm.height = seg_length
		cm.radial_segments = 6
		cyl.mesh = cm

		var mat = StandardMaterial3D.new()
		var d = int(seg["depth"])
		if d >= 3:
			mat.albedo_color = color.lerp(Color(0.2, 0.8, 0.3), 0.5)
			mat.emission_enabled = true
			mat.emission = color
			mat.emission_energy_multiplier = 0.8
		else:
			mat.albedo_color = Color(0.25, 0.18, 0.1)
			mat.roughness = 0.9
		cyl.material_override = mat

		var mid = (start + end_pt) * 0.5
		cyl.position = mid
		var up = Vector3.UP
		var norm_dir = dir.normalized()
		if abs(norm_dir.dot(up)) < 0.999:
			cyl.look_at(cyl.position + norm_dir)
			cyl.rotate_object_local(Vector3.RIGHT, PI / 2.0)

		cyl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		objects_container.add_child(cyl)

func _lsystem_branch(pos: Vector3, direction: Vector3, seg_length: float, radius: float, depth: int, segments: Array):
	if depth <= 0 or radius < 0.005:
		return

	var end_pos = pos + direction * seg_length
	segments.append({"start": pos, "end": end_pos, "radius": radius, "depth": depth})

	var branch_count = 2 + (randi() % 2)
	for i in branch_count:
		var angle = randf_range(0.3, 0.7)
		var new_dir = direction.rotated(Vector3.RIGHT, angle).rotated(Vector3.UP, randf() * TAU)
		var new_length = seg_length * randf_range(0.6, 0.8)
		var new_radius = radius * randf_range(0.5, 0.7)
		_lsystem_branch(end_pos, new_dir, new_length, new_radius, depth - 1, segments)

# ── Vine Garden ──────────────────────────────────────────────────────────────

func create_vine_garden(params: Dictionary):
	for child in objects_container.get_children():
		child.queue_free()
	spawned_items.clear()

	var vine_count = int(params.get("vines", 12))
	var color = Color.html(params.get("color", "#22aa44"))

	# Pillars for vines to climb
	for i in 6:
		var pillar = MeshInstance3D.new()
		var pm = CylinderMesh.new()
		pm.top_radius = 0.15
		pm.bottom_radius = 0.2
		pm.height = 4.0
		pm.radial_segments = 8
		pillar.mesh = pm
		var pmat = StandardMaterial3D.new()
		pmat.albedo_color = Color(0.35, 0.3, 0.25)
		pmat.roughness = 0.9
		pillar.material_override = pmat
		var angle = float(i) / 6.0 * TAU
		pillar.position = Vector3(cos(angle) * 3.0, 2.0, sin(angle) * 3.0)
		objects_container.add_child(pillar)

	# Ground
	var ground = MeshInstance3D.new()
	var gm = PlaneMesh.new()
	gm.size = Vector2(12, 12)
	ground.mesh = gm
	var gmat = StandardMaterial3D.new()
	gmat.albedo_color = Color(0.06, 0.12, 0.04)
	gmat.roughness = 0.95
	ground.material_override = gmat
	objects_container.add_child(ground)

	# Create vines
	for v in vine_count:
		var start_angle = randf() * TAU
		var start_r = randf_range(2.5, 3.5)
		var start_pos = Vector3(cos(start_angle) * start_r, 0, sin(start_angle) * start_r)
		var vine_color = color.lerp(Color(0.1, 0.6, 0.2), randf() * 0.4)
		_create_vine(start_pos, vine_color, int(randf_range(15, 35)))

	# Flowers at vine tips
	for i in 8:
		var flower = MeshInstance3D.new()
		var fm = SphereMesh.new()
		fm.radius = 0.1
		fm.height = 0.15
		flower.mesh = fm
		var fmat = StandardMaterial3D.new()
		var flower_colors = [Color(1, 0.3, 0.5), Color(0.9, 0.7, 0.2), Color(0.6, 0.3, 1.0), Color(1, 0.5, 0.2)]
		fmat.albedo_color = flower_colors[i % flower_colors.size()]
		fmat.emission_enabled = true
		fmat.emission = fmat.albedo_color
		fmat.emission_energy_multiplier = 1.5
		flower.material_override = fmat
		var fa = randf() * TAU
		flower.position = Vector3(cos(fa) * randf_range(2.0, 3.5), randf_range(1.5, 3.5), sin(fa) * randf_range(2.0, 3.5))
		flower.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		objects_container.add_child(flower)

	spawned_items.append({"type": "scene", "name": "vine_garden"})
	camera_mode = "orbit"
	camera_orbit_radius = 6.0
	camera_orbit_height = 2.5

func _create_vine(start: Vector3, color: Color, segments: int):
	var pos = start
	var direction = Vector3(randf_range(-0.2, 0.2), 1.0, randf_range(-0.2, 0.2)).normalized()

	for i in segments:
		var seg = MeshInstance3D.new()
		var cm = CylinderMesh.new()
		cm.top_radius = 0.02
		cm.bottom_radius = 0.025
		cm.height = 0.2
		cm.radial_segments = 4
		seg.mesh = cm

		var mat = StandardMaterial3D.new()
		mat.albedo_color = color
		if i > segments * 0.7:
			mat.emission_enabled = true
			mat.emission = color
			mat.emission_energy_multiplier = 0.5
		mat.roughness = 0.8
		seg.material_override = mat

		var next_pos = pos + direction * 0.2
		var mid = (pos + next_pos) * 0.5
		seg.position = mid

		var norm_dir = direction.normalized()
		if abs(norm_dir.dot(Vector3.UP)) < 0.999:
			seg.look_at(seg.position + norm_dir)
			seg.rotate_object_local(Vector3.RIGHT, PI / 2.0)

		seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		objects_container.add_child(seg)

		pos = next_pos
		direction = direction.rotated(Vector3.UP, randf_range(-0.3, 0.3))
		direction = direction.rotated(Vector3.RIGHT, randf_range(-0.15, 0.05))
		direction = direction.normalized()
		direction.y = max(direction.y, 0.3)

# ── Fluid Particle Scene ─────────────────────────────────────────────────────

func create_fluid_scene(params: Dictionary):
	for child in objects_container.get_children():
		child.queue_free()
	spawned_items.clear()

	var color = Color.html(params.get("color", "#00aaff"))
	var count = int(params.get("particles", 5000))

	var particles = GPUParticles3D.new()
	particles.amount = count
	particles.lifetime = 6.0
	particles.visibility_aabb = AABB(Vector3(-10, -5, -10), Vector3(20, 15, 20))

	var pmat = ParticleProcessMaterial.new()
	pmat.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pmat.emission_sphere_radius = 4.0
	pmat.gravity = Vector3(0, -0.5, 0)
	pmat.initial_velocity_min = 0.5
	pmat.initial_velocity_max = 2.0
	pmat.angular_velocity_min = -30
	pmat.angular_velocity_max = 30
	pmat.damping_min = 1.0
	pmat.damping_max = 3.0
	pmat.scale_min = 0.3
	pmat.scale_max = 1.0
	pmat.attractor_interaction_enabled = true

	var grad = Gradient.new()
	grad.set_color(0, color)
	grad.add_point(0.5, color.lerp(Color(1, 0.3, 0.9), 0.5))
	grad.set_color(grad.get_point_count() - 1, Color(color.r, color.g, color.b, 0.0))
	var grad_tex = GradientTexture1D.new()
	grad_tex.gradient = grad
	pmat.color_ramp = grad_tex

	particles.process_material = pmat

	var pmesh = SphereMesh.new()
	pmesh.radius = 0.04
	pmesh.height = 0.08
	pmesh.radial_segments = 6
	pmesh.rings = 3
	var draw_mat = StandardMaterial3D.new()
	draw_mat.emission_enabled = true
	draw_mat.emission = color
	draw_mat.emission_energy_multiplier = 3.0
	draw_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	draw_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pmesh.material = draw_mat
	particles.draw_pass_1 = pmesh
	particles.position = Vector3(0, 3, 0)
	objects_container.add_child(particles)
	fluid_particles = particles

	# Cursor attractor
	var attractor = GPUParticlesAttractorSphere3D.new()
	attractor.radius = 2.0
	attractor.strength = 3.0
	attractor.position = Vector3(0, 3, 0)
	attractor.name = "FluidAttractor"
	objects_container.add_child(attractor)

	var light = OmniLight3D.new()
	light.light_color = color
	light.light_energy = 1.5
	light.omni_range = 8.0
	light.position = Vector3(0, 4, 0)
	objects_container.add_child(light)

	spawned_items.append({"type": "scene", "name": "fluid"})
	camera_mode = "orbit"
	camera_orbit_speed = 0.02
	camera_orbit_radius = 7.0
	camera_orbit_height = 4.0

# ── Post-Processing Effects ──────────────────────────────────────────────────

func toggle_postfx(effect: String):
	_clear_postfx()
	if effect == "none" or effect == "off" or effect == "":
		return

	var shader_map = {
		"crt": "res://shaders/crt.gdshader",
		"tiltshift": "res://shaders/tiltshift.gdshader",
		"ink": "res://shaders/ink.gdshader",
		"vhs": "res://shaders/vhs.gdshader",
		"chroma": "res://shaders/chroma.gdshader",
		"anime": "res://shaders/anime.gdshader",
		"nightvision": "res://shaders/nightvision.gdshader",
		"pixelate": "res://shaders/pixelate.gdshader",
		"glitch": "res://shaders/glitch.gdshader",
		"thermal": "res://shaders/thermal.gdshader",
		"ascii": "res://shaders/ascii.gdshader",
		"kuwahara": "res://shaders/kuwahara.gdshader",
		"oilpaint": "res://shaders/kuwahara.gdshader",
	}

	if not shader_map.has(effect):
		push_error("Unknown post-fx: " + effect)
		return

	var shader = load(shader_map[effect])
	if not shader:
		return

	postfx_canvas = CanvasLayer.new()
	postfx_canvas.layer = 10
	add_child(postfx_canvas)

	postfx_rect = ColorRect.new()
	postfx_rect.anchors_preset = Control.PRESET_FULL_RECT
	postfx_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var mat = ShaderMaterial.new()
	mat.shader = shader
	postfx_rect.material = mat
	postfx_canvas.add_child(postfx_rect)
	current_postfx = effect

func _clear_postfx():
	if postfx_canvas:
		postfx_canvas.queue_free()
		postfx_canvas = null
		postfx_rect = null
		current_postfx = ""

# ── Visualizer _process update ───────────────────────────────────────────────

func _update_visualizer():
	if not is_instance_valid(visualizer_bars) or not visualizer_bars.is_inside_tree():
		return
	var mm = visualizer_bars.multimesh
	if not mm:
		return

	var bar_count = mm.instance_count
	var ring_radius = 3.0

	for i in bar_count:
		var angle = float(i) / float(bar_count) * TAU
		var freq_t = float(i) / float(bar_count)
		var height: float
		if freq_t < 0.33:
			height = audio_bass * 3.0
		elif freq_t < 0.66:
			height = audio_mid * 2.5
		else:
			height = audio_treble * 2.0
		height = max(height, 0.05) + beat_intensity * 0.5

		var xform = Transform3D()
		xform = xform.scaled(Vector3(1.0, height, 1.0))
		xform.origin = Vector3(cos(angle) * ring_radius, 2.0 + height * 0.5, sin(angle) * ring_radius)
		mm.set_instance_transform(i, xform)

		var t = float(i) / float(bar_count)
		var c = Color(0, 1, 0.66).lerp(Color(1, 0.3, 0.9), t)
		c = c.lerp(Color(1, 1, 1), beat_intensity * 0.3)
		mm.set_instance_color(i, c)

# ── Fluid attractor follows cursor ───────────────────────────────────────────

func _update_fluid_attractor():
	var attractor_node = objects_container.get_node_or_null("FluidAttractor")
	if attractor_node and cursor_tracking:
		attractor_node.position = cursor_world_pos + Vector3(0, 1, 0)

# ══════════════════════════════════════════════════════════════════════════════
# NEW SCENES — Wave 2
# ══════════════════════════════════════════════════════════════════════════════

# ── Ocean scene with subdivided plane ──
func create_ocean_scene(params: Dictionary):
	for child in objects_container.get_children():
		child.queue_free()
	spawned_items.clear()
	_clear_postfx()

	# Apply watery environment
	var env = $WorldEnvironment.environment as Environment
	var sky_mat = env.sky.sky_material as ProceduralSkyMaterial
	sky_mat.sky_top_color = Color(0.05, 0.08, 0.2)
	sky_mat.sky_horizon_color = Color(0.3, 0.25, 0.45)
	sky_mat.ground_horizon_color = Color(0.1, 0.15, 0.25)
	sky_mat.ground_bottom_color = Color(0.02, 0.03, 0.08)
	sky_mat.sky_energy_multiplier = 1.5
	env.ambient_light_color = Color(0.1, 0.15, 0.25)
	env.ambient_light_energy = 0.3
	$MoonLight.light_energy = 0.6
	$MoonLight.light_color = Color(0.7, 0.75, 0.9)
	env.glow_enabled = true
	env.glow_intensity = 1.0
	env.glow_strength = 0.8
	env.fog_enabled = true
	env.fog_light_color = Color(0.15, 0.2, 0.35)
	env.fog_density = 0.005

	# Subdivided plane for wave displacement
	var plane = MeshInstance3D.new()
	var pm = PlaneMesh.new()
	pm.size = Vector2(40, 40)
	pm.subdivide_width = 128
	pm.subdivide_depth = 128
	plane.mesh = pm

	var shader = load("res://shaders/ocean.gdshader")
	if shader:
		var mat = ShaderMaterial.new()
		mat.shader = shader
		plane.material_override = mat

	plane.position = Vector3(0, -0.5, 0)
	plane.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	objects_container.add_child(plane)
	spawned_items.append({"type": "ocean"})
	current_scene_name = "ocean"

# ── Audio capture restart (bug #80173: AudioStreamMicrophone accumulates ~1s delay/hour) ──
func _restart_audio_capture():
	if mic_player:
		var bus_name = mic_player.bus
		mic_player.stop()
		mic_player.queue_free()
		mic_player = AudioStreamPlayer.new()
		mic_player.stream = AudioStreamMicrophone.new()
		mic_player.bus = bus_name
		mic_player.volume_db = 0.0
		add_child(mic_player)
		mic_player.play()
		# Re-select PipeWire monitor source
		var devices = AudioServer.get_input_device_list()
		for d in devices:
			if "monitor" in d.to_lower() or "substrate" in d.to_lower():
				AudioServer.input_device = d
				break
		print("Audio capture restarted (periodic drift prevention)")

# ── Shader pre-warming — compile all shaders at startup to prevent stutter ──
# Note: canvas_item shaders referencing SCREEN_PIXEL_SIZE may log errors during
# prewarm in offscreen context — these are harmless and non-fatal.
func _prewarm_shaders():
	# Spatial shaders — render on a tiny MeshInstance3D
	var spatial_shaders = [
		"res://shaders/fractal.gdshader",
		"res://shaders/aurora.gdshader",
		"res://shaders/matrix_rain.gdshader",
		"res://shaders/mycelium.gdshader",
		"res://shaders/fire.gdshader",
		"res://shaders/vaporwave.gdshader",
		"res://shaders/domain_warp.gdshader",
		"res://shaders/ocean.gdshader",
		"res://shaders/cloudscape_fog.gdshader",
		"res://shaders/physarum_render.gdshader",
		"res://shaders/plasma.gdshader",
		"res://shaders/kaleidoscope.gdshader",
		"res://shaders/tunnel.gdshader",
		"res://shaders/starfield.gdshader",
		"res://shaders/julia.gdshader",
		"res://shaders/lava.gdshader",
		"res://shaders/nebula.gdshader",
		"res://shaders/lightning.gdshader",
		"res://shaders/blackhole.gdshader",
		"res://shaders/metaballs.gdshader",
		"res://shaders/menger.gdshader",
		"res://shaders/supernova.gdshader",
		"res://shaders/synthgrid.gdshader",
		"res://shaders/waveform.gdshader",
	]
	for path in spatial_shaders:
		var shader = load(path)
		if not shader:
			continue
		var quad = MeshInstance3D.new()
		var qm = QuadMesh.new()
		qm.size = Vector2(0.001, 0.001)
		quad.mesh = qm
		var mat = ShaderMaterial.new()
		mat.shader = shader
		quad.material_override = mat
		quad.position = Vector3(0, -100, 0)
		add_child(quad)
		quad.call_deferred("queue_free")

	# Canvas_item shaders — render on a tiny ColorRect in a CanvasLayer
	var canvas_shaders = [
		"res://shaders/crt.gdshader",
		"res://shaders/tiltshift.gdshader",
		"res://shaders/ink.gdshader",
		"res://shaders/vhs.gdshader",
		"res://shaders/chroma.gdshader",
		"res://shaders/anime.gdshader",
		"res://shaders/nightvision.gdshader",
		"res://shaders/pixelate.gdshader",
		"res://shaders/glitch.gdshader",
		"res://shaders/thermal.gdshader",
		"res://shaders/ascii.gdshader",
		"res://shaders/feedback_warp.gdshader",
		"res://shaders/transition_dissolve.gdshader",
	]
	var warmup_canvas = CanvasLayer.new()
	warmup_canvas.layer = -100  # behind everything
	add_child(warmup_canvas)
	for path in canvas_shaders:
		var shader = load(path)
		if not shader:
			continue
		var rect = ColorRect.new()
		rect.size = Vector2(1, 1)
		rect.position = Vector2(-100, -100)  # off-screen
		var mat = ShaderMaterial.new()
		mat.shader = shader
		rect.material = mat
		warmup_canvas.add_child(rect)
	warmup_canvas.call_deferred("queue_free")
	print("Shader pre-warm: ", spatial_shaders.size() + canvas_shaders.size(), " shaders queued")

# ══════════════════════════════════════════════════════════════════════════════
# FRAME FEEDBACK — Butterchurn-style two-viewport ping-pong warp
# Two SubViewports: VP0 reads VP1's texture, VP1 reads VP0's texture.
# Each frame only one updates (UPDATE_ONCE), avoiding Vulkan's prohibition
# on reading and writing the same texture in one pass.
# Beat-seeded content (kick/snare/hihat) evolves via warp frame-over-frame.
# Bloom: Godot's multi-level glow dynamically modulated by audio bands.
# ══════════════════════════════════════════════════════════════════════════════

func _setup_feedback():
	## Initialize Butterchurn-style two-viewport ping-pong feedback warp.
	## VP0's shader reads VP1's texture and vice versa. Each frame we trigger
	## UPDATE_ONCE on the write viewport, then swap. No self-reference.
	if feedback_canvas:
		return  # already set up

	# Load the warp shader
	var warp_shader = load("res://shaders/feedback_warp.gdshader")
	if not warp_shader:
		push_warning("Feedback warp shader not found")
		return

	# Create two SubViewports for ping-pong
	for i in range(2):
		feedback_vp[i] = SubViewport.new()
		feedback_vp[i].size = Vector2i(960, 540)
		feedback_vp[i].render_target_update_mode = SubViewport.UPDATE_DISABLED
		feedback_vp[i].transparent_bg = false
		add_child(feedback_vp[i])

		feedback_mat[i] = ShaderMaterial.new()
		feedback_mat[i].shader = warp_shader
		feedback_mat[i].set_shader_parameter("fade", 0.95)

		feedback_rects[i] = ColorRect.new()
		feedback_rects[i].size = Vector2(960, 540)
		feedback_rects[i].material = feedback_mat[i]
		feedback_vp[i].add_child(feedback_rects[i])

	# Cross-reference: VP0 reads VP1, VP1 reads VP0 (never self)
	feedback_mat[0].set_shader_parameter("previous_frame", feedback_vp[1].get_texture())
	feedback_mat[1].set_shader_parameter("previous_frame", feedback_vp[0].get_texture())

	# Display canvas — shows the most recently written viewport
	feedback_canvas = CanvasLayer.new()
	feedback_canvas.layer = 10  # over the 3D scene as an overlay effect
	add_child(feedback_canvas)

	feedback_display_rect = TextureRect.new()
	feedback_display_rect.stretch_mode = TextureRect.STRETCH_SCALE
	feedback_display_rect.custom_minimum_size = Vector2(1920, 1080)
	feedback_display_rect.size = Vector2(1920, 1080)
	feedback_display_rect.modulate = Color(1, 1, 1, 0.5)  # semi-transparent overlay
	feedback_display_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	feedback_canvas.add_child(feedback_display_rect)

	# Seed: render both viewports once to initialize
	feedback_vp[0].render_target_update_mode = SubViewport.UPDATE_ONCE
	feedback_vp[1].render_target_update_mode = SubViewport.UPDATE_ONCE
	feedback_write_idx = 0

	feedback_enabled = true
	print("Frame feedback initialized (two-viewport ping-pong warp)")

func _teardown_feedback():
	## Disable and clean up feedback loop.
	if feedback_canvas:
		feedback_canvas.queue_free()
		feedback_canvas = null
	for i in range(2):
		if feedback_vp[i]:
			feedback_vp[i].queue_free()
			feedback_vp[i] = null
		feedback_mat[i] = null
		feedback_rects[i] = null
	feedback_display_rect = null
	feedback_enabled = false

func _update_feedback():
	## Ping-pong: trigger write viewport, display it, swap.
	if not feedback_enabled:
		return
	if not feedback_vp[0] or not feedback_vp[1]:
		return

	# Trigger render on the write viewport (reads from the other)
	feedback_vp[feedback_write_idx].render_target_update_mode = SubViewport.UPDATE_ONCE

	# Display the write viewport's output
	feedback_display_rect.texture = feedback_vp[feedback_write_idx].get_texture()

	# Adjust fade and overlay opacity based on scene type
	var fade_val = 0.96 if current_scene_name in ART_SCENES else 0.93
	var alpha_val = 0.45 if current_scene_name in ART_SCENES else 0.35
	feedback_mat[feedback_write_idx].set_shader_parameter("fade", fade_val)
	if feedback_display_rect:
		feedback_display_rect.modulate.a = alpha_val

	# Swap write target for next frame
	feedback_write_idx = 1 - feedback_write_idx

func _update_bloom():
	## Audio-reactive bloom — modulates Godot's built-in multi-level glow.
	## Achieves the Butterchurn multi-resolution blur effect natively.
	if not bloom_reactive_enabled:
		return
	var env = $WorldEnvironment.environment as Environment
	if not env or not env.glow_enabled:
		return
	# Beat kick → brief glow intensity spike
	var kick_boost = beat_kick * 0.8
	# Energy → sustained glow modulation
	var energy_mod = audio_energy * 0.4
	# Bass → bloom spread
	var bass_bloom = audio_bass * 0.15

	env.glow_intensity = bloom_base_intensity + kick_boost + energy_mod * 0.3
	env.glow_strength = bloom_base_strength + energy_mod * 0.2
	env.glow_bloom = clamp(bloom_base_bloom + bass_bloom + kick_boost * 0.1, 0.0, 1.0)
	# Treble → lower HDR threshold (more elements bloom)
	env.glow_hdr_threshold = clamp(0.8 - audio_treble * 0.3 - beat_kick * 0.2, 0.1, 1.0)

# ══════════════════════════════════════════════════════════════════════════════
# ENHANCED SCENE TRANSITIONS — dissolve with audio-reactive edge glow
# ══════════════════════════════════════════════════════════════════════════════

func _transition_to_scene_dissolve(scene_name: String):
	## Crossfade transition using dissolve shader. Falls back to fade if unavailable.
	if is_transitioning:
		return
	is_transitioning = true

	# Use the simpler fade transition (the dissolve needs dual SubViewports
	# which is too complex for the current architecture — save for future)
	# For now, use an improved fade with audio-reactive speed
	var fade_duration = max(0.3, 0.6 - beat_intensity * 0.2)  # faster on beats

	var tw = create_tween()
	tw.tween_method(_set_fade_alpha, 0.0, 1.0, fade_duration)
	tw.tween_callback(func():
		@warning_ignore("redundant_await")
		await handle_command({"type": scene_name, "params": {}})
		current_scene_name = scene_name
	)
	tw.tween_method(_set_fade_alpha, 1.0, 0.0, fade_duration)
	tw.tween_callback(func(): is_transitioning = false)


# ── Museum Overlay System ──
var museum_overlay: CanvasLayer
var museum_title: Label
var museum_chapter: Label
var museum_desc: Label
var museum_tween: Tween

const SCENE_INFO = {
	"collatz": {
		"title": "COLLATZ CONJECTURE",
		"desc": "Take any number: if even, halve it; if odd, triple and add one. Does every number reach 1? Nobody knows — this is the simplest unsolved problem in mathematics. The complex extension f(z) = (1/4)(2 + 7z - (2+5z)cos(pi*z)) maps this to the complex plane. WHAT YOU SEE: Bright regions escape quickly (few iterations), dark regions take longer or never escape. The fractal boundary is where the conjecture lives — the edge between convergence and divergence. Color shifts encode iteration count.",
	},
	"riemann_zeta": {
		"title": "RIEMANN ZETA FUNCTION",
		"desc": "The Riemann Hypothesis states all non-trivial zeros of the zeta function lie on the line Re(s) = 1/2. Proving it wins 1 million dollars. The zeta function encodes the distribution of prime numbers — every prime leaves its fingerprint here. WHAT YOU SEE: Colors encode the complex phase of zeta(s) — hue is argument, brightness is magnitude. The golden vertical line is Re(s)=1/2. Bright white spots along it are the zeros — phase singularities where all colors converge. The pattern scrolls upward revealing more zeros.",
	},
	"kleinian": {
		"title": "KLEINIAN GROUP LIMIT SETS",
		"desc": "Mobius transformations (circle inversions) generate a group. The limit set is where orbits accumulate — the boundary between order and chaos in hyperbolic geometry. From the book Indras Pearls by Mumford, Series, and Wright. WHAT YOU SEE: Four glowing circles define the group generators. The fractal dust between them is the limit set — points that never escape under iteration. Parameters animate through quasi-Fuchsian space, continuously deforming the fractal from a circle to a gasket.",
	},
	"kerr_blackhole": {
		"title": "KERR BLACK HOLE",
		"desc": "A spinning black hole solved from Einsteins field equations. The spin creates frame dragging — spacetime itself is twisted around the singularity. The accretion disk temperature follows T(r) proportional to r^(-3/4). WHAT YOU SEE: The dark center is the event horizon — nothing escapes. The asymmetric glow is Doppler beaming: the approaching side (brighter) is blueshifted, the receding side (dimmer) is redshifted. The bright inner ring is the photon sphere where light orbits. This is real physics, not artistic interpretation.",
	},
	"spiral_waves": {
		"title": "FITZHUGH-NAGUMO SPIRAL WAVES",
		"desc": "The equations du/dt = u - u^3/3 - v model excitable media — systems that fire when stimulated then recover. The same math governs cardiac electrical activity, chemical oscillations, and neural signaling. WHAT YOU SEE: Orange wavefronts are excitation pulses propagating outward. Blue trails are the recovery phase. Spirals rotate around phase singularity cores. When spirals break up, it models cardiac fibrillation. The bright edges are where the excitation gradient is steepest — the wavefront.",
	},
	"arnold_tongues": {
		"title": "ARNOLD TONGUES",
		"desc": "Force an oscillator near a rational multiple of its natural frequency and it locks on. The circle map theta -> theta + Omega - (K/2pi)sin(2pi*theta) captures this. Each tongue grows from a rational number p/q on the frequency axis. WHAT YOU SEE: X-axis is driving frequency, Y-axis is coupling strength. Colored regions are mode-locked (periodic). Dark gaps between are quasiperiodic. The flame-shaped tongues grow wider with stronger coupling. Golden edges mark the fractal boundaries between order and chaos.",
	},
	"standard_map": {
		"title": "CHIRIKOV STANDARD MAP",
		"desc": "The most important map in Hamiltonian chaos: p_new = p + K*sin(theta), theta_new = theta + p_new. As K increases, KAM tori fracture. The KAM theorem proves some invariant curves survive perturbation while others shatter into island chains and chaos. WHAT YOU SEE: Smooth curves are surviving KAM tori — barriers to chaotic diffusion. Scattered dots are chaotic orbits exploring the sea between tori. Island chains are periodic orbits. K animates: watch order dissolve into chaos and back. Blue traces highlight the last surviving tori.",
	},
	"elliptic_finite": {
		"title": "ELLIPTIC CURVES OVER FINITE FIELDS",
		"desc": "y^2 = x^3 + ax + b mod p — the foundation of modern cryptography (Bitcoin, TLS). Over a finite field, the continuous curve becomes a discrete set of points that form a group under geometric addition. WHAT YOU SEE: Bright dots are points (x,y) satisfying the equation modulo p. The grid shows the finite field structure. As prime p changes, the entire pattern restructures — different primes reveal different symmetries. The background color encodes the quadratic residue y^2 - x^3 - ax - b mod p.",
	},
	"goldbach": {
		"title": "GOLDBACH COMET",
		"desc": "Every even number greater than 2 is the sum of two primes (unproven since 1742). For each even n, g(n) counts how many ways. Plotting g(n) vs n reveals hidden structure. WHAT YOU SEE: Each bright dot is one even number positioned at (n, g(n)). The comet shape emerges because g(n) roughly grows with n. The tail rays at specific slopes correspond to small primes p — when p is prime, n-p is often also prime. Twin primes glow gold, cousin primes green, sexy primes purple.",
	},
	"hopf": {
		"title": "HOPF FIBRATION",
		"desc": "The map S^3 -> S^2 with S^1 fibers. Every point on a 2-sphere corresponds to a circle in the 3-sphere. Every pair of circles links exactly once. This proves pi_3(S^2) = Z — the third homotopy group of the sphere is infinite. WHAT YOU SEE: Each glowing curve is one fiber (circle) projected from 4D via stereographic projection. The fibers are distributed by the Fibonacci sphere method on S^2. Colors encode base point position. The interlocking structure shows that every pair of circles is linked — topologically inseparable.",
	},
	"wigner": {
		"title": "WIGNER QUASIPROBABILITY",
		"desc": "The Wigner function W(x,p) represents quantum states in phase space. Unlike classical probability, it can go negative — the signature of quantum effects with no classical analogue. Computed via Laguerre polynomials for harmonic oscillator eigenstates. WHAT YOU SEE: Warm colors (orange/red) are positive probability — classically allowed regions. Cool colors (blue) are NEGATIVE probability — impossible in classical physics. The white boundary between them is where the quantum-classical transition occurs. Concentric rings mark classical energy levels. The pattern breathes as quantum states interfere.",
	},
	"tropical": {
		"title": "TROPICAL GEOMETRY",
		"desc": "An algebra where addition becomes max and multiplication becomes addition. Tropical curves are piecewise-linear — the skeleton of classical algebraic geometry. Deep connection to AI: ReLU neural network decision boundaries ARE tropical hypersurfaces. WHAT YOU SEE: The bright angular lines are tropical curves — where two terms tie for the maximum. Unlike smooth classical curves, these have sharp corners at vertices. Multiple layers at different scales show how tropical geometry tiles space. The dim lattice points are vertices of the Newton polygon, which is dual to the tropical curve.",
	},
	"padic": {
		"title": "P-ADIC NUMBERS",
		"desc": "Distance measured by divisibility, not magnitude. Two numbers are p-adically close if their difference is divisible by a high power of p. The p-adic integers form a Cantor-like fractal tree that branches into p children at each level. WHAT YOU SEE: Nested circles represent the tree structure of p-adic integers. Each level branches into p children (cycling through primes 2,3,5,7). The fractal dusting at the boundary is the Cantor set structure of the p-adic unit ball. Colors encode tree depth — deeper levels are the fine structure of p-adic proximity.",
	},
	"seifert": {
		"title": "SEIFERT SURFACE",
		"desc": "Every knot bounds an oriented surface — the Seifert surface. The genus of this surface is a knot invariant: it cannot change without cutting the knot. Seifert surfaces connect knot theory to 4-dimensional topology. WHAT YOU SEE: A smooth surface bounded by a trefoil knot (2,3 torus knot), ray-marched in 3D. Two-sided coloring (different hues for front/back) reveals the orientation. The surface swoops and twists, constrained by the knots topology. Fresnel rim lighting highlights the edges where the surface curves toward you.",
	},
	"schmidt": {
		"title": "SCHMIDT ARRANGEMENTS",
		"desc": "First GPU render ever created. The orbit of the real line under the Bianchi group PSL_2(O_K) for imaginary quadratic fields. Each matrix with Gaussian integer entries produces a circle. WHAT YOU SEE: Nested circles are Ford circles — each tangent to the real axis (horizontal line) with radius 1/(denominator^2). They encode the rational number p/q at each tangent point. Larger circles correspond to simpler fractions. The fractal packing shows how rationals densely fill the real line. Colors encode the curvature (1/radius) of each circle.",
	},
	"modular_forms": {
		"title": "MODULAR FORMS",
		"desc": "The Dedekind eta function eta(tau)^24 on the upper half-plane. Modular forms are functions invariant under the action of SL_2(Z). They connect number theory to geometry and appear in the proof of Fermats Last Theorem and string theory. WHAT YOU SEE: Domain coloring — hue encodes complex phase, brightness encodes magnitude. The repeating pattern reflects SL_2(Z) symmetry (the fundamental domain tiles the half-plane). Bright singularities near the bottom are cusps where the function blows up. The golden lines trace the fundamental domain boundary.",
	},
	"attractor_density": {
		"title": "STRANGE ATTRACTOR DENSITY",
		"desc": "Instead of drawing particle trajectories, accumulate how often orbits visit each region — the invariant probability measure. This reveals self-similar internal structure invisible in standard renderings. Cycles through Lorenz, Rossler, and Halvorsen. WHAT YOU SEE: Bright regions are most-visited areas of the attractor. The Lorenz butterfly has two lobes (weather prediction). Rossler has a single stretched loop (chemical kinetics). Halvorsen has three-fold symmetry. The internal filaments — bright threads within the glow — show how the attractor folds space at every scale.",
	},
	"penrose": {
		"title": "PENROSE TILING",
		"desc": "An aperiodic tiling — it fills the plane but never repeats. Generated by five sets of parallel lines at 72-degree angles (de Bruijn multigrid). The golden ratio phi = (1+sqrt(5))/2 governs every proportion. Physical quasicrystals have this structure (Nobel Prize 2011). WHAT YOU SEE: Each colored region is a tile — the color encodes which pair of grid lines determines it. Bright edges are the tile boundaries. Golden glowing vertices are where 5+ grid lines converge — exponentially rare star vertices that mark the golden ratio in the tiling. The pattern drifts, never repeating.",
	},
	"horseshoe": {
		"title": "SMALE HORSESHOE",
		"desc": "Stretch horizontally, compress vertically, fold back into the unit square. Repeat. The set of points surviving both forward and backward iteration forever forms a Cantor set — the invariant hyperbolic set where chaos lives. WHAT YOU SEE: Warm orange-red shows where forward iteration keeps points inside (stable manifold). Cool blue shows where backward iteration keeps points inside (unstable manifold). Bright gold where BOTH overlap is the invariant Cantor set — the chaotic invariant set. The fold line (horizontal center) is where stretching reverses direction.",
	},
	"dirac": {
		"title": "DIRAC EQUATION",
		"desc": "Relativistic quantum mechanics unifying special relativity with quantum theory. Predicted antimatter (positrons) before discovery. The spinor wavefunction has two components — spin up and spin down — coupled by the Dirac matrices. WHAT YOU SEE: Warm colors show spin-up probability density, cool colors show spin-down. The orbital shapes (spherical, dumbbell, cloverleaf) emerge from angular momentum quantization — s, p, d, f orbitals. Flowing patterns are probability current — where the electron is most likely moving. Multiple energy levels (n=1 through 4) superimpose.",
	},
	"conformal": {
		"title": "CONFORMAL MAPS",
		"desc": "Angle-preserving transformations of the complex plane. Every intersection angle is preserved — this is the defining property. Conformal maps solve Laplaces equation, model fluid flow, and design airplane wings (Joukowski transform). WHAT YOU SEE: The grid shows how the map deforms space. Every grid intersection remains a right angle — that is conformality. z^2 doubles angles. 1/z inverts circles to lines. The Joukowski map turns a circle into an airfoil shape. The exponential map turns straight lines into spirals. Red glow marks critical points where the derivative is zero.",
	},
	"mertens": {
		"title": "MERTENS FUNCTION",
		"desc": "M(n) = sum of mu(k) for k=1 to n, where mu is the Mobius function encoding prime factorization. The Mertens conjecture (1897) that |M(n)| < sqrt(n) was DISPROVED in 1985 by Odlyzko and te Riele, but no explicit counterexample has been computed. WHAT YOU SEE: The wildly oscillating curve is M(n) — blue when positive, red when negative. The yellow curves are the sqrt(n) bounds that were conjectured to hold. The function crosses zero frequently. Its behavior is intimately connected to the Riemann Hypothesis: if M(n) = O(n^(1/2+eps)) for all eps, then RH is true.",
	},
	"braid": {
		"title": "BRAID GROUPS",
		"desc": "The mathematical structure of interweaving strands. The braid group B_n has generators sigma_i that swap adjacent strands. The group operation is concatenation. Braids encode: DNA enzyme action, topological quantum computing (anyonic braids), and knot theory. WHAT YOU SEE: Seven colored strands weave over and under each other. Brighter strands pass OVER darker ones — the crossings are the generators sigma_i. The pattern is periodic but the braid word (sequence of crossings) encodes algebraic structure. Golden glow at crossing points highlights where strands interact.",
	},
	"symplectic": {
		"title": "SYMPLECTIC BILLIARDS",
		"desc": "A particle bouncing inside a shape, viewed in phase space (position on boundary vs launch angle). Symplectic geometry preserves the phase space area — Liouvilles theorem. This is the foundation of Hamiltonian mechanics. WHAT YOU SEE: Each orbit traces dots in phase space. Smooth curves are KAM tori — invariant under the dynamics, separating regular from chaotic regions. Scattered dots are chaotic orbits that explore ergodically. The shape parameter animates, continuously breaking and reforming the KAM structure. Every bounce exactly conserves energy.",
	},
	"sol_geometry": {
		"title": "THURSTON SOL GEOMETRY",
		"desc": "One of eight model geometries in Thurstons geometrization (which led to the Poincare conjecture proof). The metric ds^2 = e^(2z)dx^2 + e^(-2z)dy^2 + dz^2 makes x-distances grow exponentially with z while y-distances shrink. No closed-form geodesics exist. WHAT YOU SEE: A tiled space where the grid distorts anisotropically — tiles stretch horizontally and compress vertically (or vice versa) depending on depth. Each ray is numerically integrated because geodesics have no formula. The visual experience is genuinely alien — looking up feels geometrically different from looking sideways.",
	},
	"dyson": {
		"title": "DYSON BROWNIAN MOTION",
		"desc": "Eigenvalues of random matrices repel each other logarithmically, performing correlated Brownian motion. The equilibrium distribution is the Wigner semicircle. The spacing statistics follow the GUE universality class — the same statistics appear in nuclear physics, zeros of the Riemann zeta function, and bus arrival times in Cuernavaca. WHAT YOU SEE: Vertical lines are eigenvalues — they repel and can never cross. The purple curve is the Wigner semicircle (equilibrium density). At the bottom, the spacing histogram approaches the Wigner surmise distribution. Watch eigenvalues jitter while maintaining minimum spacing — log repulsion prevents collisions.",
	},
	"homoclinic": {
		"title": "HOMOCLINIC TANGLES",
		"desc": "Poincare discovered these in 1890 and wrote he dared not attempt to draw them. Where the stable manifold (forward-time convergence) and unstable manifold (backward-time convergence) of a saddle point intersect, they create an infinitely folded mesh. This is the geometric origin of chaos. WHAT YOU SEE: Warm orange traces the stable manifold (where points go TO the saddle). Cool blue traces the unstable manifold (where points come FROM the saddle). Gold intersections are homoclinic points — each one forces infinitely many more intersections nearby. The mesh gets infinitely dense near the saddle points (white dots).",
	},
	"optimal_transport": {
		"title": "OPTIMAL TRANSPORT",
		"desc": "The cheapest way to move mass from one distribution to another. The Wasserstein distance measures how far you must transport probability. The geodesic in Wasserstein space is the path of least total displacement. Applications: economics, machine learning, computer graphics. WHAT YOU SEE: Red blobs are the source distribution, green is the target. The visualization morphs between them along the optimal transport path. Streamlines show the flow direction — mass moves along these paths. The cost minimization means no mass crosses another streams path (no tangling). The phase parameter cycles through the morphing.",
	},
	"ricci_flow": {
		"title": "RICCI FLOW",
		"desc": "The PDE dg/dt = -2*Ric(g) evolves a Riemannian metric proportional to its curvature. Bumpy surfaces smooth out. Perelman used Ricci flow with surgery to prove the Poincare conjecture — the most famous solved millennium problem. WHAT YOU SEE: A bumpy terrain (representing a metric with varying curvature) smooths over time. Red regions have high positive curvature (hills shrinking). Blue has negative curvature (saddles expanding). Contour lines show constant-curvature curves. The flow ping-pongs: watch geometry heal itself then reset. Purple glow marks flat regions (zero gradient — Ricci solitons).",
	},
	"neural_ode": {
		"title": "NEURAL ODE PHASE PORTRAIT",
		"desc": "A neural network defines a continuous vector field f(x,t) and solutions flow along it — unlike discrete-layer networks, Neural ODEs have infinite depth. The dynamics reveal how AI transforms data: fixed points are decisions, flows are feature extraction. WHAT YOU SEE: Streamlines trace the learned vector field. Blue glow marks stable fixed points (attractors — where data converges to a class). Red marks unstable fixed points (repellers — decision boundaries). Arrow indicators show local flow direction. The divergence field (where colors concentrate/spread) shows where the network compresses or expands information.",
	},
	"navier_stokes": {
		"title": "NAVIER-STOKES EQUATIONS",
		"desc": "Whether smooth solutions always exist is a Millennium Prize problem worth 1 million dollars. These PDEs govern fluid motion — weather, ocean currents, blood flow, aerodynamics. The nonlinear (v dot nabla)v term creates turbulence, which remains one of the great unsolved problems in physics. WHAT YOU SEE: Red vortices rotate clockwise, blue counter-clockwise. Eight vortices interact, merge, and create turbulent cascading. Streamlines (flowing curves) trace fluid particle paths. The swirling patterns show how large vortices break into smaller ones — Richardsons energy cascade.",
	},
	"yang_mills": {
		"title": "YANG-MILLS GAUGE THEORY",
		"desc": "A Millennium Prize problem: prove that Yang-Mills theory has a mass gap (the lightest particle has positive mass). This quantum field theory underlies the Standard Model — it explains why protons exist and why the strong force confines quarks. WHAT YOU SEE: RGB channels show three SU(2) gauge field components — the mathematical structure of the weak nuclear force. Bright cores are instanton centers (topological charge density peaks). The instanton is a self-dual solution to the Yang-Mills equations — it tunnels between vacuum states. A second (anti-instanton) orbits nearby in purple.",
	},
	"lorenz_knot": {
		"title": "LORENZ ATTRACTOR KNOTS",
		"desc": "The Lorenz attractor contains periodic orbits that form every possible knot type — a result proved by Birman and Williams. The butterfly shape emerges from weather modeling equations. Chaos means nearby trajectories diverge exponentially, yet they all stay on the attractor. WHAT YOU SEE: The glowing butterfly is the Lorenz attractor rendered as orbit density (brighter = more visits). Gold highlights trace a periodic orbit — one of the knotted trajectories embedded in the chaotic flow. The two lobes represent the two unstable equilibria that trajectories spiral around before switching unpredictably.",
	},
	"langlands": {
		"title": "LANGLANDS PROGRAM",
		"desc": "The grand unified theory of mathematics — a vast web of conjectures connecting number theory (automorphic forms) to geometry (Galois representations). Proving instances wins Fields Medals. The program has been called the Rosetta Stone of mathematics. WHAT YOU SEE: Warm colors show the automorphic side (Ramanujan tau function q-expansion — number theory). Cool colors show the Galois side (Frobenius eigenvalue distributions — geometry). Gold glow appears where both sides agree — the Langlands correspondence in action. Faint vertical lines mark approximate locations of L-function zeros.",
	},
	"prime_gaps": {
		"title": "PRIME GAP DISTRIBUTION",
		"desc": "The gap between consecutive primes p_n and p_(n+1). Twin primes (gap 2) may be infinite — the Twin Prime Conjecture is unproven. Yitang Zhang proved in 2013 that gaps below 70 million occur infinitely often, later reduced to 246 by the Polymath project. WHAT YOU SEE: Each dot is a prime gap plotted at (prime index, gap size). Gold dots are twin primes (gap=2) — the most studied pattern. Green are cousin primes (gap=4). Purple are sexy primes (gap=6). Horizontal guide lines show common gap sizes. The scatter reveals that gaps grow slowly (roughly log p) but with enormous variation.",
	},
	"spectral": {
		"title": "SPECTRAL GEOMETRY",
		"desc": "Can you hear the shape of a drum? Eigenfunctions of the Laplacian on a domain. Each eigenfunction oscillates at a specific frequency — together they determine the geometry (almost). Weyls law: N(lambda) ~ Area * lambda / (4pi). WHAT YOU SEE: Bright lines are nodal curves — where the surface does not vibrate (Chladni figures). Multiple eigenmodes superimpose with time-dependent phases, creating moving interference. The pattern changes continuously as modes go in and out of phase. Each mode has n*m half-wavelengths. Nodal lines always intersect at right angles.",
	},
	"schrodinger": {
		"title": "SCHRODINGER EQUATION",
		"desc": "The fundamental equation of quantum mechanics: i*hbar*d|psi>/dt = H|psi>. A particle is described by a wave function psi whose squared magnitude gives the probability of finding it at each location. Interference between paths creates the quantum signature. WHAT YOU SEE: Two slits emit spherical waves (bright expanding circles). Where crests meet crests, probability is high (bright). Where crests meet troughs, probability cancels (dark) — destructive interference. The vertical barrier has two narrow openings. The interference pattern on the right shows the quintessential quantum effect: a single particle interferes with itself.",
	},
	"lenia": {
		"title": "LENIA",
		"desc": "Continuous generalization of cellular automata. Instead of discrete alive/dead cells, Lenia uses smooth states with ring-shaped convolution kernels. The growth function G(u) = 2exp(-(u-mu)^2/(2sigma^2)) - 1 creates self-sustaining structures that move, split, and interact like living organisms. WHAT YOU SEE: Blob-like creatures with internal ring structure drift and pulse. The rings come from the kernel shape — growth is strongest at a specific distance from each cell center. Color intensity shows activation level. The growth function determines whether each region grows (warm) or decays (cool). These are artificial lifeforms from pure mathematics.",
	},
	"calabi_yau": {
		"title": "CALABI-YAU MANIFOLD",
		"desc": "String theory requires 10 dimensions — 4 we see plus 6 compactified on a Calabi-Yau manifold. These are Ricci-flat Kahler manifolds with SU(n) holonomy. The quintic threefold z1^n+z2^n=1 is parameterized and projected from 5D. WHAT YOU SEE: A cross-section through the manifold parameterized by two angles. The surface shape comes from Hansons projection method. Bright lines trace the holomorphic structure (where z1^n+z2^n is real). The degree n animates — different values produce different manifold topologies. Shading simulates the Ricci-flat condition. These are the shapes that could determine the laws of physics.",
	},
	"apollonian3d": {
		"title": "3D APOLLONIAN GASKET",
		"desc": "The 2D Apollonian gasket (nested tangent circles) extended to 3D via folding operations: abs(), sort coordinates, scale, translate, and sphere inversion. Each iteration creates self-similar structure at smaller scales. The result is a fractal with infinite surface area but zero volume. WHAT YOU SEE: A ray-marched 3D fractal of nested spherical structures. The folding operations create octahedral symmetry. Bright areas are where the surface catches light. Ambient occlusion (darker in crevices) reveals the recursive depth. The camera orbits to show the full 3D structure. Zooming in would reveal the same pattern at every scale.",
	},
	"dual_quat_julia": {
		"title": "DUAL QUATERNION JULIA SET",
		"desc": "Dual quaternions have form q = a + epsilon*b where epsilon^2 = 0 (nilpotent). This 8-dimensional algebra extends quaternions with infinitesimal structure. The Julia set z -> z^2 + c computed here has structure invisible in standard 4D quaternion Julia sets. WHAT YOU SEE: An escape-time fractal — bright regions escape quickly, dark regions stay bounded. The dual part (epsilon component) adds subtle perturbation structure absent in regular quaternion fractals. The animated c parameter sweeps through 8D space. The smooth color gradient uses the dual part as a natural distance estimator — it provides derivative information for free via automatic differentiation.",
	},
	"hyper_mandelbrot": {
		"title": "HYPERBOLIC MANDELBROT",
		"desc": "The Mandelbrot iteration z -> z^2 + c performed in hyperbolic space (Poincare disk model). Addition becomes hyperbolic translation via Mobius transformations. Distances diverge near the boundary circle — the fractal has infinite detail compressed into a finite disk. WHAT YOU SEE: The entire fractal fits inside the unit disk. Near the boundary (where the bright ring is), hyperbolic distances go to infinity — structure accumulates endlessly. Faint circular arcs are hyperbolic geodesics (shortest paths in this geometry). The fractal combines escape-time coloring with the natural distortion of hyperbolic space.",
	},
	"eisenstein": {
		"title": "EISENSTEIN PRIMES",
		"desc": "Primes in the hexagonal integer lattice Z[omega] where omega = e^(2pi*i/3) = (-1+isqrt(3))/2. An Eisenstein integer a+b*omega is prime if its norm a^2-ab+b^2 is a rational prime. The six-fold symmetry comes from the six units: +/-1, +/-omega, +/-omega^2. WHAT YOU SEE: Bright colored dots are Eisenstein primes — their positions in the hexagonal lattice. The dim grid shows all Eisenstein integers. Colors encode the norm (a^2-ab+b^2). Purple highlights near the origin mark the six units of the ring. The hexagonal symmetry is clearly visible — contrast this with Gaussian primes which have 4-fold symmetry.",
	},
	"persistence": {
		"title": "PERSISTENT HOMOLOGY",
		"desc": "Topological data analysis: filter a function by a rising threshold and track which topological features (components, loops, voids) appear and disappear. Features that persist across many threshold values are signal; short-lived ones are noise. This is how topology extracts shape from data. WHAT YOU SEE: As the threshold sweeps upward, sublevel sets (colored regions) grow. The bright contour is the current threshold level set. Blue glow marks local minima — birth events where new connected components appear. Red glow marks saddle points — death events where components merge. The persistence diagram (corner inset) plots birth vs death for each feature.",
	},
	"legendrian": {
		"title": "LEGENDRIAN KNOTS",
		"desc": "Contact geometry studies a plane field xi = ker(dz - y*dx) — at each point in 3D space, a preferred plane that twists as you move. A Legendrian knot is a curve tangent to these planes everywhere. Contact geometry governs classical mechanics (Legendre transform), optics, and thermodynamics. WHAT YOU SEE: Flowing streamlines show the contact structure — the twisting plane field. The bright knot (Legendrian trefoil parameterization) threads through space always tangent to the contact planes. The twist rate accelerates as you move along y. The combination of flowing lines and the embedded knot shows how topology interacts with the geometric constraint of the contact structure.",
	},
	"bicomplex": {
		"title": "BICOMPLEX MANDELBROT",
		"desc": "Bicomplex numbers z = z1 + j*z2 form a 4D commutative algebra (unlike non-commutative quaternions). The idempotent decomposition e1=(1+k)/2, e2=(1-k)/2 splits the bicomplex Mandelbrot into two independent standard Mandelbrot sets. The bicomplex M-set is their intersection. WHAT YOU SEE: Two Mandelbrot sets evaluated independently, their escape times blended. The animated slice angle sweeps through 4D, changing which cross-section you see. When both sets keep a point bounded, it appears as the dark interior. The color variation shows where the two component Mandelbrot sets differ — regions colored by only one component show the boundary of each.",
	},
	"polytope5d": {
		"title": "5D HYPERCUBE",
		"desc": "The penteract: 5-dimensional analogue of a cube. It has 32 vertices (2^5), 80 edges, 80 square faces, 40 cubic cells, and 10 tesseract hyperfaces. Each vertex connects to exactly 5 neighbors. Four independent rotation planes allow motions impossible in lower dimensions. WHAT YOU SEE: Vertices (golden dots) connected by edges (colored lines), projected from 5D to 2D via perspective. The four simultaneous rotations at incommensurate speeds create quasi-periodic motion — the projection never exactly repeats. Edges that appear to pass through each other are actually separated in the hidden dimensions. The depth cue (brighter = closer) helps parse the 5D structure.",
	},
	"loss_landscape": {
		"title": "LOSS LANDSCAPE",
		"desc": "The function L(theta) mapping neural network parameters to error. Training is gradient descent through this terrain. Local minima trap learning, saddle points slow it, flat regions cause vanishing gradients. WHAT YOU SEE: A 3D terrain where height = loss value. Blue valleys are local minima (where networks get stuck). Yellow ridges separate basins of attraction. Red peaks are high error. Purple glow marks flat regions where gradients vanish. Contour lines show constant-loss curves. The camera orbits to reveal the full topology of learning.",
	},
}

func _setup_museum_overlay():
	museum_overlay = CanvasLayer.new()
	museum_overlay.layer = 10
	add_child(museum_overlay)

	# Title label
	museum_title = Label.new()
	museum_title.add_theme_font_size_override("font_size", 42)
	museum_title.add_theme_color_override("font_color", Color(1.0, 0.95, 0.85, 0.9))
	museum_title.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	museum_title.add_theme_constant_override("shadow_offset_x", 2)
	museum_title.add_theme_constant_override("shadow_offset_y", 2)
	museum_title.position = Vector2(60, 40)
	museum_title.size = Vector2(800, 60)
	museum_title.modulate.a = 0.0
	museum_overlay.add_child(museum_title)

	# Description label
	museum_desc = Label.new()
	museum_desc.add_theme_font_size_override("font_size", 18)
	museum_desc.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9, 0.85))
	museum_desc.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.7))
	museum_desc.add_theme_constant_override("shadow_offset_x", 1)
	museum_desc.add_theme_constant_override("shadow_offset_y", 1)
	museum_desc.position = Vector2(60, 100)
	museum_desc.size = Vector2(900, 300)
	museum_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	museum_desc.modulate.a = 0.0
	museum_overlay.add_child(museum_desc)

	# Chapter label (above title)
	museum_chapter = Label.new()
	museum_chapter.add_theme_font_size_override(&"font_size", 24)
	museum_chapter.add_theme_color_override(&"font_color", Color(0.7, 0.65, 0.5, 1.0))
	museum_chapter.add_theme_color_override(&"font_shadow_color", Color(0, 0, 0, 1.0))
	museum_chapter.add_theme_constant_override(&"shadow_offset_x", 1)
	museum_chapter.add_theme_constant_override(&"shadow_offset_y", 1)
	museum_chapter.position = Vector2(60, 15)
	museum_chapter.size = Vector2(800, 30)
	museum_chapter.modulate.a = 0.0
	museum_overlay.add_child(museum_chapter)

func show_museum_info(scene_name: String):
	if not museum_overlay:
		_setup_museum_overlay()

	var info = SCENE_INFO.get(scene_name, null)
	if not info:
		museum_title.modulate.a = 0.0
		museum_desc.modulate.a = 0.0
		return

	museum_title.text = info["title"]
	museum_desc.text = info["desc"]

	# Fade in
	if museum_tween:
		museum_tween.kill()
	museum_tween = create_tween()
	museum_title.modulate.a = 0.0
	museum_desc.modulate.a = 0.0
	if museum_chapter:
		museum_tween.parallel().tween_property(museum_chapter, "modulate:a", 1.0, 1.0)
	museum_tween.tween_property(museum_title, "modulate:a", 0.95, 1.0)
	museum_tween.parallel().tween_property(museum_desc, "modulate:a", 0.85, 1.5)
	# After 12 seconds, fade to subtle


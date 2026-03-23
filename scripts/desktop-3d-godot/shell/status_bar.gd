# Substrate Mathematical Status Bar
# Rendered as a translucent strip at the bottom of the screen
# Shows: time, CPU, RAM, GPU, battery, WiFi, current shader

extends CanvasLayer

var time_label: Label
var cpu_label: Label
var gpu_label: Label
var battery_label: Label
var wifi_label: Label
var scene_label: Label
var bg_panel: Panel
var update_timer: Timer

var prev_cpu_total: float = 0.0
var prev_cpu_idle: float = 0.0

func _ready():
	layer = 8

	# Background panel
	bg_panel = Panel.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.039, 0.055, 0.078, 0.7)  # DS panel #0a0e14
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	bg_panel.add_theme_stylebox_override(&"panel", style)
	# Position at bottom of whatever resolution
	var vp_size = Vector2(2560, 1440)  # fallback
	bg_panel.anchor_top = 1.0
	bg_panel.anchor_bottom = 1.0
	bg_panel.anchor_left = 0.0
	bg_panel.anchor_right = 1.0
	bg_panel.offset_top = -50
	bg_panel.offset_bottom = 0
	bg_panel.offset_left = 0
	bg_panel.offset_right = 0
	add_child(bg_panel)

	# Container
	var hbox = HBoxContainer.new()
	hbox.anchor_top = 1.0
	hbox.anchor_bottom = 1.0
	hbox.anchor_left = 0.0
	hbox.anchor_right = 1.0
	hbox.offset_top = -45
	hbox.offset_bottom = -5
	hbox.offset_left = 20
	hbox.offset_right = -20
	hbox.add_theme_constant_override(&"separation", 40)
	add_child(hbox)

	# Labels
	scene_label = _make_label("SUBSTRATE")
	hbox.add_child(scene_label)

	var spacer1 = Control.new()
	spacer1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer1)

	cpu_label = _make_label("CPU: --")
	hbox.add_child(cpu_label)

	gpu_label = _make_label("GPU: --")
	hbox.add_child(gpu_label)

	battery_label = _make_label("")
	hbox.add_child(battery_label)

	wifi_label = _make_label("WiFi: --")
	hbox.add_child(wifi_label)

	var spacer2 = Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hbox.add_child(spacer2)

	time_label = _make_label("00:00")
	hbox.add_child(time_label)

	# Update timer
	update_timer = Timer.new()
	update_timer.wait_time = 2.0
	update_timer.autostart = true
	update_timer.timeout.connect(_update_stats)
	add_child(update_timer)

	_update_stats()

func _make_label(text: String) -> Label:
	var l = Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", 16)
	l.add_theme_color_override(&"font_color", Color(0.831, 0.867, 0.910, 0.9))  # DS text #d4dde8
	return l

func set_scene_name(name: String):
	if scene_label:
		scene_label.text = name.to_upper()

func _update_stats():
	# Time
	var dt = Time.get_datetime_dict_from_system()
	time_label.text = "%02d:%02d" % [dt["hour"], dt["minute"]]

	# CPU
	var cpu_output = []
	OS.execute("head", ["-1", "/proc/stat"], cpu_output, true)
	if cpu_output.size() > 0:
		var parts = cpu_output[0].strip_edges().split(" ", false)
		if parts.size() >= 5:
			var total = 0.0
			for i in range(1, parts.size()):
				total += float(parts[i])
			var idle = float(parts[4])
			var diff_total = total - prev_cpu_total
			var diff_idle = idle - prev_cpu_idle
			if diff_total > 0:
				var usage = (1.0 - diff_idle / diff_total) * 100.0
				cpu_label.text = "CPU: %d%%" % int(usage)
			prev_cpu_total = total
			prev_cpu_idle = idle

	# GPU
	var gpu_output = []
	OS.execute("nvidia-smi", ["--query-gpu=temperature.gpu,utilization.gpu", "--format=csv,noheader,nounits"], gpu_output, true)
	if gpu_output.size() > 0:
		var gparts = gpu_output[0].strip_edges().split(", ")
		if gparts.size() >= 2:
			gpu_label.text = "GPU: %s%% %s°C" % [gparts[1].strip_edges(), gparts[0].strip_edges()]

	# Battery
	var bat_output = []
	OS.execute("cat", ["/sys/class/power_supply/BAT0/capacity"], bat_output, true)
	if bat_output.size() > 0 and bat_output[0].strip_edges() != "":
		var status_output = []
		OS.execute("cat", ["/sys/class/power_supply/BAT0/status"], status_output, true)
		var icon = ""
		if status_output.size() > 0 and "Charging" in status_output[0]:
			icon = "+"
		battery_label.text = "BAT: %s%%%s" % [bat_output[0].strip_edges(), icon]

	# WiFi
	var wifi_output = []
	OS.execute("nmcli", ["-t", "-f", "GENERAL.STATE", "dev", "show", "wlo1"], wifi_output, true)
	if wifi_output.size() > 0:
		var wstate = wifi_output[0].strip_edges()
		if "connected" in wstate.to_lower():
			wifi_label.text = "WiFi: OK"
		else:
			wifi_label.text = "WiFi: --"

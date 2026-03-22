# Substrate Mathematical App Launcher
# Super key activates, fuzzy search through .desktop files
# Results rendered as glowing constellation nodes

extends CanvasLayer

var search_input: LineEdit
var results_container: VBoxContainer
var bg_panel: Panel
var is_visible: bool = false
var desktop_entries: Array = []
var filtered: Array = []

signal app_launched(name: String)

func _ready():
	layer = 9
	visible = false

	# Semi-transparent background
	bg_panel = Panel.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.0, 0.0, 0.05, 0.85)
	style.corner_radius_top_left = 16
	style.corner_radius_top_right = 16
	style.corner_radius_bottom_left = 16
	style.corner_radius_bottom_right = 16
	style.content_margin_left = 30.0
	style.content_margin_right = 30.0
	style.content_margin_top = 20.0
	style.content_margin_bottom = 20.0
	bg_panel.add_theme_stylebox_override(&"panel", style)
	bg_panel.position = Vector2(680, 300)
	bg_panel.size = Vector2(1200, 600)
	add_child(bg_panel)

	# Title
	var title = Label.new()
	title.text = "SUBSTRATE"
	title.add_theme_font_size_override(&"font_size", 36)
	title.add_theme_color_override(&"font_color", Color(1.0, 0.85, 0.3, 0.9))
	title.position = Vector2(730, 320)
	title.size = Vector2(1100, 50)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(title)

	# Search input
	search_input = LineEdit.new()
	search_input.placeholder_text = "Search applications..."
	search_input.add_theme_font_size_override(&"font_size", 24)
	search_input.add_theme_color_override(&"font_color", Color(0.95, 0.95, 0.95))
	search_input.add_theme_color_override(&"font_placeholder_color", Color(0.5, 0.5, 0.6))
	var input_style = StyleBoxFlat.new()
	input_style.bg_color = Color(0.1, 0.1, 0.15, 0.8)
	input_style.corner_radius_top_left = 8
	input_style.corner_radius_top_right = 8
	input_style.corner_radius_bottom_left = 8
	input_style.corner_radius_bottom_right = 8
	input_style.content_margin_left = 15.0
	input_style.content_margin_right = 15.0
	input_style.content_margin_top = 10.0
	input_style.content_margin_bottom = 10.0
	search_input.add_theme_stylebox_override(&"normal", input_style)
	search_input.position = Vector2(730, 380)
	search_input.size = Vector2(1100, 50)
	search_input.text_changed.connect(_on_search_changed)
	search_input.text_submitted.connect(_on_search_submitted)
	add_child(search_input)

	# Results container
	var scroll = ScrollContainer.new()
	scroll.position = Vector2(730, 450)
	scroll.size = Vector2(1100, 420)
	add_child(scroll)

	results_container = VBoxContainer.new()
	results_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	results_container.add_theme_constant_override(&"separation", 5)
	scroll.add_child(results_container)

	# Load desktop entries
	_load_desktop_entries()

func _load_desktop_entries():
	desktop_entries.clear()
	var dirs = ["/usr/share/applications", OS.get_environment("HOME") + "/.local/share/applications"]
	for dir_path in dirs:
		var dir = DirAccess.open(dir_path)
		if dir:
			dir.list_dir_begin()
			var fname = dir.get_next()
			while fname != "":
				if fname.ends_with(".desktop"):
					var entry = _parse_desktop(dir_path + "/" + fname)
					if entry.size() > 0 and entry.get("NoDisplay", "false") != "true":
						desktop_entries.append(entry)
				fname = dir.get_next()
	desktop_entries.sort_custom(func(a, b): return a.get("Name", "") < b.get("Name", ""))

func _parse_desktop(path: String) -> Dictionary:
	var file = FileAccess.open(path, FileAccess.READ)
	if not file:
		return {}
	var entry = {}
	var in_desktop = false
	while not file.eof_reached():
		var line = file.get_line().strip_edges()
		if line == "[Desktop Entry]":
			in_desktop = true
			continue
		if line.begins_with("[") and in_desktop:
			break
		if in_desktop and "=" in line:
			var eq = line.find("=")
			entry[line.substr(0, eq)] = line.substr(eq + 1)
	entry["_path"] = path
	return entry

func toggle():
	is_visible = !is_visible
	visible = is_visible
	if is_visible:
		search_input.text = ""
		search_input.grab_focus()
		_show_results(desktop_entries.slice(0, 12))
	else:
		search_input.release_focus()

func _on_search_changed(text: String):
	if text == "":
		_show_results(desktop_entries.slice(0, 12))
		return
	filtered.clear()
	var query = text.to_lower()
	for entry in desktop_entries:
		var name = entry.get("Name", "").to_lower()
		var comment = entry.get("Comment", "").to_lower()
		var keywords = entry.get("Keywords", "").to_lower()
		if query in name or query in comment or query in keywords:
			filtered.append(entry)
	_show_results(filtered.slice(0, 12))

func _on_search_submitted(text: String):
	if filtered.size() > 0:
		_launch(filtered[0])
	elif desktop_entries.size() > 0 and text == "":
		_launch(desktop_entries[0])

func _show_results(entries: Array):
	for child in results_container.get_children():
		child.queue_free()
	for entry in entries:
		var btn = Button.new()
		btn.text = entry.get("Name", "Unknown")
		btn.add_theme_font_size_override(&"font_size", 18)
		btn.add_theme_color_override(&"font_color", Color(0.9, 0.9, 0.95))
		var btn_style = StyleBoxFlat.new()
		btn_style.bg_color = Color(0.08, 0.08, 0.12, 0.6)
		btn_style.corner_radius_top_left = 6
		btn_style.corner_radius_top_right = 6
		btn_style.corner_radius_bottom_left = 6
		btn_style.corner_radius_bottom_right = 6
		btn_style.content_margin_left = 15.0
		btn_style.content_margin_top = 8.0
		btn_style.content_margin_bottom = 8.0
		btn.add_theme_stylebox_override(&"normal", btn_style)
		var hover_style = btn_style.duplicate()
		hover_style.bg_color = Color(0.15, 0.12, 0.25, 0.8)
		btn.add_theme_stylebox_override(&"hover", hover_style)
		var pressed_style = btn_style.duplicate()
		pressed_style.bg_color = Color(0.2, 0.15, 0.3, 0.9)
		btn.add_theme_stylebox_override(&"pressed", pressed_style)
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var e = entry
		btn.pressed.connect(func(): _launch(e))
		# Add comment as tooltip
		var comment = entry.get("Comment", "")
		if comment != "":
			btn.tooltip_text = comment
		results_container.add_child(btn)

func _launch(entry: Dictionary):
	var exec = entry.get("Exec", "")
	if exec == "":
		return
	# Clean up Exec field (remove %f, %u, %F, %U, etc.)
	exec = exec.replace(" %f", "").replace(" %u", "").replace(" %F", "").replace(" %U", "")
	exec = exec.replace("%f", "").replace("%u", "").replace("%F", "").replace("%U", "")
	var parts = exec.split(" ", false)
	if parts.size() > 0:
		var cmd = parts[0]
		var args = parts.slice(1) if parts.size() > 1 else PackedStringArray()
		OS.create_process(cmd, args)
		app_launched.emit(entry.get("Name", ""))
		toggle()  # hide launcher

func _input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE and is_visible:
			toggle()
			get_viewport().set_input_as_handled()

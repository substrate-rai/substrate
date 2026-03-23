# Substrate Task Switcher — Death Stranding HUD
# Shows open windows as DS-styled cards on CanvasLayer 11
# Super+Tab toggles, Tab cycles, Enter focuses, Escape closes

extends CanvasLayer

const CARD_WIDTH = 300.0
const CARD_HEIGHT = 80.0
const CARD_SPACING = 12.0
const CARD_PADDING = 16.0

# DS palette
const BG_DIM = Color(0.039, 0.055, 0.078, 0.7)
const CARD_BG = Color(0.071, 0.102, 0.141, 0.88)
const CARD_SELECTED = Color(0.102, 0.137, 0.196, 0.95)
const CYAN = Color(0.118, 0.647, 0.780, 1.0)
const CYAN_BRIGHT = Color(0.239, 0.847, 0.941, 1.0)
const TEXT_PRIMARY = Color(0.831, 0.867, 0.910, 0.95)
const TEXT_MUTED = Color(0.478, 0.541, 0.604, 0.85)
const GOLD = Color(0.984, 0.753, 0.176, 0.9)

var is_visible: bool = false
var windows: Array = []
var selected_index: int = 0
var dim_panel: ColorRect
var cards_container: Control
var card_nodes: Array = []

func _ready():
	layer = 11
	visible = false

	# Dim overlay
	dim_panel = ColorRect.new()
	dim_panel.color = BG_DIM
	dim_panel.anchor_right = 1.0
	dim_panel.anchor_bottom = 1.0
	dim_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim_panel)

	# Cards container — centered
	cards_container = Control.new()
	cards_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cards_container.anchor_left = 0.0
	cards_container.anchor_right = 1.0
	cards_container.anchor_top = 0.0
	cards_container.anchor_bottom = 1.0
	add_child(cards_container)

func toggle():
	is_visible = !is_visible
	if is_visible:
		_refresh_windows()
		_build_cards()
		visible = true
		# Animate dim in
		dim_panel.color.a = 0.0
		var tw = create_tween()
		tw.tween_property(dim_panel, "color:a", 0.7, 0.2)
	else:
		visible = false

func _refresh_windows():
	windows.clear()
	var output = []
	OS.execute("i3-msg", ["-t", "get_tree"], output, true)
	if output.size() == 0:
		return
	var parsed = JSON.parse_string(output[0])
	if parsed:
		_walk_tree(parsed)
	selected_index = 0
	# Find focused window
	for i in range(windows.size()):
		if windows[i].get("focused", false):
			selected_index = i
			break

func _walk_tree(node):
	if node == null:
		return
	# Leaf window node
	if node.has("window") and node["window"] != null and node.get("name", "") != "":
		var win_class = ""
		if node.has("window_properties") and node["window_properties"] != null:
			win_class = str(node["window_properties"].get("class", ""))
		# Skip Godot wallpaper
		if win_class == "Godot":
			return
		windows.append({
			"id": node.get("id", 0),
			"title": str(node.get("name", "")),
			"class": win_class,
			"focused": node.get("focused", false),
			"workspace": _get_workspace_name(node),
		})
	# Recurse
	if node.has("nodes"):
		for child in node["nodes"]:
			_walk_tree(child)
	if node.has("floating_nodes"):
		for child in node["floating_nodes"]:
			_walk_tree(child)

func _get_workspace_name(node) -> String:
	# Walk up — not directly available, use workspace output
	var ws_output = []
	OS.execute("i3-msg", ["-t", "get_workspaces"], ws_output, true)
	if ws_output.size() > 0:
		var workspaces = JSON.parse_string(ws_output[0])
		if workspaces:
			for ws in workspaces:
				if ws.get("focused", false):
					return str(ws.get("name", ""))
	return ""

func _build_cards():
	# Clear old cards
	for node in card_nodes:
		if is_instance_valid(node):
			node.queue_free()
	card_nodes.clear()

	if windows.size() == 0:
		return

	var vp_size = get_viewport().get_visible_rect().size
	var total_width = windows.size() * (CARD_WIDTH + CARD_SPACING) - CARD_SPACING
	var start_x = (vp_size.x - total_width) / 2.0
	var center_y = vp_size.y / 2.0 - CARD_HEIGHT / 2.0

	for i in range(windows.size()):
		var win = windows[i]
		var card = _make_card(win, i == selected_index)
		var target_x = start_x + i * (CARD_WIDTH + CARD_SPACING)

		# Start below screen for slide-in animation
		card.position = Vector2(target_x, vp_size.y + 50)
		cards_container.add_child(card)
		card_nodes.append(card)

		# Staggered slide-in
		var tw = create_tween()
		tw.tween_property(card, "position:y", center_y, 0.25 + i * 0.05).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

func _make_card(win: Dictionary, selected: bool) -> PanelContainer:
	var card = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = CARD_SELECTED if selected else CARD_BG
	style.border_color = CYAN if selected else Color(0.165, 0.227, 0.290, 0.6)
	style.border_width_left = 3 if selected else 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 6
	style.corner_radius_top_right = 6
	style.corner_radius_bottom_left = 6
	style.corner_radius_bottom_right = 6
	style.content_margin_left = CARD_PADDING
	style.content_margin_right = CARD_PADDING
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	card.add_theme_stylebox_override(&"panel", style)
	card.custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var vbox = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override(&"separation", 4)
	card.add_child(vbox)

	# Class label (e.g. "KITTY", "FIREFOX")
	var class_label = Label.new()
	class_label.text = str(win.get("class", "")).to_upper()
	class_label.add_theme_font_size_override(&"font_size", 11)
	class_label.add_theme_color_override(&"font_color", CYAN_BRIGHT if selected else CYAN)
	vbox.add_child(class_label)

	# Title (truncated)
	var title_label = Label.new()
	var title = str(win.get("title", ""))
	if title.length() > 35:
		title = title.substr(0, 32) + "..."
	title_label.text = title
	title_label.add_theme_font_size_override(&"font_size", 13)
	title_label.add_theme_color_override(&"font_color", TEXT_PRIMARY if selected else TEXT_MUTED)
	vbox.add_child(title_label)

	# Workspace badge
	var ws = str(win.get("workspace", ""))
	if ws != "":
		var ws_label = Label.new()
		ws_label.text = ws
		ws_label.add_theme_font_size_override(&"font_size", 10)
		ws_label.add_theme_color_override(&"font_color", GOLD)
		vbox.add_child(ws_label)

	return card

func _update_selection():
	for i in range(card_nodes.size()):
		if not is_instance_valid(card_nodes[i]):
			continue
		var style = card_nodes[i].get_theme_stylebox(&"panel").duplicate() as StyleBoxFlat
		var selected = (i == selected_index)
		style.bg_color = CARD_SELECTED if selected else CARD_BG
		style.border_color = CYAN if selected else Color(0.165, 0.227, 0.290, 0.6)
		style.border_width_left = 3 if selected else 1
		card_nodes[i].add_theme_stylebox_override(&"panel", style)

		# Update text colors
		var vbox = card_nodes[i].get_child(0)
		if vbox and vbox.get_child_count() >= 2:
			vbox.get_child(0).add_theme_color_override(&"font_color", CYAN_BRIGHT if selected else CYAN)
			vbox.get_child(1).add_theme_color_override(&"font_color", TEXT_PRIMARY if selected else TEXT_MUTED)

func _focus_selected():
	if selected_index >= 0 and selected_index < windows.size():
		var win_id = windows[selected_index].get("id", 0)
		if win_id > 0:
			OS.execute("i3-msg", ["[con_id=" + str(win_id) + "] focus"])
	toggle()

func _input(event):
	if not is_visible:
		return
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_ESCAPE:
				toggle()
				get_viewport().set_input_as_handled()
			KEY_TAB:
				if windows.size() > 0:
					if event.shift_pressed:
						selected_index = (selected_index - 1 + windows.size()) % windows.size()
					else:
						selected_index = (selected_index + 1) % windows.size()
					_update_selection()
				get_viewport().set_input_as_handled()
			KEY_ENTER:
				_focus_selected()
				get_viewport().set_input_as_handled()
			KEY_LEFT:
				if windows.size() > 0:
					selected_index = (selected_index - 1 + windows.size()) % windows.size()
					_update_selection()
				get_viewport().set_input_as_handled()
			KEY_RIGHT:
				if windows.size() > 0:
					selected_index = (selected_index + 1) % windows.size()
					_update_selection()
				get_viewport().set_input_as_handled()

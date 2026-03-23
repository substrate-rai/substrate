# Substrate Notification System
# Toast notifications on CanvasLayer 10, top-right corner
# Supports categories (info, warning, error), queue, auto-dismiss, slide-in animation
# Accepts notifications via push_notification() or TCP command

extends CanvasLayer

const MAX_VISIBLE = 3
const DEFAULT_DURATION = 5.0
const SLIDE_DURATION = 0.3
const TOAST_WIDTH = 420.0
const TOAST_MARGIN = 12.0
const RIGHT_MARGIN = 20.0
const TOP_MARGIN = 20.0

# Category colors — Death Stranding palette
const COLORS = {
	"info": Color(0.118, 0.647, 0.780, 0.95),    # Bridges Cyan #1EA5C7
	"warning": Color(0.984, 0.753, 0.176, 0.95), # Porter Gold #FBC02D
	"error": Color(0.769, 0.188, 0.188, 0.95),   # BT Red #c43030
	"system": Color(0.239, 0.847, 0.941, 0.95),  # Cyan Bright #3dd8f0
}

var toast_queue: Array = []  # pending notifications
var active_toasts: Array = []  # currently displayed {panel, timer, tween}
var toast_container: Control
var vp_width: float = 2560.0

func _ready():
	layer = 10

	# Container anchored to top-right
	toast_container = Control.new()
	toast_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_container.anchor_left = 0.0
	toast_container.anchor_right = 1.0
	toast_container.anchor_top = 0.0
	toast_container.anchor_bottom = 1.0
	add_child(toast_container)

	var vp = get_viewport()
	if vp:
		var vp_size = vp.get_visible_rect().size
		if vp_size.x > 0:
			vp_width = vp_size.x

func push_notification(title: String, body: String, category: String = "info", duration: float = DEFAULT_DURATION):
	var notification = {
		"title": title,
		"body": body,
		"category": category,
		"duration": duration,
	}
	if active_toasts.size() < MAX_VISIBLE:
		_show_toast(notification)
	else:
		toast_queue.append(notification)

func _show_toast(notification: Dictionary):
	var category = notification.get("category", "info")
	var accent = COLORS.get(category, COLORS["info"])
	var duration = notification.get("duration", DEFAULT_DURATION)

	# PanelContainer auto-sizes to fit children
	var panel = PanelContainer.new()
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.039, 0.055, 0.078, 0.92)  # DS panel #0a0e14
	style.border_color = accent
	style.border_width_left = 4
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.corner_radius_top_left = 8
	style.corner_radius_top_right = 8
	style.corner_radius_bottom_left = 8
	style.corner_radius_bottom_right = 8
	style.content_margin_left = 16.0
	style.content_margin_right = 16.0
	style.content_margin_top = 12.0
	style.content_margin_bottom = 12.0
	panel.add_theme_stylebox_override(&"panel", style)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.custom_minimum_size.x = TOAST_WIDTH

	# VBox for title + body
	var vbox = VBoxContainer.new()
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_theme_constant_override(&"separation", 4)
	panel.add_child(vbox)

	# Category badge + title row
	var title_row = HBoxContainer.new()
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_row.add_theme_constant_override(&"separation", 8)
	vbox.add_child(title_row)

	var badge = Label.new()
	badge.text = category.to_upper()
	badge.add_theme_font_size_override(&"font_size", 11)
	badge.add_theme_color_override(&"font_color", accent)
	title_row.add_child(badge)

	var title_label = Label.new()
	title_label.text = notification.get("title", "")
	title_label.add_theme_font_size_override(&"font_size", 15)
	title_label.add_theme_color_override(&"font_color", Color(0.95, 0.95, 0.95, 0.95))
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(title_label)

	# Body text
	var body_text = notification.get("body", "")
	if body_text != "":
		var body_label = Label.new()
		body_label.text = body_text
		body_label.add_theme_font_size_override(&"font_size", 13)
		body_label.add_theme_color_override(&"font_color", Color(0.75, 0.75, 0.8, 0.85))
		body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body_label.custom_minimum_size.x = TOAST_WIDTH - 40
		vbox.add_child(body_label)

	# Position — start offscreen right
	var slot_y = TOP_MARGIN + active_toasts.size() * (80 + TOAST_MARGIN)
	var target_x = vp_width - TOAST_WIDTH - RIGHT_MARGIN
	panel.position = Vector2(vp_width + 10, slot_y)

	toast_container.add_child(panel)

	# Slide in
	var tween = create_tween()
	tween.tween_property(panel, "position:x", target_x, SLIDE_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Auto-dismiss timer
	var timer = Timer.new()
	timer.wait_time = duration
	timer.one_shot = true
	add_child(timer)

	var toast_data = {"panel": panel, "timer": timer, "slot": active_toasts.size()}
	active_toasts.append(toast_data)

	timer.timeout.connect(_dismiss_toast.bind(toast_data))
	timer.start()

func _dismiss_toast(toast_data: Dictionary):
	var panel = toast_data.get("panel")
	var timer = toast_data.get("timer")

	if not is_instance_valid(panel):
		return

	# Slide out
	var tween = create_tween()
	tween.tween_property(panel, "position:x", vp_width + 10, SLIDE_DURATION).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	tween.tween_callback(func():
		if is_instance_valid(panel):
			panel.queue_free()
		if is_instance_valid(timer):
			timer.queue_free()
	)

	# Remove from active list and reflow
	active_toasts.erase(toast_data)
	_reflow_toasts()

	# Show next queued notification
	if toast_queue.size() > 0 and active_toasts.size() < MAX_VISIBLE:
		var next = toast_queue.pop_front()
		_show_toast(next)

func _reflow_toasts():
	for i in range(active_toasts.size()):
		var panel = active_toasts[i].get("panel")
		if is_instance_valid(panel):
			var target_y = TOP_MARGIN + i * (80 + TOAST_MARGIN)
			var tw = create_tween()
			tw.tween_property(panel, "position:y", target_y, 0.2).set_trans(Tween.TRANS_CUBIC)
			active_toasts[i]["slot"] = i

func clear_all():
	for toast_data in active_toasts.duplicate():
		var panel = toast_data.get("panel")
		var timer = toast_data.get("timer")
		if is_instance_valid(panel):
			panel.queue_free()
		if is_instance_valid(timer):
			timer.queue_free()
	active_toasts.clear()
	toast_queue.clear()

func get_queue_size() -> int:
	return toast_queue.size() + active_toasts.size()

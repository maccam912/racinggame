class_name TouchDriving
extends Control

signal action_pressed(action: String)

var captures: Dictionary = {}
var controls: Dictionary = {}
var steer: float = 0.0
var auto_accelerate: bool = true
var enabled: bool = true
var unit: float = 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(rebuild)
	rebuild()


func rebuild() -> void:
	clear()
	var pixels := Vector2(DisplayServer.window_get_size())
	unit = size.y / maxf(pixels.y, 1) * maxf(160, DisplayServer.screen_get_dpi()) / 160.0 if OS.has_feature("mobile") else 1.5
	var safe := Rect2(Vector2.ZERO, size)
	if OS.has_feature("mobile"):
		var physical := DisplayServer.get_display_safe_area()
		safe = Rect2(Vector2(physical.position) * size / pixels, Vector2(physical.size) * size / pixels)
	var layout := {"steer": [Vector2(.18, .78), Vector2(180, 100)], "brake": [Vector2(.83, .80), Vector2(88, 88)], "handbrake": [Vector2(.91, .59), Vector2(72, 72)], "recover": [Vector2(.72, .59), Vector2(56, 56)], "camera": [Vector2(.58, .92), Vector2(48, 48)], "look_back": [Vector2(.47, .92), Vector2(48, 48)], "pause": [Vector2(.95, .08), Vector2(48, 48)]}
	for action: String in layout:
		var dimensions: Vector2 = layout[action][1] * unit
		var center: Vector2 = safe.position + safe.size * layout[action][0]
		center = center.clamp(safe.position + dimensions / 2 + Vector2.ONE * 16 * unit, safe.end - dimensions / 2 - Vector2.ONE * 16 * unit)
		controls[action] = Rect2(center - dimensions / 2, dimensions)
	queue_redraw()


func pointer_down(id: int, at: Vector2) -> void:
	if not enabled:
		return
	for action: String in controls:
		if controls[action].has_point(at) and not captures.values().any(func(c: Dictionary) -> bool: return c.action == action):
			captures[id] = {"action": action, "active": true}
			if action == "steer":
				update_steer(at)
			elif action in ["camera", "pause"]:
				action_pressed.emit(action)
			queue_redraw()
			return


func pointer_move(id: int, at: Vector2) -> void:
	if not captures.has(id):
		return
	var action: String = captures[id].action
	if action == "steer":
		update_steer(at)
	else:
		captures[id].active = controls[action].grow(24 * unit).has_point(at)
	queue_redraw()


func pointer_up(id: int) -> void:
	if captures.has(id) and captures[id].action == "steer":
		steer = 0.0
	captures.erase(id)
	queue_redraw()


func update_steer(at: Vector2) -> void:
	var displacement: float = (at.x - controls.steer.get_center().x) / unit
	steer = signf(displacement) * clampf((absf(displacement) - 8) / 62, 0, 1)


func held(action: String) -> bool:
	return captures.values().any(func(c: Dictionary) -> bool: return c.action == action and c.active)


func has_driving_capture() -> bool:
	return not captures.is_empty()


func clear() -> void:
	captures.clear()
	steer = 0.0
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not enabled or not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled:
			pointer_down(event.index, event.position)
		else:
			pointer_up(event.index)
	elif event is InputEventScreenDrag:
		pointer_move(event.index, event.position)


func _draw() -> void:
	for action: String in controls:
		var rect: Rect2 = controls[action]
		var color := Color(.09, .17, .25, .7 if held(action) else .3)
		draw_style_box(style(color), rect)
		if action in ["recover", "look_back", "camera"]:
			draw_icon(action, rect.get_center())
			continue
		var text: String = {"steer": "STEER", "brake": "BRAKE", "handbrake": "SLIDE", "recover": "RESET", "camera": "CAM", "look_back": "LOOK", "pause": "Ⅱ"}[action]
		draw_string(ThemeDB.fallback_font, rect.get_center() + Vector2(-rect.size.x * .40, 7 * unit), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x * .8, int(16 * unit), Color.html("F5EBD3"))
		if action == "steer":
			draw_circle(rect.get_center() + Vector2(steer * 70 * unit, 0), 12 * unit, Color.html("F3CD48"))


func draw_icon(action: String, center: Vector2) -> void:
	var cream := Color.html("F5EBD3")
	if action == "recover":
		draw_arc(center, 14 * unit, -.3, TAU - 1.0, 32, cream, 2 * unit, true)
		var tip := center + Vector2(14, -4) * unit
		draw_colored_polygon(PackedVector2Array([tip, tip + Vector2(-9, -5) * unit, tip + Vector2(-5, 5) * unit]), cream)
	elif action == "look_back":
		draw_polyline(PackedVector2Array([center + Vector2(13, 10) * unit, center + Vector2(13, -8) * unit, center + Vector2(-11, -8) * unit]), cream, 3 * unit, true)
		draw_colored_polygon(PackedVector2Array([center + Vector2(-16, -8) * unit, center + Vector2(-5, -16) * unit, center + Vector2(-5, 0) * unit]), cream)
	else:
		draw_rect(Rect2(center - Vector2(15, 10) * unit, Vector2(30, 22) * unit), cream, false, 2 * unit)
		draw_circle(center + Vector2(0, 1) * unit, 6 * unit, cream, false, 2 * unit, true)
		draw_rect(Rect2(center + Vector2(-9, -15) * unit, Vector2(10, 5) * unit), cream)


func style(fill: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = Color.html("F5EBD3")
	box.set_border_width_all(2)
	box.set_corner_radius_all(int(8 * unit))
	return box

class_name TouchDriving
extends Control

signal action_pressed(action: String)
signal capture_started(action: String)
signal capture_cancelled(action: String)
signal captures_cleared
signal layout_reset(profile: String)

var captures: Dictionary = {}
var controls: Dictionary = {}
var steer: float = 0.0
var auto_accelerate: bool = true
var enabled: bool = true
var unit: float = 1.0
var steering_style: String = "slider"
var button_scale: float = 1.0
var opacity: float = .6
var left_handed: bool = false
var suppressed: bool = false
var suppressed_at: int = 0
var layout_supported: bool = true
var logical_safe: Rect2
var layouts: Dictionary = {}
var reset_notices: Dictionary = {}
var recovery_armed: bool = false:
	set(value):
		if recovery_armed!=value:
			recovery_armed = value
			queue_redraw()



func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	resized.connect(rebuild)
	rebuild()


func rebuild() -> void:
	clear()
	var geometry := safe_geometry(size)
	unit = geometry.unit
	logical_safe = geometry.safe
	layout_supported = logical_safe.size.y >= 320
	var base := build_layout(logical_safe, auto_accelerate, steering_style, button_scale, left_handed)
	var key := TouchLayoutBook.profile_key(logical_safe,auto_accelerate,steering_style,left_handed)
	var resolved := TouchLayoutBook.resolve(base,logical_safe,layouts.get(key,{}))
	controls = resolved.controls
	if resolved.reset and not reset_notices.has(key):
		reset_notices[key] = true
		layout_reset.emit(key)
	if controls.is_empty():
		layout_supported = false
	for action: String in controls:
		var rect: Rect2 = controls[action]
		controls[action] = Rect2(rect.position * unit, rect.size * unit)
	queue_redraw()


static func build_layout(safe: Rect2, automatic: bool, steering: String, scale_factor: float, mirrored: bool) -> Dictionary:
	if safe.size.y < 320:
		return {}
	var definitions := {"steer":[Vector2(.18,.78),Vector2(180,100)], "brake":[Vector2(.83,.80),Vector2(88,88)], "handbrake":[Vector2(.91,.59),Vector2(72,72)], "recover":[Vector2(.72,.59),Vector2(56,56)], "camera":[Vector2(.58,.92),Vector2(48,48)], "look_back":[Vector2(.47,.92),Vector2(48,48)], "pause":[Vector2(.95,.08),Vector2(48,48)]}
	if not automatic:
		definitions.throttle = [Vector2(.90,.81),Vector2(88,88)]
		definitions.brake[0] = Vector2(.75,.81)
		definitions.handbrake[0] = Vector2(.90,.57)
		definitions.recover[0] = Vector2(.74,.57)
	if steering == "buttons":
		definitions.erase("steer")
		definitions.left = [Vector2(.11,.78),Vector2(72,72)]
		definitions.right = [Vector2(.25,.78),Vector2(72,72)]
	for reduced: bool in [false, true]:
		var result: Dictionary = {}
		for action: String in definitions:
			var base: Vector2 = definitions[action][1]
			var minimum := Vector2(150,90) if action == "steer" else Vector2.ONE * (72 if action in ["throttle","brake","left","right"] else 48)
			var dimensions := minimum if reduced else (base * scale_factor).max(minimum)
			var fraction: Vector2 = definitions[action][0]
			if mirrored and action not in ["camera","look_back","pause"]:
				fraction.x = 1 - fraction.x
			var center := safe.position + safe.size * fraction
			center = clamp_center(safe,center,dimensions,action)
			result[action] = Rect2(center - dimensions / 2, dimensions)
		if mirrored and result.has("left"):
			var temporary: Rect2 = result.left
			result.left = result.right
			result.right = temporary
		if result.has("left"):
			for attempt in range(40):
				if not result.left.grow(2).intersects(result.right):
					break
				var first := "left"
				var second := "right"
				if result[first].position.x >= safe.position.x + 18:
					result[first].position.x -= 2
				result[second].position.x += 2
		# Keep manual pedals beside each other when the safe width is small.
		if result.has("throttle"):
			for attempt in range(40):
				if not result.brake.grow(2).intersects(result.throttle):
					break
				result.brake.position.x += 4 if mirrored else -4
		for action: String in ["handbrake","recover"]:
			for attempt in range(40):
				var overlaps := false
				for other: String in result:
					if other != action and result[action].grow(2).intersects(result[other]):
						overlaps = true
				if not overlaps:
					break
				result[action].position.y -= 4
		if legal_layout(result, safe):
			return result
	return {}


static func clamp_center(safe: Rect2,center: Vector2,dimensions: Vector2,action: String) -> Vector2:
	var margin := dimensions/2+Vector2.ONE*16
	if action in ["steer","left","right","throttle","brake"]:
		margin = margin.max(Vector2.ONE*64)
	return center.clamp(safe.position+margin,safe.end-margin)


static func legal_layout(layout: Dictionary, safe: Rect2) -> bool:
	for action: String in layout:
		var rect: Rect2 = layout[action]
		var minimum := Vector2(150,90) if action=="steer" else Vector2.ONE*(72 if action in ["left","right","throttle","brake"] else 48)
		if not safe.grow(-16).encloses(rect) or rect.size.x<minimum.x or rect.size.y<minimum.y:
			return false
		if action in ["steer","left","right","throttle","brake"] and (rect.get_center().x<safe.position.x+64 or rect.get_center().y<safe.position.y+64 or rect.get_center().x>safe.end.x-64 or rect.get_center().y>safe.end.y-64):
			return false
		for other: String in layout:
			if action != other and rect.intersects(layout[other]):
				return false
	return true


func set_suppressed(value: bool) -> void:
	if suppressed == value:
		return
	suppressed = value
	suppressed_at = Time.get_ticks_msec()
	if value:
		clear()


func _process(dt: float) -> void:
	var target := .15 if suppressed and Time.get_ticks_msec() - suppressed_at >= 2000 else 1.0
	self_modulate.a = move_toward(self_modulate.a, target, dt * 4)


func pointer_down(id: int, at: Vector2) -> void:
	if not enabled or captures.has(id):
		return
	for action: String in controls:
		if controls[action].has_point(at) and not captures.values().any(func(c: Dictionary) -> bool: return c.action == action):
			captures[id] = {"action": action, "active": true}
			capture_started.emit(action)
			if action == "steer":
				update_steer(at)
			elif action in ["left", "right"]:
				update_buttons()
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
		var active: bool = controls[action].grow(24 * unit).has_point(at)
		if captures[id].active and not active: capture_cancelled.emit(action)
		captures[id].active = active
		update_buttons()
	queue_redraw()


func pointer_up(id: int, cancelled: bool = false) -> void:
	if cancelled and captures.has(id): capture_cancelled.emit(str(captures[id].action))
	if captures.has(id) and captures[id].action == "steer":
		steer = 0.0
	captures.erase(id)
	update_buttons()
	queue_redraw()


func update_steer(at: Vector2) -> void:
	var displacement: float = (at.x - controls.steer.get_center().x) / unit
	steer = signf(displacement) * clampf((absf(displacement) - 8) / 62, 0, 1)


func update_buttons() -> void:
	if steering_style == "buttons":
		steer = float(held("right")) - float(held("left"))


func held(action: String) -> bool:
	return captures.values().any(func(c: Dictionary) -> bool: return c.action == action and c.active)


func has_driving_capture() -> bool:
	return not captures.is_empty()


func clear() -> void:
	captures.clear()
	captures_cleared.emit()
	steer = 0.0
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not enabled or not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled:
			pointer_down(event.index, event.position)
		else:
			pointer_up(event.index,event.canceled)
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
		var text: String = {"steer": "STEER", "brake": "BRAKE", "handbrake": "SLIDE", "recover": "RESET", "camera": "CAM", "look_back": "LOOK", "pause": "Ⅱ", "throttle":"GO", "left":"◀", "right":"▶"}[action]
		draw_string(ThemeDB.fallback_font, rect.get_center() + Vector2(-rect.size.x * .40, 7 * unit), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x * .8, int(16 * unit), Color(Color.html("F5EBD3"), minf(1, opacity / .6)))
		if action == "steer":
			draw_circle(rect.get_center() + Vector2(steer * 70 * unit, 0), 12 * unit, Color(Color.html("F3CD48"), minf(1, opacity / .6)))


func draw_icon(action: String, center: Vector2) -> void:
	var cream := Color(Color.html("F5EBD3"), minf(1, opacity / .6))
	if action == "recover":
		if recovery_armed:
			draw_polyline(PackedVector2Array([center+Vector2(-12,0)*unit,center+Vector2(-3,10)*unit,center+Vector2(14,-12)*unit]),Color.html("F3CD48"),4*unit,true)
			return
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
	box.bg_color = Color(fill, clampf(fill.a * opacity / .6, 0, 1))
	box.border_color = Color(Color.html("F5EBD3"), minf(1, opacity / .6))
	box.set_border_width_all(2)
	box.set_corner_radius_all(int(8 * unit))
	return box


static func safe_geometry(canvas: Vector2) -> Dictionary:
	var pixels := Vector2(DisplayServer.window_get_size())
	var scale_unit := canvas.y / maxf(pixels.y, 1) * maxf(160, DisplayServer.screen_get_dpi()) / 160.0 if OS.has_feature("mobile") else 1.5
	var safe := Rect2(Vector2.ZERO, canvas)
	if OS.has_feature("mobile"):
		var physical := DisplayServer.get_display_safe_area()
		safe = Rect2(Vector2(physical.position) * canvas / pixels, Vector2(physical.size) * canvas / pixels)
	return {"unit":scale_unit, "safe":Rect2(safe.position / scale_unit, safe.size / scale_unit)}

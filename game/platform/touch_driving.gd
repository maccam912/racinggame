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
var boost_available: bool = true
var boost_charges: int = 3
var unit: float = 1.0
var steering_style: String = "slider"
var button_scale: float = 1.0
var opacity: float = .6
var high_contrast: bool = false
var display_font: Font = preload("res://assets/fonts/heading.tres")
var plate_cache: Dictionary = {}
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
	plate_cache.clear()
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
	var definitions := {"boost":[Vector2(.87,.34),Vector2(64,64)], "steer":[Vector2(.18,.78),Vector2(180,100)], "brake":[Vector2(.83,.80),Vector2(88,88)], "handbrake":[Vector2(.91,.59),Vector2(72,72)], "recover":[Vector2(.72,.59),Vector2(56,56)], "camera":[Vector2(.58,.92),Vector2(48,48)], "look_back":[Vector2(.47,.92),Vector2(48,48)], "pause":[Vector2(.95,.08),Vector2(48,48)]}
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
		for action: String in ["handbrake","recover","boost"]:
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
		if action == "boost" and not boost_available: continue
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
		if action == "boost" and not boost_available: continue
		var rect: Rect2 = controls[action]
		draw_style_box(visual_style(action),rect)
		if action in ["boost","recover","look_back","camera","pause","left","right"]:
			draw_icon(action,rect.get_center()-Vector2(0,5)*unit if action == "boost" else rect.get_center())
			if action == "boost":
				for charge in range(3):
					var at := Vector2(rect.get_center().x+(charge-1)*11*unit,rect.end.y-10*unit)
					draw_circle(at,3.5*unit,UIFactory.YELLOW if charge < boost_charges else UIFactory.NAVY)
			continue
		if action=="steer":
			draw_steering(rect)
			continue
		var text: String = {"brake":"BRAKE","handbrake":"SLIDE","throttle":"GO"}[action]
		var font_size := roundi(16*unit)
		if display_font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>rect.size.x-12*unit:
			draw_icon(action,rect.get_center())
			continue
		var at := Vector2(rect.position.x+6*unit,rect.get_center().y+(display_font.get_ascent(font_size)-display_font.get_descent(font_size))*.5)
		draw_string_outline(display_font,at,text,HORIZONTAL_ALIGNMENT_CENTER,rect.size.x-12*unit,font_size,roundi(2*unit),Color("101333"))
		draw_string(display_font,at,text,HORIZONTAL_ALIGNMENT_CENTER,rect.size.x-12*unit,font_size,Color(UIFactory.CREAM,minf(1,opacity/.6)))


func visual_style(action: String) -> StyleBox:
	var active := held(action) or action=="recover" and recovery_armed
	if high_contrast: return style(Color(.04,.08,.13,.85 if active else .55))
	var kind := "pressed" if held(action) else "hover" if active else "button"
	if not plate_cache.has(kind): plate_cache[kind] = UIFactory.chrome_box(kind,unit)
	var box: StyleBoxTexture = plate_cache[kind]
	box.modulate_color = Color(1,1,1,clampf(opacity*(1.25 if active else .78),0,1))
	return box


func draw_steering(rect: Rect2) -> void:
	var alpha := minf(1,opacity/.6)
	var middle := rect.get_center()
	# Compact profiles keep the diamond inside its frame. Input travel stays 70 dp.
	var span := minf(70*unit,rect.size.x*.5-16*unit)
	# A stationary tick rail gives the thumb a clear centre and travel range.
	for index in range(-7,8):
		var x := middle.x+index*span/7
		var tall := 10.0 if index==0 else 6.0 if index%2==0 else 3.0
		draw_line(Vector2(x,middle.y-tall*unit),Vector2(x,middle.y+tall*unit),Color(UIFactory.CREAM,alpha*.8),maxf(1,unit))
	var label_at := Vector2(rect.position.x,middle.y-23*unit)
	draw_string(display_font,label_at,"STEER",HORIZONTAL_ALIGNMENT_CENTER,rect.size.x,roundi(16*unit),Color(UIFactory.CREAM,alpha))
	var center := middle+Vector2(steer*span,0)
	var points := PackedVector2Array([center+Vector2(0,-13)*unit,center+Vector2(13,0)*unit,center+Vector2(0,13)*unit,center+Vector2(-13,0)*unit])
	draw_colored_polygon(points,Color(UIFactory.YELLOW,alpha))
	points.append(points[0])
	draw_polyline(points,Color(Color("FFF4C7"),alpha),maxf(1,unit))
	draw_line(center-Vector2(6,5)*unit,center+Vector2(4,5)*unit,Color(UIFactory.CREAM,alpha),2*unit)


func draw_icon(action: String, center: Vector2) -> void:
	var cream := Color(Color.html("F5EBD3"), minf(1, opacity / .6))
	var id := "action_ui_accept" if action=="recover" and recovery_armed else "action_steer_left" if action=="left" else "action_steer_right" if action=="right" else "action_"+action
	var tint := Color(UIFactory.YELLOW,cream.a) if action=="recover" and recovery_armed else Color(1,1,1,cream.a)
	draw_texture_rect(UIIcons.texture(id),Rect2(center-Vector2.ONE*16*unit,Vector2.ONE*32*unit),false,tint)


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

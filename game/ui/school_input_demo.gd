class_name SchoolInputDemo
extends Control
## A noninteractive demonstration reads time/preferences, never vehicle input.

var lesson_index: int = 0
var turn_action: String = "steer_right"
var hints: Dictionary = {}
var unit: float = 1
var ui_scale: float = 1
var reduce_motion: bool = false
var hold_assistance: bool = false
var suspended: bool = false
var elapsed: float = 0
var keycaps: Array[Label] = []

func actions() -> Array[String]:
	match lesson_index:
		0: return ["accelerate","brake"]
		1: return ["steer_left","steer_right"]
		2: return ["brake",turn_action]
		3: return [turn_action,"handbrake"]
	return ["recover"]

func illustration(at: float) -> Dictionary:
	var active: Array[String] = []
	var progress := 0.0
	if reduce_motion: return {"active":active,"progress":progress}
	match lesson_index:
		0:
			var phase := fposmod(at,3.6)
			if phase<1.8: active.append("accelerate")
			elif phase<3.0: active.append("brake")
		1:
			var steer := sin(at*PI/1.4)
			if absf(steer)>.15: active.append("steer_right" if steer>0 else "steer_left")
		2:
			var phase := fposmod(at,3.0)
			if phase<1: active.append("brake")
			elif phase<2.3: active.append(turn_action)
		3:
			var phase := fposmod(at,3.4)
			if phase>.2 and phase<1.9: active.append(turn_action)
			if phase>.6 and phase<1.1: active.append("handbrake")
		4:
			var phase := fposmod(at,2.4)
			if hold_assistance:
				if phase>=.2 and phase<.34 or phase>=.7 and phase<.84: active.append("recover")
				progress = .5 if phase>=.34 and phase<.7 else 1.0 if phase>=.7 and phase<1.0 else 0.0
			elif phase>=.3 and phase<=.8:
				active.append("recover")
				progress = clampf((phase-.3)/.5,0,1)
	return {"active":active,"progress":progress}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(128,72)*unit
	for action: String in actions():
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_override("font",RaceHUD.HUD_FONT)
		label.add_theme_font_size_override("font_size",roundi(16*unit*ui_scale))
		label.add_theme_color_override("font_color",UIFactory.CREAM)
		label.set_meta("action",action)
		add_child(label)
		keycaps.append(label)

func _process(dt: float) -> void:
	if not suspended and not reduce_motion: elapsed += dt
	var count := actions().size()
	for index in range(keycaps.size()):
		var label := keycaps[index]
		var action: String = label.get_meta("action")
		label.text = str(hints.get(action,"")).split(" / ")[0]
		if label.text==I18n.t("touch.hint.auto"): label.text = I18n.t("school.auto_short")
		if label.get_theme_font_size("font_size")!=roundi(16*unit*ui_scale): label.add_theme_font_size_override("font_size",roundi(16*unit*ui_scale))
		label.position = Vector2(size.x/2+(index-count/2.0)*60*unit,46*unit)
		label.size = Vector2(56,24)*unit
		if count==1:
			label.position.x = 0
			label.size.x = size.x
	queue_redraw()

func _draw() -> void:
	var values := illustration(elapsed)
	var sequence := actions()
	for index in range(sequence.size()):
		var action := sequence[index]
		var pressed: bool = action in values.active
		var at := Vector2(size.x/2+(index-sequence.size()/2.0)*60*unit,0)
		var rect := Rect2(at,Vector2(56,44)*unit)
		var style := StyleBoxFlat.new()
		style.bg_color = Color("20515A") if pressed else UIFactory.NAVY
		style.border_color = UIFactory.YELLOW if pressed else UIFactory.CREAM
		style.set_border_width_all(maxi(1,roundi(2*unit)))
		style.set_corner_radius_all(roundi(5*unit))
		draw_style_box(style,rect)
		draw_texture_rect(UIIcons.texture("action_"+action),Rect2(at+Vector2(15,7)*unit,Vector2(26,26)*unit),false)
		if pressed:
			var center := at+Vector2(28,38)*unit
			draw_colored_polygon(PackedVector2Array([center+Vector2(-4,-3)*unit,center+Vector2(4,-3)*unit,center+Vector2(0,2)*unit]),UIFactory.YELLOW)
		if action=="recover" and float(values.progress)>0:
			draw_arc(at+Vector2(28,21)*unit,18*unit,-PI/2,-PI/2+TAU*float(values.progress),32,UIFactory.YELLOW,2*unit,true)

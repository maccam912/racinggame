class_name SchoolOverlay
extends Control

var lesson: SchoolLesson
var state: VehicleState
var unit: float = 1
var hints: Dictionary = {}
var elapsed: float = 0
var panel := PanelContainer.new()
var instruction := Label.new()
var inputs := Label.new()
var last_caption: String = ""

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.show_behind_parent = true
	var box := StyleBoxFlat.new()
	box.bg_color = UIFactory.NAVY
	box.set_corner_radius_all(5)
	box.content_margin_left=36*unit
	box.content_margin_right=16*unit
	box.content_margin_top=12*unit
	box.content_margin_bottom=12*unit
	panel.add_theme_stylebox_override("panel",box)
	var list:=VBoxContainer.new()
	for label: Label in [instruction,inputs]:
		label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_override("font",preload("res://assets/fonts/Barlow-SemiBold.ttf"))
		label.add_theme_font_size_override("font_size",int(20*unit))
		label.add_theme_color_override("font_color",UIFactory.CREAM if label==instruction else UIFactory.TURQUOISE)
		list.add_child(label)
	panel.add_child(list)
	add_child(panel)
	resized.connect(layout)
	layout()

func layout() -> void:
	panel.position=Vector2(size.x*.24,size.y*.10)
	panel.size=Vector2(size.x*.52,110*unit)

func _process(dt: float) -> void:
	elapsed+=dt
	if hints.is_empty():
		return
	var values: Array = [hints.accelerate,hints.brake] if lesson.index==0 else [hints.steer_left,hints.steer_right] if lesson.index==1 else [hints.accelerate,hints.brake,hints.steer_left,hints.steer_right] if lesson.index==2 else [hints.accelerate,hints.steer_left,hints.steer_right,hints.handbrake] if lesson.index==3 else [hints.recover]
	var caption:=I18n.t("school.controls."+str(lesson.index),values)
	if caption!=last_caption:
		last_caption=caption
		instruction.text=I18n.t("school."+str(lesson.index))
		inputs.text=caption
	queue_redraw()

func _draw() -> void:
	var pulse:=.5+.5*sin(elapsed*3)
	draw_circle(panel.position+Vector2(16*unit,panel.size.y-24*unit),(6+pulse*3)*unit,UIFactory.YELLOW)

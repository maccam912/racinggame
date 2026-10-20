class_name SchoolOverlay
extends Control

var lesson: SchoolLesson
var state: VehicleState
var unit: float = 1
var hints: Dictionary = {}
var panel := PanelContainer.new()
var instruction := Label.new()
var inputs := Label.new()
var last_caption: String = ""
var demo := SchoolInputDemo.new()
var reduce_motion: bool = false
var hold_assistance: bool = false
var suspended: bool = false
var turn_action: String = "steer_right"
var ui_scale: float = 1
var mobile: bool = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.show_behind_parent = true
	var box := UIFactory.chrome_box("panel",unit)
	box.content_margin_left=16*unit
	box.content_margin_right=16*unit
	box.content_margin_top=12*unit
	box.content_margin_bottom=12*unit
	panel.add_theme_stylebox_override("panel",box)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var list:=VBoxContainer.new()
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(list)
	for label: Label in [instruction,inputs]:
		label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_font_override("font",preload("res://assets/fonts/body.tres"))
		label.add_theme_font_size_override("font_size",int(20*unit*ui_scale))
		label.add_theme_color_override("font_color",UIFactory.CREAM if label==instruction else UIFactory.TURQUOISE)
		list.add_child(label)
	demo.lesson_index = lesson.index
	demo.turn_action = turn_action
	demo.unit = unit
	demo.ui_scale = ui_scale
	row.add_child(demo)
	panel.add_child(row)
	add_child(panel)
	resized.connect(layout)
	layout()

func layout() -> void:
	panel.position=Vector2(size.x*.24,size.y*(.06 if mobile else .10))
	panel.size=Vector2(size.x*(.66 if mobile else .52),110*unit)

func _process(dt: float) -> void:
	demo.hints = hints
	demo.suspended = suspended
	demo.reduce_motion = reduce_motion
	demo.hold_assistance = hold_assistance
	demo.ui_scale = ui_scale
	for label: Label in [instruction,inputs]:
		if label.get_theme_font_size("font_size")!=roundi(20*unit*ui_scale): label.add_theme_font_size_override("font_size",roundi(20*unit*ui_scale))
	if hints.is_empty():
		return
	var values: Array = [hints.accelerate,hints.brake] if lesson.index==0 else [hints.steer_left,hints.steer_right] if lesson.index==1 else [hints.accelerate,hints.brake,hints.steer_left,hints.steer_right] if lesson.index==2 else [hints.accelerate,hints.steer_left,hints.steer_right,hints.handbrake] if lesson.index==3 else [hints.recover]
	for index in range(values.size()):
		values[index] = str(values[index]).split(" / ")[0]
		if values[index]==I18n.t("touch.hint.auto"): values[index] = I18n.t("school.auto_short")
	var caption:=I18n.t("school.controls.4_assisted" if lesson.index==4 and hold_assistance else "school.controls."+str(lesson.index),values)
	if caption!=last_caption:
		last_caption=caption
		instruction.text=I18n.t("school.4_assisted" if lesson.index==4 and hold_assistance else "school."+str(lesson.index))
		inputs.text=caption

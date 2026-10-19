class_name FocusPointer
extends Control
var button: Button
var unit: float = 1
func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.focus_entered.connect(queue_redraw)
	button.focus_exited.connect(queue_redraw)
func _draw() -> void:
	if not button.has_focus(): return
	var center := size.y*.5
	draw_colored_polygon(PackedVector2Array([Vector2(4,center-4*unit),Vector2(9*unit,center),Vector2(4,center+4*unit)]),UIFactory.YELLOW)

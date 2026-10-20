class_name MenuFocusHelp
extends Control
## Focus-first explanations; mouse-only engine tooltips are not required.

var shell: MenuShell
var focus: Control
var held: float = 0
var panel := PanelContainer.new()
var caption := Label.new()
var content_key: String = ""
var suppressed_focus: Control

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	panel.add_child(caption)
	add_child(panel)
	panel.hide()

func clear() -> void:
	focus = null
	held = 0
	panel.hide()

func explain(control: Control) -> Dictionary:
	var current: Node = control
	var disabled := false
	while current!=null and current!=shell.root:
		if current is BaseButton: disabled = disabled or current.disabled
		if current is SpinBox or current is LineEdit: disabled = disabled or not current.editable
		var key := "disabled_reason" if disabled else "focus_help"
		if current.has_meta(key):
			var value: Variant = current.get_meta(key)
			return {"text":str(value.call()) if value is Callable and value.is_valid() else str(value),"disabled":disabled}
		current = current.get_parent()
	return {"text":"","disabled":disabled}

func _input(event: InputEvent) -> void:
	if not shell.visible or not is_visible_in_tree(): return
	for child: Node in shell.root.get_children():
		if child is Window and child.visible and child!=get_viewport(): return
	if event is InputEventScreenDrag or event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
		suppressed_focus = get_viewport().gui_get_focus_owner()
		panel.hide()
		held = 0
		return
	if event is InputEventScreenTouch and event.pressed or event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		suppressed_focus = null
	# Disabled buttons remain inspectable by touch/mouse without activating them.
	if event is InputEventMouseButton and event.pressed and event.button_index==MOUSE_BUTTON_LEFT:
		for button: Button in shell.root.find_children("*","Button",true,false):
			if button.get_viewport()!=get_viewport(): continue
			var inside := true
			var parent := button.get_parent()
			while parent!=null and parent!=shell.root:
				if parent is ScrollContainer and not parent.get_global_rect().has_point(event.position): inside = false
				parent = parent.get_parent()
			if inside and button.disabled and button.is_visible_in_tree() and button.get_global_rect().has_point(event.position):
				button.grab_focus()
				break
	if event.is_action_pressed("ui_up") or event.is_action_pressed("ui_down") or event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right") or event.is_action_pressed("ui_cancel"):
		clear()

func _process(dt: float) -> void:
	if not shell.visible or not is_visible_in_tree():
		clear()
		return
	for child: Node in shell.root.get_children():
		if child is Window and child.visible and child!=get_viewport():
			clear()
			return
	var next := get_viewport().gui_get_focus_owner()
	if not is_instance_valid(next) or not shell.root.is_ancestor_of(next):
		clear()
		return
	if next!=focus:
		focus = next
		held = 0
		panel.hide()
	if is_instance_valid(suppressed_focus) and next==suppressed_focus:
		panel.hide()
		return
	held += dt
	var info := explain(focus)
	if info.text.is_empty() or held<(.0 if info.disabled else .5):
		panel.hide()
		return
	var safe := shell.frame.get_global_rect() if get_viewport()==shell.get_viewport() else get_viewport_rect().grow(-10*shell.ui.unit)
	var bounds := focus.get_global_rect()
	var side_space := safe.end.x-bounds.end.x-8*shell.ui.unit
	var side := bool(focus.get_meta("help_side",false)) and side_space>=200*shell.ui.unit*shell.ui.scale
	var width := minf(420*shell.ui.unit*shell.ui.scale,safe.size.x*.85)
	if side: width = minf(width,side_space)
	var key := str(info.text)+str(width)
	if key!=content_key:
		content_key = key
		caption.text = info.text
		caption.add_theme_color_override("font_color",UIFactory.CREAM)
		caption.add_theme_font_size_override("font_size",shell.ui.font_size(16))
		caption.custom_minimum_size.x = width-28*shell.ui.unit
		panel.add_theme_stylebox_override("panel",shell.ui.style(UIFactory.NAVY,UIFactory.YELLOW,2) if bool(shell.settings.get("high_contrast",false)) else shell.ui.chrome("hover"))
	panel.size = Vector2(width,panel.get_combined_minimum_size().y)
	var at := Vector2(bounds.position.x,bounds.end.y+8*shell.ui.unit)
	if side: at = Vector2(bounds.end.x+8*shell.ui.unit,bounds.position.y)
	if at.y+panel.size.y>safe.end.y:
		at.y = bounds.position.y-panel.size.y-8*shell.ui.unit
	panel.position = at.clamp(safe.position,safe.end-panel.size)
	panel.show()

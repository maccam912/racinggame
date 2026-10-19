class_name ChoicePicker
extends Button
## A touch choice sheet uses ordinary ScrollContainer/Button input, so a finger
## drag scrolls instead of selecting the item where a native popup drag ends.

signal item_selected(index: int)
signal context_changed

var ui: Variant
var subject: String = ""
var labels: Array[String] = []
var selected: int = 0:
	set(value):
		selected = clampi(value,0,maxi(0,labels.size()-1))
		text = labels[selected] if not labels.is_empty() else ""
var item_count: int:
	get: return labels.size()
var sheet: CanvasLayer
var panel: PanelContainer
var scroller: ScrollContainer
var choices: Array[Button] = []
var finger: int = -1
var finger_start := Vector2.ZERO
var finger_last := Vector2.ZERO
var finger_item: int = -1
var dragged: bool = false

func _ready() -> void:
	alignment = HORIZONTAL_ALIGNMENT_LEFT
	for state: String in ["normal","hover","pressed","disabled"]:
		var style := get_theme_stylebox(state).duplicate() as StyleBox
		style.content_margin_right += 24*float(ui.unit)
		add_theme_stylebox_override(state,style)
	pressed.connect(open_sheet)

func add_item(caption: String) -> void:
	labels.append(caption)
	selected = selected

func _draw() -> void:
	if ui==null:
		return
	var unit: float = ui.unit
	var center := Vector2(size.x-18*unit,size.y/2)
	draw_colored_polygon(PackedVector2Array([center+Vector2(-5,-3)*unit,center+Vector2(5,-3)*unit,center+Vector2(0,4)*unit]),Color(UIFactory.CREAM,.4 if disabled else 1.0))

func open_sheet() -> void:
	if labels.is_empty() or is_instance_valid(sheet):
		return
	sheet = CanvasLayer.new()
	sheet.layer = 20
	add_child(sheet)
	var blocker := ColorRect.new()
	blocker.color = Color(.03,.07,.10,.90)
	blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	sheet.add_child(blocker)
	panel = PanelContainer.new()
	panel.theme = ui.theme
	sheet.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	column.add_child(ui.label(subject if subject!="" else I18n.t("choice.select"),true))
	scroller = ScrollContainer.new()
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroller.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroller.follow_focus = true
	column.add_child(scroller)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroller.add_child(list)
	choices.clear()
	for index: int in range(labels.size()):
		var button: Button = ui.button(labels[index],func() -> void: choose(index))
		button.modulate = UIFactory.TURQUOISE if index==selected else Color.WHITE
		list.add_child(button)
		choices.append(button)
	column.add_child(ui.button(I18n.t("button.cancel"),close_sheet))
	get_viewport().size_changed.connect(layout_sheet)
	add_to_group("mobile_choice_sheets")
	layout_sheet()
	context_changed.emit()
	focus_choice.call_deferred()

func focus_choice() -> void:
	if is_inside_tree() and is_instance_valid(sheet) and selected<choices.size() and is_instance_valid(choices[selected]):
		choices[selected].grab_focus()

func layout_sheet() -> void:
	if not is_inside_tree() or not is_instance_valid(sheet):
		return
	var geometry := TouchDriving.safe_geometry(get_viewport().get_visible_rect().size)
	var safe := Rect2(geometry.safe.position*float(geometry.unit),geometry.safe.size*float(geometry.unit))
	var width := minf(safe.size.x*.90,safe.size.y*16/9*.90)
	panel.position = safe.position+Vector2((safe.size.x-width)/2,safe.size.y*.05)
	panel.size = Vector2(width,safe.size.y*.90)

func choose(index: int) -> void:
	if index<0 or index>=labels.size():
		return
	selected = index
	close_sheet()
	item_selected.emit(index)

func close_sheet(restore_focus: bool = true) -> void:
	if not is_instance_valid(sheet):
		return
	sheet.hide()
	sheet.process_mode = Node.PROCESS_MODE_DISABLED
	sheet.queue_free()
	sheet = null
	finger = -1
	choices.clear()
	remove_from_group("mobile_choice_sheets")
	if get_viewport().size_changed.is_connected(layout_sheet):
		get_viewport().size_changed.disconnect(layout_sheet)
	context_changed.emit()
	if restore_focus:
		focus_origin.call_deferred()

func focus_origin() -> void:
	if is_inside_tree() and is_visible_in_tree():
		grab_focus()

func _input(event: InputEvent) -> void:
	if not is_instance_valid(sheet):
		return
	if event.is_action_pressed("ui_cancel"):
		close_sheet()
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouse and event.device==-1:
		if finger!=-1 or scroller.get_global_rect().has_point(event.position):
			get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		var inside := scroller.get_global_rect().has_point(event.position)
		if event.pressed and not event.canceled and inside and finger==-1:
			finger = event.index
			finger_start = event.position
			finger_last = event.position
			finger_item = row_at(event.position)
			dragged = false
		elif not event.pressed or event.canceled:
			if finger==event.index:
				var choice := finger_item
				var should_select: bool = not dragged and not event.canceled and inside and choice>=0 and row_at(event.position)==choice
				finger = -1
				if should_select:
					choose(choice)
				get_viewport().set_input_as_handled()
				return
		if inside or finger==event.index:
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and finger==event.index:
		if event.position.distance_to(finger_start)>10*float(ui.unit):
			dragged = true
		if dragged:
			scroller.scroll_vertical -= roundi(event.position.y-finger_last.y)
		finger_last = event.position
		get_viewport().set_input_as_handled()

func row_at(at: Vector2) -> int:
	for index: int in range(choices.size()):
		if choices[index].get_global_rect().has_point(at):
			return index
	return -1

func _notification(what: int) -> void:
	if not is_inside_tree():
		return
	if what==NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		close_sheet(false)
	elif what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]:
		close_sheet()

static func close_active(viewport: Viewport) -> bool:
	for picker: Node in viewport.get_tree().get_nodes_in_group("mobile_choice_sheets"):
		if picker.get_viewport()==viewport:
			picker.close_sheet()
			return true
	return false

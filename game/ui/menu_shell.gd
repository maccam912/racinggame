class_name MenuShell
extends CanvasLayer

signal context_changed

var root: Control
var frame: MarginContainer
var column: VBoxContainer
var body: Control
var footer: HFlowContainer
var ui: UIFactory
var settings: Dictionary = {}
var modal: ConfirmationDialog
var mobile_override: Variant = null # Native-layout fixtures only.
var logical_unit_override: float = 0.0
var keyboard_height_override: float = -1.0 # Viewport pixels; fixtures only.
var keyboard_height: float = 0.0
var compact_keyboard: bool = false
var headers: Array[Control] = []
var saved_controls: Array[Dictionary] = []
var saved_control_ids: Dictionary = {}
var touches: Dictionary = {}
var motion: Control
var transition: Tween
var screen_title: String = ""
var focus_help: MenuFocusHelp


func _ready() -> void:
	layer = 5
	get_viewport().size_changed.connect(layout)


func reset(title: String, subtitle: String = "", dark: bool = true) -> VBoxContainer:
	var animate := is_instance_valid(root) and title!=screen_title and not bool(settings.get("reduce_motion",false))
	screen_title = title
	if transition: transition.kill()
	if is_instance_valid(root):
		root.hide()
		root.process_mode = Node.PROCESS_MODE_DISABLED
		root.queue_free()
	headers.clear()
	saved_controls.clear()
	saved_control_ids.clear()
	compact_keyboard = false
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui = UIFactory.new(get_viewport(), settings, mobile_override, logical_unit_override)
	root.theme = ui.theme
	add_child(root)
	if dark:
		var background := ColorRect.new()
		background.color = Color(.04, .09, .14, .88)
		background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root.add_child(background)
	motion = Control.new()
	motion.mouse_filter = Control.MOUSE_FILTER_IGNORE
	motion.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(motion)
	frame = MarginContainer.new()
	motion.add_child(frame)
	column = VBoxContainer.new()
	frame.add_child(column)
	if title != "":
		var heading := ui.label(title, true)
		heading.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		var title_control: Control = heading if dark else ui.panel(heading)
		headers.append(title_control)
		column.add_child(title_control)
	if subtitle != "":
		var caption := ui.paragraph(subtitle)
		var caption_control: Control = caption if dark else ui.panel(caption)
		headers.append(caption_control)
		column.add_child(caption_control)
	var content := VBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(content)
	body = content
	footer = HFlowContainer.new()
	footer.add_theme_constant_override("h_separation", int(10 * ui.unit))
	footer.add_theme_constant_override("v_separation", int(6 * ui.unit))
	column.add_child(ui.panel(footer))
	layout()
	layout.call_deferred()
	focus_help = MenuFocusHelp.new()
	focus_help.shell = self
	root.add_child(focus_help)
	if animate:
		motion.position.x = minf(80*ui.unit,get_viewport().get_visible_rect().size.x*.08)
		transition = create_tween()
		transition.tween_property(motion,"position:x",0.0,.18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	visible = true
	context_changed.emit()
	return content


func layout() -> void:
	if not is_instance_valid(frame):
		return
	var size := get_viewport().get_visible_rect().size
	var width := minf(size.x * .90, size.y * 16 / 9 * .90)
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.offset_left = (size.x - width) / 2
	frame.offset_right = -(size.x - width) / 2
	frame.offset_top = size.y * .05
	frame.offset_bottom = -size.y * .05 if keyboard_height<=0 else -keyboard_height-4*ui.unit
	apply_keyboard_compaction()
	if keyboard_height>0: reveal_keyboard_focus.call_deferred()


func read_keyboard_height() -> float:
	if keyboard_height_override>=0: return keyboard_height_override
	if ui==null or not ui.mobile or not DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD): return 0.0
	var window_height := maxf(1,DisplayServer.window_get_size().y)
	return float(DisplayServer.virtual_keyboard_get_height())*get_viewport().get_visible_rect().size.y/window_height

func apply_keyboard_compaction() -> void:
	if ui==null or not ui.mobile: return
	var panel: PanelContainer = footer.get_parent()
	if keyboard_height>0:
		if not compact_keyboard:
			compact_keyboard = true
			for header: Control in headers:
				saved_controls.append({"control":header,"visible":header.visible})
				header.hide()
			column.add_theme_constant_override("separation",roundi(4*ui.unit))
			var style := panel.get_theme_stylebox("panel").duplicate() as StyleBox
			style.content_margin_top = 2*ui.unit
			style.content_margin_bottom = 2*ui.unit
			panel.add_theme_stylebox_override("panel",style)
		for control: Control in root.find_children("*","Control",true,false):
			if (control is BaseButton or control is LineEdit) and not saved_control_ids.has(control.get_instance_id()):
				saved_control_ids[control.get_instance_id()] = true
				saved_controls.append({"control":control,"minimum":control.custom_minimum_size})
				control.custom_minimum_size.y = 48*ui.unit
	elif keyboard_height<=0 and compact_keyboard:
		compact_keyboard = false
		for entry: Dictionary in saved_controls:
			if not is_instance_valid(entry.control): continue
			if entry.has("minimum"): entry.control.custom_minimum_size = entry.minimum
			if entry.has("visible"): entry.control.visible = entry.visible
		saved_controls.clear()
		saved_control_ids.clear()
		column.remove_theme_constant_override("separation")
		panel.remove_theme_stylebox_override("panel")

func reveal_keyboard_focus() -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_inside_tree() or keyboard_height<=0 or not is_instance_valid(root): return
	var control: Control = get_viewport().gui_get_focus_owner()
	if not is_instance_valid(control) or not root.is_ancestor_of(control): return
	var parent := control.get_parent()
	while parent and parent!=root:
		if parent is ScrollContainer:
			parent.ensure_control_visible(control)
			break
		parent = parent.get_parent()

func _process(_delta: float) -> void:
	if not visible or not is_instance_valid(root): return
	var height := read_keyboard_height()
	# A footer press can dismiss the IME before release. Keep its target still
	# until that press completes, then restore the ordinary menu geometry.
	if height<keyboard_height and (not touches.is_empty() or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_action_pressed("ui_accept")):
		return
	if not is_equal_approx(height,keyboard_height):
		keyboard_height = height
		layout()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled: touches[event.index] = true
		else: touches.erase(event.index)

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]: touches.clear()


func scroll_column(parent: Node) -> VBoxContainer:
	var scroll := MenuScroll.new()
	scroll.unit = ui.unit
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	parent.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	return list

func explain_window(window: Window) -> void:
	var helper := MenuFocusHelp.new()
	helper.shell = self
	window.add_child(helper)


func add_back(action: Callable) -> Button:
	var button := ui.button(I18n.t("button.back"), action, 120,"back")
	footer.add_child(button)
	return button


func confirm(text: String, action: Callable, second: bool = false) -> void:
	var focused := get_viewport().gui_get_focus_owner()
	if focused is LineEdit or focused is TextEdit: focused.release_focus()
	if DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD): DisplayServer.virtual_keyboard_hide()
	if is_instance_valid(modal):
		modal.hide()
		modal.queue_free()
	modal = ConfirmationDialog.new()
	modal.borderless = ui.mobile
	modal.dialog_autowrap = true
	modal.dialog_text = text
	modal.ok_button_text = I18n.t("button.confirm")
	modal.cancel_button_text = I18n.t("button.cancel")
	modal.theme = ui.theme
	modal.add_theme_stylebox_override("panel",ui.style(UIFactory.NAVY,UIFactory.CREAM))
	modal.add_theme_constant_override("buttons_min_height",ceili(ui.row_height()))
	modal.add_theme_constant_override("buttons_min_width",ceili(96*ui.unit))
	modal.min_size = Vector2i(minf(440 * ui.unit,get_viewport().get_visible_rect().size.x * .9), minf(160 * ui.unit,get_viewport().get_visible_rect().size.y * .85))
	root.add_child(modal)
	modal.confirmed.connect(func() -> void:
		if second:
			confirm(I18n.t("settings.second_confirm"), action)
		else:
			action.call())
	modal.popup_centered()


func first_focus() -> void:
	var controls := root.find_children("*", "Button", true, false)
	for item: Button in controls:
		if not item.disabled:
			focus_later(item)
			return


func focus_later(control: Control) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if is_instance_valid(control) and control.is_inside_tree() and root.is_ancestor_of(control):
		control.grab_focus()
		var parent := control.get_parent()
		while parent and parent != root:
			if parent is ScrollContainer:
				parent.ensure_control_visible(control)
				break
			parent = parent.get_parent()


func reveal_later(control: Control) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if not is_instance_valid(control) or not control.is_inside_tree() or not root.is_ancestor_of(control):
		return
	var parent := control.get_parent()
	while parent and parent != root:
		if parent is ScrollContainer:
			parent.ensure_control_visible(control)
			return
		parent = parent.get_parent()

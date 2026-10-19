class_name MenuShell
extends CanvasLayer

var root: Control
var frame: MarginContainer
var column: VBoxContainer
var body: Control
var footer: HFlowContainer
var ui: UIFactory
var settings: Dictionary = {}
var modal: ConfirmationDialog


func _ready() -> void:
	layer = 5
	get_viewport().size_changed.connect(layout)


func reset(title: String, subtitle: String = "", dark: bool = true) -> VBoxContainer:
	if is_instance_valid(root):
		root.hide()
		root.process_mode = Node.PROCESS_MODE_DISABLED
		root.queue_free()
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui = UIFactory.new(get_viewport(), settings)
	root.theme = ui.theme
	add_child(root)
	if dark:
		var background := ColorRect.new()
		background.color = Color(.04, .09, .14, .88)
		background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		root.add_child(background)
	frame = MarginContainer.new()
	root.add_child(frame)
	column = VBoxContainer.new()
	frame.add_child(column)
	if title != "":
		var heading := ui.label(title, true)
		heading.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		column.add_child(heading if dark else ui.panel(heading))
	if subtitle != "":
		var caption := ui.paragraph(subtitle)
		column.add_child(caption if dark else ui.panel(caption))
	var content := VBoxContainer.new()
	content.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(content)
	body = content
	footer = HFlowContainer.new()
	footer.add_theme_constant_override("h_separation", int(10 * ui.unit))
	footer.add_theme_constant_override("v_separation", int(6 * ui.unit))
	column.add_child(ui.panel(footer))
	layout()
	visible = true
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
	frame.offset_bottom = -size.y * .05


func scroll_column(parent: Node) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	parent.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	return list


func add_back(action: Callable) -> Button:
	var button := ui.button(I18n.t("button.back"), action, 120)
	footer.add_child(button)
	return button


func confirm(text: String, action: Callable, second: bool = false) -> void:
	if is_instance_valid(modal):
		modal.queue_free()
	modal = ConfirmationDialog.new()
	modal.dialog_text = text
	modal.ok_button_text = I18n.t("button.confirm")
	modal.cancel_button_text = I18n.t("button.cancel")
	modal.theme = ui.theme
	modal.min_size = Vector2i(440 * ui.unit, 160 * ui.unit)
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

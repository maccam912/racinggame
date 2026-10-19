extends SceneTree
var activations: int = 0
func _initialize() -> void: call_deferred("run")
func settle() -> void:
	await process_frame
	await process_frame
	await process_frame
func touch(at: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 2
	event.position = at
	event.pressed = pressed
	event.canceled = canceled
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func drag(at: Vector2) -> void:
	var event := InputEventScreenDrag.new()
	event.index = 2
	event.position = at
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func run() -> void:
	root.size = Vector2i(1280,720)
	BindingBook.apply({})
	var menu := MenuShell.new()
	menu.settings = SettingsCatalog.defaults(true)
	menu.mobile_override = true
	menu.logical_unit_override = 1.0
	root.add_child(menu)
	var list := menu.scroll_column(menu.reset("Long menu"))
	var scroll: MenuScroll = list.get_parent()
	for index in range(20):
		list.add_child(menu.ui.button("Row %d"%index,func() -> void: activations += 1))
	var edit := LineEdit.new()
	edit.custom_minimum_size.y = 48
	list.add_child(edit)
	var toggle := CheckButton.new()
	toggle.text = "Toggle"
	toggle.custom_minimum_size.y = 48
	list.add_child(toggle)
	var picker: ChoicePicker = menu.ui.choice_picker("Choices")
	picker.add_item("First")
	picker.add_item("Second")
	list.add_child(picker)
	menu.add_back(func() -> void: pass)
	await settle()
	var start: Vector2 = list.get_child(3).get_global_rect().get_center()
	touch(start,true)
	for index in range(1,9):
		drag(start-Vector2(0,25*index))
		await process_frame
	touch(start-Vector2(0,200),false)
	await settle()
	assert(scroll.scroll_vertical>=190 and activations==0,"dragging over buttons scrolls without activating either endpoint")
	var button := list.get_child(8) as Button
	scroll.ensure_control_visible(button)
	await settle()
	var at := button.get_global_rect().get_center()
	touch(at,true)
	touch(at,false)
	await settle()
	assert(activations==1,"stationary release clicks once")
	# Godot also emits a mouse event for the physical finger; never click twice.
	for pressed: bool in [true,false]:
		var duplicate := InputEventMouseButton.new()
		duplicate.device = -1
		duplicate.button_index = MOUSE_BUTTON_LEFT
		duplicate.position = at
		duplicate.pressed = pressed
		Input.parse_input_event(duplicate)
		Input.flush_buffered_events()
	assert(activations==1)
	touch(at,true)
	touch(at,false,true)
	await settle()
	assert(activations==1 and scroll.finger==-1)
	touch(at,true)
	scroll.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	touch(at,false)
	await settle()
	assert(activations==1,"cancelled or backgrounded fingers cannot click")
	scroll.ensure_control_visible(edit)
	await settle()
	at = edit.get_global_rect().get_center()
	touch(at,true)
	touch(at,false)
	await settle()
	assert(root.gui_get_focus_owner()==edit,"a stationary field tap reaches native editing")
	scroll.ensure_control_visible(toggle)
	await settle()
	at = toggle.get_global_rect().get_center()
	touch(at,true)
	touch(at,false)
	await settle()
	assert(toggle.button_pressed,"native toggle semantics survive deferred taps")
	scroll.ensure_control_visible(picker)
	await settle()
	at = picker.get_global_rect().get_center()
	touch(at,true)
	touch(at,false)
	await settle()
	assert(is_instance_valid(picker.sheet))
	at = picker.choices[1].get_global_rect().get_center()
	touch(at,true)
	touch(at,false)
	await settle()
	assert(picker.selected==1 and not is_instance_valid(picker.sheet),"the modal sheet owns its touches")
	menu.queue_free()
	await settle()
	print("MENU_TOUCH_SCROLL_TAP_FIELD_TOGGLE_MODAL_CANCEL_PASS")
	quit()

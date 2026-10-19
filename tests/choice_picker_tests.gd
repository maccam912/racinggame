extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func key(code: int,pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func pad(code: int,pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func touch(pressed: bool,at: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 3
	event.pressed = pressed
	event.position = at
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func settle() -> void:
	await process_frame
	await process_frame

func run() -> void:
	root.size = Vector2i(1280,720)
	await settle()
	BindingBook.apply({})
	var settings := SettingsCatalog.defaults(true)
	settings.ui_scale = 150
	var ui := UIFactory.new(root,settings,true,1.0)
	var picker: ChoicePicker = ui.choice_picker("Settings")
	picker.position = Vector2(20,20)
	picker.custom_minimum_size = Vector2(320,ui.row_height())
	picker.theme = ui.theme
	for label: String in ["Display","Graphics","Audio","Controls","Touch","Accessibility","Gameplay","Data"]:
		picker.add_item(label)
	var selected: Array[int] = []
	picker.item_selected.connect(func(index: int) -> void: selected.append(index))
	root.add_child(picker)
	var repeat := MenuRepeat.new()
	repeat.allowed = func() -> bool: return true
	root.add_child(repeat)
	picker.grab_focus()
	key(KEY_ENTER,true)
	key(KEY_ENTER,false)
	await settle()
	assert(is_instance_valid(picker.sheet) and selected.is_empty(),"opening confirm does not select a row")
	assert(root.gui_get_focus_owner()==picker.choices[0])
	for button: Button in picker.choices:
		assert(button.size.y>=48*ui.unit,"choice rows retain minimum touch targets")
	assert(Rect2(root.get_visible_rect().size*.05,root.get_visible_rect().size*.90).encloses(picker.panel.get_rect()))
	var origin: Vector2 = picker.scroller.get_global_rect().position+picker.scroller.size*Vector2(.5,.80)
	touch(true,origin)
	var previous := origin
	for index: int in range(1,11):
		var event := InputEventScreenDrag.new()
		event.index = 3
		event.position = origin+Vector2(0,-20*index)
		event.relative = event.position-previous
		previous = event.position
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		await process_frame
	touch(false,previous)
	await settle()
	assert(picker.scroller.scroll_vertical>50 and selected.is_empty(),"a real finger drag scrolls without selecting")
	picker.scroller.scroll_vertical = int(picker.scroller.get_v_scroll_bar().max_value)
	await settle()
	var last: Vector2 = picker.choices[7].get_global_rect().get_center()
	assert(picker.scroller.get_global_rect().has_point(last))
	touch(true,last)
	touch(false,last)
	await settle()
	assert(selected==[7] and picker.selected==7 and not is_instance_valid(picker.sheet),"last row is reachable by touch")
	picker.open_sheet()
	await settle()
	pad(JOY_BUTTON_DPAD_UP,true)
	await settle()
	pad(JOY_BUTTON_DPAD_UP,false)
	assert(root.gui_get_focus_owner()==picker.choices[6])
	pad(JOY_BUTTON_A,true)
	pad(JOY_BUTTON_A,false)
	await settle()
	assert(selected==[7,6] and picker.selected==6,"controller chooses through the same sheet")
	picker.open_sheet()
	await settle()
	var cancel_at := picker.choices[6].get_global_rect().get_center()
	touch(true,cancel_at)
	var canceled := InputEventScreenTouch.new()
	canceled.index = 3
	canceled.position = cancel_at
	canceled.canceled = true
	Input.parse_input_event(canceled)
	Input.flush_buffered_events()
	assert(selected==[7,6] and picker.finger==-1 and is_instance_valid(picker.sheet),"pointer cancellation releases without selecting")
	key(KEY_ESCAPE,true)
	key(KEY_ESCAPE,false)
	await settle()
	assert(selected==[7,6] and not is_instance_valid(picker.sheet))
	picker.open_sheet()
	await settle()
	assert(ChoicePicker.close_active(root) and not is_instance_valid(picker.sheet),"Android Back closes the sheet before page navigation")
	picker.open_sheet()
	await settle()
	root.size = Vector2i(2400,1080)
	await settle()
	assert(picker.panel.size.x<=root.get_visible_rect().size.y*16/9*.90+.01,"ultrawide menus retain centered 16:9 content")
	assert(picker.panel.get_rect().end.y<=root.get_visible_rect().size.y*.95+.01)
	picker.queue_free()
	await settle()
	assert(get_nodes_in_group("mobile_choice_sheets").is_empty())
	repeat.queue_free()
	await settle()
	print("Mobile choice sheet: opening guard, safe bounds, actual touch drag without selection, last-row tap, controller, Back/cancel and teardown pass")
	quit()

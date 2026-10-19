extends SceneTree
var submitted: int = 0
func _initialize() -> void: call_deferred("run_tests")
func settle() -> void:
	await process_frame
	await process_frame
	await process_frame
	await process_frame
func mouse(at: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = at
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func run_tests() -> void:
	root.size = Vector2i(1280,720)
	BindingBook.apply({})
	var menu := MenuShell.new()
	menu.settings = SettingsCatalog.defaults(true)
	menu.settings.ui_scale = 150
	menu.mobile_override = true
	menu.logical_unit_override = 1.0
	root.add_child(menu)
	var body := menu.reset("Edit Name")
	var list := menu.scroll_column(body)
	list.add_child(menu.ui.label("Display name"))
	var edit := LineEdit.new()
	edit.text = "Emulator Driver"
	edit.custom_minimum_size.y = menu.ui.row_height()
	list.add_child(edit)
	var save := menu.ui.button("Save",func() -> void: submitted += 1)
	menu.footer.add_child(save)
	menu.add_back(func() -> void: submitted += 100)
	await settle()
	var normal_minimum := save.custom_minimum_size
	edit.grab_focus()
	menu.keyboard_height_override = 540
	await settle()
	assert(menu.compact_keyboard and not menu.headers[0].visible)
	assert(menu.footer.get_global_rect().end.y<=180.01,"footer must remain above IME")
	assert(save.get_global_rect().size.y>=48 and edit.get_global_rect().size.y>=48)
	var scroll: ScrollContainer = list.get_parent()
	assert(scroll.get_global_rect().encloses(edit.get_global_rect()),"the focused field must be fully visible")
	var target := save.get_global_rect().get_center()
	mouse(target,true)
	menu.keyboard_height_override = 0
	await settle()
	assert(menu.keyboard_height==540 and save.get_global_rect().has_point(target),"IME dismissal must not move a pressed footer target")
	mouse(target,false)
	await settle()
	assert(submitted==1 and not menu.compact_keyboard and menu.headers[0].visible)
	assert(save.custom_minimum_size==normal_minimum)
	menu.keyboard_height_override = 400
	await settle()
	var other_body := menu.reset("Other page")
	var other_edit := LineEdit.new()
	other_edit.custom_minimum_size.y = menu.ui.row_height()
	other_body.add_child(other_edit)
	var other_button := menu.ui.button("Back",func() -> void: pass)
	menu.footer.add_child(other_button)
	await settle()
	assert(other_button.custom_minimum_size.y==48 and other_edit.custom_minimum_size.y==48)
	menu.keyboard_height_override = 0
	await settle()
	assert(not menu.compact_keyboard and menu.headers[0].visible,"page replacement must restore its own geometry")
	assert(other_button.custom_minimum_size.y==72 and other_edit.custom_minimum_size.y==72)
	menu.queue_free()
	await settle()
	print("MOBILE_IME_FIELD_FOOTER_MINIMUM_PRESS_RESTORE_PASS")
	quit()

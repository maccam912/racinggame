extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func send_key(code: int,pressed: bool) -> void:
	var event:=InputEventKey.new()
	event.physical_keycode=code
	event.pressed=pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func run() -> void:
	var app: Node=load("res://game/client_app.gd").new()
	root.add_child(app)
	await process_frame
	app.data=AppData.new("user://tests/binding-ui-"+str(Time.get_ticks_usec()),false)
	BindingBook.apply({})
	var page: BindingsPage=app.bindings_page
	page.show_page(app.show_menu)
	await process_frame
	await process_frame
	page.begin_capture("accelerate",0)
	send_key(KEY_ENTER,true)
	assert(is_instance_valid(page.capture) and page.capture.visible and app.data.settings.bindings.is_empty())
	send_key(KEY_ENTER,false)
	page.capture.opened-=250
	var wrong:=InputEventJoypadButton.new()
	wrong.device=0
	wrong.button_index=JOY_BUTTON_A
	wrong.pressed=true
	Input.parse_input_event(wrong)
	Input.flush_buffered_events()
	assert(page.capture.visible and not page.capture.done)
	var release:=wrong.duplicate() as InputEventJoypadButton
	release.pressed=false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	send_key(KEY_E,true)
	await process_frame
	await process_frame
	assert(app.page=="bindings" and app.data.settings.bindings.keyboard.accelerate[0]==BindingBook.key(KEY_E))
	send_key(KEY_E,false)
	page.begin_capture("accelerate",0)
	page.capture.opened-=250
	send_key(KEY_S,true)
	await process_frame
	assert(is_instance_valid(page.conflict_dialog) and page.conflict_dialog.visible)
	assert(page.conflict_dialog.get_ok_button().disabled)
	send_key(KEY_S,false)
	page.conflict_dialog.confirmed.emit()
	await process_frame
	await process_frame
	assert(app.data.settings.bindings.keyboard.accelerate[0]==BindingBook.key(KEY_S) and app.data.settings.bindings.keyboard.brake[0]==BindingBook.key(KEY_E))
	var previous: Dictionary=app.data.settings.bindings.duplicate(true)
	page.begin_capture("recover",0)
	page.capture.deadline=Time.get_ticks_msec()-1
	page.capture._process(0)
	await process_frame
	assert(app.data.settings.bindings==previous and page.status.text==I18n.t("binding.timed_out"))
	page.begin_capture("recover",0)
	send_key(KEY_ESCAPE,true)
	await process_frame
	assert(app.page=="bindings" and app.data.settings.bindings==previous)
	send_key(KEY_ESCAPE,false)
	app.data.store.fail_component="settings"
	app.data.store.fail_stage="before_replace"
	page.begin_capture("recover",0)
	page.capture.opened-=250
	send_key(KEY_T,true)
	await process_frame
	assert(app.data.settings.bindings==previous and page.status.text==I18n.t("data.save_failed"))
	assert(InputMap.action_has_event("recover",BindingBook.event_for(BindingBook.key(KEY_R))))
	send_key(KEY_T,false)
	page.begin_capture("ui_cancel",0)
	var remove: Button
	# The pure contract above protects this path; inspect the actual custom button.
	for child: Node in page.capture.find_children("*","Button",true,false):
		if child is Button and child.text==I18n.t("binding.remove"):
			remove=child
	assert(remove!=null and remove.disabled)
	app.queue_free()
	await process_frame
	await process_frame
	print("Binding UI: opening-input guard, device filter, capture, conflict, timeout, cancel, failed save and essential-path protection pass")
	quit()

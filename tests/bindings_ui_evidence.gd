extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func send_key(code: int,pressed: bool) -> void:
	var event:=InputEventKey.new()
	event.physical_keycode=code
	event.pressed=pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/bindings-native-%s.png" % label)

func run() -> void:
	var data:=AppData.new("user://diagnostic_profiles/bindings_native",false)
	data.settings.window_mode="windowed"
	data.settings.ui_scale=150
	data.settings.bindings={}
	data.profile.first_run_complete=true
	data.save_profile()
	data.save_settings()
	var app: Node=load("res://game/client_app.gd").new()
	root.add_child(app)
	await process_frame
	app.bindings_page.show_page(app.show_menu)
	await capture("keyboard-150")
	app.bindings_page.begin_capture("accelerate",0)
	await capture("capture-150")
	await create_timer(.25).timeout
	send_key(KEY_E,true)
	send_key(KEY_E,false)
	await process_frame
	await process_frame
	assert(app.data.settings.bindings.keyboard.accelerate[0]==BindingBook.key(KEY_E))
	app.bindings_page.begin_capture("accelerate",0)
	await create_timer(.25).timeout
	send_key(KEY_S,true)
	send_key(KEY_S,false)
	await create_timer(.3).timeout
	await capture("conflict-150")
	send_key(KEY_ENTER,true)
	send_key(KEY_ENTER,false)
	await process_frame
	await process_frame
	assert(app.data.settings.bindings.keyboard.accelerate[0]==BindingBook.key(KEY_S))
	app.start_drive({"mode":"school","lesson":0})
	await create_timer(.5).timeout
	await capture("school-remapped")
	assert(app.drive.school_overlay.inputs.text.contains("S / Up") and app.drive.school_overlay.inputs.text.contains("E / Down"))
	app.show_menu()
	app.bindings_page.device_name="gamepad"
	app.bindings_page.show_page(app.show_menu)
	await capture("gamepad-150")
	app.queue_free()
	await process_frame
	print("BINDINGS_NATIVE_CAPTURE_CONFLICT_SCHOOL_PASS")
	quit()

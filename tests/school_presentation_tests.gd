extends SceneTree
func _initialize() -> void: call_deferred("run")
func click(button: Button) -> void:
	for pressed: bool in [true,false]:
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		event.position = button.get_global_rect().get_center()
		event.global_position = event.position
		root.push_input(event,true)
func run() -> void:
	var demo := SchoolInputDemo.new()
	assert(demo.illustration(.5).active==["accelerate"])
	assert(demo.illustration(2.2).active==["brake"])
	assert(demo.illustration(3.3).active.is_empty())
	demo.lesson_index = 1
	assert(demo.illustration(.7).active==["steer_right"] and demo.illustration(2.1).active==["steer_left"])
	demo.lesson_index = 2
	demo.turn_action = "steer_left"
	assert(demo.illustration(.5).active==["brake"] and demo.illustration(1.5).active==["steer_left"])
	demo.lesson_index = 3
	assert("handbrake" in demo.illustration(.8).active and not "handbrake" in demo.illustration(1.5).active)
	demo.lesson_index = 4
	assert(is_equal_approx(float(demo.illustration(.55).progress),.5))
	demo.hold_assistance = true
	assert(demo.illustration(.25).active==["recover"] and demo.illustration(.5).active.is_empty() and demo.illustration(.75).active==["recover"])
	demo.reduce_motion = true
	assert(demo.illustration(.75).active.is_empty() and demo.illustration(.75).progress==0)
	demo.free()
	var folder := "user://tests/school-style-"+RaceSetup.uuid()
	var app: Node = load("res://game/client_app.gd").new()
	root.add_child(app)
	await process_frame
	app.data = AppData.new(folder,false)
	app.data.settings.hold_assistance = true
	app.data.settings.bindings = BindingBook.change({},"keyboard","recover",0,BindingBook.key(KEY_T)).bindings
	app.start_drive({"mode":"school","lesson":4})
	app.drive.set_physics_process(false)
	for index in range(4): await process_frame
	var overlay: SchoolOverlay = app.drive.school_overlay
	assert(overlay.instruction.text==I18n.t("school.4_assisted") and "T" in overlay.inputs.text)
	assert(overlay.demo.hold_assistance and overlay.demo.keycaps[0].text=="T","demonstration follows actual remapped Recover input")
	app.drive.paused = true
	app.drive._process(.016)
	await process_frame
	var elapsed := overlay.demo.elapsed
	await process_frame
	assert(overlay.demo.elapsed==elapsed,"paused demonstration freezes")
	app.data.settings.reduce_motion = true
	app.drive.apply_settings()
	app.drive.paused = false
	app.drive._process(.016)
	await process_frame
	elapsed = overlay.demo.elapsed
	await process_frame
	assert(overlay.demo.reduce_motion and overlay.demo.elapsed==elapsed,"Reduce Motion leaves a static input illustration")
	var prior: RaceDrive = app.drive
	prior.lesson.stage = 1
	var retry: Button = prior.school_actions.get_child(0)
	click(retry)
	for index in range(200):
		await process_frame
		if app.page=="race" and app.drive!=prior: break
	assert(app.page=="race" and app.drive!=prior and app.drive.lesson.index==4 and app.drive.lesson.stage==0,"live Retry restarts the same exercise through the real loading path")
	app.drive.set_physics_process(false)
	for index in range(3): await process_frame
	click(app.drive.school_actions.get_child(1))
	assert(app.page=="school_complete" and not app.data.profile.school_steps[4],"Skip remains available and never invents objective completion")
	assert(not app.drive.school_overlay.visible and not app.drive.school_actions.visible and not app.drive.touch.visible,"completion shows one clean interface")
	app.data.settings.hold_assistance = false
	app.start_drive({"mode":"school","lesson":4})
	app.drive.set_physics_process(false)
	var recover := InputEventKey.new()
	recover.physical_keycode = KEY_T
	recover.pressed = true
	Input.parse_input_event(recover)
	Input.flush_buffered_events()
	for index in range(30): app.drive._physics_process(1.0/60)
	assert(app.drive.lesson.done and app.drive.state.recovery_ticks==60 and app.page=="race" and not app.drive.paused,"recovery success lets its visual transition finish")
	var release := recover.duplicate() as InputEventKey
	release.pressed = false
	Input.parse_input_event(release)
	Input.flush_buffered_events()
	for index in range(30): app.drive._physics_process(1.0/60)
	assert(app.page=="race" and app.drive.state.recovery_ticks==30)
	for index in range(30): app.drive._physics_process(1.0/60)
	assert(app.page=="school_complete" and app.data.profile.school_steps[4] and app.data.records.times.is_empty(),"one-second recovery completes before the noncompetitive success screen")
	app.queue_free()
	await create_timer(.5).timeout
	assert(AppData.remove_tree(ProjectSettings.globalize_path(folder))==OK)
	print("SCHOOL_INPUT_SEQUENCE_REMAP_HOLD_ASSIST_STATIC_MOTION_PAUSE_REAL_RETRY_CLICK_SKIP_NO_UNLOCK_WRITES_PASS")
	quit()

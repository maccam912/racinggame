extends SceneTree
func _initialize() -> void: call_deferred("run")
func key(code: int, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func pad(pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = JOY_BUTTON_Y
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
func tap(id: int, at: Vector2, cancelled: bool = false) -> void:
	for pressed: bool in [true,false]:
		var event := InputEventScreenTouch.new()
		event.index = id
		event.position = at
		event.pressed = pressed
		event.canceled = cancelled and not pressed
		Input.parse_input_event(event)
		Input.flush_buffered_events()
func tick(drive: RaceDrive, count: int = 1) -> void:
	for index in range(count): drive._physics_process(1.0/60)
func run() -> void:
	root.size = Vector2i(1280,720)
	Catalog.load_all()
	DrivingInput.register_defaults()
	var data := AppData.new("user://tests/recover-assist-"+RaceSetup.uuid(),false)
	data.settings.hold_assistance = true
	data.settings.touch_auto_accelerate = false
	var drive := RaceDrive.new()
	drive.config = {"mode":"quick","track":0,"opponents":0,"laps":1}
	drive.app_data = data
	drive.external_menus = true
	drive.show_touch = true
	root.add_child(drive)
	drive.set_physics_process(false)
	await physics_frame
	drive.session.phase = RaceSession.Phase.RACING
	# A rapid key tap remains available even if both events precede one tick.
	key(KEY_R,true)
	key(KEY_R,false)
	tick(drive)
	assert(drive.driver.recovery_armed and drive.state.recovery_hold_ticks==0)
	key(KEY_R,true)
	# This is the confirming second press; holding it never repeats a recovery.
	tick(drive,29)
	assert(drive.state.recovery_ticks==0 and drive.state.recovery_hold_ticks==29)
	tick(drive)
	assert(drive.state.recovery_ticks==60 and not drive.state.trial_valid,"assistance preserves the exact shared 30-tick recovery minimum and trial invalidation")
	key(KEY_R,false)
	tick(drive,61)
	assert(drive.state.recovery_ticks==0)
	key(KEY_R,true)
	tick(drive,90)
	assert(drive.driver.recovery_armed and drive.state.recovery_hold_ticks==0 and drive.state.recovery_ticks==0,"a held first press has no confirmation deadline and cannot recover")
	key(KEY_R,false)
	key(KEY_ESCAPE,true)
	key(KEY_ESCAPE,false)
	assert(not drive.driver.recovery_armed and not drive.paused,"Back cancels the recovery confirmation before ordinary pause navigation")
	key(KEY_R,true)
	key(KEY_R,false)
	tick(drive)
	drive.driver.set_focus(false)
	drive.driver.set_focus(true)
	assert(not drive.driver.recovery_armed and drive.driver.assisted_recovery_ticks==0)
	key(KEY_R,true)
	tick(drive)
	drive.driver.set_focus(false)
	drive.driver.set_focus(true)
	key(KEY_R,true)
	tick(drive)
	assert(not drive.driver.recovery_armed,"a held recovery cannot re-arm across focus loss")
	key(KEY_R,false)
	pad(true)
	tick(drive)
	pad(true)
	tick(drive,40)
	assert(drive.driver.recovery_armed and drive.state.recovery_ticks==0,"duplicate held pad events cannot confirm")
	pad(false)
	pad(true)
	pad(false)
	tick(drive)
	assert(drive.state.recovery_hold_ticks==1)
	drive.touch.pointer_down(8,drive.touch.controls.steer.get_center())
	tick(drive)
	assert(drive.driver.owner_device=="touch" and drive.driver.assisted_recovery_ticks==0 and drive.state.recovery_hold_ticks==0,"device takeover cancels an unfinished assisted hold")
	drive.touch.pointer_up(8)
	var recover: Vector2 = drive.touch.controls.recover.get_center()
	tap(10,recover,true)
	tick(drive)
	assert(not drive.driver.recovery_armed,"cancelled touches do not arm recovery")
	tap(11,recover)
	tick(drive)
	assert(drive.driver.recovery_armed)
	drive.touch.pointer_down(12,recover)
	drive.touch.pointer_move(12,Vector2(-100,-100))
	drive.touch.pointer_up(12)
	tick(drive)
	assert(not drive.driver.recovery_armed and drive.state.recovery_hold_ticks==0,"dragging off a touch confirmation cancels it")
	tap(13,recover)
	tick(drive)
	tap(14,recover)
	tick(drive,29)
	assert(drive.state.recovery_hold_ticks==29 and drive.state.recovery_ticks==0)
	tick(drive)
	assert(drive.state.recovery_ticks==60,"two quick touch taps execute the same shared recovery")
	tick(drive,61)
	drive.driver.hold_assistance = false
	key(KEY_R,true)
	tick(drive,29)
	assert(drive.state.recovery_hold_ticks==29 and not drive.driver.recovery_armed,"disabling assistance restores ordinary hold input")
	key(KEY_R,false)
	tick(drive)
	assert(drive.state.recovery_hold_ticks==0)
	drive.queue_free()
	await process_frame
	print("RECOVERY_TWO_PRESS_CANCEL_DEVICE_TOUCH_SHARED_30_TICK_PASS")
	await create_timer(.5).timeout # Retire stopped audio on the mixer thread.
	quit()

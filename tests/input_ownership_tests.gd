extends SceneTree

var failures: int = 0
func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		print("TEST FAIL: " + message)

func _initialize() -> void:
	call_deferred("run")

func key_event(code: int, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	return event

func joy_button(pressed: bool) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = JOY_BUTTON_A
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	return event

func run() -> void:
	Catalog.load_all()
	DrivingInput.register_defaults()
	for dimensions: Vector2 in [Vector2(853,480),Vector2(640,360),Vector2(568,320),Vector2(800,360),Vector2(720,320)]:
		var safe := Rect2(Vector2(13,7),dimensions)
		for automatic: bool in [true,false]:
			for style: String in ["slider","buttons"]:
				for scale_factor: float in [.85,1.0,1.3]:
					for mirrored: bool in [false,true]:
						var layout := TouchDriving.build_layout(safe,automatic,style,scale_factor,mirrored)
						check(not layout.is_empty() and TouchDriving.legal_layout(layout,safe), "legal touch layout %s %s %s %.2f %s" % [dimensions,automatic,style,scale_factor,mirrored])
						check(layout.has("throttle") != automatic, "manual throttle inventory")
						if not layout.is_empty():
							check(layout.pause.size.x >= 48 and layout.brake.size.x >= 72, "minimum touch targets")
	check(TouchDriving.build_layout(Rect2(0,0,568,319),true,"slider",1,false).is_empty(), "unsupported short screens rejected")
	var touch := TouchDriving.new()
	touch.unit = 1
	touch.auto_accelerate = false
	touch.controls = TouchDriving.build_layout(Rect2(0,0,853,480),false,"slider",1,false)
	root.add_child(touch)
	# The real control's resize callback built its viewport layout; use the fixed
	# logical fixture for deterministic pointer positions below.
	touch.unit = 1
	touch.controls = TouchDriving.build_layout(Rect2(0,0,853,480),false,"slider",1,false)
	var driver := DrivingInput.new()
	driver.attach_touch(touch)
	touch.pointer_down(1,touch.controls.throttle.get_center())
	touch.pointer_down(2,touch.controls.steer.get_center()+Vector2(70,0))
	var frame := driver.sample(true,touch)
	check(frame.throttle==1 and frame.steer==1 and driver.owner_device=="touch", "manual throttle plus steering")
	touch.pointer_down(3,touch.controls.brake.get_center())
	check(driver.sample(true,touch).brake==1, "three independent fingers")
	touch.pointer_down(1,touch.controls.handbrake.get_center())
	check(not touch.held("handbrake"), "pointer cannot operate two controls")
	var axis := InputEventJoypadMotion.new()
	axis.device = 0
	axis.axis = JOY_AXIS_LEFT_X
	axis.axis_value = .8
	driver.observe(axis)
	check(driver.owner_device=="gamepad" and touch.captures.is_empty() and touch.suppressed, "gamepad takeover clears touch")
	touch.pointer_down(4,touch.controls.steer.get_center()-Vector2(70,0))
	check(driver.owner_device=="touch" and not touch.suppressed and driver.sample(true,touch).steer == -1, "touch reclaims input")
	driver.observe(axis)
	check(driver.owner_device=="touch", "unchanged held stick cannot reclaim touch")
	axis.axis_value = .9
	driver.observe(axis)
	check(driver.owner_device=="gamepad", "new stick movement reclaims pad")
	var press := key_event(KEY_W,true)
	driver.observe(press)
	check(driver.owner_device=="keyboard" and driver.sample(true,touch).throttle==1, "keyboard fallback drives independently")
	driver.observe(key_event(KEY_W,false))
	driver.set_focus(false)
	driver.auto_accelerate = true
	check(driver.sample(true,touch).throttle==0, "focus loss suppresses automatic throttle")
	driver.set_focus(true)
	driver.claim("touch")
	touch.auto_accelerate = true
	driver.context_reset(true)
	check(driver.sample(true,touch).throttle==0, "online resume requires fresh steering/throttle touch")
	touch.pointer_down(5,touch.controls.brake.get_center())
	touch.pointer_up(5)
	check(driver.sample(true,touch).throttle==0, "brake tap does not arm unattended acceleration")
	touch.pointer_down(6,touch.controls.steer.get_center())
	check(driver.sample(true,touch).throttle==1, "fresh steer touch arms auto throttle")
	check(driver.sample(false,touch).throttle==0, "Grid/Countdown/inactive input is neutral")
	driver.observe(key_event(KEY_SPACE,true))
	driver.context_reset()
	check(not driver.sample(true,touch).handbrake, "menu confirm cannot leak a held slide")
	driver.observe(key_event(KEY_SPACE,false))
	driver.observe(key_event(KEY_SPACE,true))
	check(driver.sample(true,touch).handbrake, "fresh handbrake press after context switch works")
	driver.observe(key_event(KEY_SPACE,false))
	driver.observe(joy_button(true))
	driver.observe(key_event(KEY_SPACE,true))
	driver.context_reset()
	driver.observe(key_event(KEY_SPACE,false))
	driver.claim("gamepad")
	check(not driver.sample(true,touch).handbrake, "releasing a keyboard key cannot unblock another device's held confirm")
	driver.observe(key_event(KEY_SPACE,true))
	check(driver.sample(true,touch).handbrake, "fresh keyboard press works while old gamepad confirm remains blocked")
	driver.observe(key_event(KEY_SPACE,false))
	driver.observe(joy_button(false))
	driver.observe(joy_button(true))
	check(driver.sample(true,touch).handbrake, "fresh gamepad press works after its own release")
	driver.observe(joy_button(false))
	touch.clear()
	touch.steering_style = "buttons"
	touch.controls = TouchDriving.build_layout(Rect2(0,0,853,480),false,"buttons",1,true)
	check(touch.controls.left.get_center().x < touch.controls.right.get_center().x, "mirroring preserves left/right button direction")
	touch.pointer_down(7,touch.controls.left.get_center())
	check(touch.steer==-1, "left steering button")
	touch.pointer_down(8,touch.controls.right.get_center())
	check(touch.steer==0, "opposite steering buttons cancel")
	touch.pointer_up(7)
	check(touch.steer==1, "releasing left preserves independent right input")
	check(DrivingInput.radial(Vector2(.1,.1),.15)==Vector2.ZERO, "radial deadzone includes diagonal center")
	check(DrivingInput.radial(Vector2(.6,.8),.15).is_equal_approx(Vector2(.6,.8)), "radial full magnitude preserves direction")
	check(absf(DrivingInput.radial(Vector2(.575,0),.15).x-.5)<.0001, "radial range rescales outside deadzone")
	touch.queue_free()
	await process_frame
	var drive := RaceDrive.new()
	drive.show_touch = true
	drive.external_menus = true
	drive.app_data = AppData.new("user://tests/touch-drive-" + str(Time.get_ticks_usec()),true)
	drive.app_data.settings.touch_auto_accelerate = false
	DrivingInput.last_device = "touch"
	root.add_child(drive)
	await physics_frame
	drive.session.phase = RaceSession.Phase.RACING
	var start := drive.state.position
	drive.touch.pointer_down(10,drive.touch.controls.throttle.get_center())
	for tick in range(120):
		await physics_frame
	check(drive.state.speed()>20 and drive.state.position.distance_to(start)>20, "manual touch throttle drives the real chassis on the baked road")
	drive.touch.pointer_up(10)
	check(drive.driver.sample(true,drive.touch).throttle==0, "manual throttle release coasts")
	drive.queue_free()
	await process_frame
	print("Driving ownership/layout fixtures: %d failures" % failures)
	quit(1 if failures else 0)

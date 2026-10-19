extends SceneTree
func _initialize() -> void: call_deferred("run")
func action(id: String) -> void:
	for pressed: bool in [true,false]:
		var event := InputEventAction.new()
		event.action = id
		event.pressed = pressed
		root.push_input(event,true)
func run() -> void:
	DrivingInput.register_defaults()
	var shell := MenuShell.new()
	shell.settings = SettingsCatalog.defaults(false)
	root.add_child(shell)
	var body := shell.reset("First")
	var first := shell.ui.button("First",func() -> void: pass)
	shell.ui.help(first,"Choose a course for one clean standing-start lap.")
	shell.ui.selected(first,true)
	body.add_child(first)
	var blocked := shell.ui.button("Unavailable",func() -> void: assert(false,"a disabled action must not activate"))
	blocked.disabled = true
	shell.ui.help(blocked,"Waiting for all racers to be ready.",true)
	body.add_child(blocked)
	for index in range(4): await process_frame
	shell.focus_help.set_process(false)
	first.grab_focus()
	shell.focus_help._process(.49)
	assert(not shell.focus_help.panel.visible)
	shell.focus_help._process(.011)
	assert(shell.focus_help.panel.visible and shell.focus_help.caption.text.begins_with("Choose"),"focus tooltip appears after half a second")
	DrivingInput.last_device = "keyboard"
	for pressed: bool in [true,false]:
		var touch_click := InputEventMouseButton.new()
		touch_click.device = MenuScroll.TAP_DEVICE
		touch_click.button_index = MOUSE_BUTTON_LEFT
		touch_click.pressed = pressed
		touch_click.position = first.get_global_rect().get_center()
		touch_click.global_position = touch_click.position
		root.push_input(touch_click,true)
	assert(DrivingInput.last_device=="touch","touch menu confirmation selects touch hints for the next scene")
	action("ui_down")
	await process_frame
	assert(blocked.has_focus(),"keyboard/gamepad navigation can inspect a disabled button")
	shell.focus_help._process(0)
	assert(shell.focus_help.panel.visible and shell.focus_help.caption.text.begins_with("Waiting"),"disabled reason is immediate on focus")
	var drag := InputEventScreenDrag.new()
	drag.relative = Vector2(0,-20)
	shell.focus_help._input(drag)
	shell.focus_help._process(1)
	assert(not shell.focus_help.panel.visible,"touch scrolling dismisses explanation until a fresh focus or tap")
	action("ui_accept")
	first.grab_focus()
	shell.focus_help._process(.1)
	assert(not shell.focus_help.panel.visible,"navigation dismisses the prior explanation")
	for index in range(15): await process_frame
	assert(first.modulate==Color.WHITE and first.get_theme_color("font_color")==UIFactory.TURQUOISE,"focus leaves the selected text accent and yellow border untinted")
	var pointer: FocusPointer = first.get_child(0)
	pointer.set_process(false)
	pointer.strength = 0
	pointer._process(.05)
	assert(is_equal_approx(pointer.strength,.5))
	pointer._process(.05)
	assert(pointer.strength==1)
	shell.reset("Second")
	assert(shell.motion.position.x>0,"new screen slides horizontally")
	for index in range(15): await process_frame
	assert(is_zero_approx(shell.motion.position.x),"screen slide completes within the specified 0.18 seconds")
	shell.reset("Second")
	assert(shell.motion.position.x==0,"same-screen refresh does not replay navigation motion")
	shell.settings.reduce_motion = true
	var next := shell.reset("Third")
	assert(shell.motion.position.x==0,"Reduce Motion uses an instant screen cut")
	var instant := shell.ui.button("Instant",func() -> void: pass)
	next.add_child(instant)
	await process_frame
	instant.grab_focus()
	var instant_pointer: FocusPointer = instant.get_child(0)
	instant_pointer._process(0)
	assert(instant_pointer.strength==1)
	shell.queue_free()
	await process_frame
	print("MENU_FOCUS_HALF_SECOND_DISABLED_KEYBOARD_NO_ACTIVATION_SELECTED_ACCENT_POINT_ONE_FOCUS_POINT_EIGHTEEN_SLIDE_REDUCE_MOTION_PASS")
	quit()

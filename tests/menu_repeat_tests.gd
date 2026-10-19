extends SceneTree

var repeater := MenuRepeat.new()
var enabled: bool = true
var now: int = 1000000
var buttons: Array[Button] = []
var option: OptionButton
var edit: LineEdit

func _initialize() -> void:
	call_deferred("run")

func key(code: int, pressed: bool, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	event.echo = echo
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func pad(pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = JOY_BUTTON_DPAD_DOWN
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func axis(value: float) -> void:
	var event := InputEventJoypadMotion.new()
	event.device = 0
	event.axis = JOY_AXIS_LEFT_Y
	event.axis_value = value
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func settle() -> void:
	await process_frame
	await process_frame

func tick(delta: int) -> void:
	now += delta
	repeater._process(0)
	await settle()

func run() -> void:
	BindingBook.apply({})
	var list := VBoxContainer.new()
	root.add_child(list)
	for index: int in range(8):
		var button := Button.new()
		button.text = str(index)
		button.custom_minimum_size = Vector2(300,48)
		list.add_child(button)
		buttons.append(button)
	option = OptionButton.new()
	for index: int in range(6):
		option.add_item(str(index))
	list.add_child(option)
	edit = LineEdit.new()
	list.add_child(edit)
	repeater.allowed = func() -> bool: return enabled
	repeater.clock = func() -> int: return now
	root.add_child(repeater)
	repeater.set_process(false)
	await settle()
	buttons[0].grab_focus()
	key(KEY_DOWN,true)
	await settle()
	assert(root.gui_get_focus_owner()==buttons[1],"exactly one initial key navigation")
	assert(Input.is_action_pressed("ui_down"),"synthetic release must preserve physical hold")
	key(KEY_DOWN,true,true)
	await settle()
	assert(root.gui_get_focus_owner()==buttons[1],"OS echo is suppressed")
	await tick(349999)
	assert(root.gui_get_focus_owner()==buttons[1])
	await tick(1)
	assert(root.gui_get_focus_owner()==buttons[2],"first repeat is 350 ms")
	await tick(89999)
	assert(root.gui_get_focus_owner()==buttons[2])
	await tick(1)
	assert(root.gui_get_focus_owner()==buttons[3],"following repeat is 90 ms")
	await tick(1000000)
	assert(root.gui_get_focus_owner()==buttons[4],"a hitch does not burst through items")
	repeater.clear_context()
	buttons[0].grab_focus()
	key(KEY_DOWN,true,true)
	await tick(500000)
	assert(root.gui_get_focus_owner()==buttons[0],"held key cannot navigate a new context")
	key(KEY_DOWN,false)
	assert(not Input.is_action_pressed("ui_down"))
	key(KEY_DOWN,true)
	await settle()
	assert(root.gui_get_focus_owner()==buttons[1])
	key(KEY_DOWN,false)
	await tick(500000)
	assert(root.gui_get_focus_owner()==buttons[1])
	pad(true)
	await settle()
	assert(root.gui_get_focus_owner()==buttons[2])
	await tick(350000)
	assert(root.gui_get_focus_owner()==buttons[3])
	pad(false)
	axis(.8)
	await settle()
	assert(root.gui_get_focus_owner()==buttons[4],"stick initial navigation")
	await tick(350000)
	assert(root.gui_get_focus_owner()==buttons[5],"stick repeat")
	axis(0)
	await tick(500000)
	assert(root.gui_get_focus_owner()==buttons[5],"stick neutral releases repeat")
	# PopupMenu has its own native gamepad repeat. Only our synthetic actions may
	# reach it, so time standing still below must never cause a second repeat.
	option.grab_focus()
	key(KEY_ENTER,true)
	key(KEY_ENTER,false)
	await settle()
	assert(option.get_popup().visible)
	option.get_popup().set_focused_item(0)
	pad(true)
	await settle()
	assert(option.get_popup().get_focused_item()==1)
	for frame: int in range(45):
		await process_frame
	assert(option.get_popup().get_focused_item()==1,"native popup gamepad repeat suppressed")
	await tick(350000)
	assert(option.get_popup().get_focused_item()==2)
	await tick(90000)
	assert(option.get_popup().get_focused_item()==3)
	pad(false)
	option.get_popup().hide()
	await settle()
	buttons[0].grab_focus()
	key(KEY_DOWN,true)
	await settle()
	enabled = false
	await tick(500000)
	enabled = true
	await tick(500000)
	assert(root.gui_get_focus_owner()==buttons[1],"disabled context cannot leak a held direction")
	key(KEY_DOWN,false)
	key(KEY_DOWN,true)
	await settle()
	assert(root.gui_get_focus_owner()==buttons[2])
	key(KEY_DOWN,false)
	edit.text = "abcd"
	edit.grab_focus()
	edit.caret_column = 2
	key(KEY_LEFT,true)
	await settle()
	assert(edit.caret_column==1,"text editing keeps native caret navigation")
	key(KEY_LEFT,false)
	root.remove_child(repeater)
	repeater.free()
	list.queue_free()
	await settle()
	print("Menu repeat: initial step, exact 350/90 ms, OS echo suppression, context holds, keyboard, pad, stick, popup and native text editing pass")
	quit()

class_name MenuRepeat
extends Node
## Own navigation repeat without changing OS keyboard preferences. Synthetic
## press/release pairs use a separate source and never become driving input.

const DIRECTIONS := ["ui_up","ui_down","ui_left","ui_right"]
const DELAY_US: int = 350000
const INTERVAL_US: int = 90000
var allowed: Callable
var clock: Callable = func() -> int: return Time.get_ticks_usec()
var held_action: String = ""
var repeat_at: int = 0
var generation: int = 0
var blocked: Dictionary = {}
var last_joy: int = -1
var was_allowed: bool = false

func _ready() -> void:
	was_allowed = is_allowed()

func clear_context() -> void:
	generation+=1
	held_action=""
	repeat_at=0
	blocked.clear()
	for action: String in DIRECTIONS:
		if physical_held(action):
			blocked[action]=true

func is_allowed() -> bool:
	return allowed.is_valid() and bool(allowed.call())

func physical_held(action: String) -> bool:
	var pads:=Input.get_connected_joypads()
	if last_joy>=0 and not pads.has(last_joy):
		pads.append(last_joy)
	for event: InputEvent in InputMap.action_get_events(action):
		if event is InputEventKey:
			if Input.is_physical_key_pressed(event.physical_keycode) if event.physical_keycode!=0 else Input.is_key_pressed(event.keycode):
				return true
		elif event is InputEventJoypadButton:
			for device: int in pads:
				if Input.is_joy_button_pressed(device,event.button_index):
					return true
		elif event is InputEventJoypadMotion:
			for device: int in pads:
				if Input.get_joy_axis(device,event.axis)*signf(event.axis_value)>InputMap.action_get_deadzone(action):
					return true
	return false

func text_editing(event: InputEvent) -> bool:
	if not event is InputEventKey:
		return false
	var focus:=get_viewport().gui_get_focus_owner()
	return focus is LineEdit or focus is TextEdit

func _input(event: InputEvent) -> void:
	if event is InputEventAction:
		return
	if event is InputEventJoypadButton or event is InputEventJoypadMotion:
		last_joy=event.device
	if not is_allowed() or text_editing(event):
		return
	var action: String=""
	for candidate: String in DIRECTIONS:
		if event.is_action(candidate,true):
			action=candidate
			break
	if action=="":
		return
	DrivingInput.remember_menu_device(event)
	get_viewport().set_input_as_handled()
	if event.is_action_released(action,true):
		if not physical_held(action):
			blocked.erase(action)
			if held_action==action:
				held_action=""
				generation+=1
		return
	if event is InputEventKey and event.echo or blocked.has(action):
		return
	if not event.is_action_pressed(action,false,true):
		return
	if held_action!=action:
		held_action=action
		repeat_at=int(clock.call())+DELAY_US
		emit_navigation.call_deferred(action,generation)

func _process(_dt: float) -> void:
	var active:=is_allowed()
	if active!=was_allowed:
		clear_context()
		was_allowed=active
	for action: String in blocked.keys():
		if not physical_held(action):
			blocked.erase(action)
	if not active or held_action=="":
		return
	var focus := get_viewport().gui_get_focus_owner()
	if focus is LineEdit or focus is TextEdit:
		clear_context()
		return
	if not physical_held(held_action):
		held_action=""
		generation+=1
		return
	var now:=int(clock.call())
	if now>=repeat_at:
		emit_navigation.call_deferred(held_action,generation)
		# A long frame skips missed repeats rather than jumping through a menu.
		repeat_at=now+INTERVAL_US if now>repeat_at+INTERVAL_US else repeat_at+INTERVAL_US

func emit_navigation(action: String,token: int) -> void:
	if token!=generation or not is_allowed():
		return
	for pressed: bool in [true,false]:
		var event:=InputEventAction.new()
		event.device=-9123
		event.action=action
		event.pressed=pressed
		Input.parse_input_event(event)
	Input.flush_buffered_events()

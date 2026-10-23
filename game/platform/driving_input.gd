class_name DrivingInput
extends RefCounted
## One driving owner at a time. Menus keep their own InputMap context.

signal device_changed(device_name: String)

const ACTIONS := ["steer_left", "steer_right", "accelerate", "brake", "boost", "handbrake", "recover", "camera", "look_back", "pause"]
const EDGE_ACTIONS := ["boost", "handbrake", "recover", "camera", "look_back", "pause"]
static var last_device: String = ""
static var last_joy: int = -1
var auto_accelerate: bool = false
var deadzone: float = .15
var sensitivity: float = 1.0
var owner_device: String = "keyboard"
var joy_device: int = -1
var focused: bool = true
var fresh_touch_needed: bool = false
var blocked: Dictionary = {}
var previous_axes: Dictionary = {}
var touch_controls: TouchDriving
var recovery_armed: bool = false
var recovery_presses: int = 0
var assisted_recovery_ticks: int = 0
var recovery_down: Dictionary = {}
var hold_assistance: bool = false:
	set(value):
		if hold_assistance!=value: cancel_recovery_assist()
		hold_assistance = value


func _init() -> void:
	BindingBook.ensure_defaults()


static func register_defaults() -> void:
	BindingBook.ensure_defaults()


func attach_touch(control: TouchDriving) -> void:
	touch_controls = control
	control.capture_started.connect(claim_touch)
	control.captures_cleared.connect(cancel_recovery_assist)
	control.capture_cancelled.connect(func(action: String) -> void:
		if action=="recover": cancel_recovery_assist())
	owner_device = last_device if last_device != "" else ("touch" if control.visible else "keyboard")
	joy_device = last_joy
	if owner_device == "gamepad" and not Input.get_connected_joypads().has(joy_device):
		owner_device = "keyboard"
	if owner_device == "touch" and not control.visible:
		owner_device = "keyboard"
	control.set_suppressed(owner_device != "touch")
	context_reset()


func context_reset(require_fresh_touch: bool = false) -> void:
	cancel_recovery_assist()
	blocked.clear()
	var pads := Input.get_connected_joypads()
	if joy_device >= 0 and not pads.has(joy_device):
		pads.append(joy_device)
	for action: String in EDGE_ACTIONS:
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey:
				var pressed := Input.is_physical_key_pressed(event.physical_keycode) if event.physical_keycode != 0 else Input.is_key_pressed(event.keycode)
				if pressed:
					blocked[key_id(event)] = true
			elif event is InputEventJoypadButton:
				for device: int in pads:
					if Input.is_joy_button_pressed(device,event.button_index):
						blocked["button:%d:%d" % [device,event.button_index]] = true
			elif event is InputEventJoypadMotion:
				for device: int in pads:
					if Input.get_joy_axis(device,event.axis) * signf(event.axis_value) > .5:
						blocked["axis:%d:%d:%d" % [device,event.axis,int(signf(event.axis_value))]] = true
	fresh_touch_needed = require_fresh_touch
	if is_instance_valid(touch_controls):
		touch_controls.clear()


func set_focus(value: bool) -> void:
	focused = value
	if not value:
		context_reset(true)


func claim(device_name: String) -> void:
	last_device = device_name
	last_joy = joy_device
	if owner_device != device_name:
		cancel_recovery_assist()
		owner_device = device_name
		device_changed.emit(device_name)
	if is_instance_valid(touch_controls):
		touch_controls.set_suppressed(device_name != "touch")


func claim_touch(action: String) -> void:
	claim("touch")
	if action=="recover": queue_recovery_press()
	if action in ["steer", "left", "right", "throttle"]:
		fresh_touch_needed = false


func observe(event: InputEvent) -> void:
	if event is InputEventKey and not event.pressed:
		blocked.erase(key_id(event))
		recovery_down.erase(key_id(event))
	elif event is InputEventJoypadButton and not event.pressed:
		blocked.erase("button:%d:%d" % [event.device,event.button_index])
		recovery_down.erase("button:%d:%d" % [event.device,event.button_index])
	elif event is InputEventJoypadMotion:
		for direction: int in [-1,1]:
			if event.axis_value * direction < .2:
				blocked.erase("axis:%d:%d:%d" % [event.device,event.axis,direction])
				recovery_down.erase("axis:%d:%d:%d" % [event.device,event.axis,direction])
	if not focused:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		for action: String in ACTIONS:
			if event.is_action_pressed(action):
				claim("keyboard")
				if action=="recover": queue_recovery_press(key_id(event))
				return
	elif event is InputEventJoypadButton and event.pressed:
		for action: String in ACTIONS:
			if event.is_action_pressed(action):
				if owner_device=="gamepad" and joy_device!=event.device: cancel_recovery_assist()
				joy_device = event.device
				claim("gamepad")
				if action=="recover": queue_recovery_press("button:%d:%d"%[event.device,event.button_index])
				return
	elif event is InputEventJoypadMotion:
		var key := "%d:%d" % [event.device, event.axis]
		var previous := float(previous_axes.get(key, 0.0))
		previous_axes[key] = event.axis_value
		if absf(event.axis_value) > .2 and absf(event.axis_value - previous) > .02:
			for action: String in ACTIONS:
				if event.is_action_pressed(action):
					if owner_device=="gamepad" and joy_device!=event.device: cancel_recovery_assist()
					joy_device = event.device
					claim("gamepad")
					if action=="recover": queue_recovery_press("axis:%d:%d:%d"%[event.device,event.axis,int(signf(event.axis_value))])
					return


static func radial(value: Vector2, zone: float) -> Vector2:
	var magnitude := minf(value.length(), 1)
	return Vector2.ZERO if magnitude <= zone else value.normalized() * (magnitude - zone) / (1 - zone)


func action_strength(action: String) -> float:
	var result := 0.0
	for event: InputEvent in InputMap.action_get_events(action):
		if owner_device == "keyboard" and event is InputEventKey:
			var held := Input.is_physical_key_pressed(event.physical_keycode) if event.physical_keycode != 0 else Input.is_key_pressed(event.keycode)
			if held and not blocked_value(key_id(event),held):
				result = 1.0
		elif owner_device == "gamepad" and event is InputEventJoypadButton:
			if Input.is_joy_button_pressed(joy_device, event.button_index) and not blocked_value("button:%d:%d" % [joy_device,event.button_index],true):
				result = 1.0
		elif owner_device == "gamepad" and event is InputEventJoypadMotion:
			var value := Input.get_joy_axis(joy_device, event.axis)
			if action in ["steer_left", "steer_right"]:
				if event.axis in [JOY_AXIS_LEFT_X, JOY_AXIS_LEFT_Y]:
					var stick := radial(Vector2(Input.get_joy_axis(joy_device, JOY_AXIS_LEFT_X), Input.get_joy_axis(joy_device, JOY_AXIS_LEFT_Y)), deadzone)
					value = stick.x if event.axis == JOY_AXIS_LEFT_X else stick.y
				elif event.axis in [JOY_AXIS_RIGHT_X, JOY_AXIS_RIGHT_Y]:
					var stick := radial(Vector2(Input.get_joy_axis(joy_device, JOY_AXIS_RIGHT_X), Input.get_joy_axis(joy_device, JOY_AXIS_RIGHT_Y)), deadzone)
					value = stick.x if event.axis == JOY_AXIS_RIGHT_X else stick.y
				else:
					value = signf(value) * maxf(0, (absf(value) - deadzone) / (1 - deadzone))
			var strength := clampf(value * signf(event.axis_value), 0, 1)
			if not blocked_value("axis:%d:%d:%d" % [joy_device,event.axis,int(signf(event.axis_value))],strength>.2):
				result = maxf(result,strength)
	return result


func held(action: String, touch: TouchDriving = null) -> bool:
	if not focused:
		return false
	return touch.held(action) if owner_device == "touch" and touch else action_strength(action) > .5


func sample(active: bool, touch: TouchDriving = null) -> InputFrame:
	if not active or not focused or (owner_device == "touch" and touch and (not touch.enabled or not touch.layout_supported)):
		cancel_recovery_assist()
		return InputFrame.make()
	var frame := InputFrame.make()
	if owner_device == "touch" and touch:
		frame.steer = touch.steer
		frame.throttle = 1.0 if touch.held("throttle") else 0.0
		frame.brake = 1.0 if touch.held("brake") else 0.0
		frame.handbrake = touch.held("handbrake")
		frame.recover = touch.held("recover")
		frame.boost = touch.held("boost")
		if touch.auto_accelerate and not fresh_touch_needed and frame.brake == 0:
			frame.throttle = 1.0
	else:
		frame.steer = action_strength("steer_right") - action_strength("steer_left")
		if owner_device == "gamepad":
			frame.steer = signf(frame.steer) * pow(absf(frame.steer), 1.3)
		frame.throttle = action_strength("accelerate")
		frame.brake = action_strength("brake")
		frame.handbrake = action_strength("handbrake") > .5
		frame.recover = action_strength("recover") > .5
		frame.boost = action_strength("boost") > .5
		if auto_accelerate and frame.brake == 0:
			frame.throttle = 1.0
	frame.steer = clampf(frame.steer * sensitivity, -1, 1)
	if hold_assistance:
		for _press in range(recovery_presses):
			if assisted_recovery_ticks>0: break
			if recovery_armed:
				recovery_armed = false
				assisted_recovery_ticks = 30
			else: recovery_armed = true
		recovery_presses = 0
		frame.recover = assisted_recovery_ticks>0
		assisted_recovery_ticks = maxi(0,assisted_recovery_ticks-1)
	return frame


func queue_recovery_press(id: String = "") -> void:
	if not hold_assistance or not focused: return
	if id!="":
		if blocked.has(id) or recovery_down.has(id): return
		recovery_down[id] = true
	if assisted_recovery_ticks==0: recovery_presses = mini(2,recovery_presses+1)


func cancel_recovery_assist() -> void:
	recovery_armed = false
	recovery_presses = 0
	assisted_recovery_ticks = 0
	recovery_down.clear()


static func remember_menu_device(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		last_device = "touch"
	elif event is InputEventKey and event.pressed and not event.echo:
		last_device = "keyboard"
	elif event is InputEventJoypadButton and event.pressed or event is InputEventJoypadMotion and absf(event.axis_value) > .2:
		last_device = "gamepad"
		last_joy = event.device
	elif event is InputEventMouseButton and event.pressed and not OS.has_feature("mobile"):
		last_device = "keyboard"


static func key_id(event: InputEventKey) -> String:
	return ("physical:" + str(event.physical_keycode)) if event.physical_keycode != 0 else ("key:" + str(event.keycode))


func blocked_value(id: String, pressed: bool) -> bool:
	if not pressed:
		blocked.erase(id)
	return pressed and blocked.has(id)

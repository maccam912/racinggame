class_name DrivingInput
extends RefCounted

var auto_accelerate: bool = false
var deadzone: float = .15
var sensitivity: float = 1.0


static func register_defaults() -> void:
	var keys := {"steer_left": [KEY_A, KEY_LEFT], "steer_right": [KEY_D, KEY_RIGHT], "accelerate": [KEY_W, KEY_UP], "brake": [KEY_S, KEY_DOWN], "handbrake": [KEY_SPACE], "recover": [KEY_R], "camera": [KEY_C], "look_back": [KEY_V], "pause": [KEY_ESCAPE]}
	for action: String in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key: int in keys[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
	var buttons := {"handbrake": JOY_BUTTON_A, "recover": JOY_BUTTON_Y, "camera": JOY_BUTTON_B, "look_back": JOY_BUTTON_RIGHT_STICK, "pause": JOY_BUTTON_START}
	for action: String in buttons:
		var event := InputEventJoypadButton.new()
		event.button_index = buttons[action]
		InputMap.action_add_event(action, event)


func sample(active: bool, touch: TouchDriving = null) -> InputFrame:
	if not active:
		return InputFrame.make()
	var frame := InputFrame.make(Input.get_axis("steer_left", "steer_right"), Input.get_action_strength("accelerate"), Input.get_action_strength("brake"), Input.is_action_pressed("handbrake"))
	frame.recover = Input.is_action_pressed("recover")
	if not Input.get_connected_joypads().is_empty():
		var device: int = Input.get_connected_joypads()[0]
		var x := Input.get_joy_axis(device, JOY_AXIS_LEFT_X)
		if absf(x) > deadzone:
			frame.steer = signf(x) * pow((absf(x) - deadzone) / (1 - deadzone), 1.3)
		frame.throttle = maxf(frame.throttle, Input.get_joy_axis(device, JOY_AXIS_TRIGGER_RIGHT))
		frame.brake = maxf(frame.brake, Input.get_joy_axis(device, JOY_AXIS_TRIGGER_LEFT))
	if touch and touch.has_driving_capture():
		frame.steer = touch.steer
		frame.brake = 1.0 if touch.held("brake") else 0.0
		frame.handbrake = touch.held("handbrake")
		frame.recover = touch.held("recover")
	if (auto_accelerate or (touch and touch.auto_accelerate)) and frame.brake == 0:
		frame.throttle = 1.0
	frame.steer = clampf(frame.steer * sensitivity, -1, 1)
	return frame

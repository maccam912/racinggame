class_name InputFrame
extends RefCounted

var sequence: int = 0
var tick: int = 0
var steer: float = 0.0
var throttle: float = 0.0
var brake: float = 0.0
var handbrake: bool = false
var recover: bool = false
var boost: bool = false


static func make(s: float = 0.0, t: float = 0.0, b: float = 0.0, hand: bool = false) -> InputFrame:
	var frame := InputFrame.new()
	frame.steer = clampf(s, -1.0, 1.0) if is_finite(s) else 0.0
	frame.throttle = clampf(t, 0.0, 1.0) if is_finite(t) else 0.0
	frame.brake = clampf(b, 0.0, 1.0) if is_finite(b) else 0.0
	frame.handbrake = hand
	return frame

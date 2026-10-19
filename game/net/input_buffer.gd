class_name InputBuffer
extends RefCounted

var frames: Array[InputFrame] = []
var last_sequence: int = 0
var last_frame := InputFrame.make()
var missing_ticks: int = 0
var rejected: int = 0


static func newer(a: int, b: int) -> bool:
	var difference := (a - b) & 0xffffffff
	return difference > 0 and difference < 0x80000000


func push(frame: InputFrame, server_tick: int) -> void:
	if not newer(frame.sequence, last_sequence):
		return
	if abs(frame.tick - server_tick) > 12:
		rejected += 1
		return
	if frames.any(func(existing: InputFrame) -> bool: return existing.sequence == frame.sequence):
		return
	if frames.size() >= 32:
		rejected += 1
		return
	frames.append(frame)
	frames.sort_custom(func(a: InputFrame, b: InputFrame) -> bool: return newer(b.sequence, a.sequence))


func sample(server_tick: int) -> InputFrame:
	if not frames.is_empty() and frames[0].tick + 3 <= server_tick:
		last_frame = frames.pop_front()
		last_sequence = last_frame.sequence
		missing_ticks = 0
	else:
		missing_ticks += 1
	if missing_ticks > 6:
		var neutral := InputFrame.make()
		neutral.sequence = last_sequence
		return neutral
	return last_frame

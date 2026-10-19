class_name Medals
extends RefCounted


static func thresholds(length: float) -> Array[float]:
	var gold := ceilf((length / 43 + 7) * 10 - .0000001) / 10
	return [gold, ceilf(gold * 1.12 * 10 - .0000001) / 10, ceilf(gold * 1.27 * 10 - .0000001) / 10]


static func award(length: float, seconds: float, valid: bool) -> int:
	if not valid or seconds < 0:
		return -1
	var times := thresholds(length)
	for index in range(3):
		if seconds <= times[index]:
			return index
	return -1

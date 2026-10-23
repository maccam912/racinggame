class_name Medals
extends RefCounted


static func thresholds(length: float, track: TrackDefinition = null) -> Array[float]:
	var reference := float(track.bake.get("medal_reference_seconds",0)) if track!=null else 0.0
	# Tight linked bends need a target based on their actual braking line. Keep
	# the existing length target as a floor on fast and legacy fixture routes.
	var gold := ceilf(maxf(length / 43 + 7,reference+maxf(8,reference*.08)) * 10 - .0000001) / 10
	return [gold, ceilf(gold * 1.12 * 10 - .0000001) / 10, ceilf(gold * 1.27 * 10 - .0000001) / 10]


static func award(length: float, seconds: float, valid: bool, track: TrackDefinition = null) -> int:
	if not valid or seconds < 0:
		return -1
	var times := thresholds(length,track)
	for index in range(3):
		if seconds <= times[index]:
			return index
	return -1

class_name TurnGuidance
extends RefCounted
## Read-only upcoming bend cue from the same baked centerline as the minimap.
static func next_turn(track: TrackDefinition, distance: float, speed: float) -> Dictionary:
	if speed < 4 or distance < 0: return {}
	var horizon := clampf(speed*3.0,60,180)
	for ahead in range(8,int(horizon)+1,8):
		var before := -track.pose(distance+ahead).basis.z
		var after := -track.pose(distance+ahead+32).basis.z
		var angle := atan2(before.x*after.z-before.z*after.x,before.x*after.x+before.z*after.z)
		if absf(angle) >= deg_to_rad(12):
			return {"direction":1 if angle>0 else -1,"distance":float(ahead)}
	return {}

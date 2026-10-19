class_name BotDriver
extends RefCounted
## Canonical centerline controller; also drives repeatable network fixtures.

var planning_ticks: int = 0
var previous := InputFrame.make()
var difficulty: int = 1
var offset: float = 0.0
var stuck_ticks: int = 0


func sample(state: VehicleState, car: CarDefinition, track: TrackDefinition, query: WorldQuery, others: Array[VehicleState] = []) -> InputFrame:
	if state.speed() < 2 and previous.throttle > .7:
		stuck_ticks += 1
	else:
		stuck_ticks = 0
	if stuck_ticks >= 240:
		previous.recover = true
		return previous
	planning_ticks -= 1
	if planning_ticks > 0:
		return previous
	planning_ticks = [12, 6, 3][difficulty]
	var nearest := query.nearest(state.position)
	var target_s: float = nearest.s + clampf(8 + .45 * state.speed(), 12, 35)
	var target_speed: float = track.bake.ai_speeds[car.id][nearest.i] * [.78, .90, 1.0][difficulty]
	var wanted_offset := 0.0
	for rival: VehicleState in others:
		if rival == state or rival.finished:
			continue
		var delta := rival.position - state.position
		var ahead := delta.dot(state.forward())
		var lateral := delta.dot(state.forward().cross(Vector3.UP))
		if ahead > 0 and ahead < 25 and absf(lateral) < 3:
			wanted_offset = -3 if lateral > 0 or (absf(lateral) < .1 and state.slot % 2 == 0) else 3
			var half_width: float = track.bake.samples[nearest.i][8] / 2
			if absf(nearest.lateral + wanted_offset) + 2.5 > half_width:
				wanted_offset = 0
				target_speed = minf(target_speed, maxf(0, rival.speed() - 1))
	offset = move_toward(offset, wanted_offset, 2 * planning_ticks / 60.0)
	var target := track.pose(target_s, offset).origin - state.position
	var forward := state.forward()
	var error := atan2(forward.x * target.z - forward.z * target.x, forward.x * target.x + forward.z * target.z)
	previous = InputFrame.make(clampf(rad_to_deg(error) / 30, -1, 1), clampf((target_speed - state.speed()) / 6, 0, 1), clampf((state.speed() - target_speed) / 6, 0, 1))
	return previous

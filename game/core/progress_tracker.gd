class_name ProgressTracker
extends RefCounted


static func advance(state: VehicleState, previous: Vector3, track: TrackDefinition, ticks: int, lap_count: int) -> void:
	if state.finished or state.recovery_ticks > 0:
		return
	var last_fraction := -1.0
	for _crossing in range(8):
		var next: int = (state.last_gate + 1) % track.bake.gates.size()
		var gate: Dictionary = track.bake.gates[next]
		var origin := vector(gate.position)
		var forward := vector(gate.forward)
		var before := (previous - origin).dot(forward)
		var after := (state.position - origin).dot(forward)
		if before >= 0 or after < 0 or after - before <= .000001:
			break
		var fraction := -before / (after - before)
		if fraction <= last_fraction:
			break
		var crossing := previous.lerp(state.position, fraction)
		var half_width: float = track.bake.samples[track.sample_index(gate.s)][8] / 2 + 3
		if absf((crossing - origin).dot(forward.cross(Vector3.UP))) > half_width or absf(crossing.y - origin.y) > 6:
			break
		if next == 0 and state.last_gate > 0:
			state.laps += 1
			state.events.append("lap")
			if state.laps >= lap_count:
				state.finished = true
				state.finish_time = (ticks - 1 + fraction) / 60.0
				state.events.append("finish")
		state.last_gate = next
		last_fraction = fraction


static func vector(data: Array) -> Vector3:
	return Vector3(data[0], data[1], data[2])


static func recover(state: VehicleState, track: TrackDefinition) -> void:
	var gate: Dictionary = track.bake.gates[maxi(0, state.last_gate)]
	state.position = vector(gate.recovery) + Vector3.UP * .35
	var forward := vector(gate.forward)
	state.yaw = atan2(forward.x, -forward.z)
	state.velocity = Vector3.ZERO
	state.yaw_rate = 0
	state.steer_filter = 0
	state.drift_phase = 0
	state.drift_timer = 0
	state.drift_entry = 0
	state.reverse_hold = 0
	state.reversing = false
	state.recovery_ticks = 60
	state.recovery_hold_ticks = 0
	state.ghost_ticks = 180
	state.offroad_ticks = 0
	state.trial_valid = false
	state.events.append("recovery")


static func safety(state: VehicleState, frame: InputFrame, track: TrackDefinition, query: WorldQuery) -> void:
	var nearest := query.nearest(state.position)
	for marker: float in track.definition.ramp_markers:
		var crest := fposmod(marker * track.length - track.start_sample * 2, track.length)
		if state.route_s >= 0 and state.route_s < crest and nearest.s >= crest and nearest.s - state.route_s < 5 and state.grounded and state.speed() >= 30 and state.jump_lap != state.laps:
			state.velocity.y = 3.8
			state.launch_ticks = 11
			state.grounded = false
			state.jump_lap = state.laps
			state.events.append("jump")
	state.route_s = nearest.s
	var half_width: float = track.bake.samples[nearest.i][8] / 2 + 3
	state.outside_ticks = state.outside_ticks + 1 if absf(nearest.lateral) > half_width else 0
	if state.outside_ticks > 15:
		state.trial_valid = false
	var offroad: bool = absf(nearest.lateral) > half_width + 2 or state.position.y < track.points[nearest.i].y - 8
	state.offroad_ticks = state.offroad_ticks + 1 if offroad else 0
	state.recovery_hold_ticks = state.recovery_hold_ticks + 1 if frame.recover else 0
	var wrong: bool = state.forward().dot(track.forwards[nearest.i]) < -.25 and state.speed() > 5
	if wrong:
		state.wrong_way_ticks += 1
		state.forward_ticks = 0
	else:
		state.forward_ticks += 1
		if state.forward_ticks >= 30:
			state.wrong_way_ticks = 0
	if state.wrong_way_ticks > 180:
		state.trial_valid = false
	if state.offroad_ticks >= 30 or state.recovery_hold_ticks >= 30 or state.position.y < -80:
		recover(state, track)
		query.hint = track.sample_index(track.bake.gates[maxi(0, state.last_gate)].s - 6)
		state.route_s = fposmod(track.bake.gates[maxi(0, state.last_gate)].s - 6, track.length)

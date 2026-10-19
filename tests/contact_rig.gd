extends RefCounted
## Source-only NET-02 fixture: reload explicit starting states between exercises.
## Ordinary car/world contact is unchanged. Reload corrections are tagged recovery.


func apply(session: RaceSession) -> void:
	if session.phase not in [RaceSession.Phase.RACING, RaceSession.Phase.GRACE]:
		return
	var offset := (session.elapsed_ticks - 1) % 240
	if offset == 0:
		var side_contact := int((session.elapsed_ticks - 1) / 240) % 2 == 0
		for index in range(session.states.size()):
			var state := session.states[index]
			var s := 20.0 if side_contact or index == 0 else 12.0
			var pose := session.track.pose(s, (-3.0 if index == 0 else 3.0) if side_contact else 0.0)
			state.position = pose.origin + Vector3.UP * .35
			state.yaw = atan2(-pose.basis.z.x, pose.basis.z.z) + ((asin(5.0 / 30) if index == 0 else -asin(5.0 / 30)) if side_contact else 0.0)
			state.velocity = state.forward() * (30.0 if side_contact or index == 1 else 20.0)
			state.yaw_rate = 0
			state.steer_filter = 0
			state.drift_phase = 0
			state.drift_timer = 0
			state.drift_entry = 0
			state.wall_contact = false
			state.contact_ticks = 0
			state.recovery_ticks = 0
			state.ghost_ticks = 0
			state.last_gate = 0
			state.laps = 0
			state.route_s = s
			state.grounded = true
			state.finished = false
			state.events.clear()
			session.queries[index].hint = session.track.sample_index(s)
	if offset < 13:
		for state: VehicleState in session.states:
			if not "recovery" in state.events:
				state.events.append("recovery")

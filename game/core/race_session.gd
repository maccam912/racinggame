class_name RaceSession
extends RefCounted
## One simulation entry point for offline play and dedicated authority.

enum Phase { LOBBY, LOADING, GRID, COUNTDOWN, RACING, GRACE, RESULTS }

var race_id: int = 1
var seed: int = 1
var track: TrackDefinition
var states: Array[VehicleState] = []
var cars: Array[CarDefinition] = []
var queries: Array[WorldQuery] = []
var inputs: Array[InputFrame] = []
var phase: Phase = Phase.GRID
var phase_ticks: int = 0
var elapsed_ticks: int = 0
var lap_count: int = 2
var contact_enabled: bool = true
var first_finish_tick: int = -1
var settled_ticks: int = 0
var bots: Dictionary = {}
var driving_assists: Dictionary = {} # Human slots; online assignments are authority-owned.
var corner_braking: Dictionary = {} # Local-only preference, never a client authority override.
var finish_drivers: Array[BotDriver] = []
var roster: Array[Dictionary] = []
var human_slot: int = 0
var mode: String = "quick"
var race_uuid: String = ""
var event_uuid: String = ""
var cup_event: int = -1


func setup(route: TrackDefinition, car_indices: Array[int], world: World3D, laps: int = 2) -> void:
	track = route
	lap_count = laps
	for index in range(car_indices.size()):
		var state := VehicleState.new()
		state.slot = index
		state.boost_charges = Catalog.cars[car_indices[index]].boost_charges
		var s := -8.0 - 7 * (index / 2)
		var pose := track.pose(s, -2.5 if index % 2 == 0 else 2.5)
		state.position = pose.origin + Vector3.UP * .35
		state.yaw = atan2(-pose.basis.z.x, pose.basis.z.z)
		states.append(state)
		cars.append(Catalog.cars[car_indices[index]])
		queries.append(WorldQuery.new(world, track, s))
		inputs.append(InputFrame.make())
		finish_drivers.append(BotDriver.new())


func step(frames: Dictionary) -> void:
	if phase == Phase.RESULTS:
		return
	phase_ticks += 1
	if phase == Phase.GRID:
		if phase_ticks >= 120:
			phase = Phase.COUNTDOWN
			phase_ticks = 0
		return
	if phase == Phase.COUNTDOWN:
		if phase_ticks >= 180:
			phase = Phase.RACING
			phase_ticks = 0
			for state: VehicleState in states:
				state.ghost_ticks = 90
		return
	elapsed_ticks += 1
	update_race_roles()
	remember_recovery_order()
	# Sample the whole field before any car moves, avoiding slot-order bias.
	var pace: Dictionary = {}
	for index: int in bots: pace[index] = rubberband_pace(states[index])
	var previous: Array[Vector3] = []
	for index in range(states.size()):
		previous.append(states[index].position)
		inputs[index] = frames.get(index, InputFrame.make())
		if states[index].finished:
			var ack := states[index].last_ack
			inputs[index] = finish_drivers[index].sample(states[index], cars[index], track, queries[index], states)
			inputs[index].sequence = ack
		elif bots.has(index):
			inputs[index] = bots[index].sample(states[index], cars[index], track, queries[index], states, pace[index])
		else:
			if driving_assists.has(index):
				inputs[index] = DrivingAssist.apply(states[index], inputs[index], queries[index], int(driving_assists[index]))
			if bool(corner_braking.get(index,false)) or int(driving_assists.get(index,0))==DrivingAssist.RELAXED:
				inputs[index] = CornerAssist.apply(states[index], inputs[index], cars[index], queries[index])
		if states[index].dnf_reason == "":
			VehicleSim.step(states[index], inputs[index], cars[index], queries[index])
	if contact_enabled:
		CarContact.resolve(states, queries)
	for index in range(states.size()):
		var state := states[index]
		if state.finished or state.dnf_reason != "":
			continue
		if race_assistance() and state.recovery_rank >= 0:
			if state.recovery_ticks == 30:
				rejoin_field(state, queries[index])
		if state.recovery_ticks == 0 and previous[index].distance_to(state.position) < 5:
			state.distance_m += previous[index].distance_to(state.position)
		ProgressTracker.advance(state, previous[index], track, elapsed_ticks, lap_count)
		ProgressTracker.safety(state, inputs[index], track, queries[index])
		if state.finished and first_finish_tick < 0:
			first_finish_tick = elapsed_ticks
			phase = Phase.GRACE
			phase_ticks = 0
	if elapsed_ticks >= int(Catalog.rules.hard_limit_ticks) or (first_finish_tick >= 0 and elapsed_ticks - first_finish_tick >= finish_grace_limit()):
		finish_race("Time limit" if elapsed_ticks >= int(Catalog.rules.hard_limit_ticks) else "Finish grace expired")
		return
	var complete := states.all(func(state: VehicleState) -> bool: return state.finished or state.dnf_reason != "")
	var has_humans := false
	var humans_complete := true
	for state: VehicleState in states:
		if not bots.has(state.slot):
			has_humans = true
			if not state.finished and state.dnf_reason == "": humans_complete = false
	humans_complete = has_humans and humans_complete
	# AI can keep racing briefly, but never hold completed human races open.
	# Keep the shorter settling period when the entire field is already done.
	settled_ticks = settled_ticks + 1 if complete or humans_complete else 0
	if (complete and settled_ticks >= 120) or (humans_complete and settled_ticks >= int(Catalog.rules.human_finish_grace_ticks)):
		finish_race("Race complete")


func finish_race(reason: String) -> void:
	for state: VehicleState in states:
		if not state.finished and state.dnf_reason == "": state.dnf_reason = reason
	phase = Phase.RESULTS
	phase_ticks = 0


func standings() -> Array[VehicleState]:
	var order := states.duplicate()
	order.sort_custom(func(a: VehicleState, b: VehicleState) -> bool:
		if a.finished != b.finished:
			return a.finished
		if a.finished:
			return a.finish_time < b.finish_time if a.finish_time != b.finish_time else a.slot < b.slot
		if a.laps != b.laps:
			return a.laps > b.laps
		if a.last_gate != b.last_gate:
			return a.last_gate > b.last_gate
		var da := bounded_progress(a)
		var db := bounded_progress(b)
		return da > db if not is_equal_approx(da, db) else a.slot < b.slot)
	return order


func bounded_progress(state: VehicleState) -> float:
	var gate: Dictionary = track.bake.gates[maxi(0, state.last_gate)]
	var next: int = (state.last_gate + 1) % track.bake.gates.size()
	var maximum: float = track.bake.gates[next].s - gate.s if next > 0 else track.length - gate.s
	return clampf((state.position - ProgressTracker.vector(gate.position)).dot(ProgressTracker.vector(gate.forward)), 0, maximum)


func configure_bots(records: Array[Dictionary], local_slot: int, difficulty: int) -> void:
	roster = records
	human_slot = local_slot
	for index in range(records.size()):
		if records[index].get("bot", false):
			var driver := BotDriver.new()
			driver.difficulty = difficulty
			bots[index] = driver


func race_assistance() -> bool:
	return mode not in ["trial", "school"] and states.size() > 1


func update_race_roles() -> void:
	for state: VehicleState in states: state.race_role = 0
	if not race_assistance() or not states.any(func(state: VehicleState) -> bool: return not bots.has(state.slot) and not state.finished and state.dnf_reason == ""):
		return
	var order := standings().filter(func(state: VehicleState) -> bool: return state.dnf_reason == "")
	if order.size() < 2: return
	for state: VehicleState in order:
		if not state.finished: state.race_role = 1 if state == order[0] else 2


func rubberband_pace(state: VehicleState) -> float:
	if not race_assistance() or state.finished or state.dnf_reason != "": return 1.0
	var gap := INF
	var progress := ProgressTracker.race_progress(state, track)
	for rival: VehicleState in states:
		if rival == state or bots.has(rival.slot) or rival.finished or rival.dnf_reason != "": continue
		var candidate := ProgressTracker.race_progress(rival, track) - progress
		if absf(candidate) < absf(gap): gap = candidate
	if not is_finite(gap): return 1.0
	# Close fights stay steady; stronger catch-up ramps in beyond 15 m.
	var amount := clampf((absf(gap) - 15.0) / 160.0, 0, 1)
	return 1.0 + amount * (.22 if gap > 0 else -.24)


func remember_recovery_order() -> void:
	if not race_assistance(): return
	var rank := 0
	for state: VehicleState in standings():
		if state.dnf_reason != "": continue
		if not state.finished and state.recovery_ticks == 0 and state.offroad_ticks == 0 and state.outside_ticks == 0 and state.recovery_hold_ticks == 0:
			state.recovery_rank = rank
			state.recovery_progress = ProgressTracker.race_progress(state, track)
		rank += 1


func rejoin_field(state: VehicleState, query: WorldQuery) -> void:
	var rivals: Array[VehicleState] = []
	for rival: VehicleState in standings():
		if rival != state and rival.dnf_reason == "": rivals.append(rival)
	var rank := clampi(state.recovery_rank, 0, rivals.size())
	var target := state.recovery_progress
	var speed := 0.0
	if rank > 0:
		var ahead := rivals[rank - 1]
		target = ProgressTracker.race_progress(ahead, track) - 10.0
		speed = ahead.speed() if not ahead.finished else 0.0
	if rank < rivals.size():
		var behind := rivals[rank]
		var tail := ProgressTracker.race_progress(behind, track) + 10.0
		if rank == 0:
			target = tail
			speed = behind.speed() if not behind.finished else 0.0
		else:
			target = (target + tail) * .5
			speed = (speed + (behind.speed() if not behind.finished else 0.0)) * .5
	# Predict the remaining half-second fade; bound each rescue and leave the
	# finish to actual driving. No race time, lap time or driven-distance credit.
	target = clampf(target + speed * .5, state.recovery_progress, state.recovery_progress + 240.0)
	ProgressTracker.place_recovery(state, track, target)
	query.hint = track.sample_index(state.route_s)
	state.recovery_speed = minf(minf(speed, cars[state.slot].top_speed * .8), float(track.bake.ai_speeds[cars[state.slot].id][query.hint]) * .9)


func finish_grace_limit() -> int:
	# Online racers get one fixed deadline, including assisted humans and bots.
	if mode == "online": return int(Catalog.rules.online_grace_ticks)
	# Keep standard races brisk, but give assisted families time to finish.
	# Finished assisted humans still count: their setting must not shorten the
	# deadline for other racers partway through the finishing period.
	if mode not in ["trial", "school"]:
		for slot in range(states.size()):
			if bots.has(slot) or states[slot].dnf_reason != "": continue
			if int(driving_assists.get(slot,0)) > 0 or bool(corner_braking.get(slot,false)):
				return int(Catalog.rules.assisted_grace_ticks)
	return int(Catalog.rules.grace_ticks)

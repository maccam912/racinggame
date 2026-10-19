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


func setup(route: TrackDefinition, car_indices: Array[int], world: World3D, laps: int = 2) -> void:
	track = route
	lap_count = laps
	for index in range(car_indices.size()):
		var state := VehicleState.new()
		state.slot = index
		var s := -8.0 - 7 * (index / 2)
		var pose := track.pose(s, -2.5 if index % 2 == 0 else 2.5)
		state.position = pose.origin + Vector3.UP * .35
		state.yaw = atan2(-pose.basis.z.x, pose.basis.z.z)
		states.append(state)
		cars.append(Catalog.cars[car_indices[index]])
		queries.append(WorldQuery.new(world, track, s))
		inputs.append(InputFrame.make())


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
	var previous: Array[Vector3] = []
	for index in range(states.size()):
		previous.append(states[index].position)
		inputs[index] = frames.get(index, InputFrame.make())
		if not states[index].finished and states[index].dnf_reason == "":
			VehicleSim.step(states[index], inputs[index], cars[index], queries[index])
	if contact_enabled:
		CarContact.resolve(states, queries)
	for index in range(states.size()):
		var state := states[index]
		if state.finished or state.dnf_reason != "":
			continue
		ProgressTracker.advance(state, previous[index], track, elapsed_ticks, lap_count)
		ProgressTracker.safety(state, inputs[index], track, queries[index])
		if state.finished and first_finish_tick < 0:
			first_finish_tick = elapsed_ticks
			phase = Phase.GRACE
			phase_ticks = 0
	if elapsed_ticks >= 36000 or (first_finish_tick >= 0 and elapsed_ticks - first_finish_tick >= 1800):
		for state: VehicleState in states:
			if not state.finished and state.dnf_reason == "":
				state.dnf_reason = "Time limit" if elapsed_ticks >= 36000 else "Finish grace expired"
	var complete := states.all(func(state: VehicleState) -> bool: return state.finished or state.dnf_reason != "")
	settled_ticks = settled_ticks + 1 if complete else 0
	if settled_ticks >= 120:
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

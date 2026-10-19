class_name PredictionBuffer
extends RefCounted

var state: VehicleState
var car: CarDefinition
var query: WorldQuery
var track: TrackDefinition
var lap_count: int = 2
var history: Array[InputFrame] = []
var correction := Vector3.ZERO
var clear_corrections: Array[float] = []
var contact_corrections: Array[float] = []
var recovery_corrections: int = 0
var snapshot_count: int = 0
var elapsed_ticks: int = 0


func advance(frame: InputFrame) -> void:
	simulate(frame)
	history.append(frame)
	if history.size() > 180:
		history.pop_front()


func simulate(frame: InputFrame) -> void:
	elapsed_ticks += 1
	var previous := state.position
	VehicleSim.step(state, frame, car, query)
	ProgressTracker.advance(state, previous, track, elapsed_ticks, lap_count)
	ProgressTracker.safety(state, frame, track, query)


func reconcile(authority: VehicleState, ticks: int) -> void:
	var previous := state.position
	var missing_history := not history.is_empty() and InputBuffer.newer(history[0].sequence, (authority.last_ack + 1) & 0xffffffff)
	for property: Dictionary in state.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var value: Variant = authority.get(property.name)
			state.set(property.name, value.duplicate() if value is Array else value)
	query.hint = track.sample_index(track.bake.gates[maxi(0, state.last_gate)].s + 50)
	history = history.filter(func(frame: InputFrame) -> bool: return InputBuffer.newer(frame.sequence, authority.last_ack))
	elapsed_ticks = ticks
	for frame: InputFrame in history:
		simulate(frame)
	var delta := previous - state.position
	snapshot_count += 1
	if "recovery" in authority.events or authority.recovery_ticks > 0 or missing_history:
		recovery_corrections += 1
		correction = Vector3.ZERO
	elif delta.length() > 3:
		correction = Vector3.ZERO
		record_correction(authority, delta.length())
	else:
		correction += delta
		record_correction(authority, delta.length())


func record_correction(authority: VehicleState, distance: float) -> void:
	if authority.contact_ticks > 0 or authority.wall_contact:
		contact_corrections.append(distance)
	elif authority.speed() > 5:
		clear_corrections.append(distance)


func render_offset(dt: float) -> Vector3:
	correction *= exp(-log(2.0) * dt / .12)
	return correction

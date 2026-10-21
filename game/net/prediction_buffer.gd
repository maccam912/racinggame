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
var reconnect_corrections: Array[float] = []
var clock_corrections: Array[float] = []
var elapsed_ticks: int = 0
var terminal_corrections: Array[float] = []
var trace_enabled: bool = false
var trace: Array[Dictionary] = []
var remotes: RemoteBuffer
var contact_enabled: bool = false
var prediction_tick: int = -1
var remote_states: Array[VehicleState] = []
var predicted_contacts: int = 0


func advance(frame: InputFrame) -> void:
	simulate(frame)
	history.append(frame)
	if history.size() > 180:
		history.pop_front()


func simulate(frame: InputFrame) -> void:
	elapsed_ticks += 1
	prediction_tick = frame.tick + InputBuffer.DELAY_TICKS
	var previous := state.position
	VehicleSim.step(state, frame, car, query)
	update_remotes(prediction_tick, true)
	ProgressTracker.advance(state, previous, track, elapsed_ticks, lap_count)
	ProgressTracker.safety(state, frame, track, query)


func update_remotes(tick: int, resolve_contacts: bool = false) -> void:
	remote_states.clear()
	if remotes == null or remotes.samples.is_empty(): return
	var queries: Array[WorldQuery] = []
	for index in range(remotes.samples[-1].states.size()):
		remote_states.append(state if index == state.slot else remotes.predict(index, tick))
		queries.append(query if index == state.slot else remotes.query_for(index))
	if resolve_contacts and contact_enabled and remotes.contact_fresh(tick):
		var before := state.velocity
		CarContact.resolve(remote_states, queries, state.slot)
		if state.velocity != before: predicted_contacts += 1


func reconcile(authority: VehicleState, ticks: int, authority_tick: int = -1) -> void:
	var previous := state.position
	var missing_history := not history.is_empty() and InputBuffer.newer(history[0].sequence, (authority.last_ack + 1) & 0xffffffff)
	apply_authority(authority, ticks)
	prediction_tick = authority_tick
	update_remotes(prediction_tick)
	history = history.filter(func(frame: InputFrame) -> bool: return InputBuffer.newer(frame.sequence, authority.last_ack))
	if authority.finished or authority.dnf_reason != "":
		history.clear()
	else:
		for frame: InputFrame in history:
			# Missing input may already have advanced authority using held/neutral
			# controls without advancing its acknowledgement. Do not simulate
			# those elapsed ticks a second time merely because ack stayed still.
			if authority_tick < 0 or frame.tick + InputBuffer.DELAY_TICKS > authority_tick:
				simulate(frame)
	var delta := previous - state.position
	if trace_enabled and trace.size() < 12000:
		trace.append({"server_elapsed":ticks, "ack":authority.last_ack, "history":history.size(), "latest_sequence":history[-1].sequence if not history.is_empty() else authority.last_ack, "latest_intended":history[-1].tick if not history.is_empty() else -1, "delta":delta.length(), "speed":authority.speed(), "finished":authority.finished, "route":authority.route_s})
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


func restore_reconnect(authority: VehicleState, ticks: int, catch_up_ticks: int = 0, authority_tick: int = -1) -> void:
	# The bot has advanced while this client was away. These are full-state
	# restores, reported separately, rather than ordinary driving corrections.
	reconnect_corrections.append(state.position.distance_to(authority.position))
	restore_at_tick(authority,ticks,catch_up_ticks,authority_tick)
	snapshot_count += 1


func restore_clock(authority: VehicleState, ticks: int, catch_up_ticks: int, authority_tick: int = -1) -> void:
	clock_corrections.append(state.position.distance_to(authority.position))
	restore_at_tick(authority,ticks,catch_up_ticks,authority_tick)


func restore_at_tick(authority: VehicleState, ticks: int, catch_up_ticks: int, authority_tick: int = -1) -> void:
	apply_authority(authority, ticks)
	prediction_tick = authority_tick
	update_remotes(prediction_tick)
	history.clear()
	# Present the reserved bot's state at the synchronized client tick. A short
	# static-world coast bridges transport delay without replaying old controls.
	for _tick in range(clampi(catch_up_ticks, 0, 9)):
		var coast := InputFrame.make(authority.steer_filter)
		coast.sequence = authority.last_ack
		coast.tick = prediction_tick + 1 - InputBuffer.DELAY_TICKS
		simulate(coast)
	correction = Vector3.ZERO


func apply_authority(authority: VehicleState, ticks: int) -> void:
	for property: Dictionary in state.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE:
			var value: Variant = authority.get(property.name)
			state.set(property.name, value.duplicate() if value is Array else value)
	query.hint = track.sample_index(track.bake.gates[maxi(0, state.last_gate)].s + 50)
	elapsed_ticks = ticks


func record_correction(authority: VehicleState, distance: float) -> void:
	if authority.finished or authority.dnf_reason != "":
		terminal_corrections.append(distance)
	elif authority.contact_ticks > 0 or authority.wall_contact:
		contact_corrections.append(distance)
	elif authority.speed() > 5:
		clear_corrections.append(distance)


func render_offset(dt: float) -> Vector3:
	correction *= exp(-log(2.0) * dt / .12)
	return correction

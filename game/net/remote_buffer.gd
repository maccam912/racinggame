class_name RemoteBuffer
extends RefCounted

var samples: Array[Dictionary] = []
const MAX_PREDICTION_TICKS: int = 9 # 150 ms, including input-buffer lead.
var forecasts: Dictionary = {}
var queries: Dictionary = {}
var world: World3D
var track: TrackDefinition


func configure(space: World3D, route: TrackDefinition) -> void:
	world = space
	track = route
	clear()


func clear() -> void:
	samples.clear()
	forecasts.clear()
	queries.clear()


func push(tick: int, states: Array[VehicleState]) -> void:
	if not samples.is_empty() and tick <= int(samples[-1].tick):
		return
	samples.append({"tick":tick, "states":states})
	forecasts.clear()
	if samples.size() > 20:
		samples.pop_front()


func sample(slot: int, clock_tick: float) -> VehicleState:
	if samples.is_empty():
		return null
	var target := clock_tick - 6 # 100 ms interpolation delay.
	for i in range(samples.size() - 1):
		if samples[i].tick <= target and samples[i + 1].tick >= target:
			var a: VehicleState = samples[i].states[slot]
			var b: VehicleState = samples[i + 1].states[slot]
			var weight: float = (target - samples[i].tick) / float(samples[i + 1].tick - samples[i].tick)
			var state := b.copy() if weight>=1 else a.copy()
			state.position = a.position.lerp(b.position, weight)
			state.yaw = lerp_angle(a.yaw, b.yaw, weight)
			return state
	var latest: VehicleState = samples[-1].states[slot]
	var result := latest.copy()
	var delta := clampf((target - float(samples[-1].tick)) / 60.0, 0, .15)
	result.position += result.velocity * delta
	result.yaw += result.yaw_rate * delta
	return result


func contact_fresh(tick: int) -> bool:
	return not samples.is_empty() and tick >= int(samples[0].tick) and tick <= int(samples[-1].tick) + MAX_PREDICTION_TICKS


func query_for(slot: int) -> WorldQuery:
	if not queries.has(slot):
		if world == null or track == null: return null
		var latest: VehicleState = samples[-1].states[slot]
		queries[slot] = WorldQuery.new(world, track, track.bake.gates[maxi(0, latest.last_gate)].s)
	return queries[slot]


func predict(slot: int, tick: int) -> VehicleState:
	if samples.is_empty() or slot < 0 or slot >= samples[-1].states.size(): return null
	# Reconciliation asks for historical simulation ticks, never delayed render
	# ticks. Keep discontinuities (recovery/finish/ghost changes) authoritative.
	if tick < int(samples[0].tick): return samples[0].states[slot].copy()
	for index in range(samples.size() - 1):
		var a: Dictionary = samples[index]
		var b: Dictionary = samples[index + 1]
		if tick >= int(a.tick) and tick < int(b.tick):
			var first: VehicleState = a.states[slot]
			var second: VehicleState = b.states[slot]
			var result := first.copy()
			var duration := float(int(b.tick) - int(a.tick)) / 60.0
			if first.recovery_ticks > 0 or second.recovery_ticks > 0 or first.position.distance_to(second.position) > maxf(3.0, maxf(first.velocity.length(), second.velocity.length()) * duration + 1.0):
				result.ghost_ticks = maxi(1, result.ghost_ticks)
				return result
			var weight := float(tick - int(a.tick)) / float(int(b.tick) - int(a.tick))
			result.position = first.position.lerp(second.position, weight)
			result.velocity = first.velocity.lerp(second.velocity, weight)
			result.yaw = lerp_angle(first.yaw, second.yaw, weight)
			result.yaw_rate = lerpf(first.yaw_rate, second.yaw_rate, weight)
			return result
	var latest: VehicleState = samples[-1].states[slot]
	var steps := clampi(tick - int(samples[-1].tick), 0, MAX_PREDICTION_TICKS)
	if not forecasts.has(slot): forecasts[slot] = [latest.copy()]
	var cache: Array = forecasts[slot]
	var query := query_for(slot)
	# At most nine static-world steps per remote per snapshot, shared by live
	# prediction, replay and rendering. Never write into received snapshots.
	while cache.size() <= steps:
		var state: VehicleState = cache[-1].copy()
		if state.recovery_ticks == 0 and state.dnf_reason == "":
			var angle := state.yaw_rate * VehicleSim.DT
			state.yaw = wrapf(state.yaw + angle, -PI, PI)
			if state.grounded and not state.wall_contact:
				state.velocity = state.velocity.rotated(Vector3.UP, -angle)
			elif not state.grounded:
				state.velocity.y -= 22.0 * VehicleSim.DT
			if query:
				# Reset route search from authority, including after recovery.
				query.hint = track.sample_index(track.bake.gates[maxi(0, latest.last_gate)].s + 50)
				var ground := query.ground(state)
				if ground.supported and (state.grounded or state.velocity.dot(ground.normal) <= 0):
					state.grounded = true
					state.ground_normal = ground.normal
					state.position.y = ground.height + .35
					state.velocity = state.velocity.slide(ground.normal)
				else:
					state.grounded = false
				var swept := query.sweep(state.position, state.velocity, state.yaw, VehicleSim.DT, false)
				state.position = swept.position
				state.velocity = swept.velocity
				state.wall_contact = swept.hit
			else:
				state.position += state.velocity * VehicleSim.DT
		cache.append(state)
	return cache[steps].copy()

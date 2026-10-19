class_name RemoteBuffer
extends RefCounted

var samples: Array[Dictionary] = []


func push(tick: int, states: Array[VehicleState]) -> void:
	if not samples.is_empty() and tick <= int(samples[-1].tick):
		return
	samples.append({"tick":tick, "states":states})
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

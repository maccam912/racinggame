class_name NetCodec
extends RefCounted
## Explicit fixed-width little-endian packets. No Variant deserialization on UDP.

const PROTOCOL: int = 2
const MAX_PACKET: int = 1200
const FIELDS: Array = [
	["yaw", "i16", 100.0 * 180 / PI], ["yaw_rate", "i16", 100.0 * 180 / PI],
	["steer_filter", "i8", 127.0], ["drift_phase", "u8", 1],
	["drift_timer", "u16", 1000], ["drift_entry", "u16", 1000],
	["reverse_hold", "u16", 1000], ["wall_separation_ticks", "u16", 1],
	["contact_ticks", "u8", 1],
	["recovery_ticks", "u8", 1], ["recovery_hold_ticks", "u8", 1],
	["ghost_ticks", "u16", 1], ["offroad_ticks", "u8", 1], ["outside_ticks", "u16", 1],
	["wrong_way_ticks", "u16", 1], ["forward_ticks", "u16", 1],
	["launch_ticks", "u8", 1], ["jump_lap", "i8", 1], ["last_gate", "i8", 1],
	["route_s", "i32", 100],
	["backwards_m", "u16", 100],
	["laps", "u8", 1], ["last_ack", "u32", 1]
]


static func writer(magic: String) -> StreamPeerBuffer:
	var buffer := StreamPeerBuffer.new()
	buffer.put_data(magic.to_ascii_buffer())
	buffer.put_u8(PROTOCOL)
	return buffer


static func encode_inputs(race: int, frames: Array[InputFrame]) -> PackedByteArray:
	if frames.is_empty() or frames.size() > 6:
		return PackedByteArray()
	var buffer := writer("PRIN")
	buffer.put_u32(race)
	buffer.put_u8(frames.size())
	for frame: InputFrame in frames:
		if not is_finite(frame.steer) or not is_finite(frame.throttle) or not is_finite(frame.brake) or absf(frame.steer) > 1 or frame.throttle < 0 or frame.throttle > 1 or frame.brake < 0 or frame.brake > 1 or frame.sequence < 0 or frame.sequence > 0xffffffff or frame.tick < 0 or frame.tick > 0xffffffff:
			return PackedByteArray()
		buffer.put_u32(frame.sequence)
		buffer.put_u32(frame.tick)
		buffer.put_8(roundi(frame.steer * 127))
		buffer.put_u8(roundi(frame.throttle * 255))
		buffer.put_u8(roundi(frame.brake * 255))
		buffer.put_u8(int(frame.handbrake) | (int(frame.recover) << 1))
	return buffer.data_array


static func decode_inputs(bytes: PackedByteArray, race: int) -> Array[InputFrame]:
	var result: Array[InputFrame] = []
	if bytes.size() < 10 or bytes.size() > 82 or bytes.slice(0, 4).get_string_from_ascii() != "PRIN" or bytes[4] != PROTOCOL:
		return result
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = bytes
	buffer.seek(5)
	if buffer.get_u32() != race:
		return result
	var count := buffer.get_u8()
	if count < 1 or count > 6 or bytes.size() != 10 + 12 * count:
		return result
	for _index in range(count):
		var frame := InputFrame.new()
		frame.sequence = buffer.get_u32()
		frame.tick = buffer.get_u32()
		var steer := buffer.get_8()
		frame.steer = steer / 127.0
		frame.throttle = buffer.get_u8() / 255.0
		frame.brake = buffer.get_u8() / 255.0
		var buttons := buffer.get_u8()
		if buttons & ~3 or steer == -128:
			return []
		frame.handbrake = bool(buttons & 1)
		frame.recover = bool(buttons & 2)
		result.append(frame)
	return result


static func quantize(frame: InputFrame) -> InputFrame:
	var frames: Array[InputFrame] = [frame]
	return decode_inputs(encode_inputs(0, frames), 0)[0]


static func encode_snapshot(session: RaceSession, server_tick: int, hash_prefix: PackedByteArray) -> PackedByteArray:
	var buffer := writer("PRSN")
	buffer.put_u32(session.race_id)
	buffer.put_u32(server_tick)
	buffer.put_data(hash_prefix.slice(0, 8))
	buffer.put_u8(session.phase)
	buffer.put_u32(session.elapsed_ticks)
	buffer.put_u32(0) # Reliable event sequence, extended by the room event layer.
	buffer.put_u8(session.states.size())
	for state: VehicleState in session.states:
		buffer.put_u8(state.slot)
		for value: float in [state.position.x, state.position.y, state.position.z]:
			if not is_finite(value) or absf(value) > 21474836:
				return PackedByteArray()
			buffer.put_32(roundi(value * 100))
		for value: float in [state.velocity.x, state.velocity.y, state.velocity.z]:
			if not is_finite(value) or absf(value) > 327.67:
				return PackedByteArray()
			buffer.put_16(roundi(value * 100))
		if not state.ground_normal.is_finite() or state.ground_normal.x * state.ground_normal.x + state.ground_normal.z * state.ground_normal.z > 1.001 or not state.surface in ["asphalt", "sand", "grass"]:
			return PackedByteArray()
		for value: float in [state.finish_time, state.lap_start_time, state.last_lap_time, state.best_lap_time, state.distance_m]:
			if not is_finite(value) or value < -1 or value > 100000:
				return PackedByteArray()
		buffer.put_16(roundi(state.ground_normal.x * 32767))
		buffer.put_16(roundi(state.ground_normal.z * 32767))
		for field: Array in FIELDS:
			var value: float = float(state.get(field[0]))
			if not is_finite(value):
				return PackedByteArray()
			var scaled := roundi(value * float(field[2]))
			var bounds: Array = {"i8":[-128,127], "u8":[0,255], "i16":[-32768,32767], "u16":[0,65535], "i32":[-2147483648,2147483647], "u32":[0,4294967295]}[field[1]]
			if scaled < bounds[0] or scaled > bounds[1]:
				return PackedByteArray()
			buffer.call("put_" + str(field[1]).replace("i", ""), scaled)
		var flags := int(state.grounded) | (int(state.reversing) << 1) | (int(state.wall_contact) << 2) | (int(state.finished) << 3) | (int(state.trial_valid) << 4) | (int(state.dnf_reason != "") << 5) | (int(state.recovery_latched) << 6)
		buffer.put_u8(flags)
		buffer.put_u8(int(state.lap_valid))
		buffer.put_u8(["asphalt", "sand", "grass"].find(state.surface))
		buffer.put_float(state.finish_time)
		buffer.put_float(state.lap_start_time)
		buffer.put_float(state.last_lap_time)
		buffer.put_float(state.best_lap_time)
		buffer.put_float(state.distance_m)
		var events := int("wall" in state.events) | (int("bump" in state.events) << 1) | (int("recovery" in state.events) << 2) | (int("land" in state.events) << 3)
		buffer.put_u8(events)
	if buffer.data_array.size() > MAX_PACKET:
		return PackedByteArray()
	return buffer.data_array


static func decode_snapshot(bytes: PackedByteArray, race: int, hash_prefix: PackedByteArray) -> Dictionary:
	if bytes.size() < 31 or bytes.size() > MAX_PACKET or bytes.slice(0, 4).get_string_from_ascii() != "PRSN" or bytes[4] != PROTOCOL:
		return {}
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = bytes
	buffer.seek(5)
	if buffer.get_u32() != race:
		return {}
	var tick := buffer.get_u32()
	if buffer.get_data(8)[1] != hash_prefix.slice(0, 8):
		return {}
	var phase := buffer.get_u8()
	var elapsed := buffer.get_u32()
	var event_sequence := buffer.get_u32()
	var count := buffer.get_u8()
	var record_size := 1 + 12 + 6 + 4 + 1 + 1 + 1 + 20 + 1
	for field: Array in FIELDS:
		record_size += {"i8":1, "u8":1, "i16":2, "u16":2, "i32":4, "u32":4}[field[1]]
	if count < 1 or count > 8 or bytes.size() != 31 + count * record_size or phase > RaceSession.Phase.RESULTS:
		return {}
	var states: Array[VehicleState] = []
	var slots: Dictionary = {}
	for _index in range(count):
		var state := VehicleState.new()
		state.slot = buffer.get_u8()
		if state.slot >= count or slots.has(state.slot):
			return {}
		slots[state.slot] = true
		state.position = Vector3(buffer.get_32(), buffer.get_32(), buffer.get_32()) / 100
		state.velocity = Vector3(buffer.get_16(), buffer.get_16(), buffer.get_16()) / 100
		var nx := buffer.get_16() / 32767.0
		var nz := buffer.get_16() / 32767.0
		if nx * nx + nz * nz > 1.001:
			return {}
		state.ground_normal = Vector3(nx, sqrt(maxf(0, 1 - nx * nx - nz * nz)), nz)
		for field: Array in FIELDS:
			var value: float = buffer.call("get_" + str(field[1]).replace("i", ""))
			state.set(field[0], value / float(field[2]))
		var flags := buffer.get_u8()
		if flags & ~127:
			return {}
		state.grounded = bool(flags & 1)
		state.reversing = bool(flags & 2)
		state.wall_contact = bool(flags & 4)
		state.finished = bool(flags & 8)
		state.trial_valid = bool(flags & 16)
		state.dnf_reason = "DNF" if flags & 32 else ""
		state.recovery_latched = bool(flags & 64)
		var lap_valid := buffer.get_u8()
		if lap_valid > 1:
			return {}
		state.lap_valid = bool(lap_valid)
		var surface := buffer.get_u8()
		if surface > 2 or state.drift_phase > 2 or state.last_gate < -1 or state.last_gate > 40 or absf(state.steer_filter) > 1:
			return {}
		state.surface = ["asphalt", "sand", "grass"][surface]
		state.finish_time = buffer.get_float()
		state.lap_start_time = buffer.get_float()
		state.last_lap_time = buffer.get_float()
		state.best_lap_time = buffer.get_float()
		state.distance_m = buffer.get_float()
		var events := buffer.get_u8()
		if events & ~15:
			return {}
		for value: float in [state.finish_time, state.lap_start_time, state.last_lap_time, state.best_lap_time, state.distance_m]:
			if not is_finite(value) or value < -1 or value > 100000:
				return {}
		for bit in range(4):
			if events & (1 << bit):
				state.events.append(["wall", "bump", "recovery", "land"][bit])
		states.append(state)
	states.sort_custom(func(a: VehicleState, b: VehicleState) -> bool: return a.slot < b.slot)
	return {"tick":tick, "phase":phase, "elapsed":elapsed, "event_sequence":event_sequence, "states":states}

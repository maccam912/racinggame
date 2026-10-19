class_name GhostCodec
extends RefCounted

const FORMAT: int = 1
const LIMIT: int = 2097152


static func valid_id(value: String) -> bool:
	var expression := RegEx.new()
	expression.compile("^[a-z][a-z0-9_]{0,31}$")
	return expression.search(value) != null


static func encode(track: String, car: String, content_hash: String, total_time: float, samples: Array[Dictionary]) -> PackedByteArray:
	if not valid_id(track) or not valid_id(car) or content_hash.length() != 64 or not content_hash.is_valid_hex_number(false) or not is_finite(total_time) or total_time <= 0 or total_time > 600 or samples.size() < 2 or samples.size() > 12002:
		return PackedByteArray()
	var buffer := StreamPeerBuffer.new()
	buffer.put_data("PRGH".to_ascii_buffer())
	buffer.put_u16(FORMAT)
	buffer.put_data(content_hash.hex_decode())
	for value: String in [track, car]:
		buffer.put_u8(value.length())
		buffer.put_data(value.to_ascii_buffer())
	buffer.put_double(total_time)
	buffer.put_u32(samples.size())
	for index in range(samples.size()):
		var sample: Dictionary = samples[index]
		var expected_time := total_time if index == samples.size() - 1 else index / 20.0
		if not sample.get("position") is Vector3 or not sample.get("yaw") is float or not is_finite(sample.yaw) or absf(float(sample.get("time", -1)) - expected_time) > .00001:
			return PackedByteArray()
		var position: Vector3 = sample.position
		for axis: float in [position.x, position.y, position.z]:
			if not is_finite(axis) or absf(axis) > 21474836:
				return PackedByteArray()
			buffer.put_32(roundi(axis * 100))
		buffer.put_16(roundi(rad_to_deg(wrapf(sample.yaw, -PI, PI)) * 100))
	if total_time <= (samples.size() - 2) / 20.0:
		return PackedByteArray()
	var payload := buffer.data_array
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(payload)
	payload.append_array(context.finish())
	return payload if payload.size() <= LIMIT else PackedByteArray()


static func decode(bytes: PackedByteArray, track: String, car: String, content_hash: String) -> Dictionary:
	if bytes.size() < 84 or bytes.size() > LIMIT or bytes.slice(0, 4).get_string_from_ascii() != "PRGH":
		return {}
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(bytes.slice(0, bytes.size() - 32))
	if context.finish() != bytes.slice(bytes.size() - 32):
		return {}
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = bytes
	buffer.seek(4)
	if buffer.get_u16() != FORMAT or buffer.get_data(32)[1].hex_encode() != content_hash:
		return {}
	var ids: Array[String] = []
	for _id in range(2):
		if buffer.get_available_bytes() < 1:
			return {}
		var length := buffer.get_u8()
		if length < 1 or length > 32 or buffer.get_available_bytes() < length + 44:
			return {}
		ids.append(buffer.get_data(length)[1].get_string_from_ascii())
	if ids != [track, car] or buffer.get_available_bytes() < 44:
		return {}
	var total_time := buffer.get_double()
	var count := buffer.get_u32()
	if count < 2 or count > 12002 or not is_finite(total_time) or total_time <= (count - 2) / 20.0 or total_time > 600 or buffer.get_available_bytes() != count * 14 + 32:
		return {}
	var samples: Array[Dictionary] = []
	for index in range(count):
		var position := Vector3(buffer.get_32(), buffer.get_32(), buffer.get_32()) / 100
		var yaw := buffer.get_16() / 100.0
		if absf(yaw) > 180:
			return {}
		samples.append({"time":total_time if index == count - 1 else index / 20.0, "position":position, "yaw":deg_to_rad(yaw)})
	return {"time":total_time, "samples":samples}


static func at_time(ghost: Dictionary, time: float) -> Dictionary:
	if ghost.is_empty():
		return {}
	var samples: Array = ghost.samples
	var i := clampi(floori(time * 20), 0, samples.size() - 2)
	var a: Dictionary = samples[i]
	var b: Dictionary = samples[i + 1]
	var alpha := clampf((time - float(a.time)) / (float(b.time) - float(a.time)), 0, 1)
	return {"position":a.position.lerp(b.position, alpha), "yaw":lerp_angle(a.yaw, b.yaw, alpha)}

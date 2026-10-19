class_name ReliableFragments
extends RefCounted
## Bounded reliable control messages; racing snapshots/inputs never fragment.

const CHUNK: int = 1000
const LIMIT: int = 16384
var sequence: int = 0
var pending: Dictionary = {}


func split(bytes: PackedByteArray) -> Array[PackedByteArray]:
	var packets: Array[PackedByteArray] = []
	if bytes.is_empty() or bytes.size() > LIMIT:
		return packets
	sequence = (sequence + 1) & 0xffffffff
	var count := ceili(bytes.size() / float(CHUNK))
	for index in range(count):
		var buffer := StreamPeerBuffer.new()
		buffer.put_data("PRFR".to_ascii_buffer())
		buffer.put_u32(sequence)
		buffer.put_u8(index)
		buffer.put_u8(count)
		buffer.put_u16(bytes.size())
		buffer.put_data(bytes.slice(index * CHUNK, mini((index + 1) * CHUNK, bytes.size())))
		packets.append(buffer.data_array)
	return packets


func receive(sender: int, bytes: PackedByteArray, now: int) -> PackedByteArray:
	for key: String in pending.keys():
		if now - int(pending[key].created) > 5000:
			pending.erase(key)
	if bytes.size() < 13 or bytes.size() > CHUNK + 12 or bytes.slice(0, 4).get_string_from_ascii() != "PRFR":
		return PackedByteArray()
	var buffer := StreamPeerBuffer.new()
	buffer.data_array = bytes
	buffer.seek(4)
	var id := buffer.get_u32()
	var index := buffer.get_u8()
	var count := buffer.get_u8()
	var length := buffer.get_u16()
	if length < 1201 or length > LIMIT or count != ceili(length / float(CHUNK)) or index >= count or bytes.size() != 12 + mini(CHUNK, length - index * CHUNK):
		return PackedByteArray()
	var key := str(sender) + ":" + str(id)
	if not pending.has(key):
		if pending.size() >= 32:
			return PackedByteArray()
		pending[key] = {"created":now, "length":length, "count":count, "parts":{}}
	var message: Dictionary = pending[key]
	if int(message.length) != length or int(message.count) != count:
		pending.erase(key)
		return PackedByteArray()
	var payload := bytes.slice(12)
	if message.parts.has(index) and message.parts[index] != payload:
		pending.erase(key)
		return PackedByteArray()
	message.parts[index] = payload
	if message.parts.size() != count:
		return PackedByteArray()
	var result := PackedByteArray()
	for part in range(count):
		result.append_array(message.parts[part])
	pending.erase(key)
	return result if result.size() == length else PackedByteArray()

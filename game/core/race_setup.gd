class_name RaceSetup
extends RefCounted

const BOT_NAMES: Array[String] = ["Sunny", "Jet", "Poppy", "Ridge", "Skipper", "Dash", "Cove"]
const BOT_CARS: Array[int] = [0, 2, 1, 3]


static func uuid() -> String:
	var bytes := Crypto.new().generate_random_bytes(16)
	bytes[6] = (bytes[6] & 15) | 64
	bytes[8] = (bytes[8] & 63) | 128
	var value := bytes.hex_encode()
	return "%s-%s-%s-%s-%s" % [value.substr(0, 8), value.substr(8, 4), value.substr(12, 4), value.substr(16, 4), value.substr(20)]


static func roster(opponents: int, car: int, paint: int, name_value: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var human := mini(4, opponents)
	var bot_index := 0
	for slot in range(opponents + 1):
		if slot == human:
			result.append({"id":"local", "name":name_value, "car":car, "paint":paint, "bot":false})
		else:
			result.append({"id":"bot_" + BOT_NAMES[bot_index].to_lower(), "name":BOT_NAMES[bot_index], "car":BOT_CARS[slot % 4], "paint":slot % 8, "bot":true})
			bot_index += 1
	return result


static func car_indices(records: Array[Dictionary]) -> Array[int]:
	var result: Array[int] = []
	for record: Dictionary in records:
		result.append(int(record.car))
	return result

class_name PlayerName
extends RefCounted
## Unicode NFC using vendored canonical tables and algorithmic Hangul.

static var tables: Dictionary = {}


static func nfc(value: String) -> String:
	if tables.is_empty():
		tables = JSON.parse_string(FileAccess.get_file_as_string("res://game/content/unicode_nfc.json"))
	var points: Array[int] = []
	for character: String in value:
		decompose(character.unicode_at(0), points)
	for i in range(1, points.size()):
		var j := i
		var order := combining(points[j])
		while j > 0 and order > 0 and combining(points[j - 1]) > order:
			var temporary := points[j - 1]
			points[j - 1] = points[j]
			points[j] = temporary
			j -= 1
	if points.is_empty():
		return ""
	var result: Array[int] = [points[0]]
	var starter := points[0]
	var starter_index := 0
	var previous_class := combining(starter)
	for i in range(1, points.size()):
		var point := points[i]
		var current_class := combining(point)
		var combined := compose(starter, point)
		if combined >= 0 and (previous_class < current_class or previous_class == 0):
			result[starter_index] = combined
			starter = combined
		else:
			if current_class == 0:
				starter_index = result.size()
				starter = point
			result.append(point)
			previous_class = current_class
	var output := ""
	for point: int in result:
		output += String.chr(point)
	return output


static func combining(point: int) -> int:
	return int(tables.combining.get(str(point), 0))


static func decompose(point: int, output: Array[int]) -> void:
	if point >= 0xac00 and point < 0xd7a4:
		var index := point - 0xac00
		output.append(0x1100 + index / 588)
		output.append(0x1161 + (index % 588) / 28)
		if index % 28 > 0:
			output.append(0x11a7 + index % 28)
	elif tables.decomposition.has(str(point)):
		for child: float in tables.decomposition[str(point)]:
			decompose(int(child), output)
	else:
		output.append(point)


static func compose(first: int, second: int) -> int:
	if first >= 0x1100 and first < 0x1113 and second >= 0x1161 and second < 0x1176:
		return 0xac00 + ((first - 0x1100) * 21 + second - 0x1161) * 28
	if first >= 0xac00 and first < 0xd7a4 and (first - 0xac00) % 28 == 0 and second > 0x11a7 and second < 0x11c3:
		return first + second - 0x11a7
	return int(tables.composition.get(str(first) + ":" + str(second), -1))


static func validate(value: String, maximum: int = 16) -> Dictionary:
	if value.to_utf8_buffer().size() > 384:
		return {"valid":false, "value":"", "error":"name.length"}
	var normalized := nfc(value)
	var count := TextServerManager.get_primary_interface().string_get_character_breaks(normalized).size()
	if count < 3 or count > maximum or normalized.to_utf8_buffer().size() > 96:
		return {"valid":false, "value":normalized, "error":"name.length"}
	for character: String in normalized:
		var point := character.unicode_at(0)
		if point < 32 or point == 127 or (point >= 0x80 and point <= 0x9f) or point in [0x200b, 0x200e, 0x200f, 0x202a, 0x202b, 0x202c, 0x202d, 0x202e, 0x2066, 0x2067, 0x2068, 0x2069] or character in ["<", ">", "[", "]"]:
			return {"valid":false, "value":normalized, "error":"name.characters"}
	return {"valid":true, "value":normalized, "error":""}

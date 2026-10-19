class_name SettingsCatalog
extends RefCounted

static var rows: Array[Dictionary] = []


static func load_rows() -> void:
	if not rows.is_empty():
		return
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/content/settings_definitions.json"))
	for row: Dictionary in data.rows:
		rows.append(row)


static func defaults(mobile: bool) -> Dictionary:
	load_rows()
	var values: Dictionary = {"bindings":{}, "touch_layouts":{}}
	for row: Dictionary in rows:
		values[row.id] = row.get("mobile_default", row.default) if mobile else row.default
	return values


static func valid_value(row: Dictionary, value: Variant, mobile: bool) -> bool:
	if row.kind == "toggle":
		return value is bool
	if row.kind == "choice":
		if row.get("dynamic", "") != "":
			return value is String if row.id == "resolution" else (value is int or value is float) and float(value) >= 0 and float(value) < 16
		var choices: Array = row.get("mobile_values", row.values) if mobile else row.values
		for choice: Variant in choices:
			if (value is float or value is int) and (choice is float or choice is int) and is_finite(float(value)) and float(value) == float(choice):
				return true
			if typeof(value) == typeof(choice) and value == choice:
				return true
		return false
	if not (value is int or value is float) or not is_finite(float(value)):
		return false
	return float(value) >= float(row.minimum) and float(value) <= float(row.maximum)


static func sanitize(saved: Variant, mobile: bool) -> Dictionary:
	var result := defaults(mobile)
	if not saved is Dictionary: return result
	for row: Dictionary in rows:
		if saved.has(row.id) and valid_value(row, saved[row.id], mobile):
			result[row.id] = saved[row.id]
	for key in ["bindings", "touch_layouts"]:
		if saved.get(key) is Dictionary:
			result[key] = saved[key].duplicate(true)
	return result

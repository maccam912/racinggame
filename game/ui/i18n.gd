class_name I18n
extends RefCounted

static var messages: Dictionary = {}


static func t(key: String, arguments: Array = []) -> String:
	if messages.is_empty():
		messages = JSON.parse_string(FileAccess.get_file_as_string("res://game/ui/text/en.json"))
	var value: String = messages.get(key, key)
	return value % arguments if not arguments.is_empty() else value

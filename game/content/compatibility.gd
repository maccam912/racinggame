class_name Compatibility
extends RefCounted

static var hash_value: String = ""


static func content_hash() -> String:
	if hash_value != "":
		return hash_value
	var manifest: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/content/compatibility.json"))
	hash_value = manifest.content_hash
	return hash_value

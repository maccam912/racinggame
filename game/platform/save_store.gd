class_name SaveStore
extends RefCounted
## Component-local atomic replacement, verified backups, future-schema protection.
## FileAccess.flush is used; native fsync adapters remain a platform acceptance gate.

const SCHEMA: int = 1
const COMPONENTS: Array[String] = ["settings", "profile", "records", "cup", "suspended_race"]
var root_path: String
var read_only: Dictionary = {}
var notices: Array[String] = []
var last_error: String = ""
var fail_stage: String = "" # Test-only write failure injection.
var fail_component: String = ""


func _init(folder: String = "user://") -> void:
	root_path = ProjectSettings.globalize_path(folder)
	if DirAccess.make_dir_recursive_absolute(root_path) != OK:
		last_error = "data.save_failed"


func path(component: String) -> String:
	assert(component in COMPONENTS, "Unknown save component")
	return root_path.path_join(component + ".json")


func load_component(component: String, defaults: Dictionary, validator: Callable = Callable()) -> Dictionary:
	var primary := path(component)
	var main := read_envelope(primary, validator)
	if main.get("future", false):
		read_only[component] = true
		notice("data.newer_schema")
		return defaults.duplicate(true)
	if main.get("valid", false):
		return main.payload
	var backup := read_envelope(primary + ".bak", validator)
	if backup.get("future", false):
		read_only[component] = true
		notice("data.newer_schema")
		return defaults.duplicate(true)
	if FileAccess.file_exists(primary):
		preserve_corrupt(primary)
	if backup.get("valid", false):
		notice("data.backup_restored")
		return backup.payload
	if FileAccess.file_exists(primary + ".bak"):
		preserve_corrupt(primary + ".bak")
		notice("data.corrupt_defaults")
	elif main.get("exists", false):
		notice("data.corrupt_defaults")
	return defaults.duplicate(true)


func save_component(component: String, payload: Dictionary) -> Error:
	if read_only.get(component, false):
		last_error = "data.newer_schema"
		return ERR_UNAVAILABLE
	if not json_safe(payload):
		last_error = "data.invalid_payload"
		return ERR_INVALID_DATA
	var primary := path(component)
	var temporary := primary + ".tmp"
	var envelope := {"schema_version":SCHEMA, "saved_at_utc":Time.get_datetime_string_from_system(true) + "Z", "payload":payload}
	var file := FileAccess.open(temporary, FileAccess.WRITE)
	if file == null:
		return failed()
	file.store_string(JSON.stringify(envelope, "\t"))
	file.flush()
	var error := file.get_error()
	file.close()
	var injected := fail_component == "" or fail_component == component
	if error != OK or (injected and fail_stage == "after_tmp"):
		return failed()
	# Only a known-good primary may replace the previous known-good backup.
	if read_envelope(primary).get("valid", false):
		var backup_tmp := primary + ".bak.tmp"
		if DirAccess.copy_absolute(primary, backup_tmp) != OK:
			return failed()
		if DirAccess.rename_absolute(backup_tmp, primary + ".bak") != OK:
			return failed()
	if injected and fail_stage in ["after_backup", "before_replace"]:
		return failed()
	if DirAccess.rename_absolute(temporary, primary) != OK:
		return failed()
	last_error = ""
	return OK


func delete_component(component: String) -> Error:
	for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
		var target: String = path(component) + suffix
		if FileAccess.file_exists(target) and DirAccess.remove_absolute(target) != OK:
			return failed()
	read_only.erase(component)
	return OK


func read_envelope(filename: String, validator: Callable = Callable()) -> Dictionary:
	if not FileAccess.file_exists(filename):
		return {"exists":false}
	var file := FileAccess.open(filename, FileAccess.READ)
	if file == null or file.get_length() > 16777216:
		return {"exists":true}
	var parser := JSON.new()
	if parser.parse(file.get_as_text()) != OK or not parser.data is Dictionary:
		return {"exists":true}
	var data: Dictionary = parser.data
	var version: Variant = data.get("schema_version")
	if not (version is int or version is float) or not is_finite(float(version)) or float(version) != floorf(float(version)):
		return {"exists":true}
	if int(version) > SCHEMA:
		return {"exists":true, "future":true}
	if int(version) != SCHEMA or not data.get("saved_at_utc") is String or not data.get("payload") is Dictionary or not json_safe(data.payload):
		return {"exists":true}
	if validator.is_valid() and not validator.call(data.payload):
		return {"exists":true}
	return {"exists":true, "valid":true, "payload":data.payload}


func preserve_corrupt(filename: String) -> void:
	var suffix := Time.get_datetime_string_from_system(true).replace(":", "-") + "-" + str(Time.get_ticks_usec())
	DirAccess.rename_absolute(filename, filename + ".corrupt-" + suffix)


func notice(key: String) -> void:
	if not key in notices:
		notices.append(key)


func failed() -> Error:
	last_error = "data.save_failed"
	return ERR_FILE_CANT_WRITE


static func json_safe(value: Variant, depth: int = 0) -> bool:
	if depth > 32:
		return false
	if value is float:
		return is_finite(value)
	if value is int or value is String or value is bool or value == null:
		return true
	if value is Array:
		for item: Variant in value:
			if not json_safe(item, depth + 1):
				return false
		return true
	if value is Dictionary:
		for key: Variant in value:
			if not key is String or not json_safe(value[key], depth + 1):
				return false
		return true
	return false

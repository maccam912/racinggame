class_name SaveStore
extends RefCounted
## Component-local atomic replacement, verified backups, future-schema protection.
## A native lifetime lease excludes other writers; file/directory barriers precede success.

const SCHEMA: int = 1
const COMPONENTS: Array[String] = ["settings", "profile", "records", "cup", "suspended_race"]
var root_path: String
var read_only: Dictionary = {}
var notices: Array[String] = []
var last_error: String = ""
var fail_stage: String = "" # Test-only write failure injection.
var fail_component: String = ""
var file_ops: Object
var lock_state: String = "source_fallback"
var writable: bool = true


func _init(folder: String = "user://") -> void:
	root_path = ProjectSettings.globalize_path(folder).replace("\\","/").simplify_path()
	if DirAccess.make_dir_recursive_absolute(root_path) != OK:
		last_error = "data.save_failed"
	if ClassDB.class_exists("PacificSaveFiles"):
		file_ops = ClassDB.instantiate("PacificSaveFiles")
		var outcome: Dictionary = file_ops.open_profile(root_path)
		lock_state = outcome.state
		writable = outcome.ok
	elif OS.has_feature("template"):
		lock_state = "unavailable"
		writable = false
	if not writable:
		last_error = "data.profile_busy" if lock_state=="busy" else "data.save_failed"
		notice(last_error)


func path(component: String) -> String:
	assert(component in COMPONENTS, "Unknown save component")
	return root_path.path_join(component + ".json")


func load_component(component: String, defaults: Dictionary, validator: Callable = Callable()) -> Dictionary:
	var primary := path(component)
	if FileAccess.file_exists(primary+".deleted"):
		if writable and delete_component(component)!=OK:
			notice("data.save_failed")
		return defaults.duplicate(true)
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
	if writable and FileAccess.file_exists(primary):
		preserve_corrupt(primary)
	if backup.get("valid", false):
		notice("data.backup_restored")
		return backup.payload
	if FileAccess.file_exists(primary + ".bak"):
		if writable: preserve_corrupt(primary + ".bak")
		notice("data.corrupt_defaults")
	elif main.get("exists", false):
		notice("data.corrupt_defaults")
	return defaults.duplicate(true)


func save_component(component: String, payload: Dictionary) -> Error:
	if not writable:
		last_error = "data.profile_busy" if lock_state=="busy" else "data.save_failed"
		return ERR_BUSY if lock_state=="busy" else ERR_UNAVAILABLE
	if not json_safe(payload):
		last_error = "data.invalid_payload"
		return ERR_INVALID_DATA
	var primary := path(component)
	if FileAccess.file_exists(primary+".deleted") and delete_component(component)!=OK: return failed()
	# A writer must also honor a future envelope created after it last loaded.
	if read_envelope(path(component)).get("future",false) or read_envelope(path(component)+".bak").get("future",false):
		read_only[component] = true
	if read_only.get(component, false):
		last_error = "data.newer_schema"
		return ERR_UNAVAILABLE
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
	if error != OK or not sync_file(temporary) or (injected and fail_stage == "after_tmp"):
		return failed()
	# Only a known-good primary may replace the previous known-good backup.
	if read_envelope(primary).get("valid", false):
		var backup_tmp := primary + ".bak.tmp"
		if DirAccess.copy_absolute(primary, backup_tmp) != OK:
			return failed()
		if not sync_file(backup_tmp) or not replace_file(backup_tmp,primary+".bak"):
			return failed()
	if injected and fail_stage in ["after_backup", "before_replace"]:
		return failed()
	if not replace_file(temporary,primary):
		return failed()
	last_error = ""
	return OK


func delete_component(component: String) -> Error:
	if not writable:
		last_error = "data.profile_busy" if lock_state=="busy" else "data.save_failed"
		return ERR_BUSY if lock_state=="busy" else ERR_UNAVAILABLE
	# A durable tombstone makes an interrupted deletion suppress every backup.
	var marker := path(component)+".deleted"
	if not FileAccess.file_exists(marker):
		var file := FileAccess.open(marker+".tmp",FileAccess.WRITE)
		if file==null: return failed()
		file.store_string("Pacific Rush deleted component 1\n")
		file.flush()
		var error := file.get_error()
		file.close()
		if error!=OK or not sync_file(marker+".tmp") or not replace_file(marker+".tmp",marker): return failed()
	if fail_stage=="after_delete_marker": return failed()
	for suffix in ["", ".bak", ".tmp", ".bak.tmp", ".deleted.tmp"]:
		var target: String = path(component) + suffix
		if FileAccess.file_exists(target) and not remove_file(target):
			return failed()
		if suffix=="" and fail_stage=="after_delete_primary": return failed()
	if not remove_file(marker): return failed()
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
	if not replace_file(filename,filename+".corrupt-"+suffix): failed()


func sync_file(filename: String) -> bool:
	if fail_stage=="sync_file": return false
	return bool(file_ops.sync_file(relative_name(filename)).ok) if file_ops else true


func replace_file(source: String, target: String) -> bool:
	if fail_stage=="sync_directory": return false
	return bool(file_ops.replace_file(relative_name(source),relative_name(target)).ok) if file_ops else DirAccess.rename_absolute(source,target)==OK


func remove_file(filename: String) -> bool:
	return bool(file_ops.remove_file(relative_name(filename)).ok) if file_ops else DirAccess.remove_absolute(filename)==OK


func relative_name(filename: String) -> String:
	var prefix := root_path.trim_suffix("/")+"/"
	return filename.trim_prefix(prefix) if filename.begins_with(prefix) else ""


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

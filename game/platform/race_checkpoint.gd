class_name RaceCheckpoint
extends RefCounted
var data: AppData
var payload: Dictionary = {}

func _init(owner_data: AppData) -> void:
	data = owner_data
	reload()

func reload() -> void:
	payload = data.store.load_component("suspended_race",{},RaceArchive.valid)

func supported() -> bool:
	return payload.is_empty() or payload.get("format")==RaceArchive.FORMAT and payload.get("content_hash")==Compatibility.content_hash()

func can_resume() -> bool:
	return not payload.is_empty() and RaceArchive.compatible(payload,data)

func save(drive: RaceDrive) -> Error:
	reload()
	if not supported():
		data.store.last_error = "resume.incompatible"
		return ERR_UNAVAILABLE
	var value := RaceArchive.capture(drive)
	if value.is_empty() or not RaceArchive.valid(value): return ERR_INVALID_DATA
	var error := data.store.save_component("suspended_race",value)
	if error==OK: payload = value
	return error

func discard(explicit: bool = false) -> Error:
	reload()
	if not explicit and (not supported() or data.store.read_only.get("suspended_race",false) or data.store.read_envelope(data.store.path("suspended_race")+".bak").get("future",false)):
		return ERR_UNAVAILABLE
	var exists := false
	for suffix: String in ["",".bak",".tmp",".deleted",".deleted.tmp"]:
		exists = exists or FileAccess.file_exists(data.store.path("suspended_race")+suffix)
	if not exists:
		payload = {}
		return OK
	var error := data.store.delete_component("suspended_race")
	if error==OK: payload = {}
	return error

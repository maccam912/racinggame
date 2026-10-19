class_name AppData
extends RefCounted

var store: SaveStore
var mobile: bool = false
var settings_document: Dictionary = {}
var settings: Dictionary = {}
var profile: Dictionary = {}
var records: Dictionary = {}
var cup := CupBook.new()
var pending_result: Dictionary = {}


func _init(folder: String = "user://", mobile_profile: Variant = null) -> void:
	mobile = OS.has_feature("mobile") if mobile_profile == null else bool(mobile_profile)
	store = SaveStore.new(folder)
	settings_document = store.load_component("settings", {"desktop":{}, "mobile":{}})
	settings = SettingsCatalog.sanitize(settings_document.get("mobile" if mobile else "desktop", {}), mobile)
	profile = store.load_component("profile", default_profile(), validate_profile)
	records = store.load_component("records", {"times":{}, "committed":{}, "pending":{}}, validate_records)
	cup.data = store.load_component("cup", {}, CupBook.validate_data)
	resume_stat_commits()
	reconcile_cup_profile()


func default_profile() -> Dictionary:
	var bytes := Crypto.new().generate_random_bytes(4)
	return {"display_name":"Driver%04d" % (bytes.decode_u32(0) % 10000), "selected_car":0, "selected_paint":0, "first_run_complete":false, "school_steps":[false, false, false, false, false], "races_completed":0, "distance_m":0.0, "trophies":[], "ledger":{}, "guest_reference":"", "last_mode":"quick", "last_menu":"quick"}


func save_settings() -> Error:
	settings_document["mobile" if mobile else "desktop"] = settings.duplicate(true)
	return store.save_component("settings", settings_document)


func set_setting(key: String, value: Variant) -> Error:
	for row: Dictionary in SettingsCatalog.rows:
		if row.id == key and SettingsCatalog.valid_value(row, value, mobile):
			settings[key] = value
			if row.tab == "graphics" and key not in ["preset", "retro", "adaptive_resolution"]:
				settings.preset = "custom"
			if key == "preset":
				apply_preset(str(value))
			return save_settings()
	return ERR_INVALID_PARAMETER


func apply_preset(preset: String) -> void:
	var values: Dictionary = {}
	match preset:
		"low": values = {"render_scale":70, "msaa":0, "shadows":"off", "draw_distance":400, "effects":"reduced", "anisotropic":2}
		"medium": values = {"render_scale":80 if mobile else 100, "msaa":2 if mobile else 4, "shadows":"low", "draw_distance":400 if mobile else 700, "effects":"reduced" if mobile else "full", "anisotropic":2 if mobile else 4}
		"high": values = {"render_scale":100, "msaa":4, "shadows":"high", "draw_distance":1000, "effects":"full", "anisotropic":16}
		"battery": values = {"frame_cap":30, "render_scale":70, "shadows":"off", "effects":"reduced"}
	settings.merge(values, true)


func restore_tab(tab: String) -> Error:
	var defaults := SettingsCatalog.defaults(mobile)
	for row: Dictionary in SettingsCatalog.rows:
		if row.tab == tab:
			settings[row.id] = defaults[row.id]
	if tab == "controls":
		settings.bindings = {}
	if tab == "touch":
		settings.touch_layouts = {}
	return save_settings()


func save_profile() -> Error:
	return store.save_component("profile", profile)


func select_car(car: int, paint: int) -> Error:
	if car < 0 or car > 3 or paint < 0 or paint > 7:
		return ERR_INVALID_PARAMETER
	profile.selected_car = car
	profile.selected_paint = paint
	return save_profile()


func start_cup() -> Error:
	cup.start(int(profile.selected_car), int(profile.selected_paint), profile.display_name, Compatibility.content_hash())
	return store.save_component("cup", cup.data)


func abandon_cup() -> Error:
	var error := store.delete_component("cup")
	if error == OK:
		cup.data = {}
	return error


func commit_cup(session: RaceSession) -> Error:
	if not cup.compatible(Compatibility.content_hash()) or session.cup_event < 0:
		return ERR_INVALID_DATA
	for event: Dictionary in cup.data.results:
		if event.race_id == session.race_uuid:
			return reconcile_cup_profile()
	var order: Array[Dictionary] = []
	for state: VehicleState in session.standings():
		order.append({"id":session.roster[state.slot].id, "dnf":state.dnf_reason, "time":state.finish_time, "best_lap":state.best_lap_time, "distance_m":state.distance_m})
	var original := cup.data.duplicate(true)
	if not cup.commit(session.cup_event, session.race_uuid, order):
		return ERR_INVALID_DATA
	var error := store.save_component("cup", cup.data)
	if error != OK:
		cup.data = original
		return error
	return reconcile_cup_profile()


func reconcile_cup_profile() -> Error:
	if cup.data.is_empty():
		return OK
	var updated := profile.duplicate(true)
	var changed := false
	for event: Dictionary in cup.data.results:
		if updated.ledger.has(event.race_id):
			continue
		for row: Dictionary in event.order:
			if row.id == "local" and (row.get("distance_m") is float or row.get("distance_m") is int):
				updated.ledger[event.race_id] = true
				updated.distance_m = float(updated.distance_m) + maxf(0, float(row.distance_m))
				if row.dnf == "" and float(row.get("time", -1)) >= 0:
					updated.races_completed = int(updated.races_completed) + 1
				changed = true
	if int(cup.data.next_event) == 6:
		var rank := -1
		var ranking := cup.standings()
		for index in range(ranking.size()):
			if ranking[index].id == "local":
				rank = index
		if rank >= 0 and rank < 3 and not cup.data.id in updated.get("trophy_reset_cups", []) and not updated.trophies.any(func(trophy: Dictionary) -> bool: return trophy.cup_id == cup.data.id):
			updated.trophies.append({"cup_id":cup.data.id, "rank":rank, "car":cup.data.car, "content_hash":cup.data.content_hash})
			changed = true
	if changed:
		var error := store.save_component("profile", updated)
		if error == OK:
			profile = updated
		return error
	return OK


func record_key(mode: String, track: String, car: String) -> String:
	return "%s:%s:%s:%s" % [mode, track, car, Compatibility.content_hash()]


func best(mode: String, track: String, car: String) -> float:
	return float(records.times.get(record_key(mode, track, car), {}).get("time", -1))


func ghost_path(track: String, car: String) -> String:
	assert(GhostCodec.valid_id(track) and GhostCodec.valid_id(car))
	return store.root_path.path_join("ghosts").path_join(track).path_join(car).path_join(Compatibility.content_hash() + ".bin")


func load_ghost(track: String, car: String) -> Dictionary:
	var expected := best("trial", track, car)
	if expected < 0:
		return {}
	for suffix in ["", ".bak"]:
		var filename: String = ghost_path(track, car) + suffix
		if not FileAccess.file_exists(filename):
			continue
		var ghost := GhostCodec.decode(FileAccess.get_file_as_bytes(filename), track, car, Compatibility.content_hash())
		if not ghost.is_empty() and absf(float(ghost.time) - expected) < .00000001:
			return ghost
	store.notice("data.ghost_unavailable")
	return {}


func commit_result(session: RaceSession, samples: Array[Dictionary] = []) -> Dictionary:
	if session.race_uuid == "":
		session.race_uuid = RaceSetup.uuid()
	if session.human_slot < 0 or session.mode == "school":
		return {"saved":true, "new_best":false}
	var state := session.states[session.human_slot]
	var car := session.cars[session.human_slot].id
	var key := record_key("trial" if session.mode == "trial" else "race_lap", session.track.id, car)
	var previous := float(records.times.get(key, {}).get("time", -1))
	var candidate := state.finish_time if session.mode == "trial" else state.best_lap_time
	var eligible := state.finished and state.trial_valid if session.mode == "trial" else candidate > 0
	var new_best := eligible and candidate > 0 and (previous < 0 or candidate < previous)
	if records.committed.has(session.race_uuid):
		resume_stat_commits()
		var summary: Variant = records.committed[session.race_uuid]
		var repeated: Dictionary = summary.duplicate(true) if summary is Dictionary else {"new_best":false, "previous":previous}
		repeated.saved = not records.pending.has(session.race_uuid)
		return repeated
	if store.read_only.get("records", false):
		return {"saved":false, "new_best":false, "previous":previous}
	var updated := records.duplicate(true)
	var ghost_filename := ""
	var had_ghost := false
	if new_best and session.mode == "trial":
		var bytes := GhostCodec.encode(session.track.id, car, Compatibility.content_hash(), candidate, samples)
		if bytes.is_empty():
			return {"saved":false, "new_best":false, "previous":previous}
		ghost_filename = ghost_path(session.track.id, car)
		had_ghost = FileAccess.file_exists(ghost_filename)
		if write_ghost(ghost_filename, bytes) != OK:
			return {"saved":false, "new_best":false, "previous":previous}
	if new_best:
		updated.times[key] = {"time":candidate, "race_id":session.race_uuid, "medal":Medals.award(session.track.length, candidate, true) if session.mode == "trial" else -1}
	updated.committed[session.race_uuid] = {"new_best":new_best, "previous":previous, "time":candidate}
	updated.pending[session.race_uuid] = {"distance_m":state.distance_m, "completed":state.finished}
	if store.save_component("records", updated) != OK:
		if ghost_filename != "":
			if had_ghost and FileAccess.file_exists(ghost_filename + ".bak"):
				DirAccess.copy_absolute(ghost_filename + ".bak", ghost_filename)
			elif not had_ghost:
				DirAccess.remove_absolute(ghost_filename)
		return {"saved":false, "new_best":false, "previous":previous}
	records = updated
	resume_stat_commits()
	return {"saved":not records.pending.has(session.race_uuid), "new_best":new_best, "previous":previous, "time":candidate}


func resume_stat_commits() -> void:
	if records.get("pending", {}).is_empty():
		return
	var updated := profile.duplicate(true)
	for id: String in records.pending:
		if updated.ledger.has(id):
			continue
		var result: Dictionary = records.pending[id]
		updated.ledger[id] = true
		updated.distance_m = float(updated.distance_m) + float(result.distance_m)
		if result.completed:
			updated.races_completed = int(updated.races_completed) + 1
	if store.save_component("profile", updated) != OK:
		return
	profile = updated
	var cleared := records.duplicate(true)
	cleared.pending = {}
	if store.save_component("records", cleared) == OK:
		records = cleared


func write_ghost(filename: String, bytes: PackedByteArray) -> Error:
	if DirAccess.make_dir_recursive_absolute(filename.get_base_dir()) != OK:
		return ERR_CANT_CREATE
	var file := FileAccess.open(filename + ".tmp", FileAccess.WRITE)
	if file == null:
		return ERR_FILE_CANT_WRITE
	file.store_buffer(bytes)
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		return error
	if FileAccess.file_exists(filename) and DirAccess.copy_absolute(filename, filename + ".bak") != OK:
		return ERR_FILE_CANT_WRITE
	return DirAccess.rename_absolute(filename + ".tmp", filename)


static func validate_profile(value: Dictionary) -> bool:
	if not value.get("display_name") is String or not NetEvents.integer(value.get("selected_car"), 0, 3) or not NetEvents.integer(value.get("selected_paint"), 0, 7) or not value.get("first_run_complete") is bool or not value.get("school_steps") is Array or value.school_steps.size() != 5 or not value.get("ledger") is Dictionary or not value.get("trophies") is Array or not NetEvents.integer(value.get("races_completed"), 0, 1000000000) or not (value.get("distance_m") is float or value.get("distance_m") is int) or float(value.distance_m) < 0:
		return false
	if not PlayerName.validate(value.display_name).valid:
		return false
	for entry: Variant in value.trophies:
		if not entry is Dictionary or not entry.get("cup_id") is String or not NetEvents.integer(entry.get("rank"), 0, 2) or not NetEvents.integer(entry.get("car"), 0, 3) or not entry.get("content_hash") is String:
			return false
	for key: Variant in value.ledger:
		if not key is String or not value.ledger[key] is bool:
			return false
	if not value.get("trophy_reset_cups", []) is Array:
		return false
	for flag: Variant in value.school_steps:
		if not flag is bool:
			return false
	for key in ["guest_reference", "last_mode", "last_menu"]:
		if not value.get(key) is String:
			return false
	return true


static func validate_records(value: Dictionary) -> bool:
	if not value.get("times") is Dictionary or not value.get("committed") is Dictionary or not value.get("pending") is Dictionary:
		return false
	for entry: Variant in value.times.values():
		if not entry is Dictionary or not entry.get("time") is float or float(entry.time) <= 0 or float(entry.time) > 600:
			return false
	for entry: Variant in value.committed.values():
		if not entry is Dictionary or not entry.get("new_best") is bool or not (entry.get("previous") is float or entry.get("previous") is int) or not (entry.get("time") is float or entry.get("time") is int):
			return false
	for entry: Variant in value.pending.values():
		if not entry is Dictionary or not entry.get("distance_m") is float or float(entry.distance_m) < 0 or not entry.get("completed") is bool:
			return false
	return true


func reset_local(all_data: bool) -> Error:
	var components: Array[String] = ["records"]
	if all_data:
		components = ["settings", "profile", "records", "cup", "suspended_race"]
	for component: String in components:
		var error := store.delete_component(component)
		if error != OK:
			return error
	var ghosts := store.root_path.path_join("ghosts")
	if DirAccess.dir_exists_absolute(ghosts):
		var error := remove_tree(ghosts)
		if error != OK:
			return error
	records = {"times":{}, "committed":{}, "pending":{}}
	if all_data:
		settings_document = {"desktop":{}, "mobile":{}}
		settings = SettingsCatalog.defaults(mobile)
		profile = default_profile()
		cup.data = {}
	else:
		profile.trophies = []
		if not cup.data.is_empty() and int(cup.data.next_event) == 6:
			profile.trophy_reset_cups = profile.get("trophy_reset_cups", [])
			if not cup.data.id in profile.trophy_reset_cups:
				profile.trophy_reset_cups.append(cup.data.id)
		return save_profile()
	return OK


static func remove_tree(folder: String) -> Error:
	var directory := DirAccess.open(folder)
	if directory == null:
		return ERR_CANT_OPEN
	for child: String in directory.get_directories():
		var error := remove_tree(folder.path_join(child))
		if error != OK:
			return error
	for child: String in directory.get_files():
		var error := DirAccess.remove_absolute(folder.path_join(child))
		if error != OK:
			return error
	return DirAccess.remove_absolute(folder)

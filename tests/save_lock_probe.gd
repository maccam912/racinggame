extends SceneTree

func _initialize() -> void: call_deferred("run")
func run() -> void:
	assert(ClassDB.class_exists("PacificSaveFiles"),"native file adapter is required for interprocess acceptance")
	var folder: String
	var operation: String
	var stage: String
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--folder="): folder = argument.trim_prefix("--folder=")
		elif argument.begins_with("--operation="): operation = argument.trim_prefix("--operation=")
		elif argument.begins_with("--stage="): stage = argument.trim_prefix("--stage=")
	assert(not folder.is_empty())
	var store := SaveStore.new(folder)
	match operation:
		"hold":
			assert(store.writable and store.file_ops.owned())
			assert(store.save_component("settings",{"value":1})==OK)
			print("NATIVE_PROFILE_LOCK_HELD")
			while true: await process_frame
		"busy":
			assert(not store.writable and store.lock_state=="busy")
			assert(store.notices.has("data.profile_busy"))
			var bytes := FileAccess.get_file_as_bytes(store.path("settings"))
			assert(store.load_component("settings",{}).value==1)
			assert(store.save_component("settings",{"value":99})==ERR_BUSY)
			assert(store.delete_component("settings")==ERR_BUSY)
			assert(FileAccess.get_file_as_bytes(store.path("settings"))==bytes and not FileAccess.file_exists(store.path("settings")+".tmp"))
			print("NATIVE_SECOND_PROCESS_READ_ONLY_BYTES_UNCHANGED_PASS")
		"after_kill":
			assert(store.writable and store.load_component("settings",{}).value==1)
			assert(store.save_component("settings",{"value":2})==OK)
			print("NATIVE_LOCK_RELEASED_AFTER_KILL_ATOMIC_WRITE_PASS")
		"interrupted":
			assert(store.writable)
			store.fail_stage = stage
			assert(store.save_component("settings",{"value":3})!=OK)
			print("NATIVE_INTERRUPTED_WRITE_READY "+stage)
			while true: await process_frame
		"verify_interrupted":
			assert(store.writable and store.load_component("settings",{}).value==2)
			print("NATIVE_LAST_COMMITTED_VALUE_AFTER_KILL_PASS")
		"interrupted_delete":
			assert(store.save_component("cup",{"value":1})==OK and store.save_component("cup",{"value":2})==OK)
			store.fail_stage = stage
			assert(store.delete_component("cup")!=OK)
			print("NATIVE_INTERRUPTED_WRITE_READY "+stage)
			while true: await process_frame
		"verify_deleted":
			assert(store.writable and store.load_component("cup",{}).is_empty())
			assert(not FileAccess.file_exists(store.path("cup")+".bak"))
			print("NATIVE_NO_BACKUP_RESURRECTION_AFTER_KILL_PASS")
		_:
			assert(false,"unknown fixture operation")
	quit()

extends Node
## Exported-package storage fixture, restricted to a fresh diagnostic UUID.
var store: SaveStore
var probe_folder: String

func _ready() -> void: call_deferred("run")
func run() -> void:
	var scope: String
	var action: String
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--probe-scope="): scope = argument.trim_prefix("--probe-scope=")
		elif argument.begins_with("--probe-action="): action = argument.trim_prefix("--probe-action=")
	if not scope.begins_with("test:") or not GuestIdentity.valid_uuid(scope.trim_prefix("test:")) or not ClassDB.class_exists("PacificSaveFiles"):
		finish(false)
		return
	probe_folder = "user://diagnostic_profiles/save_files_probe/"+scope.trim_prefix("test:")
	store = SaveStore.new(probe_folder)
	var ok: bool = store.writable and store.file_ops!=null and store.file_ops.owned()
	if not ok:
		finish(false)
		return
	var loaded := store.load_component("settings",{})
	match action:
		"write": ok = loaded.is_empty() and store.save_component("settings",{"value":1})==OK
		"read": ok = loaded.get("value")==1
		"replace": ok = loaded.get("value")==1 and store.save_component("settings",{"value":2})==OK
		"fail":
			store.fail_stage = "before_replace"
			ok = loaded.get("value")==2 and store.save_component("settings",{"value":3})!=OK
		"read_replaced": ok = loaded.get("value")==2
		"hold":
			if loaded.get("value")!=2:
				finish(false)
				return
			print("SAVE_FILES_PROBE_HELD "+scope)
			await get_tree().create_timer(45).timeout
			finish(true)
			return
		"delete_interrupted":
			store.fail_stage = "after_delete_primary"
			ok = loaded.get("value")==2 and store.delete_component("settings")!=OK
		"read_deleted": ok = loaded.is_empty() and not FileAccess.file_exists(store.path("settings")+".bak")
		"cleanup":
			store.file_ops.release()
			store = null
			ok = AppData.remove_tree(ProjectSettings.globalize_path(probe_folder))==OK
		_: ok = false
	finish(ok)

func finish(ok: bool) -> void:
	print("SAVE_FILES_PROBE_PASS" if ok else "SAVE_FILES_PROBE_FAIL")
	get_tree().quit(0 if ok else 1)

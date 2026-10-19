extends SceneTree

func _initialize() -> void:
	Catalog.load_all()
	var folder := "user://tests/durable-save-"+RaceSetup.uuid()
	var store := SaveStore.new(folder)
	assert(store.writable)
	assert(store.save_component("settings",{"value":1})==OK)
	for stage: String in ["sync_file","sync_directory","after_tmp","after_backup","before_replace"]:
		store.fail_stage = stage
		assert(store.save_component("settings",{"value":2})!=OK)
		assert(SaveStore.new(folder).load_component("settings",{}).value==1,"a failed precommit barrier retains the last committed component")
	store.fail_stage = ""
	assert(store.save_component("settings",{"value":2})==OK)
	var old := FileAccess.get_file_as_bytes(store.path("settings")+".bak")
	var future := FileAccess.open(store.path("settings"),FileAccess.WRITE)
	future.store_string('{"schema_version":99,"saved_at_utc":"future","payload":{"value":9}}')
	future.close()
	var bytes := FileAccess.get_file_as_bytes(store.path("settings"))
	assert(store.save_component("settings",{"value":3})==ERR_UNAVAILABLE,"a previously loaded writer cannot overwrite a newer envelope")
	assert(FileAccess.get_file_as_bytes(store.path("settings"))==bytes and FileAccess.get_file_as_bytes(store.path("settings")+".bak")==old)
	for stage: String in ["after_delete_marker","after_delete_primary"]:
		store.fail_stage = ""
		assert(store.save_component("cup",{"value":1})==OK)
		assert(store.save_component("cup",{"value":2})==OK)
		store.fail_stage = stage
		assert(store.delete_component("cup")!=OK)
		var cold := SaveStore.new(folder)
		assert(cold.load_component("cup",{}).is_empty(),"interrupted deletion cannot resurrect the backup")
		assert(not FileAccess.file_exists(store.path("cup")+".deleted"))
	store.fail_stage = ""
	assert(store.save_component("profile",{"value":1})==OK)
	assert(store.save_component("profile",{"value":2})==OK)
	store.fail_stage = "after_tmp"
	assert(store.save_component("profile",{"value":3})!=OK)
	store.fail_stage = ""
	var preserved: Dictionary = {}
	for suffix: String in ["",".bak",".tmp"]: preserved[suffix] = FileAccess.get_file_as_bytes(store.path("profile")+suffix)
	var multibyte := "界".repeat(6000000)
	assert(multibyte.length()<SaveStore.MAX_ENVELOPE_BYTES and multibyte.to_utf8_buffer().size()>SaveStore.MAX_ENVELOPE_BYTES)
	assert(store.save_component("profile",{"text":multibyte})==ERR_INVALID_DATA)
	for suffix: String in preserved: assert(FileAccess.get_file_as_bytes(store.path("profile")+suffix)==preserved[suffix],"oversized UTF-8 cannot touch committed, backup or pending bytes")
	multibyte = ""
	var empty := {"schema_version":1,"saved_at_utc":"2000-01-01T00:00:00Z","payload":{"text":""}}
	var padding := SaveStore.MAX_ENVELOPE_BYTES-JSON.stringify(empty,"\t",true).to_utf8_buffer().size()
	assert(store.save_component("profile",{"text":"a".repeat(padding)})==OK)
	assert(FileAccess.get_file_as_bytes(store.path("profile")).size()==SaveStore.MAX_ENVELOPE_BYTES)
	assert(SaveStore.new(folder).load_component("profile",{}).text.length()==padding,"the exact accepted byte boundary cold-loads")
	assert(store.save_component("profile",{"text":"a".repeat(padding+1)})==ERR_INVALID_DATA)
	if store.file_ops:
		assert(store.file_ops.owned())
		for bad: String in ["../settings.json","/tmp/settings.json","sub/../../settings.json",".pacific-save.lock",".PACIFIC-SAVE.LOCK","a\\b.json"]:
			assert(not store.file_ops.sync_file(bad).ok and not store.file_ops.remove_file(bad).ok)
		assert(not store.file_ops.replace_file("settings.json","../outside.json").ok)
		assert(store.file_ops.sync_directory().ok)
	assert(AppData.remove_tree(ProjectSettings.globalize_path(folder))==OK)
	print("DURABLE_SAVE_NATIVE_OR_SOURCE_BARRIERS_FUTURE_ENVELOPE_DELETION_TOMBSTONE_PROFILE_CONFINEMENT_EXACT_16_MIB_UTF8_BOUND_PASS backend="+store.lock_state)
	quit()

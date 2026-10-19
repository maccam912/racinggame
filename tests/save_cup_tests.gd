extends SceneTree

var failures: int = 0


func check(condition: bool, message: String) -> void:
	if not condition:
		push_error("TEST FAIL: " + message)
		failures += 1


func _initialize() -> void:
	var folder := "user://test-save-" + str(Time.get_ticks_usec())
	var store := SaveStore.new(folder)
	check(store.save_component("settings", {"value":1}) == OK, "initial save")
	check(store.save_component("settings", {"value":2}) == OK, "atomic replacement")
	for stage in ["after_tmp", "after_backup", "before_replace"]:
		store.fail_stage = stage
		check(store.save_component("settings", {"value":3}) != OK, "injected disk/write failure")
		check(SaveStore.new(folder).load_component("settings", {}).value == 2, "last committed data survives interrupted write")
	store.fail_stage = ""
	var corrupt := FileAccess.open(store.path("settings"), FileAccess.WRITE)
	corrupt.store_string("broken JSON")
	corrupt.close()
	var recovered := SaveStore.new(folder)
	check(recovered.load_component("settings", {}).value == 2, "valid backup restored")
	check(recovered.notices.has("data.backup_restored"), "backup recovery notice")
	check(store.save_component("profile", {"name":"Independent"}) == OK, "independent component save")
	corrupt = FileAccess.open(store.path("settings") + ".bak", FileAccess.WRITE)
	corrupt.store_string("broken backup")
	corrupt.close()
	check(SaveStore.new(folder).load_component("settings", {"value":9}).value == 9, "both corrupt restore component defaults")
	check(SaveStore.new(folder).load_component("profile", {}).name == "Independent", "settings corruption preserves profile")
	var future := FileAccess.open(store.path("records"), FileAccess.WRITE)
	future.store_string('{"schema_version":99,"saved_at_utc":"future","payload":{"unknown":true}}')
	future.close()
	var original := FileAccess.get_file_as_string(store.path("records"))
	var reader := SaveStore.new(folder)
	reader.load_component("records", {})
	check(reader.save_component("records", {"overwrite":true}) == ERR_UNAVAILABLE, "future schema read-only")
	check(FileAccess.get_file_as_string(store.path("records")) == original, "future bytes preserved")
	check(store.save_component("profile", {"nonfinite":NAN}) != OK, "nonfinite save rejected")
	var cup := CupBook.new()
	cup.start(0, 0, "Local", "test_hash")
	check(cup.grid()[4].id == "local" and cup.data.seeds.size() == 6, "cup initial fifth slot and stable event seeds")
	var order: Array[Dictionary] = []
	for record: Dictionary in cup.grid():
		order.append({"id":record.id, "dnf":""})
	check(cup.commit(0, "race-0", order), "first cup event committed")
	check(not cup.commit(0, "different-result", order), "completed cup result immutable")
	check(cup.standings()[0].points == 10 and cup.grid()[-1].id == order[0].id, "points and reversed championship grid")
	check(not cup.compatible("changed_hash"), "incompatible cup cannot continue")
	var directory := DirAccess.open(store.root_path)
	for file: String in directory.get_files():
		directory.remove(file)
	DirAccess.remove_absolute(store.root_path)
	print("Persistence/cup fixtures: corruption, interrupted writes, future schema, points and grids; failures %d" % failures)
	quit(1 if failures else 0)

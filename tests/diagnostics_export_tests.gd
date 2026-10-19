extends SceneTree
const CANARY: String = "PRIVATE_EXPORT_CANARY_6d8f"
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var app: Node = load("res://game/client_app.gd").new()
	root.add_child(app)
	await process_frame
	var folder := "user://tests/diagnostics-"+RaceSetup.uuid()
	app.data = AppData.new(folder,false)
	app.data.profile.display_name = CANARY
	app.data.profile.guest_reference = "6789082b-64e6-4dc0-9e95-e50bc0b1bb13"
	app.data.settings["private_path"] = "/Users/"+CANARY+"/records.json"
	app.data.settings.resolution = "203.0.113.7"
	app.data.settings.bindings = {"private_token":CANARY,"keyboard":{"private_action":[CANARY],"recover":[BindingBook.key(KEY_R),null]}}
	app.data.settings.touch_layouts = {"private_path":CANARY,"landscape_phone_auto_slider_right":{"steer":[.2,.8],"private_token":CANARY}}
	app.start_drive({"mode":"quick","track":1,"car":2,"opponents":0,"seed":12345678,"private_ticket":CANARY})
	app.drive.set_physics_process(false)
	var book: Diagnostics = app.diagnostics
	book.log._log_message("NETWORK_STATUS https://203.0.113.7/"+CANARY,false)
	book.log._log_error(CANARY,"/Users/"+CANARY+"/script.gd",42,CANARY,CANARY,false,Logger.ERROR_TYPE_SCRIPT,[])
	book._process(.016)
	var contents := book.snapshot()
	var encoded := JSON.stringify(contents)
	for private_value: String in [CANARY,"203.0.113.7","6789082b-64e6-4dc0-9e95-e50bc0b1bb13",app.data.store.root_path]:
		assert(not encoded.contains(private_value),"diagnostics must omit personal paths/names/identity/hosts/tokens")
	assert(contents["settings.json"].resolution=="native")
	assert(contents["settings.json"].touch_layouts.landscape_phone_auto_slider_right=={"steer":[.2,.8]})
	assert(contents["race.json"].seed=="12345678" and contents["race.json"].track=="citrus_pass")
	assert(contents["events.json"].error_counts[Logger.ERROR_TYPE_SCRIPT]==1)
	assert(contents["performance.json"].seconds.size()>0 and contents["performance.json"].seconds.size()<=60)
	assert(SaveStore.json_safe(contents))
	var source := folder.path_join("source.zip")
	var destination := folder.path_join("selected.zip")
	assert(Diagnostics.write_zip(source,contents)==OK)
	assert(Diagnostics.verify_archive(source))
	var oversized := contents.duplicate(true)
	oversized["events.json"] = {"fixture":"x".repeat(Diagnostics.MAX_ARCHIVE_BYTES)}
	assert(Diagnostics.write_zip(folder.path_join("oversized.zip"),oversized)==ERR_OUT_OF_MEMORY)
	assert(not FileAccess.file_exists(folder.path_join("oversized.zip")))
	var prior := FileAccess.open(destination,FileAccess.WRITE)
	prior.store_string("PRIOR FIXTURE FILE")
	prior.close()
	assert(Diagnostics.copy_archive(source,destination)==OK)
	assert(FileAccess.get_file_as_bytes(source)==FileAccess.get_file_as_bytes(destination),"selected file receives the complete verified archive")
	var reader := ZIPReader.new()
	assert(reader.open(destination)==OK)
	var names := reader.get_files()
	names.sort()
	var expected := PackedStringArray(Diagnostics.FILES)
	expected.sort()
	assert(names==expected,"ZIP contains only the six fixed technical entries")
	for name_value: String in names:
		var parser := JSON.new()
		assert(parser.parse(reader.read_file(name_value).get_string_from_utf8())==OK)
	reader.close()
	assert(Diagnostics.copy_archive(source,folder.path_join("missing/failed.zip"))!=OK)
	assert(FileAccess.get_file_as_bytes(source)==FileAccess.get_file_as_bytes(destination),"a failed export does not alter the previous destination")
	var malicious := Diagnostics.safe_build({"version":"203.0.113.7","engine_version":"4.6.3-stable","private_token":CANARY,"target_platform":CANARY,"commit":"a".repeat(40)})
	assert(malicious.version=="Development" and not JSON.stringify(malicious).contains(CANARY))
	# Bounded logs are safe even when callbacks arrive from a worker thread.
	var worker := Thread.new()
	worker.start(func() -> void:
		for index in range(400): book.log._log_message("PACIFIC_RUSH_CLIENT_READY",false))
	while worker.is_alive():
		assert(book.log.snapshot().entries.size()<=256)
		await process_frame
	worker.wait_to_finish()
	assert(book.log.snapshot().entries.size()==256)
	app.queue_free()
	await process_frame
	await process_frame
	assert(AppData.remove_tree(ProjectSettings.globalize_path(folder))==OK)
	print("DIAGNOSTICS_ZIP_WHITELIST_PRIVACY_ATOMIC_COPY_BOUNDED_LOG_PASS")
	await create_timer(.5).timeout # Retire stopped audio on the mixer thread.
	quit()

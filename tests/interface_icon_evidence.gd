extends SceneTree
var app: Node
var captures: Array[String] = []
var folder: String
func _initialize() -> void: call_deferred("run")
func capture(id: String) -> void:
	for index in range(5): await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://reports/m4-ui-"+id+".png"
	assert(root.get_texture().get_image().save_png(path)==OK)
	captures.append(path)
func run() -> void:
	assert(DisplayServer.get_name()!="headless")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://reports"))
	Catalog.load_all()
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1920,1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var sheet := Control.new()
	sheet.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(sheet)
	var background := ColorRect.new()
	background.color = UIFactory.NAVY
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	sheet.add_child(background)
	var font: Font = load("res://assets/fonts/Barlow-SemiBold.ttf")
	var heading := Label.new()
	heading.text = "PACIFIC RUSH — ORIGINAL INTERFACE ICONS"
	heading.add_theme_font_override("font",load("res://assets/fonts/BarlowCondensed-Bold.ttf"))
	heading.add_theme_font_size_override("font_size",48)
	heading.position = Vector2(60,30)
	sheet.add_child(heading)
	var entries := UIIcons.entries().values()
	for index in range(entries.size()):
		var row: Dictionary = entries[index]
		var at := Vector2(60+(index%10)*180,130+(index/10)*140)
		var icon := TextureRect.new()
		icon.texture = UIIcons.texture(row.id)
		icon.position = at+Vector2(48,0)
		icon.size = Vector2(64,64)
		sheet.add_child(icon)
		var label := Label.new()
		label.text = str(row.id).replace("_"," ")
		label.position = at+Vector2(0,70)
		label.size = Vector2(165,50)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.add_theme_font_override("font",font)
		label.add_theme_font_size_override("font_size",18)
		sheet.add_child(label)
	await capture("icon-library")
	sheet.queue_free()
	await process_frame
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1280,720)
	folder = "user://tests/icon-evidence-"+RaceSetup.uuid()
	app = load("res://game/client_app.gd").new()
	app.capture_path = "user://unused-icon-evidence.png"
	app.capture_frame = 1000000
	root.add_child(app)
	await process_frame
	app.data = AppData.new(folder,false)
	app.data.profile.first_run_complete = true
	app.data.profile.display_name = "Coast Driver"
	app.data.settings.reduce_motion = true
	app.show_menu()
	await capture("main")
	app.show_garage("trial")
	await capture("garage")
	var track: TrackDefinition = Catalog.tracks[0]
	app.data.records.times[app.data.record_key("trial",track.id,"comet")] = {"time":Medals.thresholds(track.length)[0]}
	app.events.mode = "trial"
	app.events.show_event()
	await capture("trial-gold")
	app.events.select_track(5)
	await capture("summit-details")
	app.data.settings.ui_scale = 150
	app.menu.settings = app.data.settings
	app.events.show_event()
	await capture("track-150")
	app.settings_page.show_tab("graphics",app.show_menu)
	await capture("settings-150")
	app.bindings_page.show_page(app.show_menu)
	await capture("bindings-150")
	app.data.settings.ui_scale = 100
	app.data.profile.trophies = [{"cup_id":RaceSetup.uuid(),"rank":0,"car":0,"content_hash":Compatibility.content_hash()}]
	app.show_cup()
	await capture("cup-trophy")
	app.start_drive({"mode":"trial","track":0,"car":0,"laps":1})
	await process_frame
	app.drive.set_physics_process(false)
	app.drive.result_sent = true
	app.drive.state.finished = true
	app.drive.state.finish_time = Medals.thresholds(track.length)[0]-.5
	app.drive.state.best_lap_time = app.drive.state.finish_time
	app.drive.session.phase = RaceSession.Phase.RESULTS
	app.result_receipt = ResultReceipt.capture(app.drive.session,[])
	app.result_summary = {"saved":true,"new_best":false,"previous":Medals.thresholds(track.length)[0]}
	app.page = "results"
	app.render_results()
	await capture("trial-results")
	var file := FileAccess.open("res://reports/m4-ui-reference.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"renderer":"Godot 4.6.3 Compatibility","resolution":[1920,1080],"icons":UIIcons.entries().size(),"asset_hash":JSON.parse_string(FileAccess.get_file_as_string("res://assets/checksums.json")).asset_hash,"captures":captures,"boundary":"Native UI and synthetic isolated record/trophy presentation, not human medals, real Cup wins, physical input or complete race acceptance"},"  "))
	file.close()
	app.queue_free()
	await create_timer(.5).timeout
	assert(AppData.remove_tree(ProjectSettings.globalize_path(folder))==OK)
	print("NATIVE_ORIGINAL_ICONS_SELECTION_STATS_MEDALS_SETTINGS_RESULTS_REFERENCE_PASS")
	quit()

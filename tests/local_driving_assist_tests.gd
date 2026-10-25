extends SceneTree
## Exercise persisted preference, real setup UI, local stepping and resume.
func _initialize() -> void: call_deferred("run")

func run() -> void:
	Catalog.load_all()
	assert(SettingsCatalog.defaults(false).steering_assist == "off" and not SettingsCatalog.defaults(false).corner_braking)
	assert(SettingsCatalog.sanitize({"steering_assist":"autopilot"},false).steering_assist == "off")
	var app: Node = load("res://game/client_app.gd").new()
	app.capture_path = "user://unused-local-assist.png"
	app.capture_frame = 1000000000
	root.add_child(app)
	await process_frame
	var folder := "user://tests/local-assist-"+RaceSetup.uuid()
	app.data = AppData.new(folder,false)
	app.checkpoint = RaceCheckpoint.new(app.data)
	app.menu.settings = app.data.settings
	app.data.profile.first_run_complete = true
	app.events.mode = "quick"
	app.events.track_index = 5
	app.events.show_event()
	for i in range(5): await process_frame
	var relaxed: Control = app.menu.root.find_child("RelaxedSetup",true,false)
	assert(app.events.detail_scroll.get_global_rect().encloses(relaxed.get_global_rect()),"preset is visible before scrolling through the course photograph and map")
	relaxed.pressed.emit()
	assert(app.page == "event", "preset lets the parent review before starting")
	assert(app.events.laps == 1 and app.events.opponents == 3 and app.events.difficulty == 0 and not app.events.contact)
	assert(app.events.track_index == 0 and EventMenu.FILTERS[app.events.filter_index] == "smooth")
	assert(app.data.settings.turn_hints and app.data.settings.corner_braking and app.data.settings.steering_assist == "strong" and app.data.settings.auto_accelerate and app.data.settings.touch_auto_accelerate)
	var reloaded := AppData.new(folder,false)
	assert(reloaded.settings.steering_assist == "strong" and reloaded.settings.auto_accelerate and reloaded.settings.sensitivity==.75)
	var saved_setup: Dictionary = reloaded.profile.quick_setup
	assert(saved_setup.laps==1 and saved_setup.opponents==3 and saved_setup.difficulty==0 and not saved_setup.contact)
	assert(saved_setup.track=="palm_bay" and saved_setup.filter=="smooth")
	reloaded = null
	for mobile: bool in [false,true]:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		root.size = Vector2i(884,398) if mobile else Vector2i(1280,720)
		app.data.mobile = mobile
		app.menu.mobile_override = mobile
		app.menu.logical_unit_override = 1.0
		app.data.settings.ui_scale = 150
		app.settings_page.show_tab("accessibility",app.events.show_event)
		for i in range(5): await process_frame
		var picker: Control = app.menu.root.find_child("setting_steering_assist",true,false)
		assert(picker != null and picker.get_global_rect().end.x <= root.size.x)
		picker.item_selected.emit(1)
		assert(app.data.settings.steering_assist == "gentle")
		picker.item_selected.emit(2)
		assert(app.data.settings.steering_assist == "strong")
		if "--capture" in OS.get_cmdline_user_args():
			app.menu.reveal_later(picker)
			for i in range(6): await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://reports/local-assist-"+("phone" if mobile else "desktop")+".png")
	app.data.mobile = false
	app.menu.mobile_override = false
	app.data.settings.ui_scale = 100
	root.size = Vector2i(1280,720)
	app.events.show_event()
	app.events.start()
	for i in range(1200):
		if app.page == "race": break
		await process_frame
	assert(app.page == "race")
	app.drive.set_physics_process(false)
	var drive: RaceDrive = app.drive
	assert(drive.driver.sensitivity==.75)
	assert(drive.session.driving_assists == {drive.local_slot:2} and drive.session.corner_braking == {drive.local_slot:true})
	assert(drive.driver.auto_accelerate and drive.session.states.size() == 4 and not drive.session.contact_enabled)
	# A live setting change reaches the actual session without touching bots.
	app.data.set_setting("steering_assist","gentle")
	drive.apply_settings()
	assert(drive.session.driving_assists == {drive.local_slot:1} and drive.session.corner_braking == {drive.local_slot:true})
	var archive := RaceArchive.capture(drive)
	assert(RaceArchive.valid(archive))
	assert(RaceArchive.restore(drive,archive))
	assert(drive.session.driving_assists == {drive.local_slot:1} and drive.session.corner_braking == {drive.local_slot:true})
	# Reconstructed races apply the saved device preference too.
	app.retry_drive()
	app.drive.set_physics_process(false)
	assert(app.drive.session.driving_assists == {app.drive.local_slot:1} and app.drive.session.corner_braking == {app.drive.local_slot:true})
	drive = app.drive
	for mode: String in ["trial","school"]:
		drive.session.mode = mode
		drive.apply_settings()
		assert(drive.session.driving_assists.is_empty() and drive.session.corner_braking.is_empty())
	drive.session.mode = "cup"
	drive.apply_settings()
	assert(drive.session.driving_assists == {drive.local_slot:1} and drive.session.corner_braking == {drive.local_slot:true})
	# The network path must not replace authority-owned assistance.
	var network := NetworkClient.new()
	drive.network = network
	drive.session.driving_assists = {drive.local_slot:2}
	drive.apply_settings()
	assert(drive.session.driving_assists == {drive.local_slot:2} and drive.session.corner_braking == {drive.local_slot:true})
	drive.network = null
	network.wire.close()
	network.free()
	app.data.set_setting("steering_assist","off")
	drive.apply_settings()
	assert(drive.session.driving_assists == {drive.local_slot:0})
	app.show_menu()
	await process_frame
	app.queue_free()
	await create_timer(.5).timeout
	assert(AppData.remove_tree(ProjectSettings.globalize_path(folder)) == OK)
	print("LOCAL_ASSIST_RELAXED_SETUP_PERSISTENCE_LIVE_CHANGE_RETRY_RESUME_MODE_AND_ONLINE_BOUNDARIES_PASS")
	quit()

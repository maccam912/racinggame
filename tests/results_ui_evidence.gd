extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/results-native-%s.png" % label)

func run() -> void:
	var folder := "user://tests/results-native-"+RaceSetup.uuid()
	var data := AppData.new(folder,false)
	data.settings.window_mode = "windowed"
	data.settings.ui_scale = 150
	data.profile.first_run_complete = true
	data.save_profile()
	data.save_settings()
	var app: Node = load("res://game/client_app.gd").new()
	app.capture_path = "user://unused-results-fixture.png"
	app.capture_frame = 1000000
	root.add_child(app)
	await process_frame
	app.data = data
	SettingsRuntime.apply(app,data.settings,true)
	assert(app.data.start_cup()==OK)
	app.start_cup_event()
	while app.page=="loading": await process_frame
	await physics_frame
	app.drive.set_physics_process(false)
	app.drive.session.phase = RaceSession.Phase.RESULTS
	app.drive.result_sent = true
	for state: VehicleState in app.drive.session.states:
		state.finished = true
		state.finish_time = 140.125+state.slot
		state.best_lap_time = 70.0625+state.slot
		state.distance_m = 6000
	app.data.store.fail_component = "cup"
	app.data.store.fail_stage = "before_replace"
	app.show_results()
	await capture("failed-150")
	assert(not app.result_summary.saved)
	app.data.store.fail_stage = ""
	app.retry_result_save()
	await capture("saved-150")
	assert(app.result_summary.saved and app.data.cup.data.next_event==1)
	app.show_menu()
	for frame: int in range(8):
		await process_frame
		await RenderingServer.frame_post_draw
	app.queue_free()
	for frame: int in range(8):
		await process_frame
		await RenderingServer.frame_post_draw
	print("RESULTS_NATIVE_FAILURE_RETRY_PASS")
	assert(AppData.remove_tree(ProjectSettings.globalize_path(folder))==OK)
	quit()

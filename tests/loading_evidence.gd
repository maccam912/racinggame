extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var app: Node = load("res://game/client_app.gd").new()
	root.add_child(app)
	app.data.settings.ui_scale = 150
	app.menu.settings = app.data.settings
	app.show_menu()
	app.events.track_index = 5
	app.events.mode = "quick"
	app.events.start()
	var job: TrackLoader = app.track_loader
	job.set_process(false)
	for step in range(7): job._process(0)
	assert(app.page=="loading" and app.loading_bar.value>0 and app.loading_bar.value<1)
	await create_timer(.3).timeout
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://reports/loading-native-150.png")==OK)
	app.back_action.call()
	await process_frame
	assert(app.page=="event")
	app.queue_free()
	await process_frame
	print("LOADING_NATIVE_POSTCARD_PROGRESS_CANCEL_PASS")
	quit()

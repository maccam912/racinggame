extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var profile := AppData.new("user://diagnostic_profiles/display_native",false)
	profile.settings.window_mode = "windowed"
	profile.settings.frame_cap = 60
	profile.profile.first_run_complete = true
	profile.save_settings()
	profile.save_profile()
	var app: Node = load("res://game/client_app.gd").new()
	root.add_child(app)
	await process_frame
	app.settings_page.show_tab("display",app.show_menu)
	app.settings_page.begin_display("window_mode","windowed")
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/display-native-confirm.png")
	var started := Time.get_ticks_msec()
	await create_timer(15.2).timeout
	assert(app.settings_page.pending_display.is_empty())
	assert(app.data.settings.window_mode=="windowed")
	assert(Time.get_ticks_msec()-started>=15000)
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/display-native-timeout.png")
	print("DISPLAY_NATIVE_CONFIRM_TIMEOUT_PASS elapsed_ms=",Time.get_ticks_msec()-started)
	app.queue_free()
	await process_frame
	quit()

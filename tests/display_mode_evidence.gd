extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var profile := AppData.new("user://diagnostic_profiles/display_modes_native",false)
	profile.settings.window_mode = "windowed"
	profile.profile.first_run_complete = true
	profile.save_settings()
	profile.save_profile()
	var app: Node = load("res://game/client_app.gd").new()
	root.add_child(app)
	await process_frame
	app.settings_page.show_tab("display",app.show_menu)
	app.settings_page.begin_display("window_mode","borderless")
	await create_timer(2.5).timeout
	assert(DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN)
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/display-native-borderless.png")
	app.settings_page.revert_display()
	await create_timer(2.5).timeout
	assert(DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_WINDOWED)
	assert(not DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS))
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/display-native-windowed-restored.png")
	print("DISPLAY_NATIVE_MODE_REVERT_PASS")
	app.queue_free()
	await process_frame
	quit()

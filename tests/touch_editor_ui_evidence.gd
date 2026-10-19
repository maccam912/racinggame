extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/touch-editor-%s.png" % label)

func run() -> void:
	var profile := AppData.new("user://diagnostic_profiles/touch_editor_native",false)
	profile.settings.window_mode = "windowed"
	profile.settings.ui_scale = 150
	profile.profile.first_run_complete = true
	profile.save_profile()
	profile.save_settings()
	var app: Node = load("res://game/client_app.gd").new()
	root.add_child(app)
	await process_frame
	app.settings_page.show_tab("touch",app.show_menu)
	app.show_touch_editor()
	await create_timer(.4).timeout
	var editor: TouchLayoutEditor = app.touch_editor
	await capture("phone-150")
	assert(editor.toolbar.get_rect().end.y<editor.controls.recover.position.y*editor.unit,"toolbar leaves recovery accessible")
	editor.selected = "steer"
	editor.move_selected(editor.controls.steer.get_center()-Vector2(0,32))
	editor.begin_preview()
	await create_timer(4).timeout
	await capture("preview-150")
	editor.finish_preview()
	editor.save_layout()
	await process_frame
	await process_frame
	assert(app.touch_editor==null)
	app.queue_free()
	for frame: int in range(8):
		await process_frame
		await RenderingServer.frame_post_draw
	print("TOUCH_EDITOR_NATIVE_SAVE_PREVIEW_PASS")
	quit()

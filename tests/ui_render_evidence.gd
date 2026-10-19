extends SceneTree

var app: Node


func _initialize() -> void:
	call_deferred("run")


func capture(name_value: String) -> void:
	for frame in range(3):
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/ui-" + name_value + ".png")


func run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1920,1080)
	app = load("res://game/client_app.gd").new()
	app.capture_path = "user://unused-ui-evidence.png"
	app.capture_frame = 1000000
	root.add_child(app)
	await process_frame
	app.show_menu()
	await capture("main")
	app.show_garage("quick")
	await capture("garage")
	app.events.show_event()
	await capture("event")
	app.data.settings.ui_scale = 150
	app.menu.settings = app.data.settings
	app.events.show_event()
	await capture("event-150")
	app.show_menu()
	await capture("main-150")
	print("UI150 viewport=", root.get_visible_rect(), " frame=", app.menu.frame.get_rect(), " min=", app.menu.column.get_combined_minimum_size(), " footer=", app.menu.footer.get_global_rect())
	app.settings_page.show_tab("graphics", app.show_menu)
	await capture("settings-150")
	app.data.settings.ui_scale = 100
	app.menu.settings = app.data.settings
	root.size = Vector2i(960, 720)
	app.events.show_event()
	await capture("event-4x3")
	app.queue_free()
	await process_frame
	print("UI_RENDER_EVIDENCE_SAVED")
	quit()

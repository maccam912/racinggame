extends SceneTree
var app: Node
var captures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func capture(id: String,frames: int = 8) -> void:
	for index in range(frames): await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://reports/m4-menu-"+id+".png"
	assert(root.get_texture().get_image().save_png(path)==OK)
	captures.append(path)
func run() -> void:
	assert(DisplayServer.get_name()!="headless")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://reports"))
	root.size = Vector2i(1920,1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1280,720)
	var folder := "user://tests/menu-style-"+RaceSetup.uuid()
	app = load("res://game/client_app.gd").new()
	app.capture_path = "user://unused-menu-style.png"
	app.capture_frame = 1000000
	root.add_child(app)
	await process_frame
	app.data = AppData.new(folder,false)
	app.data.profile.first_run_complete = true
	app.data.profile.display_name = "Coast Driver"
	app.show_menu()
	for button: Button in app.menu.root.find_children("*","Button",true,false):
		if button.text==I18n.t("menu.trial"): app.menu.focus_later(button)
	await create_timer(.6).timeout
	await capture("main-focus-help")
	app.show_garage("trial")
	await capture("slide",1)
	await create_timer(.6).timeout
	await capture("garage-selected")
	app.data.settings.ui_scale = 150
	app.show_garage("trial")
	await capture("garage-150")
	app.show_online()
	for index in range(4): await process_frame
	app.online_page.hub_buttons[0].grab_focus()
	await capture("disabled-reason-150")
	app.data.settings.reduce_motion = true
	app.show_menu()
	assert(app.menu.motion.position.x==0)
	await capture("reduced-motion-cut",1)
	app.data.mobile = true
	app.menu.mobile_override = true
	app.menu.logical_unit_override = 1.0
	for layout: Dictionary in [{"id":"phone","size":Vector2i(884,398)},{"id":"tablet","size":Vector2i(1280,800)}]:
		root.size = layout.size*2 if layout.id=="phone" else layout.size
		root.content_scale_size = layout.size
		for scale_value: int in [100,150]:
			app.data.settings.ui_scale = scale_value
			app.show_menu()
			await capture(layout.id+"-main-"+str(scale_value))
			assert(app.menu.body.size.y>=48,"narrow mobile menu retains at least one full touch row")
			for button: Button in app.menu.footer.find_children("*","Button",true,false):
				assert(root.get_visible_rect().encloses(button.get_global_rect()),"mobile footer remains inside the viewport")
			app.show_garage("quick")
			await capture(layout.id+"-garage-"+str(scale_value))
			app.settings_page.show_tab("display",app.show_menu)
			await capture(layout.id+"-settings-"+str(scale_value))
	app.data.settings.high_contrast = true
	app.settings_page.show_tab("accessibility",app.show_menu)
	await capture("tablet-high-contrast-150")
	var file := FileAccess.open("res://reports/m4-menu-reference.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"desktop_resolution":[1920,1080],"mobile_layouts":[[884,398],[1280,800]],"renderer":"Godot 4.6.3 Compatibility","captures":captures,"screen_transition_seconds":.18,"focus_transition_seconds":.1,"focus_help_seconds":.5,"boundary":"Native desktop menu renders with explicit mobile-layout overrides, 100/150 percent scale, plus deterministic keyboard/focus tests. These are not Android APK captures, human comprehension, screen-reader or physical input-device acceptance."},"  "))
	file.close()
	app.queue_free()
	await create_timer(.5).timeout
	assert(AppData.remove_tree(ProjectSettings.globalize_path(folder))==OK)
	print("NATIVE_FOCUS_EXPLANATION_SELECTED_ACCENT_DISABLED_LARGE_TEXT_SLIDE_INSTANT_CUT_PASS")
	quit()

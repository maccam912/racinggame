extends SceneTree
func _initialize() -> void: call_deferred("run")

func frames(count_value: int = 8) -> void:
	for index in range(count_value): await process_frame

func run() -> void:
	assert(DisplayServer.get_name()!="headless")
	var original := DesktopDisplay.capture()
	var original_screen_size := DisplayServer.screen_get_size(original.screen)
	var app: Node = load("res://game/client_app.gd").new()
	app.capture_path = "user://unused-display-fixture.png"
	app.capture_frame = 1000000
	root.add_child(app)
	await frames()
	app.set_process(false)
	var folder := "user://tests/display-native-"+RaceSetup.uuid()
	app.data = AppData.new(folder,false)
	app.data.settings.window_mode = "windowed"
	app.data.settings.resolution = "native"
	SettingsRuntime.apply(app,app.data.settings,true)
	app.show_menu()
	await frames()
	var screen: int = DisplayServer.window_get_current_screen()
	var choices := DesktopDisplay.modes(screen)
	assert(choices.size()>1,"native adapter must enumerate this desktop's supported sizes")
	var selected: String = choices[1]
	for mode: String in choices:
		var size := DesktopDisplay.resolution_size(mode)
		if size.x>=1280 and size.y>=720 and size.x<=1920 and size.y<=1080:
			selected = mode
			break
	DisplayServer.window_set_size(Vector2i(1120,630))
	DisplayServer.window_set_position(DisplayServer.screen_get_usable_rect(screen).position+Vector2i(70,90))
	await frames()
	var prior := DesktopDisplay.capture()
	app.settings_page.show_tab("display",app.show_menu)
	app.settings_page.begin_display("resolution",selected)
	await frames()
	var preview := DesktopDisplay.capture()
	var expected := DesktopDisplay.fitted_size(DesktopDisplay.resolution_size(selected),DisplayServer.screen_get_usable_rect(screen).size)
	assert(preview.size==expected,"selected window resolution applies real client pixels")
	app.settings_page.revert_display()
	await frames()
	var reverted := DesktopDisplay.capture()
	assert(reverted.size==prior.size and reverted.position==prior.position,"Revert restores actual window size and position")
	app.settings_page.preview_display({"window_mode":"borderless","resolution":selected})
	await frames(75)
	assert(DisplayServer.screen_get_size(screen)==original_screen_size,"fullscreen never changes the desktop display mode")
	var host_size := DisplayServer.window_get_size()
	var world_size: Vector2i = app.presentation.viewport.size
	print("DISPLAY_MEASURE screen=",original_screen_size," client=",host_size," root=",root.size," texture=",root.get_texture().get_size()," image=",root.get_texture().get_image().get_size()," content_scale=",root.content_scale_mode)
	assert(world_size==DesktopDisplay.resolution_size(selected),"fullscreen uses chosen world resolution")
	assert(root.get_texture().get_image().get_size()==host_size,"HUD image retains actual native client pixels, including OS safe-area limits")
	await RenderingServer.frame_post_draw
	var file := FileAccess.open("res://docs/evidence/m3-display-native.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"platform":OS.get_name(),"renderer":RenderingServer.get_current_rendering_method(),"supported_sizes":choices,"selected":selected,"window_preview":{ "width":preview.size.x,"height":preview.size.y},"window_revert":{ "width":reverted.size.x,"height":reverted.size.y,"position_restored":reverted.position==prior.position},"fullscreen":{"desktop_width":original_screen_size.x,"desktop_height":original_screen_size.y,"client_width":host_size.x,"client_height":host_size.y,"world_width":world_size.x,"world_height":world_size.y,"desktop_mode_unchanged":true},"boundaries":["Single desktop monitor; hotplug and multiple-monitor placement require target acceptance","The OS can reserve a notch/safe area; native UI follows client pixels rather than the full display rectangle","Windows/X11 adapter compile and native gates run remotely"]},"  ")+"\n")
	file.close()
	root.get_texture().get_image().save_png("res://docs/evidence/m3-display-confirmation.png")
	app.settings_page.revert_display()
	await frames(20)
	app.queue_free()
	await frames()
	DesktopDisplay.restore(original)
	assert(AppData.remove_tree(ProjectSettings.globalize_path(folder))==OK)
	print("DISPLAY_NATIVE_ENUM_WINDOW_PIXELS_GEOMETRY_REVERT_FULLSCREEN_WORLD_PASS")
	quit()

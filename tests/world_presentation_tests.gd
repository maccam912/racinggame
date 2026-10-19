extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	assert(SettingsCatalog.sanitize(42,false)==SettingsCatalog.defaults(false))
	assert(SettingsCatalog.sanitize(null,true)==SettingsCatalog.defaults(true))
	var values := SettingsCatalog.defaults(false)
	assert(WorldPresentation.render_size(Vector2i(1920,1080),values)==Vector2i(1920,1080))
	values.render_scale = 70
	assert(WorldPresentation.render_size(Vector2i(1920,1080),values)==Vector2i(1344,756))
	assert(WorldPresentation.render_size(Vector2i(320,180),values)==Vector2i(320,180))
	values.retro = true
	assert(WorldPresentation.render_size(Vector2i(3440,1440),values)==Vector2i(640,360))
	var fullscreen := SettingsCatalog.defaults(false)
	fullscreen.resolution = "1280x720"
	fullscreen.render_scale = 80
	assert(WorldPresentation.render_size(Vector2i(3440,1440),fullscreen)==Vector2i(1024,576),"fullscreen world resolution precedes render scale while HUD stays native")
	fullscreen.window_mode = "windowed"
	assert(WorldPresentation.render_size(Vector2i(1600,900),fullscreen)==Vector2i(1280,720),"windowed world follows the actual fitted client size")
	var app: Node = load("res://game/client_app.gd").new()
	root.add_child(app)
	await process_frame
	app.show_menu()
	var display: WorldPresentation = app.presentation
	display.pixel_size_override = Vector2i(1920,1080)
	var host_size := root.get_visible_rect().size
	var menu_unit: float = app.menu.ui.unit
	app.data.settings = values
	SettingsRuntime.apply(app,values)
	assert(display.viewport.size==Vector2i(640,360) and root.disable_3d)
	assert(display.viewport.find_world_3d()==app.get_world_3d(),"world render shares the actual physics world")
	assert(display.viewport.gui_disable_input and not display.viewport.audio_listener_enable_3d)
	assert(root.get_visible_rect().size==host_size and app.menu.ui.unit==menu_unit,"Retro must not resize or rescale the HUD viewport")
	assert(display.image.stretch_mode==TextureRect.STRETCH_KEEP_ASPECT_CENTERED)
	values.retro = false
	values.anisotropic = 16
	SettingsRuntime.apply(app,values)
	assert(display.viewport.size==Vector2i(1344,756) and values.render_scale==70,"disabling Retro restores the selected render scale")
	assert(display.viewport.anisotropic_filtering_level==Viewport.ANISOTROPY_16X)
	assert(display.viewport.msaa_3d==Viewport.MSAA_4X)
	var scenery: GeometryInstance3D = get_first_node_in_group("scenery_distance")
	assert(scenery.visibility_range_end==700)
	values.draw_distance = 400
	SettingsRuntime.apply(app,values)
	assert(scenery.visibility_range_end==400 and app.stage.camera.far>=1000,"scenery distance cannot remove the road or signs")
	display._process(0)
	assert(display.camera.global_transform==app.stage.camera.global_transform)
	assert(display.camera.h_offset==app.stage.camera.h_offset and display.camera.fov==app.stage.camera.fov)
	app.start_drive({"mode":"quick","track":1,"opponents":0})
	app.drive.set_physics_process(false)
	await physics_frame
	display._process(0)
	assert(display.camera.global_transform==app.drive.camera.global_transform,"the render camera follows scene camera ownership")
	assert(app.drive.camera.far>=1000,"the driving camera must retain the road beyond the scenery setting")
	app.queue_free()
	await process_frame
	assert(not root.disable_3d,"presentation teardown restores its host viewport")
	print("WORLD_NATIVE_HUD_RETRO_SCALE_CAMERA_SCENERY_SETTINGS_PASS")
	quit()

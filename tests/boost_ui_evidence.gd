extends SceneTree
## Native posed presentation reference, separate from the driving assertions.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	Catalog.load_all()
	root.size = Vector2i(1280,720)
	var app: Node = load("res://game/client_app.gd").new()
	root.add_child(app)
	await process_frame
	var folder := "user://tests/boost-ui-"+RaceSetup.uuid()
	app.data = AppData.new(folder,false)
	app.data.settings.reduce_motion = true
	app.data.select_car(7,7)
	app.menu.settings = app.data.settings
	app.show_garage()
	await capture("garage")
	app.start_drive({"mode":"quick","track":0,"car":7,"paint":7,"opponents":0})
	var drive: RaceDrive = app.drive
	drive.set_physics_process(false)
	var pose := drive.track.pose(50)
	drive.state.position = pose.origin+Vector3.UP*.35
	drive.state.yaw = atan2(-pose.basis.z.x,pose.basis.z.z)
	drive.state.boost_charges = 2
	drive.state.boost_ticks = 90
	drive.state.velocity = drive.state.forward()*60
	drive.phase = "Racing"
	drive.hud.phase = "Racing"
	drive.hud.ticks = 1200
	drive.camera.initialized = false
	drive._process(.016)
	await capture("desktop-boost")
	drive.touch.show()
	drive.touch.boost_available = true
	drive.touch.boost_charges = 2
	drive.hud.mobile = true
	drive.hud.mobile_unit = drive.touch.unit
	drive._process(.016)
	await capture("touch-boost")
	app.queue_free()
	await create_timer(.5).timeout
	assert(AppData.remove_tree(ProjectSettings.globalize_path(folder)) == OK)
	print("BOOST_GARAGE_DESKTOP_TOUCH_NATIVE_POSED_REFERENCE_PASS")
	quit()

func capture(label: String) -> void:
	for frame in range(12): await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://reports/cars16-"+label+".png") == OK)

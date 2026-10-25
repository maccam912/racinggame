extends SceneTree

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var app: Node = load("res://game/client_app.gd").new()
	root.add_child(app)
	await process_frame
	var folder := "user://tests/camera-preference-"+RaceSetup.uuid()
	app.data = AppData.new(folder,false)
	assert(app.data.settings.camera=="far")
	assert(app.data.set_setting("camera","near")==OK)
	app.start_drive({"mode":"quick","track":0,"opponents":0})
	app.drive.set_physics_process(false)
	assert(app.drive.camera.mode==0,"existing Near preference is respected")
	var event := InputEventAction.new()
	event.action = "camera"
	event.pressed = true
	app.drive._unhandled_input(event)
	assert(app.drive.camera.mode==1,"desktop camera shortcut selects Far")
	app.drive.show_pause()
	app.foreground = true
	app.resume_drive()
	assert(app.drive.resume_ticks==180)
	for tick in range(181): app.drive._physics_process(1.0/60)
	assert(app.drive.camera.mode==1,"Far survives resume and the complete countdown")
	var reloaded := AppData.new(folder,false)
	assert(reloaded.settings.camera=="far","camera shortcut persists across launches")
	app.drive.touch_action("camera")
	assert(app.drive.camera.mode==2)
	app.drive.apply_settings()
	assert(app.drive.camera.mode==2,"touch camera choice survives settings refresh")
	assert(AppData.new(folder,false).settings.camera=="hood")
	app.drive.show_pause()
	assert(app.data.set_setting("camera","near")==OK)
	app.resume_drive()
	assert(app.drive.camera.mode==0,"explicit paused settings changes still apply")
	app.drive.touch_action("camera")
	app.start_drive({"mode":"quick","track":0,"opponents":0})
	app.drive.set_physics_process(false)
	assert(app.drive.camera.mode==1,"new races retain the last selected view")
	app.queue_free()
	await process_frame
	print("CAMERA_PREFERENCE_RESUME_COUNTDOWN_DESKTOP_TOUCH_PASS")
	await create_timer(.5).timeout
	quit()

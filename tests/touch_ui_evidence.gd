extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	Catalog.load_all()
	DrivingInput.register_defaults()
	DisplayServer.window_set_size(Vector2i(1280,720))
	var data := AppData.new("user://tests/touch-evidence-" + RaceSetup.uuid(),true)
	var drive := RaceDrive.new()
	drive.app_data = data
	drive.show_touch = true
	drive.external_menus = true
	root.add_child(drive)
	drive.set_physics_process(false)
	for variant: String in ["auto","manual","mirrored_buttons"]:
		data.settings.touch_auto_accelerate = variant=="auto"
		data.settings.left_handed = variant=="mirrored_buttons"
		data.settings.steering_style = "buttons" if variant=="mirrored_buttons" else "slider"
		drive.apply_settings()
		await process_frame
		if variant=="manual":
			drive.touch.pointer_down(1,drive.touch.controls.throttle.get_center())
			drive.touch.pointer_down(2,drive.touch.controls.steer.get_center()+Vector2(50,0)*drive.touch.unit)
		elif variant=="mirrored_buttons":
			drive.touch.pointer_down(1,drive.touch.controls.throttle.get_center())
			drive.touch.pointer_down(2,drive.touch.controls.left.get_center())
		await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://reports/touch-native-%s.png" % variant)
		assert(drive.touch.layout_supported)
		print("TOUCH_NATIVE_VARIANT ",variant," unit=",drive.touch.unit)
	drive.queue_free()
	await process_frame
	quit()

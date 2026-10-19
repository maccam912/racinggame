extends SceneTree
var app: Node
var captures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func capture(id: String) -> void:
	for index in range(6): await process_frame
	app.drive.school_overlay.demo._process(0)
	for index in range(2): await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://reports/m4-school-"+id+".png"
	assert(root.get_texture().get_image().save_png(path)==OK)
	captures.append(path)
func run() -> void:
	assert(DisplayServer.get_name()!="headless")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://reports"))
	root.size = Vector2i(1920,1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1280,720)
	var folder := "user://tests/school-reference-"+RaceSetup.uuid()
	app = load("res://game/client_app.gd").new()
	app.capture_path = "user://unused-school-reference.png"
	app.capture_frame = 1000000
	root.add_child(app)
	await process_frame
	app.data = AppData.new(folder,false)
	app.data.profile.first_run_complete = true
	for index in range(5):
		app.start_drive({"mode":"school","lesson":index})
		app.drive.set_physics_process(false)
		var demo: SchoolInputDemo = app.drive.school_overlay.demo
		demo.set_process(false)
		demo.elapsed = [.5,.7,1.5,.8,.55][index]
		demo._process(0)
		await capture(["accelerate","steering","corner","slide-held","recover-hold"][index])
		if index==3:
			demo.elapsed = 1.5
			demo._process(0)
			await capture("slide-release")
	app.data.settings.hold_assistance = true
	app.data.settings.ui_scale = 150
	app.drive.apply_settings()
	app.drive.school_overlay.demo.elapsed = .75
	app.drive.school_overlay.demo._process(0)
	await capture("assisted-150")
	app.data.settings.reduce_motion = true
	app.drive.apply_settings()
	await capture("static-motion")
	var file := FileAccess.open("res://reports/m4-school-reference.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"renderer":"Godot 4.6.3 Compatibility","resolution":[1920,1080],"captures":captures,"boundary":"Scripted illustrations with frozen vehicle state; not human lesson completion or physical-device usability. Actual Retry/Skip clicks, remapping and objective isolation are tested separately."},"  "))
	file.close()
	app.queue_free()
	await create_timer(.5).timeout
	assert(AppData.remove_tree(ProjectSettings.globalize_path(folder))==OK)
	print("NATIVE_FIVE_SCHOOL_INPUT_GUIDES_SLIDE_RELEASE_RECOVERY_HOLD_ASSIST_LARGE_TEXT_STATIC_PASS")
	quit()

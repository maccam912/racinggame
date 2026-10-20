extends SceneTree
var app: Node
var captures: Array[String] = []
var capture_details: Array[Dictionary] = []
func _initialize() -> void: call_deferred("run")
func capture(id: String) -> void:
	for index in range(8): await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://reports/m4-hud-"+id+".png"
	assert(root.get_texture().get_image().save_png(path)==OK)
	captures.append(path)
	capture_details.append({"image":path,"width":root.size.x,"height":root.size.y,"sha256":FileAccess.get_sha256(path)})
func run() -> void:
	assert(DisplayServer.get_name()!="headless")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://reports"))
	root.size = Vector2i(1920,1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1280,720)
	var folder := "user://tests/hud-evidence-"+RaceSetup.uuid()
	app = load("res://game/client_app.gd").new()
	app.capture_path = "user://unused-hud-reference.png"
	app.capture_frame = 1000000
	root.add_child(app)
	await process_frame
	app.data = AppData.new(folder,false)
	app.data.profile.first_run_complete = true
	app.data.profile.display_name = "Coast Driver"
	app.data.settings.reduce_motion = true
	app.data.settings.nameplates = true
	app.start_drive({"mode":"quick","track":0,"car":0,"laps":2,"opponents":7})
	var drive: RaceDrive = app.drive
	drive.set_physics_process(false)
	drive.set_process(false)
	drive.phase = "Racing"
	drive.race_ticks = 3690
	for index in range(8):
		var state := drive.session.states[index]
		var s: float = 300.0 if index==drive.local_slot else 315+12*index
		var pose := drive.track.pose(s,0 if index==drive.local_slot else -2.5 if index%2==0 else 2.5)
		state.position = pose.origin+Vector3.UP*.35
		state.yaw = atan2(-pose.basis.z.x,pose.basis.z.z)
		state.velocity = state.forward()*40
		state.laps = 1
		state.lap_start_time = 54.125
		state.best_lap_time = 54.125
		state.route_s = s
		state.last_gate = 1
		state.ghost_ticks = 0
	drive.camera.initialized = false
	drive._process(.016)
	drive.hud.ticks = 3690
	drive.hud.phase = "Racing"
	drive.hud.rank = 5
	drive.hud.queue_redraw()
	await capture("race-100")
	drive.hud.ui_scale = 1.5
	drive.hud.queue_redraw()
	await capture("race-150")
	drive.hud.ui_scale = 1
	drive.hud.network_level = 2
	drive.hud.queue_redraw()
	await capture("connection")
	drive.hud.network_level = 0
	drive.nameplates.enabled = false
	drive.hud.trial = true
	drive.hud.lap_count = 1
	drive.state.laps = 0
	drive.state.lap_start_time = 0
	drive.state.best_lap_time = -1
	drive.hud.ticks = 3000
	drive.hud.trial_delta = -.125
	drive.hud.queue_redraw()
	await capture("trial-delta")
	drive.state.recovery_ticks = 30
	drive.state.wrong_way_ticks = 100
	drive.hud.queue_redraw()
	await capture("recovery-priority")
	drive.state.recovery_ticks = 0
	drive.state.wrong_way_ticks = 0
	drive.state.recovery_hold_ticks = 18
	drive.hud.queue_redraw()
	await capture("recover-hold")
	drive.state.recovery_hold_ticks = 0
	drive.state.finished = true
	drive.state.finish_time = 72.345
	drive.state.last_lap_time = 72.345
	drive.session.mode = "trial"
	drive.session.phase = RaceSession.Phase.RESULTS
	app.result_receipt = ResultReceipt.capture(drive.session,[])
	app.result_summary = {"saved":true,"new_best":false,"previous":73.123}
	app.page = "results"
	app.render_results()
	await capture("results")
	app.queue_free()
	await create_timer(.5).timeout
	assert(AppData.remove_tree(ProjectSettings.globalize_path(folder))==OK)
	await touch_previews()
	var file := FileAccess.open("res://reports/m4-hud-reference.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"renderer":"Godot 4.6.3 Compatibility","baseline_resolution":[1920,1080],"captures":captures,"capture_details":capture_details,"content_hash":Compatibility.content_hash(),"asset_hash":JSON.parse_string(FileAccess.get_file_as_string("res://assets/checksums.json")).asset_hash,"boundary":"Native final-art HUD and touch layout with posed race/lap/record states and explicit per-image dimensions. Numerical timing and real collision occlusion are separate tests. No human driving, physical device or gameplay win acceptance."},"  "))
	file.close()
	print("NATIVE_HUD_LAP_DELTA_NAMEPLATES_LARGE_TEXT_CONNECTION_RECOVERY_RESULTS_REFERENCE_PASS")
	quit()


func touch_previews() -> void:
	Catalog.load_all()
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.size = Vector2i(1768,796)
	var world := TrackWorld.new()
	world.build(Catalog.tracks[6])
	root.add_child(world)
	await physics_frame
	await physics_frame
	var state := VehicleState.new()
	var s := CourseArt.original_s(world.track,.35)
	var pose := world.track.pose(s)
	state.position = world.ground_pose(s,0).origin+Vector3.UP*.35
	state.yaw = atan2(-pose.basis.z.x,pose.basis.z.z)
	var query := WorldQuery.new(world.get_world_3d(),world.track,s)
	state.ground_normal = query.ground(state).normal
	var visual := CarVisual.new()
	visual.build(Catalog.paints[0],"comet")
	world.add_child(visual)
	visual.present(state,InputFrame.make(),.016)
	var camera := ChaseCamera.new()
	camera.current = true
	camera.dynamic_fov = false
	camera.reduce_motion = true
	world.add_child(camera)
	camera.follow(state,.016)
	var overlay := CanvasLayer.new()
	root.add_child(overlay)
	var touch := TouchDriving.new()
	overlay.add_child(touch)
	for spec: Dictionary in [{"id":"phone-slider","dp":Vector2i(884,398),"auto":true,"style":"slider","mirror":false,"contrast":false},{"id":"phone-minimum","dp":Vector2i(884,398),"auto":true,"style":"slider","mirror":false,"contrast":false,"scale":.65},{"id":"phone-buttons","dp":Vector2i(884,398),"auto":false,"style":"buttons","mirror":true,"contrast":false},{"id":"tablet-slider","dp":Vector2i(1280,800),"auto":true,"style":"slider","mirror":false,"contrast":false},{"id":"phone-contrast","dp":Vector2i(884,398),"auto":true,"style":"slider","mirror":false,"contrast":true}]:
		root.size = spec.dp*2
		for frame in range(6): await process_frame
		touch.clear()
		touch.unit = 2.0
		touch.auto_accelerate = spec.auto
		touch.steering_style = spec.style
		touch.left_handed = spec.mirror
		touch.high_contrast = spec.contrast
		touch.plate_cache.clear()
		touch.controls = TouchDriving.build_layout(Rect2(Vector2.ZERO,spec.dp),spec.auto,spec.style,float(spec.get("scale",1.0)),spec.mirror)
		for action: String in touch.controls:
			var r: Rect2 = touch.controls[action]
			touch.controls[action] = Rect2(r.position*2,r.size*2)
		touch.pointer_down(501,touch.controls.brake.get_center())
		if touch.controls.has("steer"): touch.pointer_down(502,touch.controls.steer.get_center()+Vector2(140 if spec.id=="phone-minimum" else 70,0))
		touch.queue_redraw()
		for frame in range(6): await process_frame
		await capture("touch-"+spec.id)
	query = null
	world.queue_free()
	overlay.queue_free()
	await process_frame

extends SceneTree
var app: Node
var captures: Array[String] = []
var samples: Array[Dictionary] = []
func _initialize() -> void: call_deferred("run")
func capture(id: String) -> void:
	for index in range(8): await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://reports/m5-runtime-"+id+".png"
	assert(root.get_texture().get_image().save_png(path)==OK)
	captures.append(path)
func run() -> void:
	assert(DisplayServer.get_name()!="headless")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://reports"))
	root.size = Vector2i(1920,1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1280,720)
	var folder := "user://tests/runtime-evidence-"+RaceSetup.uuid()
	app = load("res://game/client_app.gd").new()
	app.capture_path = "user://unused-runtime-reference.png"
	app.capture_frame = 1000000
	root.add_child(app)
	await process_frame
	app.data = AppData.new(folder,true)
	app.data.profile.first_run_complete = true
	app.data.settings.reduce_motion = true
	app.touch_demo = true
	app.start_drive({"mode":"quick","track":1,"car":1,"paint":3,"laps":2,"opponents":7})
	var drive: RaceDrive = app.drive
	drive.set_physics_process(false)
	drive.set_process(false)
	drive.phase = "Racing"
	drive.session.phase = RaceSession.Phase.RACING
	drive.session.elapsed_ticks = 1890
	drive.race_ticks = 1890
	for index in range(8):
		var state := drive.session.states[index]
		var s: float = 300 if index==drive.local_slot else 315+12*index
		var pose := drive.track.pose(s,0 if index==drive.local_slot else -2.5 if index%2==0 else 2.5)
		state.position = pose.origin+Vector3.UP*.35
		state.yaw = atan2(-pose.basis.z.x,pose.basis.z.z)
		state.velocity = state.forward()*40
		state.route_s = s
		state.last_gate = 1
	drive.camera.initialized = false
	drive._process(.016)
	drive.hud.ticks = 1890
	drive.hud.phase = "Racing"
	drive.hud.rank = 5
	drive.hud.queue_redraw()
	var display: WorldPresentation = app.presentation
	await capture("selected-80")
	assert(display.viewport.size==Vector2i(1536,864))
	for index in range(200): display.adaptive.sample(.02,.02,true)
	display.reflow()
	assert(display.adaptive.current==60 and display.viewport.size==Vector2i(1152,648))
	await capture("adaptive-60")
	var physics_space: RID = drive.world.get_world_3d().space
	var position := drive.state.position
	app.notification(MainLoop.NOTIFICATION_OS_MEMORY_WARNING)
	await capture("memory-pressure")
	assert(drive.world.get_world_3d().space==physics_space and drive.state.position==position and drive.session.elapsed_ticks==1890)
	for index in range(1200): display.adaptive.sample(.01,1.0/60,true)
	display.reflow()
	assert(display.adaptive.current==80 and app.data.settings.render_scale==80)
	await capture("restored-80")
	for index in range(30):
		await RenderingServer.frame_post_draw
		samples.append({"work_ms":display.last_work_seconds*1000,"gpu_ms":display.last_gpu_seconds*1000,"interval_ms":display.last_interval_seconds*1000})
	assert(display.measurement_enabled and Engine.physics_ticks_per_second==60)
	var result := {"renderer":"Godot 4.6.3 Compatibility","host_pixels":[1920,1080],"selected_scale":80,"adaptive_floor":60,"world_sizes":[[1536,864],[1152,648]],"hud_native_host_unchanged":true,"physics_hz":60,"active_state_and_space_preserved":true,"captures":captures,"live_timing_samples":samples,"boundary":"Actual renderer, posed eight-car scene, synthetic continuous pressure/headroom samples and injected OS memory notification. Live timings validate instrumentation only; not physical thermal, real memory exhaustion, human driving or sustained device performance acceptance."}
	var file := FileAccess.open("res://reports/m5-runtime-reference.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(result,"  "))
	file.close()
	app.queue_free()
	await create_timer(.5).timeout
	assert(AppData.remove_tree(ProjectSettings.globalize_path(folder))==OK)
	print("NATIVE_ADAPTIVE_80_60_80_HUD_MEMORY_RESOURCE_RETENTION_MEASURED_RENDERING_REFERENCE_PASS")
	quit()

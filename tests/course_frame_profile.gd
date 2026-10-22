extends SceneTree
## Spatial render sweep: repeated Far Chase views, wall-clock timings, no movie.
## Deliberately disables Retro so its lower resolution cannot hide regressions.

func _initialize() -> void: call_deferred("run")

func run() -> void:
	assert(DisplayServer.get_name()!="headless")
	Catalog.load_all()
	root.size = Vector2i(1920,1080)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var id := "pacific_summit"
	var output := "res://reports/course-frame-profile.json"
	var shadows := "low"
	var legacy := "--legacy" in OS.get_cmdline_user_args()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--track="): id = argument.trim_prefix("--track=")
		if argument.begins_with("--report="): output = argument.trim_prefix("--report=")
		if argument.begins_with("--shadows="): shadows = argument.trim_prefix("--shadows=")
	var track: TrackDefinition
	for candidate: TrackDefinition in Catalog.tracks:
		if candidate.id==id: track = candidate
	assert(track!=null)
	var world: TrackWorld = load("res://tests/summit_legacy_render.gd").new() if legacy else TrackWorld.new()
	world.build(track)
	root.add_child(world)
	var camera := ChaseCamera.new()
	camera.mode = 1
	camera.current = true
	root.add_child(camera)
	var settings := SettingsCatalog.defaults(false)
	settings.shadows = shadows
	settings.retro = false
	SettingsRuntime.apply(world,settings,false)
	Engine.max_fps = 0
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	await physics_frame
	await physics_frame
	var rows: Array[Dictionary] = []
	var state := VehicleState.new()
	for lap in range(2):
		for step in range(240):
			var s := track.length*step/240
			var pose := track.pose(s)
			state.position = pose.origin+Vector3.UP*.35
			state.yaw = atan2(-pose.basis.z.x,pose.basis.z.z)
			state.ground_normal = pose.basis.y
			state.velocity = -pose.basis.z*40
			camera.initialized = false
			var began := Time.get_ticks_usec()
			camera.follow(state,1.0/60)
			var camera_us := Time.get_ticks_usec()-began
			# Settle asynchronous submission, then measure four real rendered frames.
			for frame in range(2): await RenderingServer.frame_post_draw
			began = Time.get_ticks_usec()
			for frame in range(4): await RenderingServer.frame_post_draw
			rows.append({"lap":lap,"s":s,"u":float(track.bake.samples[track.sample_index(s)][7]),"frame_ms":(Time.get_ticks_usec()-began)/4000.0,"camera_us":camera_us,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),"primitives":Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)})
		print("COURSE_FRAME_SWEEP track=",id," lap=",lap)
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"track":id,"legacy_render":legacy,"shadows":shadows,"gpu":RenderingServer.get_video_adapter_name(),"renderer":RenderingServer.get_current_rendering_method(),"size":root.size,"rows":rows,"boundary":"Two complete 240-pose rendered Far Chase sweeps, recorded shadow preset, native 1920x1080, VSync/cap off, no Retro, no HUD/audio/vehicle simulation. Four-frame wall-clock averages after two settling frames. Spatial renderer/camera evidence on this host, not a human driving or exported-device performance guarantee."},"\t")+"\n")
	file.close()
	print("COURSE_FRAME_PROFILE_COMPLETE ",output)
	world.queue_free()
	await process_frame
	quit()

extends SceneTree
var app: Node
var captures: Array[String] = []
func _initialize() -> void: call_deferred("run")
func capture(id: String) -> void:
	for index in range(8): await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://reports/m4-hud-"+id+".png"
	assert(root.get_texture().get_image().save_png(path)==OK)
	captures.append(path)
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
	var file := FileAccess.open("res://reports/m4-hud-reference.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"renderer":"Godot 4.6.3 Compatibility","resolution":[1920,1080],"captures":captures,"boundary":"Native final-art HUD layout with posed race/lap/record states; numerical timing and real collision occlusion are separate tests. No human driving, physical device or gameplay win acceptance."},"  "))
	file.close()
	app.queue_free()
	await create_timer(.5).timeout
	assert(AppData.remove_tree(ProjectSettings.globalize_path(folder))==OK)
	print("NATIVE_HUD_LAP_DELTA_NAMEPLATES_LARGE_TEXT_CONNECTION_RECOVERY_RESULTS_REFERENCE_PASS")
	quit()

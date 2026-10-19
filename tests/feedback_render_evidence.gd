extends SceneTree
## Native presentation states are scripted; these are not driving-feel fixtures.
var app: Node
var drive: RaceDrive
var views: Array[Dictionary] = []

func _initialize() -> void: call_deferred("run")
func capture(id: String) -> void:
	for index in range(4): await process_frame
	await RenderingServer.frame_post_draw
	var path := "res://reports/m4-feedback-"+id+".png"
	root.get_texture().get_image().save_png(path)
	var counts: Dictionary = {}
	for kind: String in drive.feedback.batches: counts[kind] = drive.feedback.batches[kind].multimesh.visible_instance_count
	views.append({"id":id,"file":path,"particles":counts,"skid_strips":drive.feedback.skid_batch.multimesh.visible_instance_count,"recovery_ticks":drive.state.recovery_ticks,"car_opacity":drive.visual.opacity,"world_cover":drive.recovery_cover.color.a,"draw_calls":Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)})

func present() -> void:
	drive.camera.initialized = false # Scripted fixture placement is an intentional teleport.
	drive._process(1.0/60)
	for index in range(24): drive.camera.follow(drive.state,1.0/60)
	drive.feedback.advance(0,drive.camera.global_basis)
	drive.hud.queue_redraw()

func run() -> void:
	assert(DisplayServer.get_name()!="headless","actual graphics context required")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://reports"))
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1920,1080)
	app = load("res://game/client_app.gd").new()
	app.capture_path = "user://unused-feedback-evidence.png"
	app.capture_frame = 1000000
	root.add_child(app)
	await process_frame
	app.data.settings = SettingsCatalog.defaults(false)
	app.data.settings.effects = "full"
	app.data.settings.collision_shake = 0
	app.start_drive({"mode":"quick","track":0,"car":0,"opponents":7,"seed":72531})
	await process_frame
	drive = app.drive
	drive.set_physics_process(false)
	drive.set_process(false)
	drive.audio.set_physics_process(false)
	drive.feedback.set_physics_process(false)
	drive.feedback.set_process(false)
	drive.phase = "Racing"
	drive.race_ticks = 1800
	drive.hud.phase = "Racing"
	drive.hud.ticks = drive.race_ticks
	var s := drive.track.length*.35
	for state: VehicleState in drive.session.states:
		var pose := drive.track.pose(s-8*(state.slot-drive.local_slot),3.0 if state.slot%2 else -3.0)
		state.position = pose.origin+Vector3.UP*.35
		state.yaw = atan2(-pose.basis.z.x,pose.basis.z.z)
		state.ground_normal = pose.basis.y
		state.ghost_ticks = 0
	var own := drive.state
	var fx := drive.feedback
	fx.set_mode("full")
	for index in range(60):
		var pose := drive.track.pose(s-30+index*.5)
		own.position = pose.origin+pose.basis.y*.35
		own.yaw = atan2(-pose.basis.z.x,pose.basis.z.z)+.16
		own.ground_normal = pose.basis.y
		own.velocity = -pose.basis.z*26
		own.steer_filter = .65
		own.drift_phase = 1
		fx.add_skid(own)
		fx.spawn("smoke",own)
		fx.advance(1.0/60,drive.camera.global_basis)
	drive.frame = InputFrame.make(.65,1,0,true)
	present()
	await capture("smoke-skids-full")
	fx.particles.clear()
	for kind: String in ["dust","landing"]: fx.spawn(kind,own,fx.cap(kind,own.slot))
	fx.advance(.16,drive.camera.global_basis)
	fx.advance(0,drive.camera.global_basis)
	await capture("dust-landing-full")
	fx.particles.clear()
	fx.spawn("spark",own,12)
	fx.advance(.04,drive.camera.global_basis)
	await capture("wall-sparks")
	fx.set_mode("reduced")
	fx.spawn("smoke",own,100)
	fx.advance(.12,drive.camera.global_basis)
	await capture("reduced")
	fx.set_mode("off")
	await capture("off")
	var pose := drive.track.pose(s+400)
	own.position = pose.origin+pose.basis.y*.35
	own.yaw = atan2(-pose.basis.z.x,pose.basis.z.z)
	own.ground_normal = pose.basis.y
	own.velocity = Vector3.ZERO
	own.ghost_ticks = 180
	for ticks in [60,45,30,15,0]:
		own.recovery_ticks = ticks
		drive._process(1.0/60)
		drive.hud.queue_redraw()
		await capture("recovery-"+str(ticks))
	var file := FileAccess.open("res://reports/m4-feedback-render.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"renderer":"Godot 4.6.3 Compatibility","resolution":[1920,1080],"asset_hash":JSON.parse_string(FileAccess.get_file_as_string("res://assets/checksums.json")).asset_hash,"views":views,"boundary":"Scripted presentation-state native renders, not physical driving, thermal, gamepad motor or human feel acceptance"},"  "))
	file.close()
	app.queue_free()
	await create_timer(.5).timeout
	print("NATIVE_SMOKE_DUST_SPARK_SKID_REDUCED_OFF_RECOVERY_RENDER_PASS")
	quit()

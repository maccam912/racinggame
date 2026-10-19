extends SceneTree
func _initialize() -> void: call_deferred("run")
func tick(drive: RaceDrive, count: int) -> void:
	for index in range(count): drive._physics_process(1.0/60)
func run() -> void:
	var app: Node = load("res://game/client_app.gd").new()
	root.add_child(app)
	await process_frame
	app.data = AppData.new("user://tests/retry-"+str(Time.get_ticks_usec()),false)
	app.events.mode = "quick"
	app.events.opponents = 7
	app.events.start()
	var first_seed: int = app.pending_config.seed
	var first_roster: Array = app.drive.session.roster.duplicate(true)
	var first_world: TrackWorld = app.drive.world
	var first_uuid: String = app.drive.session.race_uuid
	assert(first_seed>=0 and first_seed<=4294967295)
	app.drive.set_physics_process(false)
	app.retry_drive()
	app.drive.set_physics_process(false)
	assert(app.drive.world==first_world and app.pending_config.seed==first_seed)
	assert(app.drive.session.roster==first_roster and app.drive.session.race_uuid!=first_uuid,"retry retains event seed/grid but starts a new result identity")
	assert(app.drive.session.phase==RaceSession.Phase.GRID)
	app.events.start()
	app.drive.set_physics_process(false)
	assert(app.pending_config.seed!=first_seed,"a new confirmed event draws a fresh seed")
	app.start_drive({"mode":"trial","track":0,"car":2,"paint":5,"opponents":0,"laps":1,"ghost":false})
	app.drive.set_physics_process(false)
	assert(app.drive.session.phase==RaceSession.Phase.GRID)
	tick(app.drive,300)
	assert(app.drive.session.phase==RaceSession.Phase.RACING and app.drive.session.elapsed_ticks==0)
	tick(app.drive,6)
	var world: TrackWorld = app.drive.world
	var collision: RID = world.get_world_3d().space
	first_uuid = app.drive.session.race_uuid
	app.drive.state.trial_valid = false
	app.drive.state.last_gate = 4
	app.drive.state.velocity = Vector3(20,0,0)
	app.drive.paused = true
	app.drive.result_sent = true
	app.drive.ghost_samples.append({"time":999.0,"position":Vector3.ZERO,"yaw":0.0})
	var started := Time.get_ticks_usec()
	app.retry_drive()
	app.drive.set_physics_process(false)
	var ready_ms := (Time.get_ticks_usec()-started)/1000.0
	assert(ready_ms<3000,"the already-loaded standing grid is restored within three seconds")
	assert(app.drive.world==world and world.get_world_3d().space==collision,"same-track retry retains the collision world")
	assert(app.drive.session.race_uuid!=first_uuid and app.drive.session.elapsed_ticks==0)
	assert(not app.drive.paused and not app.drive.result_sent and app.drive.ghost_samples.is_empty())
	assert(app.drive.state.trial_valid and app.drive.state.last_gate==-1 and app.drive.state.velocity==Vector3.ZERO)
	assert(app.drive.car==Catalog.cars[2] and app.pending_config.paint==5 and not app.pending_config.ghost)
	assert(app.drive.session.phase==RaceSession.Phase.COUNTDOWN)
	tick(app.drive,179)
	assert(app.drive.session.phase==RaceSession.Phase.COUNTDOWN and app.drive.session.elapsed_ticks==0)
	tick(app.drive,1)
	assert(app.drive.session.phase==RaceSession.Phase.RACING and app.drive.session.elapsed_ticks==0,"retry preserves all 180 countdown ticks and starts timing with physics")
	tick(app.drive,1)
	assert(app.drive.session.elapsed_ticks==1 and app.drive.ghost_samples[0].time==0.0)
	app.show_menu()
	await process_frame
	app.queue_free()
	await process_frame
	print("QUICK_FRESH_SEED_RETRY_GRID_TRIAL_WORLD_COUNTDOWN_PASS ready_ms=%.3f"%ready_ms)
	quit()

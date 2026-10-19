extends SceneTree
var app: Node
var folder: String
func _initialize() -> void: call_deferred("run")
func start(config: Dictionary) -> RaceDrive:
	app.start_drive(config)
	app.drive.set_physics_process(false)
	return app.drive
func run() -> void:
	Catalog.load_all()
	folder = "user://tests/race-archive-"+RaceSetup.uuid()
	app = load("res://game/client_app.gd").new()
	root.add_child(app)
	await process_frame
	app.data = AppData.new(folder,true)
	var roster := RaceSetup.roster(7,2,5,"Archive Driver")
	var drive := start({"mode":"quick","track":0,"car":2,"paint":5,"opponents":7,"laps":2,"difficulty":2,"contact":true,"seed":123456,"roster":roster})
	await physics_frame
	await physics_frame
	var baseline := drive.session
	for tick in range(900):
		baseline.step({baseline.human_slot:drive.demo_driver.sample(drive.state,drive.car,drive.track,drive.query)})
	var archive := RaceArchive.capture(drive)
	assert(RaceArchive.valid(archive))
	var exact_time := 12.345678912345
	baseline.states[baseline.human_slot].best_lap_time = exact_time
	archive = RaceArchive.capture(drive)
	assert(app.data.store.save_component("suspended_race",archive)==OK)
	var cold := SaveStore.new(folder).load_component("suspended_race",{},RaceArchive.valid)
	assert(RaceArchive.compatible(cold,app.data))
	var old_id := baseline.race_uuid
	drive = start(cold.config)
	assert(RaceArchive.restore(drive,cold))
	assert(drive.session.race_uuid==old_id and drive.state.best_lap_time==exact_time,"completed sub-tick lap time survives without snapshot float quantization")
	assert(drive.session.seed==baseline.seed and drive.session.elapsed_ticks==baseline.elapsed_ticks)
	for slot in range(8):
		for key: String in ["id","name","bot"]: assert(drive.session.roster[slot][key]==baseline.roster[slot][key])
		for key: String in ["car","paint"]: assert(int(drive.session.roster[slot][key])==int(baseline.roster[slot][key]))
	for slot in range(8):
		for key: String in RaceArchive.variables(baseline.states[slot]):
			if key!="events": assert(baseline.states[slot].get(key)==drive.session.states[slot].get(key),"full-precision JSON preserves every controller scalar")
	await physics_frame
	await physics_frame
	var maximum := 0.0
	for tick in range(120):
		var frame := InputFrame.make(sin(tick*.01)*.15,.7,.1 if tick>90 else 0)
		baseline.step({baseline.human_slot:frame})
		drive.session.step({drive.local_slot:frame})
		for slot in range(8):
			maximum = maxf(maximum,baseline.states[slot].position.distance_to(drive.session.states[slot].position))
			assert(baseline.states[slot].velocity.distance_to(drive.session.states[slot].velocity)<.00001)
	assert(maximum<.00001,"full bot/controller state continues through the same 120 ticks")
	assert(app.data.profile.races_completed==0 and app.data.records.times.is_empty())
	for field: String in ["states","inputs","queries","finish_drivers"]:
		var bad := cold.duplicate(true)
		bad[field].pop_back()
		assert(not RaceArchive.valid(bad))
	var bad := cold.duplicate(true)
	bad.states[0].position[0] = NAN
	assert(not RaceArchive.valid(bad))
	bad = cold.duplicate(true)
	bad.states[0].unexpected = 1
	assert(not RaceArchive.valid(bad))
	bad = cold.duplicate(true)
	bad.queries[0] = 999999
	assert(not RaceArchive.valid(bad))
	bad = cold.duplicate(true)
	bad.bots.clear()
	assert(not RaceArchive.valid(bad))
	bad = cold.duplicate(true)
	bad.config.roster[0].name = "<bad>"
	assert(not RaceArchive.valid(bad))
	var old := cold.duplicate(true)
	old.content_hash = "0".repeat(64)
	assert(RaceArchive.valid(old) and not RaceArchive.compatible(old,app.data))
	var future := {"format":2,"unknown_future_payload":true}
	assert(RaceArchive.valid(future) and not RaceArchive.compatible(future,app.data))
	for value: Dictionary in [old,future]:
		assert(app.data.store.save_component("suspended_race",value)==OK)
		var bytes := FileAccess.get_file_as_bytes(app.data.store.path("suspended_race"))
		var loaded := SaveStore.new(folder).load_component("suspended_race",{},RaceArchive.valid)
		assert(not RaceArchive.compatible(loaded,app.data) and FileAccess.get_file_as_bytes(app.data.store.path("suspended_race"))==bytes,"unsupported state stays preserved for explicit discard")
	drive = start({"mode":"school","track":0,"car":0,"paint":0,"opponents":0,"lesson":3})
	drive.lesson.stage = 1
	drive.lesson.slide_ticks = 18
	var school := RaceArchive.capture(drive)
	assert(RaceArchive.valid(school))
	drive = start(school.config)
	assert(RaceArchive.restore(drive,school) and drive.lesson.stage==1 and drive.lesson.slide_ticks==18)
	assert(app.data.start_cup()==OK)
	app.start_cup_event()
	while app.page=="loading": await process_frame
	drive = app.drive
	drive.set_physics_process(false)
	var cup := RaceArchive.capture(drive)
	assert(RaceArchive.valid(cup) and RaceArchive.compatible(cup,app.data))
	var cup_id: String = drive.session.event_uuid
	drive = start(cup.config)
	assert(RaceArchive.restore(drive,cup) and drive.session.event_uuid==cup_id and drive.session.cup_event==0)
	var completed := drive.session
	completed.phase = RaceSession.Phase.RESULTS
	completed.phase_ticks = 0
	completed.elapsed_ticks = 3600
	completed.first_finish_tick = 2700
	completed.settled_ticks = 120
	for state: VehicleState in completed.states:
		state.finished = true
		state.laps = 2
		state.finish_time = 45+state.slot
		state.best_lap_time = 22.5+state.slot
		state.distance_m = 2000+state.slot
	assert(app.data.commit_cup(completed)==OK)
	var count: int = app.data.profile.races_completed
	assert(count==1 and app.data.commit_cup(completed)==OK and app.data.profile.races_completed==count)
	assert(not RaceArchive.compatible(cup,app.data),"an already advanced Cup cannot restore its old event")
	drive = start({"mode":"trial","track":0,"car":1,"paint":2,"opponents":0,"laps":1})
	var trial := RaceArchive.capture(drive)
	assert(RaceArchive.valid(trial) and not RaceArchive.restore(drive,trial),"a cold interrupted trial must restart")
	var network := NetworkClient.new()
	drive.network = network
	assert(RaceArchive.capture(drive).is_empty(),"online state is never a local resurrection checkpoint")
	drive.network = null
	network.wire.close()
	network.free()
	baseline = null
	app.queue_free()
	await create_timer(.5).timeout
	assert(AppData.remove_tree(ProjectSettings.globalize_path(folder))==OK)
	print("FULL_PRECISION_EIGHT_CAR_BOT_PLAN_120_TICK_CONTINUATION_MAX_M=%.9f_INCOMPATIBLE_PRESERVED_TRIAL_RESTART_SCHOOL_NO_STATS_PASS"%maximum)
	quit()

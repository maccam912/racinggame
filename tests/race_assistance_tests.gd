extends SceneTree
## Actual authority ticks against baked collision; no earned results.
func _initialize() -> void: call_deferred("run")

func place(race: RaceSession, slot: int, s: float, speed: float = 25) -> void:
	var state := race.states[slot]
	ProgressTracker.place_recovery(state,race.track,s)
	state.velocity = state.forward()*speed
	race.queries[slot].hint = race.track.sample_index(state.route_s)

func run() -> void:
	Catalog.load_all()
	var scene := Node3D.new()
	root.add_child(scene)
	var track: TrackDefinition = Catalog.tracks[0]
	var collision := RouteCollision.new()
	collision.build(track)
	scene.add_child(collision)
	await physics_frame
	await physics_frame
	var race := RaceSession.new()
	race.setup(track,[0,0,0],scene.get_world_3d(),2)
	race.phase = RaceSession.Phase.RACING
	race.contact_enabled = false
	race.bots[0] = BotDriver.new()
	race.bots[2] = BotDriver.new()
	place(race,0,100)
	place(race,1,400)
	place(race,2,700)
	assert(is_equal_approx(race.rubberband_pace(race.states[0]),1.22))
	assert(is_equal_approx(race.rubberband_pace(race.states[2]),.76))
	place(race,0,390)
	assert(race.rubberband_pace(race.states[0])==1,"nearby fights have no pace change")
	place(race,0,100)
	var bot := race.states[0]
	var nearest := race.queries[0].nearest(bot.position)
	var safe: float = track.bake.ai_speeds.comet[nearest.i]
	bot.velocity = bot.forward()*safe*.9
	var neutral := BotDriver.new().sample(bot,race.cars[0],track,race.queries[0],[],1)
	var catchup := BotDriver.new().sample(bot,race.cars[0],track,race.queries[0],[],1.22)
	var ease := BotDriver.new().sample(bot,race.cars[0],track,race.queries[0],[],.76)
	assert(catchup.throttle > neutral.throttle and ease.brake > neutral.brake,"rubberband changes actual controller inputs")
	var hard := BotDriver.new()
	hard.difficulty = 2
	bot.velocity = bot.forward()*safe
	assert(hard.sample(bot,race.cars[0],track,race.queries[0],[],1.22).throttle<.001,"catchup cannot exceed baked safe corner speed")
	race.states[1].finished = true
	assert(race.rubberband_pace(bot)==1,"finished humans cannot pull the field")
	race.states[1].finished = false
	race.bots[1] = BotDriver.new()
	assert(race.rubberband_pace(bot)==1,"all-bot fields retain explicit difficulty")
	race.bots.clear()
	for mode: String in ["trial","school"]:
		race.mode = mode
		assert(not race.race_assistance() and race.rubberband_pace(bot)==1)
	race.mode = "quick"
	# Remember the order before departure, even after the field overtakes.
	for saved_rank in range(3):
		for state: VehicleState in race.states:
			state.recovery_ticks = 0
			state.recovery_hold_ticks = 0
			state.recovery_speed = 0
			state.offroad_ticks = 0
			state.outside_ticks = 0
			state.laps = 0
		place(race,0,400)
		place(race,1,420 if saved_rank>0 else 380)
		place(race,2,440 if saved_rank==2 else 360)
		race.remember_recovery_order()
		assert(race.states[0].recovery_rank==saved_rank)
		var anchor := race.states[0].recovery_progress
		race.states[0].position += track.forwards[race.queries[0].hint].cross(Vector3.UP)*30
		race.states[0].velocity = Vector3.ZERO
		race.states[0].offroad_ticks = 29
		race.step({})
		assert(race.states[0].recovery_ticks==60 and race.states[0].recovery_rank==saved_rank,"automatic rescue keeps departure order")
		place(race,1,480)
		place(race,2,450)
		for tick in range(60): race.step({})
		var order := race.standings()
		assert(absi(order.find(race.states[0])-saved_rank)<=1,"rejoin stays near saved place after moving-field fade")
		assert(race.states[0].recovery_ticks==0 and race.states[0].speed()>0,"control resumes with rolling reentry")
		assert(not race.states[0].trial_valid and not race.states[0].lap_valid)
		assert(race.states[0].distance_m<10,"teleport distance is excluded")
		assert(ProgressTracker.race_progress(race.states[0],track)>=anchor)
	# Manual recovery captures rank on the first hold, not tick 30.
	place(race,0,800,0)
	place(race,1,780,0)
	place(race,2,760,0)
	race.states[0].recovery_latched = false
	var hold := InputFrame.make()
	hold.recover = true
	race.step({0:hold})
	assert(race.states[0].recovery_rank==0)
	place(race,1,900,0)
	place(race,2,880,0)
	for tick in range(29): race.step({0:hold})
	assert(race.states[0].recovery_ticks==60 and race.states[0].recovery_rank==0)
	# Clamp at the actual finish and preserve lap count, even if rivals lap us.
	place(race,0,track.length-30)
	race.states[0].recovery_progress = track.length-30
	race.states[0].recovery_rank = 0
	race.states[1].laps = 1
	place(race,1,track.length+100)
	race.states[2].laps = 1
	place(race,2,track.length+80)
	race.rejoin_field(race.states[0],race.queries[0])
	assert(race.states[0].laps==0 and not race.states[0].finished and race.states[0].route_s<=track.length-8)
	assert(race.states[0].last_gate==track.bake.gates.size()-1)
	# Layered crossings and ramp heights use the exact collision branch.
	for route: TrackDefinition in Catalog.tracks:
		for fraction: float in [.2,.5,.73,.99]:
			var state := VehicleState.new()
			ProgressTracker.place_recovery(state,route,route.length*fraction)
			var i := route.sample_index(state.route_s)
			assert(state.position.distance_to(RouteGeometry.point(route,i,0))<3,"safe centerline follows authored layer and ramp")
			assert(absf(ProgressTracker.race_progress(state,route)-state.route_s)<.001)
	# Authority-only anchors survive a cold checkpoint without growing UDP.
	var saved := RaceArchive.pack(race.states[0])
	saved.events = []
	var restored := VehicleState.new()
	assert(RaceArchive.unpack(saved,restored))
	assert(restored.recovery_rank==race.states[0].recovery_rank and restored.recovery_progress==race.states[0].recovery_progress)
	var packet := NetCodec.encode_snapshot(race,1,Compatibility.content_hash().hex_decode())
	var decoded := NetCodec.decode_snapshot(packet,race.race_id,Compatibility.content_hash().hex_decode())
	assert(not decoded.is_empty() and decoded.states[0].position.distance_to(race.states[0].position)<.02)
	var predicted: VehicleState = decoded.states[0]
	var authoritative := race.states[0].copy()
	authoritative.recovery_ticks = 30
	predicted.recovery_ticks = 30
	assert(absf(predicted.recovery_speed-authoritative.recovery_speed)<.01)
	for tick in range(30):
		VehicleSim.step(authoritative,InputFrame.make(),race.cars[0],race.queries[0])
		VehicleSim.step(predicted,InputFrame.make(),race.cars[0],race.queries[0])
	assert(authoritative.velocity.distance_to(predicted.velocity)<.02 and predicted.speed()>0,"snapshot prediction restores the same rolling speed on release")
	# A recovering car must still drive across the finish; no clean lap record.
	race.states[0] = authoritative
	race.lap_count = 1
	for rival: VehicleState in [race.states[1],race.states[2]]: rival.dnf_reason = "Fixture ended"
	for tick in range(180):
		race.step({0:InputFrame.make(0,1)})
		if authoritative.finished: break
	assert(authoritative.finished and authoritative.laps==1 and authoritative.best_lap_time<0,"recovery retains a real finish crossing without a clean-lap award")
	print("RACE_ASSISTANCE_ACTUAL_INPUTS_MOVING_FIELD_MANUAL_AUTO_RANK_FINISH_LAYER_ARCHIVE_SNAPSHOT_PASS")
	race = null
	scene.queue_free()
	await process_frame
	quit()

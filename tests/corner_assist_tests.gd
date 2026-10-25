extends SceneTree
func _initialize() -> void: call_deferred("run")

func place(state: VehicleState, query: WorldQuery, index: int, speed: float) -> void:
	var pose := query.track.pose(query.track.distances[index])
	state.position = pose.origin+Vector3.UP*.35
	state.yaw = atan2(-pose.basis.z.x,pose.basis.z.z)
	state.velocity = state.forward()*speed
	query.hint = index

func run() -> void:
	Catalog.load_all()
	var track: TrackDefinition = Catalog.tracks[0]
	var car: CarDefinition = Catalog.cars[0]
	var query := WorldQuery.new(root.world_3d,track)
	var bend := -1
	var straight := -1
	for index in range(track.points.size()):
		var speed := float(track.bake.ai_speeds[car.id][index])
		if speed < 35: bend = index
		if speed >= car.top_speed*.94: straight = index
	assert(bend>=0 and straight>=0)
	var state := VehicleState.new()
	place(state,query,bend,70)
	var raw := InputFrame.make(.7,1,.1)
	raw.sequence = 135
	raw.tick = 246
	var helped := CornerAssist.apply(state,raw,car,query)
	assert(helped != raw and helped.steer==raw.steer and helped.sequence==135 and helped.tick==246)
	assert(helped.throttle<raw.throttle and helped.brake>raw.brake and helped.brake<=.65)
	assert(raw.throttle==1 and raw.brake==.1 and not helped.boost and not helped.recover)
	raw.brake = 1
	assert(CornerAssist.apply(state,raw,car,query).brake==1, "manual braking remains stronger")
	raw.brake = .1
	place(state,query,straight,car.top_speed)
	assert(CornerAssist.apply(state,raw,car,query)==raw, "no straight-line speed limiter")
	place(state,query,bend,10)
	assert(CornerAssist.apply(state,raw,car,query)==raw, "never brakes below the corner target")
	for key: String in ["finished","reversing"]:
		place(state,query,bend,70)
		state.set(key,true)
		assert(CornerAssist.apply(state,raw,car,query)==raw)
		state.set(key,false)
	for key: String in ["handbrake","recover","boost"]:
		raw.set(key,true)
		assert(CornerAssist.apply(state,raw,car,query)==raw)
		raw.set(key,false)
	state.grounded = false
	assert(CornerAssist.apply(state,raw,car,query)==raw)
	state.grounded = true
	state.recovery_ticks = 12
	assert(CornerAssist.apply(state,raw,car,query)==raw)
	state.recovery_ticks = 0
	state.boost_ticks = 30
	assert(CornerAssist.apply(state,raw,car,query)==raw)
	state.boost_ticks = 0
	state.dnf_reason = "Left"
	assert(CornerAssist.apply(state,raw,car,query)==raw)
	state.dnf_reason = ""
	state.yaw += PI
	assert(CornerAssist.apply(state,raw,car,query)==raw, "wrong-way control stays manual")
	place(state,query,bend,70)
	state.velocity = -state.forward()*10
	assert(CornerAssist.apply(state,raw,car,query)==raw)
	query = null
	await finishing_case()
	print("CORNER_BRAKING_INPUT_OWNERSHIP_STRAIGHTS_OVERRIDES_AND_ASSISTED_FINISH_DEADLINES_PASS")
	quit()

func finishing_case() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var road := RouteCollision.new()
	road.build(Catalog.tracks[0])
	scene.add_child(road)
	await physics_frame
	await physics_frame
	for enabled: bool in [false,true]:
		var race := RaceSession.new()
		race.setup(Catalog.tracks[0],[0,0],scene.get_world_3d(),1)
		race.mode = "quick"
		race.human_slot = 1
		race.phase = RaceSession.Phase.GRACE
		race.elapsed_ticks = 1900
		race.first_finish_tick = 100
		race.contact_enabled = false
		race.states[0].finished = true
		race.states[0].finish_time = 1
		if enabled: race.driving_assists[1] = 2
		race.step({})
		assert((race.states[1].dnf_reason=="")==enabled)
		if enabled:
			assert(race.finish_grace_limit()==7200 and race.phase==RaceSession.Phase.GRACE)
			race.states[1].finished = true
			assert(race.finish_grace_limit()==7200, "assisted finisher does not shorten other racers' deadline")
			race.states[1].finished = false
			race.driving_assists.clear()
			race.corner_braking[1] = true
			assert(race.finish_grace_limit()==7200)
			race.bots[1] = BotDriver.new()
			assert(race.finish_grace_limit()==1800, "bot-only assignments never extend the race")
			race.bots.clear()
			for mode: String in ["trial","school"]:
				race.mode = mode
				assert(race.finish_grace_limit()==1800)
			race.mode = "online"
			race.corner_braking.clear()
			race.driving_assists[1] = 1
			assert(race.finish_grace_limit()==7200, "host steering help grants the same finishing time")
			race.elapsed_ticks = 7300
			race.step({})
			assert(race.states[1].dnf_reason=="Finish grace expired" and race.phase==RaceSession.Phase.RESULTS)
			race.states[1].dnf_reason = ""
			race.phase = RaceSession.Phase.GRACE
			race.first_finish_tick = 35900
			race.elapsed_ticks = 35999
			race.step({})
			assert(race.states[1].dnf_reason=="Time limit", "the hard ten-minute bound is unchanged")
		race = null
	scene.queue_free()
	await process_frame

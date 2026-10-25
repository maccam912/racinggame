extends SceneTree
## Every car shares authority/prediction braking, including delayed replay.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	Catalog.load_all()
	var cases := 0
	for id: String in ["palm_bay","festival_speedway","temple_coast"]:
		var track: TrackDefinition = Catalog.tracks.filter(func(t: TrackDefinition) -> bool: return t.id==id)[0]
		var collision := RouteCollision.new()
		collision.build(track)
		root.add_child(collision)
		await physics_frame
		await physics_frame
		for car_index in range(Catalog.cars.size()):
			var race := RaceSession.new()
			race.setup(track,[car_index],root.world_3d,1)
			race.phase = RaceSession.Phase.RACING
			race.driving_assists[0] = DrivingAssist.RELAXED
			var car := race.cars[0]
			var bend := -1
			for i in range(track.points.size()):
				if float(track.bake.ai_speeds[car.id][i])<35 and track.distances[i]>150 and track.distances[i]<track.length*.5:
					bend = i
					break
			assert(bend>=0)
			ProgressTracker.place_recovery(race.states[0],track,track.distances[bend])
			race.states[0].recovery_ticks = 0
			race.states[0].velocity = race.states[0].forward()*65
			race.queries[0].hint = bend
			var prediction := PredictionBuffer.new()
			prediction.car = car
			prediction.track = track
			prediction.lap_count = 1
			prediction.query = WorldQuery.new(root.world_3d,track,track.distances[bend])
			prediction.state = race.states[0].copy()
			prediction.driving_assist = DrivingAssist.RELAXED
			var snapshot: VehicleState
			var braking_ticks := 0
			for tick in range(1,181):
				var frame := InputFrame.make(.6 if tick<90 else -.3,1)
				frame.sequence = tick
				frame.tick = tick-InputBuffer.DELAY_TICKS
				frame.boost = tick==120
				frame.handbrake = tick>=140 and tick<150
				race.step({0:frame})
				prediction.advance(frame)
				if race.inputs[0].brake>0: braking_ticks += 1
				assert(frame.throttle==1 and frame.brake==0,"history retains original controls")
				assert(prediction.state.position.distance_to(race.states[0].position)<.00001,"%s %s tick=%d delta=%f hints=%d/%d"%[id,car.id,tick,prediction.state.position.distance_to(race.states[0].position),prediction.query.hint,race.queries[0].hint])
				assert(prediction.state.velocity.distance_to(race.states[0].velocity)<.00001)
				assert(prediction.state.boost_charges==race.states[0].boost_charges)
				if tick==60: snapshot = race.states[0].copy()
			assert(braking_ticks>0,"every car actually exercises bounded braking")
			prediction.state.position += Vector3(1,0,1)
			prediction.reconcile(snapshot,60,60)
			assert(prediction.history.size()==120)
			assert(prediction.state.position.distance_to(race.states[0].position)<.00001,"delayed snapshot replays original inputs once")
			assert(prediction.state.velocity.distance_to(race.states[0].velocity)<.00001)
			cases += 1
			prediction = null
			race = null
		collision.queue_free()
		await physics_frame
		await physics_frame
	print("ONLINE_CORNER_BRAKING_ALL_CARS_AUTHORITY_PREDICTION_DELAYED_REPLAY_PASS cases=",cases)
	quit()

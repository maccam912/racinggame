extends SceneTree
## Actual standing-start trials, human-slot legal input frames, no state resets.

func _initialize() -> void: call_deferred("run")


func run() -> void:
	Catalog.load_all()
	var cases: Array[Dictionary] = []
	var failures: Array[String] = []
	var path := "res://reports/m6-trial-gold.json"
	var filter := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--report="): path = argument.trim_prefix("--report=")
		elif argument.begins_with("--track="): filter = argument.trim_prefix("--track=")
	for track: TrackDefinition in Catalog.tracks:
		if not filter.is_empty() and filter!=track.id: continue
		var scene := Node3D.new()
		root.add_child(scene)
		var collision := RouteCollision.new()
		collision.build(track)
		scene.add_child(collision)
		await physics_frame
		await physics_frame
		for car_index in range(Catalog.cars.size()):
			var race := RaceSession.new()
			var indices: Array[int] = [car_index]
			race.setup(track,indices,scene.get_world_3d(),1)
			race.mode = "trial"
			race.human_slot = 0
			race.contact_enabled = false
			var driver := BotDriver.new()
			driver.difficulty = 1
			var state: VehicleState = race.states[0]
			var car: CarDefinition = race.cars[0]
			var input_hash := HashingContext.new()
			assert(input_hash.start(HashingContext.HASH_SHA256)==OK)
			var recoveries := 0
			var max_speed: float = 0
			var launches := 0
			var landings := 0
			var ticks := 0
			for tick in range(36300):
				var frame := driver.sample(state,car,track,race.queries[0])
				input_hash.update(var_to_bytes([frame.steer,frame.throttle,frame.brake,frame.handbrake,frame.recover]))
				race.step({0:frame})
				ticks += 1
				max_speed = maxf(max_speed,state.speed())
				if "recovery" in state.events: recoveries += 1
				if "jump" in state.events: launches += 1
				if "land" in state.events: landings += 1
				if race.phase==RaceSession.Phase.RESULTS: break
			var threshold := Medals.thresholds(track.length)[0]
			var medal := Medals.award(track.length,state.finish_time,state.finished and state.trial_valid)
			var passed := race.phase==RaceSession.Phase.RESULTS and state.finished and state.trial_valid and state.dnf_reason.is_empty() and recoveries==0 and medal==0
			if not passed: failures.append(track.id+"/"+car.id)
			cases.append({"track":track.id,"car":car.id,"passed":passed,"finished":state.finished,"trial_valid":state.trial_valid,
				"time_seconds":state.finish_time,"gold_seconds":threshold,"gold_margin_seconds":threshold-state.finish_time,
				"medal":medal,"dnf":state.dnf_reason,"recoveries":recoveries,"launches":launches,"landings":landings,
				"max_horizontal_speed_mps":max_speed,"ticks_including_grid_countdown_settle":ticks,"input_sha256":input_hash.finish().hex_encode()})
			print("TRIAL_GOLD track=%s car=%s valid=%s seconds=%.6f gold=%.1f recoveries=%d"%[track.id,car.id,state.trial_valid,state.finish_time,threshold,recoveries])
			race = null
			await process_frame
		scene.queue_free()
		await process_frame
	assert(cases.size()==(Catalog.tracks.size()*Catalog.cars.size() if filter.is_empty() else 4))
	var file := FileAccess.open(path,FileAccess.WRITE)
	assert(file!=null)
	file.store_string(JSON.stringify({"passed":failures.is_empty(),"content_hash":Compatibility.content_hash(),"cases":cases,"failures":failures,
		"boundary":"Real standing-start shared RaceSession, canonical route collision and 60 Hz legal input frames from the unmodified Medium reference driver in the human slot. No teleport, recovery, modified car/track, opponents or saved human record. Numeric Gold reachability; not human skill/difficulty, rendered performance or physical input acceptance."},"\t")+"\n")
	file.close()
	if failures.is_empty(): print("ALL_CAR_COURSE_VALID_STANDING_START_GOLD_TARGETS_PASS cases=",cases.size())
	else: push_error("Gold reachability failures: "+str(failures))
	quit(0 if failures.is_empty() else 1)

extends SceneTree
## Delayed digital-input proxy, not a claim about human skill or comfort.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	Catalog.load_all()
	var results: Array[Dictionary] = []
	for track_index in [0,29,24]:
		var track: TrackDefinition = Catalog.tracks[track_index]
		var scene := Node3D.new()
		root.add_child(scene)
		var collision := RouteCollision.new()
		collision.build(track)
		scene.add_child(collision)
		await physics_frame
		await physics_frame
		for enabled: bool in [false,true]:
			var race := RaceSession.new()
			race.setup(track,[0],scene.get_world_3d(),1)
			race.mode = "quick"
			race.human_slot = 0
			race.driving_assists[0] = 2
			race.corner_braking[0] = enabled
			var pilot := BotDriver.new()
			var frame := InputFrame.make(0,1)
			var offroad := 0
			var recoveries := 0
			var roadside := 0
			var wall := 0
			var ticks := 0
			for tick in range(18000):
				var state: VehicleState = race.states[0]
				var desired := pilot.sample(state,race.cars[0],track,race.queries[0])
				if tick%36 == 0:
					frame = InputFrame.make(signf(desired.steer) if absf(desired.steer)>.18 else 0,1)
				var input := frame
				race.step({0:input})
				if state.offroad_ticks>0: offroad += 1
				if state.outside_ticks>0: roadside += 1
				if state.wall_contact: wall += 1
				if "recovery" in state.events: recoveries += 1
				ticks = tick
				if state.finished: break
			var row := {"track":track.id,"enabled":enabled,"roadside_ticks":roadside,"wall_ticks":wall,"offroad_ticks":offroad,"recoveries":recoveries,"finished":race.states[0].finished,"progress":ProgressTracker.race_progress(race.states[0],track),"ticks":ticks}
			print(row)
			results.append(row)
			race = null
		scene.queue_free()
		await process_frame
	for i in range(0,results.size(),2):
		var standard: Dictionary = results[i]
		var assisted: Dictionary = results[i+1]
		assert(standard.finished and assisted.finished and assisted.recoveries==0)
		assert(assisted.wall_ticks < standard.wall_ticks, "held digital steering spends less time against walls: "+str(standard.track))
		assert(assisted.ticks < standard.ticks*1.5, "braking aid must still make useful progress")
	FileAccess.open("res://reports/corner-driving20.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":true,"cases":results,"boundary":"One Comet on three actual roads, full accelerator, steering quantized to left/neutral/right and held for 0.6 seconds. Strong steering help in both runs. No manual braking or recovery. This proxy does not establish physical-device or human driving feel."},"\t"))
	print("DELAYED_DIGITAL_DRIVER_ALL_FINISHES_FEWER_WALL_TICKS_NO_RECOVERY_PASS")
	quit()

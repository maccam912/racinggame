extends SceneTree
## Actual road probes, loose-surface handling and every shipped launch ramp.

func _initialize() -> void: call_deferred("run")

func run() -> void:
	Catalog.load_all()
	var records: Array[Dictionary] = []
	for track: TrackDefinition in Catalog.tracks:
		var scene := Node3D.new()
		var collision := RouteCollision.new()
		collision.build(track)
		scene.add_child(collision)
		root.add_child(scene)
		await physics_frame
		await physics_frame
		var query := WorldQuery.new(scene.get_world_3d(),track)
		for u: float in [.10,.35,.60,.85]:
			var s := CourseArt.original_s(track,u)
			var state := at(track,s)
			query.hint = track.sample_index(s)
			var ground := query.ground(state)
			assert(ground.supported and ground.surface==track.road_surface(),"the visible main road supplies its authored traction")
		var consumed := -1
		for marker_index in range(track.definition.ramp_markers.size()):
			var marker: float = track.definition.ramp_markers[marker_index]
			var crest := fposmod(marker*track.length-track.start_sample*2,track.length)
			var state := at(track,crest-9)
			state.jump_lap = consumed
			state.velocity = track.forwards[track.sample_index(crest-9)]*60
			state.route_s = crest-9
			query.hint = track.sample_index(crest-9)
			var bot := BotDriver.new()
			bot.difficulty = 2
			var launches := 0
			var landings := 0
			var air_ticks := 0
			for tick in range(90):
				VehicleSim.step(state,bot.sample(state,Catalog.cars[0],track,query),Catalog.cars[0],query)
				ProgressTracker.safety(state,InputFrame.make(),track,query)
				if "jump" in state.events: launches += 1
				if "land" in state.events: landings += 1
				if not state.grounded: air_ticks += 1
			assert(launches==1 and landings==1 and air_ticks>=23 and state.grounded,"every authored ramp launches and lands on actual course collision: "+track.id+" "+str(marker_index))
			consumed = state.jump_lap
			assert((consumed & (1<<marker_index))!=0,"each ramp consumes its own bit without suppressing the next ramp")
			# Recrossing an already consumed ramp in this lap cannot farm launches.
			state = at(track,crest+2.1)
			state.velocity = track.forwards[track.sample_index(crest)]*60
			state.route_s = crest-1
			state.jump_lap = consumed
			query.hint = track.sample_index(crest)
			ProgressTracker.safety(state,InputFrame.make(),track,query)
			assert(not "jump" in state.events)
			state.laps = 1
			state.route_s = crest-1
			ProgressTracker.safety(state,InputFrame.make(),track,query)
			assert("jump" in state.events,"the next lap re-arms every ramp")
			records.append({"track":track.id,"ramp":marker_index,"air_seconds":air_ticks/60.0,"launches":launches,"landings":landings})
		query = null
		scene.queue_free()
		await process_frame
	var speeds: Dictionary = {}
	var sideways: Dictionary = {}
	for surface: String in ["asphalt","dirt"]:
		var query := FlatQuery.new()
		query.surface = surface
		var state := VehicleState.new()
		state.position.y = .35
		state.velocity = Vector3(20,0,-40)
		for tick in range(10): VehicleSim.step(state,InputFrame.make(0,1),Catalog.cars[0],query)
		speeds[surface] = -state.velocity.z
		sideways[surface] = absf(state.velocity.x)
	assert(speeds.dirt<speeds.asphalt and sideways.dirt>sideways.asphalt,"dirt has measurable drag and looser grip")
	DirAccess.make_dir_recursive_absolute("res://reports")
	var file := FileAccess.open("res://reports/arcade-track-physics.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":true,"content_hash":Compatibility.content_hash(),"ramps":records,"surface_forward_speed":speeds,"surface_remaining_lateral_speed":sideways},"\t")+"\n")
	file.close()
	print("TEN_COURSE_MAIN_SURFACES_ALL_RAMPS_REARM_LAND_DIRT_TRACTION_PASS ramps=",records.size())
	quit()


func at(track: TrackDefinition, s: float) -> VehicleState:
	var state := VehicleState.new()
	var index := track.sample_index(s)
	state.position = RouteGeometry.point(track,index,0)+Vector3.UP*.35
	state.yaw = atan2(track.forwards[index].x,-track.forwards[index].z)
	return state

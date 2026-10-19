extends SceneTree

var failures: int = 0


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	Catalog.load_all()
	var evidence: Array[Dictionary] = []
	for slope: float in [-.15,0.0,.15]:
		var track := fixture(slope)
		var scale := sqrt(1+slope*slope)
		var scene := Node3D.new()
		root.add_child(scene)
		var collision := RouteCollision.new()
		collision.build(track)
		scene.add_child(collision)
		await physics_frame
		await physics_frame
		for speed: float in [30.0,45.0,60.0,80.0,95.0]:
			var state := VehicleState.new()
			state.position = Vector3(0,200+490*slope+.55,-490)
			# Coasting onto the uphill ramp loses speed. Seed a small explicit
			# approach margin, recording the actual post-kick horizontal speed.
			state.velocity = Vector3(0,slope,-1)*(speed+2.0)
			state.last_gate = 4
			var query := WorldQuery.new(scene.get_world_3d(),track,490*scale)
			var jumps := 0
			var air_ticks := 0
			var landings := 0
			var recoveries := 0
			var takeoff_speed := -1.0
			for tick in range(240):
				VehicleSim.step(state,InputFrame.make(),Catalog.cars[1],query)
				ProgressTracker.safety(state,InputFrame.make(),track,query)
				if "jump" in state.events:
					jumps+=1
					takeoff_speed = state.speed()
				if "land" in state.events: landings+=1
				if "recovery" in state.events: recoveries+=1
				if not state.grounded: air_ticks+=1
			var floor_height := 200-state.position.z*slope
			var passed := jumps==1 and landings==1 and recoveries==0 and air_ticks>=23 and air_ticks<=75 and state.grounded and state.position.y>=floor_height+.30
			evidence.append({"nominal_speed_band_mps":speed,"initial_horizontal_mps":speed+2,"post_kick_horizontal_mps":takeoff_speed,"grade":slope,"launches":jumps,"landings":landings,"recoveries":recoveries,"air_seconds":air_ticks/60.0,"passed":passed})
			if not passed:
				push_error("TEST FAIL: jump %.0f m/s grade %.2f: launches=%d landings=%d air=%d"%[speed,slope,jumps,landings,air_ticks])
				failures+=1
			print("Jump fixture %.0f m/s grade %.2f: %d launch, %d landing, %.3f s airborne"%[speed,slope,jumps,landings,air_ticks/60.0])
			query = null
		scene.queue_free()
		await process_frame
	DirAccess.make_dir_recursive_absolute("res://reports")
	var file := FileAccess.open("res://reports/content5-jumps.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failures==0,"boundary":"Actual 3D collision/probe straight-ramp fixtures, not human driving or a completed course","cases":evidence},"\t")+"\n")
	file.close()
	quit(1 if failures else 0)


func fixture(slope: float = 0) -> TrackDefinition:
	var scale := sqrt(1+slope*slope)
	var track := TrackDefinition.new()
	track.id = "jump_fixture"
	track.length = 1000*scale
	track.definition = {"surface":"asphalt", "ramp_markers":[.5]}
	track.bake = {"samples":[], "gates":[]}
	for i in range(501):
		var s := i * 2.0
		var relative := (s-500)*scale
		var height := 1.2 * (relative + 12) / 12 if relative >= -12 and relative < 0 else 1.2 * (1 - smoothstep(0, 50, relative)) if relative >= 0 and relative < 50 else 0.0
		track.points.append(Vector3(0,200+s*slope,-s))
		track.forwards.append(Vector3(0,slope,-1).normalized())
		track.distances.append(s*scale)
		track.bake.samples.append([0,200+s*slope,-s,0,slope/scale,-1/scale,0,s/1000,20,0,height])
	for s in range(0, 1000, 100):
		track.bake.gates.append({"s":s*scale,"position":[0,200+s*slope,-s],"forward":[0,slope/scale,-1/scale],"recovery":[0,200+(s-6)*slope,-s+6]})
	return track

extends SceneTree
## All three Summit ramps, three approach lines and all four capped car types.


func _initialize() -> void: call_deferred("run")


func run() -> void:
	Catalog.load_all()
	var track: TrackDefinition = Catalog.tracks[5]
	var scene := Node3D.new()
	root.add_child(scene)
	var collision := RouteCollision.new()
	collision.build(track)
	scene.add_child(collision)
	await physics_frame
	await physics_frame
	var cases: Array[Dictionary] = []
	for marker: float in track.definition.ramp_markers:
		var crest := fposmod(marker*track.length-track.start_sample*2,track.length)
		for car: CarDefinition in Catalog.cars:
			for speed: float in [30.0,45.0,60.0,80.0,95.0]:
				for lateral: float in [-6.0,0.0,6.0]:
					var start := crest-6
					var pose := track.pose(start,lateral)
					var state := VehicleState.new()
					state.position = pose.origin+Vector3.UP*.35
					state.position.y = RouteGeometry.point(track,track.sample_index(start),lateral).y+.35
					state.velocity = -pose.basis.z*(speed+2)
					state.yaw = atan2(-pose.basis.z.x,pose.basis.z.z)
					state.route_s = start
					var query := WorldQuery.new(scene.get_world_3d(),track,start)
					var launched := false
					var landed := false
					var recoveries := 0
					var air := 0
					var takeoff_speed := -1.0
					for tick in range(180):
						VehicleSim.step(state,InputFrame.make(0,1,0),car,query)
						ProgressTracker.safety(state,InputFrame.make(),track,query)
						if state.events.has("jump"):
							launched = true
							takeoff_speed = state.speed()
						if state.events.has("recovery"): recoveries+=1
						if launched and not state.grounded: air+=1
						if launched and state.events.has("land"):
							landed = true
							break
					var near := query.nearest(state.position)
					var half: float = track.bake.samples[int(near.i)][8]*.5
					assert(launched and landed and recoveries==0 and air>=23 and air<=65,"Summit ramp car=%s speed=%s lateral=%s launch=%s land=%s recoveries=%s air=%s"%[car.id,speed,lateral,launched,landed,recoveries,air])
					assert(absf(near.lateral)<half+2,"even the outside high-speed approach lands with clearance from the wall")
					cases.append({"ramp_marker":marker,"car":car.id,"nominal_speed_band_mps":speed,"post_kick_horizontal_mps":takeoff_speed,"initial_lateral_m":lateral,"land_lateral_m":near.lateral,"launch":launched,"land":landed,"recoveries":recoveries,"air_seconds":air/60.0})
					query = null
	DirAccess.make_dir_recursive_absolute("res://reports")
	var file := FileAccess.open("res://reports/content5-summit-landings.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":true,"content_hash":Compatibility.content_hash(),"cases":cases,"boundary":"Full throttle, tangent-aligned straight takeoff, actual course collision; car caps remain active. Nominal 95 m/s is an approach band, not an assertion that every car reaches that speed."},"\t")+"\n")
	file.close()
	scene.queue_free()
	await process_frame
	print("SUMMIT_180_REAL_COURSE_LEFT_CENTER_RIGHT_ALL_CARS_30_TO_95_APPROACH_BANDS_SAFE_LANDINGS_PASS")
	quit()

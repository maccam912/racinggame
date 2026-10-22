extends SceneTree
## Real fast-car laps with all six chase/hood/look-back presentation paths.
func _initialize() -> void: call_deferred("run")

func run() -> void:
	Catalog.load_all()
	root.size = Vector2i(1280,720)
	var cases: Array[Dictionary] = []
	var failures: Array[Dictionary] = []
	var selected := ""
	var output := "res://reports/m6-course-cameras.json"
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--track="): selected = argument.trim_prefix("--track=")
		elif argument.begins_with("--report="): output = argument.trim_prefix("--report=")
	var sphere := SphereShape3D.new()
	sphere.radius = .23 # 2 cm tolerance inside the production 25 cm cast sphere.
	for track: TrackDefinition in Catalog.tracks:
		if not selected.is_empty() and track.id!=selected: continue
		var scene := Node3D.new()
		root.add_child(scene)
		var world := TrackWorld.new()
		world.build(track)
		assert(not world.terrain_grid.is_empty(),"Camera clearance must use the real exported terrain")
		scene.add_child(world)
		await physics_frame
		await physics_frame
		var race := RaceSession.new()
		var indices: Array[int] = [1]
		race.setup(track,indices,scene.get_world_3d(),1)
		race.mode = "trial"
		race.human_slot = 0
		race.contact_enabled = false
		var driver := BotDriver.new()
		driver.difficulty = 1
		var visual := CarVisual.new()
		visual.build(Catalog.paints[0],"needle")
		scene.add_child(visual)
		var terrain_query := WorldQuery.new(scene.get_world_3d(),track)
		var cameras: Array[ChaseCamera] = []
		var rows: Array[Dictionary] = []
		for mode in range(3):
			for rear in range(2):
				var camera := ChaseCamera.new()
				camera.mode = mode
				camera.hood_profiles = visual.hood_profiles
				scene.add_child(camera)
				cameras.append(camera)
				rows.append({"mode":mode,"look_phase":rear,"samples":0,"terrain_samples":0,"overlaps":0,"terrain_clips":0,"min_terrain_clearance_m":INF,"max_distance_m":0.0,"max_camera_step_m":0.0})
		var state: VehicleState = race.states[0]
		var previous: Array[Vector3] = []
		previous.resize(6)
		var recoveries := 0
		var max_speed := 0.0
		for tick in range(36300):
			race.step({0:driver.sample(state,race.cars[0],track,race.queries[0])})
			if "recovery" in state.events: recoveries += 1
			max_speed = maxf(max_speed,state.speed())
			for index in range(6):
				var camera: ChaseCamera = cameras[index]
				var look_back := (tick/240+int(rows[index].look_phase))%2==1
				camera.follow(state,1.0/60,look_back)
				rows[index].max_distance_m = maxf(float(rows[index].max_distance_m),camera.position.distance_to(state.position))
				if tick>0: rows[index].max_camera_step_m = maxf(float(rows[index].max_camera_step_m),camera.position.distance_to(previous[index]))
				previous[index] = camera.position
				if tick%6!=0 or race.phase not in [RaceSession.Phase.RACING,RaceSession.Phase.GRACE]: continue
				var query := PhysicsShapeQueryParameters3D.new()
				query.shape = sphere
				query.transform.origin = camera.position
				query.collision_mask = 3
				query.margin = 0
				var hits := scene.get_world_3d().direct_space_state.intersect_shape(query,1)
				terrain_query.hint = race.queries[0].hint
				var nearest := terrain_query.nearest(camera.position)
				var ground_y := CourseArt.height_from_grid(world.terrain_grid,camera.position,-INF)
				var verge_y := world.verge_height(nearest.s,nearest.lateral,camera.position)
				var clearance := camera.position.y-maxf(ground_y,verge_y)
				rows[index].samples += 1
				if is_finite(ground_y): rows[index].terrain_samples += 1
				rows[index].min_terrain_clearance_m = minf(float(rows[index].min_terrain_clearance_m),clearance)
				if not hits.is_empty(): rows[index].overlaps += 1
				if clearance<.15: rows[index].terrain_clips += 1
				if (not hits.is_empty() or clearance<.15) and failures.size()<100:
					failures.append({"track":track.id,"mode":camera.mode,"look_back":look_back,"tick":tick,"camera":camera.position,"vehicle":state.position,"terrain_clearance":clearance,"static_overlap":not hits.is_empty(),"boom_fraction":camera.boom_fraction})
			if race.phase==RaceSession.Phase.RESULTS: break
		var passed := state.finished and state.trial_valid and state.dnf_reason.is_empty() and recoveries==0 and rows.all(func(row: Dictionary) -> bool: return row.samples>400 and row.terrain_samples==row.samples and row.overlaps==0 and row.terrain_clips==0)
		cases.append({"track":track.id,"car":"needle","passed":passed,"time_seconds":state.finish_time,"recoveries":recoveries,"max_horizontal_speed_mps":max_speed,"cameras":rows})
		print("COURSE_CAMERAS ",track.id," passed=",passed," samples=",rows[0].samples)
		race = null
		terrain_query = null
		cameras.clear()
		scene.queue_free()
		await process_frame
	var passed := cases.all(func(row: Dictionary) -> bool: return row.passed)
	assert(cases.size()==(Catalog.tracks.size() if selected.is_empty() else 1))
	var file := FileAccess.open(output,FileAccess.WRITE)
	assert(file!=null)
	file.store_string(JSON.stringify({"passed":passed,"content_hash":Compatibility.content_hash(),"cases":cases,"failures":failures,
		"boundary":"Six real standing-start Needle laps, ordinary Medium inputs, full static world/camera bounds and actual exported cosmetic terrain triangles. All three cameras with alternating four-second look-back phases, 60 Hz updates and 10 Hz clearance samples. No synthetic vehicle poses or saved records. Numeric camera/static-clearance coverage; not human preference, rendered occlusion, every off-road pose or live frame timing."},"\t")+"\n")
	file.close()
	if passed: print("SELECTED_COURSES_NEAR_FAR_HOOD_LOOKBACK_STATIC_TERRAIN_CLEAR_PASS")
	else: print("TEST FAIL: course-camera clearance; inspect raw report")
	quit(0 if passed else 1)

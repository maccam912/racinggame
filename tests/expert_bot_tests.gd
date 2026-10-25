extends SceneTree
## Expert plans faster inputs, anticipates braking, and uses the shared drift.
func _initialize() -> void: call_deferred("run")

func run() -> void:
	Catalog.load_all()
	var scene := Node3D.new()
	root.add_child(scene)
	var track: TrackDefinition = Catalog.tracks[0]
	var car: CarDefinition = Catalog.cars[0]
	var collision := RouteCollision.new()
	collision.build(track)
	scene.add_child(collision)
	await physics_frame
	await physics_frame
	var query := WorldQuery.new(scene.get_world_3d(), track)
	var expert := BotDriver.new()
	expert.difficulty = BotDriver.EXPERT
	assert(RaceArchive.valid_bot(expert))
	var faster := 0
	var braking := 0
	var controlled_slides := 0
	for i in range(0, track.points.size(), 10):
		var s := float(track.distances[i])
		var safe: float = track.bake.ai_speeds[car.id][i]
		var target := expert.expert_speed(car, track, s, 1)
		assert(target <= car.top_speed * .99 + .001)
		assert(expert.expert_speed(car, track, s, 1.22) >= target)
		if target > safe * 1.1: faster += 1
		var future_s := s + 80
		var future: float = track.bake.ai_speeds[car.id][track.sample_index(future_s)]
		assert(target * target <= pow(minf(car.top_speed * .99, future * 1.42), 2) + 24 * 80 + .01, "brake early enough for the upcoming corner")
		if target < car.top_speed * .85: braking += 1
		var state := VehicleState.new()
		ProgressTracker.place_recovery(state, track, s)
		state.velocity = state.forward() * 35
		query.hint = i
		expert.planning_ticks = 0
		var frame := expert.sample(state, car, track, query)
		assert(expert.planning_ticks == 1 and RaceArchive.valid_input(frame))
		if frame.handbrake:
			controlled_slides += 1
			var rival := state.copy()
			rival.position += state.forward() * 6
			expert.planning_ticks = 0
			assert(not expert.sample(state, car, track, query, [rival]).handbrake, "avoid deliberate slides in nearby traffic")
	assert(faster > 10 and braking > 10 and controlled_slides > 0, "Expert must use its pace, braking and drift plans on a shipped route")
	# Ramp approaches retain the authored launch speed.
	for route: TrackDefinition in Catalog.tracks:
		for i in range(route.points.size()):
			if float(route.bake.samples[i][10]) <= .01: continue
			assert(expert.expert_speed(car, route, float(route.distances[i]), 1.22) <= float(route.bake.ai_speeds[car.id][i]) + .001)
			break
	query = null
	scene.queue_free()
	await process_frame
	print("EXPERT_PACE_BRAKING_PREVIEW_DRIFT_TRAFFIC_RAMPS_AND_ARCHIVE_VALIDATION_PASS")
	quit()

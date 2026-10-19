extends SceneTree

var failures: int = 0


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	Catalog.load_all()
	var track := fixture()
	var scene := Node3D.new()
	root.add_child(scene)
	var collision := RouteCollision.new()
	collision.build(track)
	scene.add_child(collision)
	await physics_frame
	await physics_frame
	for speed: float in [30.0, 45.0, 60.0]:
		var state := VehicleState.new()
		state.position = Vector3(0, .45, -490)
		state.velocity = Vector3(0, 0, -(speed + .4))
		state.last_gate = 4
		var query := WorldQuery.new(scene.get_world_3d(), track, 490)
		var jumps := 0
		var air_ticks := 0
		var landings := 0
		for tick in range(180):
			var frame := InputFrame.make()
			VehicleSim.step(state, frame, Catalog.cars[1], query)
			ProgressTracker.safety(state, frame, track, query)
			if "jump" in state.events:
				jumps += 1
			if "land" in state.events:
				landings += 1
			if not state.grounded:
				air_ticks += 1
		if jumps != 1 or landings != 1 or air_ticks < 11 or air_ticks > 40 or not state.grounded or state.position.y < .3:
			push_error("TEST FAIL: jump at %.0f m/s: launches=%d landings=%d air=%d" % [speed, jumps, landings, air_ticks])
			failures += 1
		print("Jump fixture %.0f m/s: %d launch, %d landing, %.3f s airborne" % [speed, jumps, landings, air_ticks / 60.0])
		query = null
	scene.queue_free()
	await process_frame
	quit(1 if failures else 0)


func fixture() -> TrackDefinition:
	var track := TrackDefinition.new()
	track.id = "jump_fixture"
	track.length = 1000
	track.definition = {"surface":"asphalt", "ramp_markers":[.5]}
	track.bake = {"samples":[], "gates":[]}
	for i in range(501):
		var s := i * 2.0
		var relative := s - 500
		var height := .6 * (relative + 12) / 12 if relative >= -12 and relative < 0 else .6 * (1 - smoothstep(0, 22, relative)) if relative >= 0 and relative < 22 else 0.0
		track.points.append(Vector3(0, 0, -s))
		track.forwards.append(Vector3.FORWARD)
		track.distances.append(s)
		track.bake.samples.append([0, 0, -s, 0, 0, -1, 0, s / 1000, 20, 0, height])
	for s in range(0, 1000, 100):
		track.bake.gates.append({"s":s, "position":[0, 0, -s], "forward":[0, 0, -1], "recovery":[0, 0, -s + 6]})
	return track

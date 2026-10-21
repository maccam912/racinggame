extends SceneTree

var failures: int = 0


func check(condition: bool, message: String) -> void:
	if not condition:
		push_error("TEST FAIL: " + message)
		failures += 1


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	Catalog.load_all()
	var buffer := RemoteBuffer.new()
	var moving := VehicleState.new()
	moving.velocity = Vector3(0, 0, -40)
	buffer.push(100, [moving])
	check(buffer.predict(0, 106).position.distance_to(Vector3(0, 0, -4)) < .001, "100 ms old car advances to current time, with no render delay")
	check(buffer.predict(0, 1000).position.distance_to(Vector3(0, 0, -6)) < .001, "prediction stops at 150 ms even during a long outage")
	check(not buffer.contact_fresh(110) and buffer.contact_fresh(109), "frozen stale cars cannot produce speculative hits")
	check(moving.position == Vector3.ZERO, "forecasting never mutates authoritative snapshots")
	var expected_now := Vector3(0, 0, -6) # 100 ms transit + 50 ms input lead.
	check(buffer.predict(0, 109).position.distance_to(expected_now) < .001 and buffer.sample(0, 106).position.distance_to(expected_now) > 5.9, "latency estimate removes six metres of old buffered-time targeting error at 40 m/s")
	var curve := RemoteBuffer.new()
	var turning := moving.copy()
	turning.yaw_rate = 1.0
	curve.push(100, [turning])
	var corner := curve.predict(0, 109)
	check(corner.position.x > .4 and corner.velocity.x > 5 and absf(corner.yaw - .15) < .001, "turning forecasts bend velocity with yaw instead of sliding straight ahead")
	var recovered := moving.copy()
	recovered.position.x = 100
	recovered.recovery_ticks = 30
	buffer.push(103, [recovered])
	check(buffer.predict(0, 102).position == moving.position and buffer.predict(0, 106).position == recovered.position, "recovery never interpolates through the track or coasts away from the rescue pose")
	buffer.clear()
	check(buffer.predict(0, 104) == null and buffer.forecasts.is_empty() and not buffer.contact_fresh(104), "new race/reconnect clears samples and forecast cache together")
	await world_cases()
	await process_frame
	print("CLIENT_PREDICTION_TIME_CONTACT_REPLAY_BOTH_SLOTS_STALE_GHOST_RECOVERY_WALL_PASS failures=%d" % failures)
	quit(1 if failures else 0)


func world_cases() -> void:
	var buffer := RemoteBuffer.new()
	var scene := Node3D.new()
	root.add_child(scene)
	var collision := RouteCollision.new()
	collision.build(Catalog.tracks[0])
	scene.add_child(collision)
	await physics_frame
	await physics_frame
	var race := RaceSession.new()
	race.setup(Catalog.tracks[0], [0, 0], scene.get_world_3d(), 2)
	var pose := race.track.pose(30)
	var right := pose.basis.x
	for index in range(2):
		var state := race.states[index]
		state.position = pose.origin + Vector3.UP * .35 + right * (-.8 if index == 0 else .8)
		state.yaw = atan2(-pose.basis.z.x, pose.basis.z.z)
		state.velocity = -pose.basis.z * 30 + right * (5 if index == 0 else -5)
		state.route_s = 30
	var initial: Array[VehicleState] = [race.states[0].copy(), race.states[1].copy()]
	var predictions: Array[PredictionBuffer] = []
	var frame := InputFrame.make()
	frame.tick = 98 # Applied at authority tick 101, including three-tick buffer.
	frame.sequence = 1
	for slot in range(2):
		var prediction := PredictionBuffer.new()
		prediction.state = initial[slot].copy()
		prediction.track = race.track
		prediction.car = race.cars[slot]
		prediction.query = WorldQuery.new(scene.get_world_3d(), race.track, 30)
		prediction.remotes = RemoteBuffer.new()
		prediction.remotes.configure(scene.get_world_3d(), race.track)
		prediction.remotes.push(100, initial)
		prediction.contact_enabled = true
		prediction.advance(frame)
		predictions.append(prediction)
		check(prediction.prediction_tick == 101 and prediction.predicted_contacts > 0, "both device slots predict immediate contact on the input-buffer timeline")
		check(prediction.state.position.distance_to(initial[slot].position) < 1, "predicted overlap separation remains bounded")
		var predicted_velocity := prediction.state.velocity
		var predicted_position := prediction.state.position
		prediction.reconcile(initial[slot], 0, 100)
		check(prediction.state.velocity.distance_to(predicted_velocity) < .0001 and prediction.state.position.distance_to(predicted_position) < .0001, "authority restore replays the same contact once without accumulating impulses")
		check(prediction.remote_states[1 - slot] != initial[1 - slot], "contact proxies are disposable copies")
	check(initial[0].velocity == race.states[0].velocity and initial[1].position == race.states[1].position, "neither client writes remote authority")
	# Compare each device's result with the shared server contact solver.
	for index in range(2): VehicleSim.step(race.states[index], frame, race.cars[index], race.queries[index])
	CarContact.resolve(race.states, race.queries)
	for slot in range(2):
		check(predictions[slot].state.position.distance_to(race.states[slot].position) < .03 and predictions[slot].state.velocity.distance_to(race.states[slot].velocity) < .03, "client contact agrees with authority for both pair orderings")
	var local := predictions[0]
	for mode in ["disabled", "ghost", "finished", "dnf", "stale", "bridge"]:
		var other := initial[1].copy()
		if mode == "ghost": other.ghost_ticks = 60
		if mode == "finished": other.finished = true
		if mode == "dnf": other.dnf_reason = "Left race"
		if mode == "bridge": other.position.y += 4
		local.state = initial[0].copy()
		local.remotes.clear()
		local.remotes.push(100, [initial[0], other])
		local.contact_enabled = mode != "disabled"
		var before := local.predicted_contacts
		frame.tick = 107 if mode == "stale" else 98
		local.simulate(frame)
		check(local.predicted_contacts == before, "no speculative contact for " + mode)
	# Actual static wall geometry must stop a forecast before it crosses out.
	var wall := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1, 6, 20)
	shape.shape = box
	wall.add_child(shape)
	wall.position = pose.origin + right * 4 + Vector3.UP * 2
	wall.rotation.y = -initial[0].yaw
	scene.add_child(wall)
	await physics_frame
	await physics_frame
	buffer.configure(scene.get_world_3d(), race.track)
	var towards_wall := initial[0].copy()
	towards_wall.position = pose.origin + Vector3.UP * .35
	towards_wall.velocity = right * 50
	buffer.push(100, [towards_wall])
	var stopped := buffer.predict(0, 109)
	check((stopped.position - pose.origin).dot(right) < 3, "remote forecast sweeps against real static walls")
	check(buffer.predict(0, 1000).position == stopped.position, "wall-limited forecast freezes exactly at its bounded endpoint")
	var link := NetworkClient.new()
	link.prediction = local
	link.latest_snapshot_tick = 100
	check(link.remote_state(1) == local.remote_states[1], "rendered rival uses the same proxy as predicted collision")
	link.prediction = null
	link.wire.close()
	link.free()
	predictions.clear()
	local = null
	buffer = null
	race = null
	scene.queue_free()
	await process_frame

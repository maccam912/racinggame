extends SceneTree
## Bounded human control, actual UDP authorization/privacy, prediction and rematch.

func _initialize() -> void: call_deferred("run")

func wait_for(condition: Callable) -> void:
	var deadline := Time.get_ticks_msec() + 5000
	while not condition.call() and Time.get_ticks_msec() < deadline: await process_frame
	assert(condition.call(), "network fixture timed out")

func run() -> void:
	Catalog.load_all()
	var track := TrackDefinition.new()
	track.points = PackedVector3Array([Vector3.ZERO, Vector3.FORWARD * 10000])
	track.forwards = PackedVector3Array([Vector3.FORWARD, Vector3.FORWARD])
	track.distances = PackedFloat64Array([0, 10000])
	track.length = 20000
	track.bake = {"samples":[[0,0,0,0,0,-1,0,0,16,0,0],[0,0,-10000,0,0,-1,0,0,16,0,0]]}
	var query := WorldQuery.new(root.world_3d, track)
	var state := VehicleState.new()
	state.position = Vector3(6,.35,-100)
	state.velocity = Vector3(4,0,-30)
	state.yaw_rate = .3
	var raw := InputFrame.make(1,.7,.2)
	raw.sequence = 123
	raw.tick = 456
	raw.recover = true
	raw.boost = true
	assert(DrivingAssist.apply(state,raw,query,0) == raw)
	var gentle := DrivingAssist.apply(state,raw,query,1)
	var strong := DrivingAssist.apply(state,raw,query,2)
	assert(strong.steer >= .76 and strong.steer < gentle.steer and gentle.steer < raw.steer, "outward steering stays available with bounded centering")
	assert(strong.throttle == raw.throttle and strong.brake == raw.brake and strong.sequence == 123 and strong.tick == 456 and strong.boost and strong.recover)
	state.position.x = -6
	state.velocity.x = -4
	state.yaw_rate = -.3
	assert(DrivingAssist.apply(state,InputFrame.make(),query,2).steer > 0, "left shoulder nudges right")
	for key: String in ["finished","reversing"]:
		state.set(key,true)
		assert(DrivingAssist.apply(state,raw,query,2) == raw)
		state.set(key,false)
	state.grounded = false
	assert(DrivingAssist.apply(state,raw,query,2) == raw)
	state.grounded = true
	var slide := InputFrame.make(1,1,0,true)
	assert(DrivingAssist.apply(state,slide,query,2) == slide)
	# After a correction, release steering with lateral momentum: damping must
	# settle the car instead of carrying it across the road into another wall.
	var excursions: Array[float] = []
	for level in [0,1,2]:
		var car_state := VehicleState.new()
		car_state.position = Vector3(2,.35,-100)
		car_state.yaw = .15
		car_state.velocity = car_state.forward()*30
		var total := 0.0
		for tick in range(180):
			var controls := DrivingAssist.apply(car_state,InputFrame.make(0,.5),query,level)
			VehicleSim.step(car_state,controls,Catalog.cars[0],FlatQuery.new())
			total += absf(car_state.position.x)
		excursions.append(total)
	assert(excursions[2] < excursions[0]*.6 and excursions[1] < excursions[0], "steering help reduces released-steering overshoot")
	print("STEERING_EXCURSION_SUM off/gentle/strong=",excursions)
	# Race-wide roles follow actual progress and exclude solo/trials/all-bot fields.
	var race := RaceSession.new()
	race.setup(Catalog.tracks[0],[0,0],root.world_3d,1)
	ProgressTracker.place_recovery(race.states[0],race.track,300)
	ProgressTracker.place_recovery(race.states[1],race.track,100)
	race.update_race_roles()
	assert(race.states[0].race_role == 1 and race.states[1].race_role == 2)
	ProgressTracker.place_recovery(race.states[1],race.track,400)
	race.update_race_roles()
	assert(race.states[1].race_role == 1 and race.states[0].race_role == 2)
	race.mode = "trial"
	race.update_race_roles()
	assert(race.states.all(func(s: VehicleState) -> bool: return s.race_role == 0))
	var speeds: Array[float] = []
	for role in [0,1,2]:
		var car_state := VehicleState.new()
		car_state.position.y = .35
		car_state.velocity = Vector3.FORWARD*40
		car_state.race_role = role
		var shoulder := FlatQuery.new()
		shoulder.surface = "grass"
		for tick in range(120): VehicleSim.step(car_state,InputFrame.make(0,1),Catalog.cars[0],shoulder)
		speeds.append(car_state.speed())
	assert(speeds[1] < speeds[0] and speeds[2] > speeds[0]+3, "leader eases off and chasers lose less shoulder speed")
	var wall := StaticBody3D.new()
	wall.position = Vector3(8,0,-100)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(1,4,500)
	shape.shape = box
	wall.add_child(shape)
	root.add_child(wall)
	await physics_frame
	await physics_frame
	var impact := query.sweep(Vector3(6.4,.35,-100),Vector3(12,0,-30),0,VehicleSim.DT,true)
	var catchup_impact := query.sweep(Vector3(6.4,.35,-100),Vector3(12,0,-30),0,VehicleSim.DT,true,VehicleSim.CHASER_ROADSIDE_FACTOR)
	assert(impact.hit and catchup_impact.hit and catchup_impact.velocity.length() > impact.velocity.length()+.5, "actual wall impact retains more tangential speed for chasers")
	wall.queue_free()
	await physics_frame
	for level: int in [2,3]: await network_case(level)
	query = null
	race = null
	print("HOST_PRIVATE_STEERING_BOUNDS_DAMPING_RACE_ROLES_UDP_AUTH_PREDICTION_RECONNECT_REMATCH_PASS")
	quit()

func network_case(level: int) -> void:
	var probe := PacketPeerUDP.new()
	assert(probe.bind(0,"127.0.0.1") == OK)
	var port := probe.get_local_port()
	probe.close()
	var server := RoomServer.new()
	server.port = port
	server.lobby.rules.bot_fill = false
	root.add_child(server)
	var host := NetworkClient.new()
	root.add_child(host)
	assert(host.connect_to("127.0.0.1",port,"Parent") == OK)
	await wait_for(func() -> bool: return not host.lobby.is_empty())
	var child := NetworkClient.new()
	root.add_child(child)
	assert(child.connect_to("127.0.0.1",port,"Child") == OK)
	await wait_for(func() -> bool: return host.lobby.get("members",[]).size() == 2 and child.lobby.get("members",[]).size() == 2)
	child.command("driving_assist",{"id":child.guest_id,"level":level})
	await create_timer(.15).timeout
	assert(server.lobby.member(child.guest_id).driving_assist == 0, "nonhost cannot grant assists")
	host.command("driving_assist",{"id":child.guest_id,"level":4})
	await create_timer(.15).timeout
	assert(server.lobby.member(child.guest_id).driving_assist==0,"out-of-range levels rejected")
	host.command("driving_assist",{"id":child.guest_id,"level":level})
	await wait_for(func() -> bool: return int(host.lobby.get("driving_assists",{}).get(child.guest_id,0)) == level)
	assert(not child.lobby.has("driving_assists") and not server.lobby.roster()[1].has("driving_assist"), "assignments stay out of other players' lobby and roster")
	for client: NetworkClient in [host,child]:
		client.loading_requested.connect(func(config: Dictionary) -> void: client.mark_loaded(int(config.race)))
		client.command("ready",{"value":true})
	await wait_for(func() -> bool: return server.lobby.all_ready())
	host.command("start")
	await wait_for(func() -> bool: return child.config.get("type") == "start" and host.config.get("type") == "start")
	assert(int(child.config.driving_assist) == level and int(host.config.driving_assist) == 0)
	assert(not child.config.roster[0].has("driving_assist"))
	var local := RaceSession.new()
	local.setup(Catalog.tracks[0],[0,0],root.world_3d,1)
	child.attach_prediction(local.states[1],local.cars[1],local.queries[1],local.track,1)
	assert(child.prediction.driving_assist == level)
	# Exact prediction/authority step from identical inputs and physical state.
	server.session.phase = RaceSession.Phase.RACING
	server.session.contact_enabled = false
	ProgressTracker.place_recovery(server.session.states[0],server.session.track,300)
	ProgressTracker.place_recovery(server.session.states[1],server.session.track,100)
	server.session.states[1].position += server.session.track.forwards[server.session.queries[1].hint].cross(Vector3.UP)*4
	server.session.states[1].velocity = server.session.states[1].forward()*30
	if level==DrivingAssist.RELAXED:
		var bend := -1
		for index in range(server.session.track.points.size()):
			if float(server.session.track.bake.ai_speeds[server.session.cars[1].id][index])<35: bend = index
		assert(bend>=0)
		ProgressTracker.place_recovery(server.session.states[1],server.session.track,server.session.track.distances[bend])
		server.session.states[1].recovery_ticks = 0
		server.session.states[1].velocity = server.session.states[1].forward()*65
		server.session.queries[1].hint = bend
		assert(CornerAssist.apply(server.session.states[1],InputFrame.make(.5,.8),server.session.cars[1],server.session.queries[1]).brake>0,"parity fixture actually invokes braking")
	server.session.update_race_roles()
	server.session.driving_assists[1] = level
	child.prediction.query.hint = server.session.queries[1].hint
	child.prediction.state = server.session.states[1].copy()
	child.prediction.elapsed_ticks = server.session.elapsed_ticks
	child.prediction.remotes = null
	child.prediction.contact_enabled = false
	var frame := InputFrame.make(.5,.8)
	frame.tick = server.tick
	frame.sequence = 1
	server.session.step({1:frame})
	child.prediction.advance(frame)
	assert(child.prediction.state.position.distance_to(server.session.states[1].position) < .00001)
	assert(child.prediction.history[0].steer == .5, "resend/replay stores original input, never applies assist twice")
	host.command("driving_assist",{"id":child.guest_id,"level":0})
	await create_timer(.15).timeout
	assert(server.lobby.member(child.guest_id).driving_assist==level,"assist choices are locked during races")
	var identity := child.guest_id
	child.process_mode = Node.PROCESS_MODE_DISABLED
	child.wire.peer.close()
	server.disconnect_peer(int(server.lobby.member(identity).peer))
	child.process_mode = Node.PROCESS_MODE_INHERIT
	child.begin_reconnect()
	await wait_for(func() -> bool: return child.resume_count > 0)
	assert(child.guest_id == identity and child.prediction.driving_assist == level and int(child.config.driving_assist) == level)
	server.session.phase = RaceSession.Phase.RESULTS
	await wait_for(func() -> bool: return child.phase == RaceSession.Phase.RESULTS)
	for client: NetworkClient in [host,child]: client.command("return_lobby")
	await wait_for(func() -> bool: return server.lobby.phase == LobbyState.Phase.LOBBY)
	assert(server.lobby.member(identity).driving_assist == level, "rematch retains identity preference")
	for client: NetworkClient in [host,child]:
		client.wire.close()
		client.prediction = null
		client.queue_free()
	server.wire.close()
	server.queue_free()
	local = null
	await create_timer(.2).timeout

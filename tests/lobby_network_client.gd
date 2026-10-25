extends SceneTree

var link := NetworkClient.new()
var scene := Node3D.new()
var collision: RouteCollision
var setup_session: RaceSession
var bot := BotDriver.new()
var results: Array[Dictionary] = []
var result_hashes: Array[String] = []
var index: int = 0
var output: String = ""
var expected_humans: int = 8
var port: int = 27050
var loaded_tracks: Array[int] = []
var requested_rules: Dictionary = {}
var started_ms: int = 0
var maximum_packet: int = 0
var reconnect_test: bool = false
var reconnect_done: bool = false
var resume_at_ms: int = -1
var lobby_reconnect_test: bool = false
var lobby_reconnect_done: bool = false
var reserved_identity: String = ""
var trace: Array[Dictionary] = []
var next_trace_ms: int = 0
var required_races: int = 2
var timeout_ms: int = 340000
var race_metrics: Array[Dictionary] = []
var highest_gate_by_race: Dictionary = {}
var minimum_ms: int = 0
var requested_laps: int = 1
var requested_tracks: Array[int] = [0,1]
var iroh_code: String = ""
var requested_assist_level: int = 0
var all_car_models: bool = "--all-cars" in OS.get_cmdline_user_args()


func fixture_car(racer_index: int) -> int:
	return racer_index % (Catalog.cars.size() if all_car_models else 4)


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	Catalog.load_all()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--index="): index = int(arg.trim_prefix("--index="))
		elif arg.begins_with("--iroh-code="): iroh_code = arg.trim_prefix("--iroh-code=")
		elif arg.begins_with("--latency-ms="): link.wire.latency_ms = int(arg.trim_prefix("--latency-ms="))
		elif arg.begins_with("--jitter-ms="): link.wire.jitter_ms = int(arg.trim_prefix("--jitter-ms="))
		elif arg.begins_with("--loss="): link.wire.loss = float(arg.trim_prefix("--loss="))
		elif arg.begins_with("--port="): port = int(arg.trim_prefix("--port="))
		elif arg == "--reconnect": reconnect_test = true
		elif arg == "--lobby-reconnect": lobby_reconnect_test = true
		elif arg.begins_with("--report="): output = arg.trim_prefix("--report=")
		elif arg.begins_with("--races="): required_races = int(arg.trim_prefix("--races="))
		elif arg.begins_with("--seconds="): timeout_ms = int(float(arg.trim_prefix("--seconds=")) * 1000)
		elif arg.begins_with("--minimum-seconds="): minimum_ms = int(float(arg.trim_prefix("--minimum-seconds=")) * 1000)
		elif arg.begins_with("--assist-level="): requested_assist_level = int(arg.trim_prefix("--assist-level="))
		elif arg.begins_with("--laps="): requested_laps = int(arg.trim_prefix("--laps="))
		elif arg.begins_with("--tracks="):
			requested_tracks.clear()
			for value: String in arg.trim_prefix("--tracks=").split(","):
				assert(value.is_valid_int() and int(value)>=0 and int(value)<Catalog.tracks.size())
				requested_tracks.append(int(value))
	assert(not requested_tracks.is_empty() and requested_assist_level>=0 and requested_assist_level<=DrivingAssist.MAX_LEVEL)
	link.admission_ticket = OS.get_environment("PR_TEST_TICKET")
	root.add_child(scene)
	scene.add_child(link)
	link.initial_car = fixture_car(index)
	link.initial_paint = index % 8
	link.loading_requested.connect(load_route)
	link.lobby_changed.connect(on_lobby)
	link.race_started.connect(start_race)
	link.results_received.connect(func(rows: Array) -> void:
		result_hashes.append(JSON.stringify(rows).sha256_text())
		results.append({"race":link.race_id, "track":int(link.config.track), "rows":rows.duplicate(true)})
		if link.prediction:
			race_metrics.append({"race":link.race_id, "slot":link.slot, "car":link.prediction.car.id, "boosts_used":link.prediction.car.boost_charges-link.prediction.state.boost_charges, "driving_assist":link.prediction.driving_assist, "snapshots":link.prediction.snapshot_count, "highest_snapshot_gate":int(highest_gate_by_race.get(link.race_id,-1)),
				"clear":statistics(link.prediction.clear_corrections), "contact":statistics(link.prediction.contact_corrections),
				"terminal":statistics(link.prediction.terminal_corrections), "recoveries":link.prediction.recovery_corrections,
				"clock_restores":statistics(link.prediction.clock_corrections), "history":link.prediction.history.size(), "rtt_ms":link.rtt_ms})
		write_race_progress()
		print("LOBBY_CLIENT_RACE_DONE index=%d race=%d" % [index, link.race_id])
		link.command("return_lobby"))
	link.status_changed.connect(func(message: String) -> void: print("LOBBY_CLIENT_STATUS ", message))
	var display_name := "👨‍👩‍👧‍👦".repeat(3) + "a" + String.chr(97 + index)
	if iroh_code.is_empty(): link.connect_to("127.0.0.1",port,display_name)
	else:
		var service := IrohRendezvous.new()
		scene.add_child(service)
		var reply := await service.resolve(iroh_code)
		assert(reply.ok,str(reply.get("message","")))
		assert(link.connect_iroh(str(reply.payload.endpoint_id),display_name)==OK)
	started_ms = Time.get_ticks_msec()
	while results.size() < required_races and Time.get_ticks_msec() - started_ms < timeout_ms:
		await physics_frame
		for authority: VehicleState in link.latest_snapshot.get("states",[]):
			highest_gate_by_race[link.race_id] = maxi(int(highest_gate_by_race.get(link.race_id,-1)),authority.last_gate)
		if Time.get_ticks_msec() >= next_trace_ms:
			next_trace_ms = Time.get_ticks_msec() + 5000
			trace.append({"ms":Time.get_ticks_msec() - started_ms, "physics_ticks":link.tick_counter, "connected":link.connected, "transport":link.wire.peer.get_connection_status(), "received_age_ms":Time.get_ticks_msec() - link.last_received_ms, "sent":link.wire.sent_bytes, "received":link.wire.received_bytes, "pending":link.wire.pending.size(), "phase":link.phase})
		if lobby_reconnect_test and not lobby_reconnect_done and link.connected and link.lobby.get("members", []).size() == 8:
			lobby_reconnect_done = true
			reserved_identity = link.guest_id
			link.process_mode = Node.PROCESS_MODE_DISABLED
			link.wire.peer.close()
			resume_at_ms = Time.get_ticks_msec() + 5000
		if reconnect_test and not reconnect_done and link.prediction and Time.get_ticks_msec() - started_ms > 15000:
			reconnect_done = true
			link.command("away")
			link.wire.poll()
			link.process_mode = Node.PROCESS_MODE_DISABLED
			link.wire.peer.close()
			resume_at_ms = Time.get_ticks_msec() + 5000
		if resume_at_ms > 0 and Time.get_ticks_msec() >= resume_at_ms:
			resume_at_ms = -1
			link.process_mode = Node.PROCESS_MODE_INHERIT
			link.begin_reconnect()
	while results.size() == required_races and Time.get_ticks_msec() - started_ms < minimum_ms:
		await physics_frame
	var lobby_rejoin_ok := not lobby_reconnect_test or (lobby_reconnect_done and link.guest_id == reserved_identity)
	var report := {"index":index, "results":results, "result_hashes":result_hashes, "loaded_tracks":loaded_tracks, "race_metrics":race_metrics, "wire_sent":link.wire.sent_bytes, "wire_received":link.wire.received_bytes, "resume_count":link.resume_count, "large_racing_events":link.large_racing_events, "reconnect_done":reconnect_done, "lobby_rejoin_ok":lobby_rejoin_ok, "trace":trace}
	if output != "":
		var file := FileAccess.open(output, FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "\t"))
	var expected_tracks: Array[int] = []
	for race: int in range(required_races): expected_tracks.append(requested_tracks[race%requested_tracks.size()])
	var success := results.size() == required_races and loaded_tracks == expected_tracks and link.large_racing_events == 0 and lobby_rejoin_ok and (not reconnect_test or (reconnect_done and link.resume_count >= 1))
	print("LOBBY_CLIENT_DONE index=%d races=%d tracks=%s" % [index, results.size(), loaded_tracks])
	link.leave_room()
	link.input_provider = Callable()
	link.prediction = null
	setup_session = null
	scene.queue_free()
	await process_frame
	quit(0 if success else 1)


func write_race_progress() -> void:
	if output.is_empty(): return
	var path := output+".race-"+str(link.race_id)+".json"
	var value := {"index":index,"race":link.race_id,"result":results.back(),"result_hash":result_hashes.back(),
		"metrics":race_metrics.back() if not race_metrics.is_empty() and int(race_metrics.back().race)==link.race_id else {}}
	var file := FileAccess.open(path+".pending",FileAccess.WRITE)
	assert(file!=null,"owned per-race evidence must be writable")
	file.store_string(JSON.stringify(value,"\t")+"\n")
	file.close()
	assert(DirAccess.rename_absolute(path+".pending",path)==OK,"publish only complete per-race evidence")


func on_lobby(state: Dictionary) -> void:
	if state.host!=link.guest_id: assert(not state.has("driving_assists"),"private assignment map never leaks to other clients")
	if results.size() >= required_races: return
	if int(state.phase) != LobbyState.Phase.LOBBY or state.members.size() != expected_humans:
		return
	var target := {"track":requested_tracks[results.size()%requested_tracks.size()], "laps":requested_laps, "bot_fill":false, "difficulty":1, "contact":true}
	if state.host == link.guest_id and state.rules != target:
		if requested_rules != target:
			requested_rules = target
			link.command("rules", {"rules":target})
		return
	if state.rules != target:
		return
	if state.host==link.guest_id and requested_assist_level>0:
		var assignments_ready := true
		for row: Dictionary in state.members:
			var level := requested_assist_level if int(row.slot)%2 else 0
			if int(state.get("driving_assists",{}).get(row.id,0))!=level:
				assignments_ready = false
				link.command("driving_assist",{"id":row.id,"level":level})
		if not assignments_ready: return
	for row: Dictionary in state.members:
		if row.id == link.guest_id and not row.ready:
			link.command("ready", {"value":true})


func load_route(config: Dictionary) -> void:
	setup_session = null
	if is_instance_valid(collision):
		scene.remove_child(collision)
		collision.queue_free()
	collision = RouteCollision.new()
	collision.build(Catalog.tracks[int(config.track)])
	scene.add_child(collision)
	loaded_tracks.append(int(config.track))
	await physics_frame
	await physics_frame
	link.mark_loaded(int(config.race))


func start_race(config: Dictionary) -> void:
	assert(int(config.get("driving_assist",0))==(requested_assist_level if int(config.slot)%2 else 0))
	assert(config.roster.all(func(row: Dictionary) -> bool: return not row.has("driving_assist")))
	print("LOBBY_CLIENT_RACE_STARTED index=%d race=%d" % [index, int(config.race)])
	setup_session = RaceSession.new()
	var roster: Array[Dictionary] = []
	roster.assign(config.roster)
	setup_session.setup(Catalog.tracks[int(config.track)], RaceSetup.car_indices(roster), scene.get_world_3d(), int(config.laps))
	link.attach_prediction(setup_session.states[link.slot], setup_session.cars[link.slot], setup_session.queries[link.slot], setup_session.track, int(config.laps))
	link.input_provider = func() -> InputFrame: return bot.sample(link.prediction.state, link.prediction.car, link.prediction.track, link.prediction.query)


func statistics(values: Array[float]) -> Dictionary:
	if values.is_empty(): return {"count":0, "p95":0.0, "max":0.0}
	var sorted := values.duplicate()
	sorted.sort()
	return {"count":sorted.size(), "p95":sorted[ceili(sorted.size() * .95) - 1], "max":sorted[-1]}

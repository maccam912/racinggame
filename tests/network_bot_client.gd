extends SceneTree

var link := NetworkClient.new()
var scene := Node3D.new()
var collision := RouteCollision.new()
var setup_session: RaceSession
var driver := BotDriver.new()
var report: String = ""
var seconds: float = 70
var start_ms: int = 0
var result: Array = []
var maximum_speed: float = 0
var reconnect_at: float = -1
var reconnect_done: bool = false
var reconnect_pause_seconds: float = 5
var resume_at_ms: int = 0
var initial_slot: int = -1
var contact_exercises: bool = false
var permanent_error: String = ""
var hitch_at: float = -1
var hitch_seconds: float = 0
var hitch_done: bool = false
var lamp_snapshot_tick: int = -1
var remote_brake_on: int = 0
var remote_brake_off: int = 0
var quality_observations := {"active_samples":0,"levels":[0,0,0],"max_rtt_ms":0.0,"max_delivery_loss_percent":0.0}
var next_quality_ms: int = 0
var remote_extrapolation := {"samples":0,"capped_samples":0,"max_requested_seconds":0.0,"max_distance_m":0.0,"max_buffer_samples":0}


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	Catalog.load_all()
	var port := 27021
	var name_value := "TestDriver"
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--port="):
			port = int(arg.trim_prefix("--port="))
		elif arg.begins_with("--name="):
			name_value = arg.trim_prefix("--name=")
		elif arg.begins_with("--report="):
			report = arg.trim_prefix("--report=")
		elif arg.begins_with("--seconds="):
			seconds = float(arg.trim_prefix("--seconds="))
		elif arg.begins_with("--latency-ms="):
			link.wire.latency_ms = int(arg.trim_prefix("--latency-ms="))
		elif arg.begins_with("--jitter-ms="):
			link.wire.jitter_ms = int(arg.trim_prefix("--jitter-ms="))
		elif arg.begins_with("--loss="):
			link.wire.loss = float(arg.trim_prefix("--loss="))
		elif arg.begins_with("--reconnect-at="):
			reconnect_at = float(arg.trim_prefix("--reconnect-at="))
		elif arg.begins_with("--away-seconds="):
			reconnect_pause_seconds = float(arg.trim_prefix("--away-seconds="))
		elif arg == "--contact-exercises":
			contact_exercises = true
		elif arg.begins_with("--hitch-at="):
			hitch_at = float(arg.trim_prefix("--hitch-at="))
		elif arg.begins_with("--hitch-seconds="):
			hitch_seconds = float(arg.trim_prefix("--hitch-seconds="))
	root.add_child(scene)
	scene.add_child(collision)
	collision.build(Catalog.tracks[0])
	scene.add_child(link)
	link.race_started.connect(start_race)
	link.loading_requested.connect(func(config: Dictionary) -> void: link.mark_loaded(int(config.race)))
	link.results_received.connect(func(value: Array) -> void:
		result = value
		if "--retirement-commands" in OS.get_cmdline_user_args():
			link.command("return_lobby")
			link.command("ready", {"value":true})
			link.command("start"))
	link.disconnected_permanently.connect(func(message: String) -> void: permanent_error = message)
	link.status_changed.connect(func(message: String) -> void: print("TEST_NETWORK_STATUS " + message))
	await physics_frame
	await physics_frame
	link.connect_to("127.0.0.1", port, name_value)
	start_ms = Time.get_ticks_msec()
	while Time.get_ticks_msec() - start_ms < seconds * 1000:
		await physics_frame
		if hitch_at>0 and not hitch_done and Time.get_ticks_msec()-start_ms>hitch_at*1000:
			hitch_done = true
			# Deliberate fixture-only main-thread stall: the real worker/proxy
			# continue and Godot drops excess local physics backlog on return.
			OS.delay_msec(roundi(hitch_seconds*1000))
		if link.prediction:
			maximum_speed = maxf(maximum_speed, link.prediction.state.speed())
		var now := Time.get_ticks_msec()
		if now>=next_quality_ms and link.start_tick>=0 and link.phase in [RaceSession.Phase.RACING,RaceSession.Phase.GRACE]:
			next_quality_ms = now+100
			var quality := link.quality.measure(now,true)
			quality_observations.active_samples += 1
			quality_observations.levels[int(quality.level)] += 1
			quality_observations.max_rtt_ms = maxf(quality_observations.max_rtt_ms,quality.rtt_ms)
			quality_observations.max_delivery_loss_percent = maxf(quality_observations.max_delivery_loss_percent,quality.loss_percent)
			remote_extrapolation.max_buffer_samples = maxi(remote_extrapolation.max_buffer_samples,link.remotes.samples.size())
			assert(link.remotes.samples.size()<=20,"real impaired traffic must keep the remote buffer bounded")
			if not link.remotes.samples.is_empty():
				var latest: Dictionary = link.remotes.samples[-1]
				var requested := (link.server_tick-6-float(latest.tick))/60.0
				if requested>0:
					for other: VehicleState in latest.states:
						if other.slot==link.slot: continue
						var rendered := link.remotes.sample(other.slot,link.server_tick)
						assert(rendered.position.is_finite() and is_finite(rendered.yaw))
						var distance := rendered.position.distance_to(other.position)
						assert(distance<=other.velocity.length()*.15+.001,"real remote extrapolation must stop at 150 milliseconds")
						remote_extrapolation.samples += 1
						if requested>.15: remote_extrapolation.capped_samples += 1
						remote_extrapolation.max_requested_seconds = maxf(remote_extrapolation.max_requested_seconds,requested)
						remote_extrapolation.max_distance_m = maxf(remote_extrapolation.max_distance_m,distance)
		if link.latest_snapshot_tick!=lamp_snapshot_tick and not link.latest_snapshot.is_empty():
			lamp_snapshot_tick = link.latest_snapshot_tick
			for state: VehicleState in link.latest_snapshot.states:
				if state.slot!=link.slot:
					if state.braking: remote_brake_on += 1
					else: remote_brake_off += 1
		if reconnect_at > 0 and not reconnect_done and Time.get_ticks_msec() - start_ms > reconnect_at * 1000:
			reconnect_done = true
			link.wire.event(1, {"type":"away"})
			link.wire.poll()
			link.process_mode = Node.PROCESS_MODE_DISABLED
			link.wire.peer.close()
			resume_at_ms = Time.get_ticks_msec() + roundi(reconnect_pause_seconds * 1000)
		if resume_at_ms > 0 and Time.get_ticks_msec() >= resume_at_ms:
			resume_at_ms = 0
			link.process_mode = Node.PROCESS_MODE_INHERIT
			link.begin_reconnect()
		if not result.is_empty() or permanent_error != "":
			break
	var data: Dictionary = {"slot":link.slot, "results":result, "max_speed":maximum_speed, "rtt_ms":link.rtt_ms, "sent_bytes":link.wire.sent_bytes, "received_bytes":link.wire.received_bytes, "dropped_packets":link.wire.dropped_packets, "reconnect_done":reconnect_done, "connected":link.connected, "sequence":link.sequence}
	data.large_racing_events = link.large_racing_events
	data.remote_brake_on = remote_brake_on
	data.remote_brake_off = remote_brake_off
	data.quality_observations = quality_observations
	data.remote_extrapolation = remote_extrapolation
	data.resume_count = link.resume_count
	data.hitch_done = hitch_done
	data.clock_rebase_count = link.clock_rebase_count
	data.coalesced_snapshots = link.coalesced_snapshots
	data.initial_slot = initial_slot
	data.permanent_error = permanent_error
	if link.prediction:
		data.snapshots = link.prediction.snapshot_count
		data.clear_corrections = statistics(link.prediction.clear_corrections)
		data.contact_corrections = statistics(link.prediction.contact_corrections)
		data.recoveries = link.prediction.recovery_corrections
		data.reconnect_restores = statistics(link.prediction.reconnect_corrections)
		data.clock_restores = statistics(link.prediction.clock_corrections)
		data.terminal_corrections = statistics(link.prediction.terminal_corrections)
		if link.prediction.trace_enabled:
			data.reconciliation_trace = link.prediction.trace
		data.last_gate = link.prediction.state.last_gate
		data.laps = link.prediction.state.laps
		data.finish_time = link.prediction.state.finish_time
		data.acknowledged_sequence = link.prediction.state.last_ack
	if report != "":
		var file := FileAccess.open(report, FileAccess.WRITE)
		file.store_string(JSON.stringify(data, "\t"))
	var console_data := data.duplicate()
	console_data.erase("reconciliation_trace")
	print("TEST_NETWORK_REPORT " + JSON.stringify(console_data))
	# Synthetic retirement ends the race after only a short driving interval.
	# Its contract is movement plus receipt; full driving fixtures retain 15 m/s.
	var retirement_fixture := "--retirement-commands" in OS.get_cmdline_user_args()
	var success := link.prediction != null and maximum_speed > (5 if retirement_fixture else 15)
	if retirement_fixture: success = success and not result.is_empty()
	var exit_code := 0 if success else 1
	link.input_provider = Callable()
	link.prediction = null
	setup_session = null
	scene.queue_free()
	await process_frame
	quit(exit_code)


func start_race(config: Dictionary) -> void:
	initial_slot = link.slot
	setup_session = RaceSession.new()
	var cars: Array[int] = []
	for row: Dictionary in config.roster:
		cars.append(int(row.car))
	setup_session.setup(Catalog.tracks[0], cars, scene.get_world_3d(), int(config.laps))
	link.attach_prediction(setup_session.states[link.slot], setup_session.cars[link.slot], setup_session.queries[link.slot], setup_session.track, int(config.laps))
	link.prediction.trace_enabled = "--trace-network" in OS.get_cmdline_user_args()
	link.input_provider = func() -> InputFrame:
		if contact_exercises:
			return InputFrame.make(0, .05)
		var frame := driver.sample(link.prediction.state, link.prediction.car, link.prediction.track, link.prediction.query)
		return frame


func statistics(values: Array[float]) -> Dictionary:
	if values.is_empty():
		return {"count":0, "p95":0, "max":0}
	var sorted := values.duplicate()
	sorted.sort()
	return {"count":sorted.size(), "p95":sorted[mini(sorted.size() - 1, ceili(sorted.size() * .95) - 1)], "max":sorted[-1]}

extends SceneTree

var link := NetworkClient.new()
var scene := Node3D.new()
var collision: RouteCollision
var setup_session: RaceSession
var bot := BotDriver.new()
var results: Array[Dictionary] = []
var index: int = 0
var output: String = ""
var expected_humans: int = 8
var port: int = 27050
var loaded_tracks: Array[int] = []
var requested_rules: Dictionary = {}
var started_ms: int = 0
var maximum_packet: int = 0


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	Catalog.load_all()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--index="): index = int(arg.trim_prefix("--index="))
		elif arg.begins_with("--port="): port = int(arg.trim_prefix("--port="))
		elif arg.begins_with("--report="): output = arg.trim_prefix("--report=")
	root.add_child(scene)
	scene.add_child(link)
	link.initial_car = index % 4
	link.initial_paint = index % 8
	link.loading_requested.connect(load_route)
	link.lobby_changed.connect(on_lobby)
	link.race_started.connect(start_race)
	link.results_received.connect(func(rows: Array) -> void:
		results.append({"race":link.race_id, "track":int(link.config.track), "rows":rows.duplicate(true)})
		link.command("return_lobby"))
	link.status_changed.connect(func(message: String) -> void: print("LOBBY_CLIENT_STATUS ", message))
	link.connect_to("127.0.0.1", port, "👨‍👩‍👧‍👦".repeat(3) + "a" + String.chr(97 + index))
	started_ms = Time.get_ticks_msec()
	while results.size() < 2 and Time.get_ticks_msec() - started_ms < 340000:
		await physics_frame
	var report := {"index":index, "results":results, "loaded_tracks":loaded_tracks, "wire_sent":link.wire.sent_bytes, "wire_received":link.wire.received_bytes}
	if output != "":
		var file := FileAccess.open(output, FileAccess.WRITE)
		file.store_string(JSON.stringify(report, "\t"))
	var success := results.size() == 2 and loaded_tracks == [0, 1]
	print("LOBBY_CLIENT_DONE index=%d races=%d tracks=%s" % [index, results.size(), loaded_tracks])
	link.leave_room()
	link.input_provider = Callable()
	link.prediction = null
	setup_session = null
	scene.queue_free()
	await process_frame
	quit(0 if success else 1)


func on_lobby(state: Dictionary) -> void:
	if int(state.phase) != LobbyState.Phase.LOBBY or state.members.size() != expected_humans:
		return
	var target := {"track":mini(results.size(), 1), "laps":1, "bot_fill":false, "difficulty":1, "contact":true}
	if state.host == link.guest_id and state.rules != target:
		if requested_rules != target:
			requested_rules = target
			link.command("rules", {"rules":target})
		return
	if state.rules != target:
		return
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
	setup_session = RaceSession.new()
	var roster: Array[Dictionary] = []
	roster.assign(config.roster)
	setup_session.setup(Catalog.tracks[int(config.track)], RaceSetup.car_indices(roster), scene.get_world_3d(), int(config.laps))
	link.attach_prediction(setup_session.states[link.slot], setup_session.cars[link.slot], setup_session.queries[link.slot], setup_session.track, int(config.laps))
	link.input_provider = func() -> InputFrame: return bot.sample(link.prediction.state, link.prediction.car, link.prediction.track, link.prediction.query)

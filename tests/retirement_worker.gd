extends SceneTree
## Synthetic result transition to exercise shutdown delivery, never real records.
var server := RoomServer.new()
var requested_tick: int = -1
var request_distance: float = 0
var forced: bool = false
var late := NetworkClient.new()
var expected: int = 8
var reported_results: bool = false

func _initialize() -> void: call_deferred("run")

func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--retire-expected="): expected = int(argument.trim_prefix("--retire-expected="))
	root.add_child(server)
	server.auto_start = false

func _process(_dt: float) -> bool:
	if not server.session:
		if server.players.size() == expected and server.lobby.phase == LobbyState.Phase.LOBBY:
			for player: Dictionary in server.players: server.lobby.set_ready(player.id, true)
			if server.lobby.request_start(server.lobby.host_id, server.tick): server.send_loading()
		return false
	if requested_tick < 0 and server.tick >= server.start_tick + 370:
		server.retiring = true
		requested_tick = server.tick
		request_distance = server.session.states[0].distance_m
		print("RETIREMENT_REQUESTED_DURING_RACE tick=%d" % requested_tick)
		root.add_child(late)
		late.disconnected_permanently.connect(func(message: String) -> void:
			if message == "Room unavailable": print("RETIREMENT_LATE_ADMISSION_REJECTED"))
		late.connect_to("127.0.0.1", server.port, "LateDriver")
	if requested_tick >= 0 and not forced and server.tick >= requested_tick + 60:
		forced = true
		assert(server.session.states[0].distance_m > request_distance + 1, "Retirement must keep the active race running")
		for state: VehicleState in server.session.states:
			state.finished = true
			state.finish_time = 3 + state.slot * .01
			state.best_lap_time = state.finish_time
			state.laps = server.session.lap_count
		server.session.phase = RaceSession.Phase.RESULTS
		print("RETIREMENT_SYNTHETIC_RESULTS ticks_after_request=%d" % (server.tick-requested_tick))
	if server.result_sent and not reported_results:
		reported_results = true
		var bytes := 4 + JSON.stringify({"type":"results", "race":server.race_number, "results":server.final_results}).to_utf8_buffer().size()
		print("RETIREMENT_RESULTS_BYTES %d" % bytes)
	return false

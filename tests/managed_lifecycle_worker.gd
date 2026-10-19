extends SceneTree
## Isolated operator fixture. Synthetic finish after real private-service drain.
var server := RoomServer.new()
var report_path: String
var retire_tick: int = -1
var distance_before: float = 0
var forced: bool = false
var next_report: int = 0

func _initialize() -> void: call_deferred("run")

func run() -> void:
	report_path = OS.get_environment("PR_LIFECYCLE_REPORT")
	assert(not report_path.is_empty())
	var configuration: Dictionary = JSON.parse_string(OS.get_environment("PR_WORKER_CONFIG"))
	assert(TicketVerifier.uuid(str(configuration.get("worker_id", ""))))
	report_path = report_path.path_join(str(configuration.worker_id)+".json")
	root.add_child(server)

func _process(_dt: float) -> bool:
	if not server.is_inside_tree(): return false
	if not server.session and server.players.size() == 2 and server.lobby.phase == LobbyState.Phase.LOBBY:
		for player: Dictionary in server.players: server.lobby.set_ready(player.id, true)
		if server.lobby.request_start(server.lobby.host_id, server.tick): server.send_loading()
	if server.session and server.retiring and retire_tick < 0:
		retire_tick = server.tick
		distance_before = server.session.states[0].distance_m
	if retire_tick >= 0 and not forced and server.tick >= retire_tick + 60 and FileAccess.file_exists(OS.get_environment("PR_LIFECYCLE_FINISH_GATE")):
		forced = true
		assert(server.session.states[0].distance_m > distance_before + 1)
		for state: VehicleState in server.session.states:
			state.finished = true
			state.finish_time = 3 + state.slot * .01
			state.best_lap_time = state.finish_time
			state.laps = server.session.lap_count
		server.session.phase = RaceSession.Phase.RESULTS
	if Time.get_ticks_msec() >= next_report:
		next_report = Time.get_ticks_msec() + 100
		var ids: Array[String] = []
		for player: Dictionary in server.players: ids.append(player.id)
		var payload := {"tick":server.tick,"retiring":server.retiring,"results_sent":server.result_sent,
			"race_active":server.session != null and server.tick >= server.start_tick + 370,
			"race_uuid":server.session.race_uuid if server.session else "","guest_ids":ids,
			"forced_synthetic_result":forced,"advanced_after_retire":retire_tick >= 0 and server.session != null and server.session.states[0].distance_m > distance_before + 1}
		var file := FileAccess.open(report_path,FileAccess.WRITE)
		assert(file != null)
		file.store_string(JSON.stringify(payload))
		file.close()
	return false

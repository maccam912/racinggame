class_name NetworkClient
extends Node

signal status_changed(message: String)
signal race_started(config: Dictionary)
signal results_received(results: Array)
signal lobby_changed(state: Dictionary)
signal loading_requested(config: Dictionary)
signal returned_to_lobby
signal disconnected_permanently(message: String)

var wire := WirePeer.new()
var slot: int = -1
var guest_id: String = ""
var lobby: Dictionary = {}
var lobby_revision: int = -1
var loading_race: int = -1
var loaded_race: int = -1
var initial_car: int = 0
var initial_paint: int = 0
var room_code: String = ""
var admission_ticket: String = ""
var official: bool = false
var result_event: Dictionary = {}
var deliberate_leave: bool = false
var race_id: int = 1
var server_tick: float = 0
var start_tick: int = -1
var control_tick: int = 0
var latest_snapshot_tick: int = -1
var latest_snapshot: Dictionary = {}
var phase: int = RaceSession.Phase.LOBBY
var elapsed_ticks: int = 0
var sequence: int = 0
var next_input_tick: int = -1
var connected: bool = false
var hello_sent: bool = false
var name_value: String = "Driver"
var reconnect_token: String = ""
var rtt_ms: float = 0
var last_received_ms: int = 0
var tick_counter: int = 0
var prediction: PredictionBuffer
var remotes := RemoteBuffer.new()
var input_provider: Callable
var config: Dictionary = {}
var host: String = "127.0.0.1"
var port: int = 27020
var retry_at: int = 0
var retry_count: int = 0
var disconnected_at: int = 0
var clock_ready: bool = false
var restoring_reconnect: bool = false
var large_racing_events: int = 0
var resume_count: int = 0


func _init() -> void:
	wire.accept_fragments = true


func connect_to(address: String, udp_port: int, display_name: String = "Driver") -> Error:
	host = address
	port = udp_port
	name_value = display_name
	var error := wire.peer.create_client(host, port, 4)
	if error != OK:
		status_changed.emit("Unable to connect")
		return error
	last_received_ms = Time.get_ticks_msec()
	status_changed.emit("Connecting")
	return OK


func _process(_dt: float) -> void:
	for packet: Dictionary in wire.poll():
		last_received_ms = Time.get_ticks_msec()
		if packet.channel == 2:
			receive_snapshot(packet.bytes)
		else:
			receive_event(WirePeer.decode_event(packet.bytes))
	var status := wire.peer.get_connection_status()
	if not hello_sent and disconnected_at == 0 and status == MultiplayerPeer.CONNECTION_CONNECTING and Time.get_ticks_msec() - last_received_ms > 10000:
		wire.peer.close()
		status_changed.emit("Connection timed out — Retry or Back")
		return
	if status == MultiplayerPeer.CONNECTION_CONNECTED and not hello_sent:
		hello_sent = true
		if admission_ticket != "" and reconnect_token == "":
			wire.event(1, {"type":"hello", "ticket":admission_ticket, "car":initial_car, "paint":initial_paint})
		else:
			wire.event(1, {"type":"hello", "protocol":NetCodec.PROTOCOL, "content":Compatibility.content_hash(), "name":name_value, "token":reconnect_token, "car":initial_car, "paint":initial_paint, "code":room_code})
	if connected and not deliberate_leave and Time.get_ticks_msec() - last_received_ms >= 3000:
		begin_reconnect()
	if status == MultiplayerPeer.CONNECTION_DISCONNECTED and hello_sent and disconnected_at == 0 and not deliberate_leave:
		begin_reconnect()
	if disconnected_at > 0 and not deliberate_leave and Time.get_ticks_msec() >= retry_at:
		if Time.get_ticks_msec() - disconnected_at > 20000:
			status_changed.emit("Reconnect expired — return to lobby")
			disconnected_permanently.emit("Reconnect expired — return to lobby")
			retry_at = 0x7fffffffffffffff
			return
		wire.peer.close()
		wire.pending.clear()
		hello_sent = false
		wire.peer.create_client(host, port, 4)
		retry_at = Time.get_ticks_msec() + [1000, 2000, 4000, 5000][mini(retry_count, 3)]
		retry_count += 1


func begin_reconnect() -> void:
	connected = false
	if disconnected_at == 0:
		disconnected_at = Time.get_ticks_msec()
		retry_at = disconnected_at + 1000
	status_changed.emit("Reconnecting")


func _physics_process(_dt: float) -> void:
	tick_counter += 1
	server_tick += 1
	if hello_sent and not deliberate_leave and tick_counter % 30 == 0:
		wire.event(1, {"type":"ping", "sent":Time.get_ticks_msec()}, 3)
	if not connected or prediction == null or start_tick < 0:
		return
	if phase < RaceSession.Phase.GRACE:
		phase = RaceSession.Phase.GRID if server_tick < start_tick + 120 else RaceSession.Phase.COUNTDOWN if server_tick < start_tick + 300 else RaceSession.Phase.RACING
	if phase not in [RaceSession.Phase.RACING, RaceSession.Phase.GRACE] or server_tick < control_tick:
		return
	if prediction.state.finished or prediction.state.dnf_reason != "":
		return
	if restoring_reconnect:
		restoring_reconnect = false
		prediction.history.clear()
	var frame: InputFrame = input_provider.call() if input_provider.is_valid() else InputFrame.make()
	sequence = (sequence + 1) & 0xffffffff
	frame.sequence = sequence
	if next_input_tick < 0:
		next_input_tick = roundi(server_tick)
	frame.tick = next_input_tick
	next_input_tick += 1
	frame = NetCodec.quantize(frame)
	prediction.advance(frame)
	if tick_counter % 2 == 0:
		var batch: Array[InputFrame] = []
		for index in range(maxi(0, prediction.history.size() - 6), prediction.history.size()):
			batch.append(prediction.history[index])
		wire.send(1, 1, NetCodec.encode_inputs(race_id, batch))


func receive_event(event: Dictionary) -> void:
	if not NetEvents.server_event(event):
		return
	if phase in [RaceSession.Phase.RACING, RaceSession.Phase.GRACE] and event.get("type") in ["lobby", "start", "loading"] and JSON.stringify(event).to_utf8_buffer().size() + 4 > 1200:
		large_racing_events += 1
	match event.get("type", ""):
		"welcome":
			restoring_reconnect = prediction != null
			slot = int(event.slot)
			guest_id = event.id
			race_id = int(event.race)
			reconnect_token = event.token
			admission_ticket = ""
			official = bool(event.get("official", false))
			connected = true
			disconnected_at = 0
			retry_count = 0
			server_tick = float(event.tick) + rtt_ms / 2000 * 60
			clock_ready = true
			if restoring_reconnect:
				next_input_tick = -1
				sequence = int(event.get("ack", sequence))
				control_tick = roundi(server_tick) + 30
				prediction.history.clear()
				remotes.samples.clear()
			status_changed.emit(("Official room" if official else "Community server") + " — waiting for racers")

		"lobby":
			if int(event.revision) < lobby_revision:
				return
			lobby_revision = int(event.revision)
			event.rules = LobbyState.normalize_rules(event.rules)
			lobby = event
			if int(event.phase) == LobbyState.Phase.LOBBY:
				var was_racing := start_tick >= 0
				phase = RaceSession.Phase.LOBBY
				start_tick = -1
				if was_racing:
					prediction = null
					input_provider = Callable()
					latest_snapshot.clear()
					latest_snapshot_tick = -1
					remotes.samples.clear()
					returned_to_lobby.emit()
			lobby_changed.emit(event)
		"loading":
			if int(event.race) == loading_race:
				if loaded_race == loading_race:
					mark_loaded(loaded_race)
				return
			loading_race = int(event.race)
			phase = RaceSession.Phase.LOADING
			config = event
			prediction = null
			latest_snapshot.clear()
			latest_snapshot_tick = -1
			remotes.samples.clear()
			loading_requested.emit(event)
		"start":
			receive_start(event)
		"resume":
			var expanded := expand_resume(event)
			if expanded.is_empty():
				receive_event({"type":"error", "message":"Race details unavailable — return to lobby"})
				return
			resume_count += 1
			if NetEvents.server_event(expanded):
				receive_start(expanded)
		"presence":
			apply_presence(event)
		"pong":
			rtt_ms = Time.get_ticks_msec() - float(event.sent)
			var estimate := float(event.tick) + rtt_ms / 2000.0 * 60
			server_tick = estimate if not clock_ready else lerpf(server_tick, estimate, .25)
			clock_ready = true
		"results":
			if int(event.race) != race_id:
				return
			result_event = event
			phase = RaceSession.Phase.RESULTS
			if "--network-evidence" in OS.get_cmdline_user_args():
				print("PACIFIC_RUSH_CLIENT_RESULTS " + JSON.stringify(event.results))
			results_received.emit(event.results)
		"error":
			var message := str(event.get("message", "Connection failed"))
			status_changed.emit(message)
			deliberate_leave = true
			disconnected_at = 0
			connected = false
			wire.peer.close()
			disconnected_permanently.emit(message)


func receive_snapshot(bytes: PackedByteArray) -> void:
	if start_tick < 0 or not connected:
		return
	var snapshot := NetCodec.decode_snapshot(bytes, race_id, Compatibility.content_hash().hex_decode())
	if snapshot.is_empty() or int(snapshot.tick) <= latest_snapshot_tick:
		return
	var route: TrackDefinition = Catalog.tracks[int(config.get("track", 0))]
	for state: VehicleState in snapshot.states:
		if state.last_gate >= route.bake.gates.size() or state.laps > int(config.get("laps", 3)):
			return
	latest_snapshot_tick = snapshot.tick
	latest_snapshot = snapshot
	elapsed_ticks = snapshot.elapsed
	if snapshot.phase >= RaceSession.Phase.GRACE:
		phase = snapshot.phase
	remotes.push(snapshot.tick, snapshot.states)
	if prediction and slot >= 0 and slot < snapshot.states.size() and int(snapshot.phase) >= RaceSession.Phase.RACING:
		if restoring_reconnect or server_tick < control_tick:
			prediction.restore_reconnect(snapshot.states[slot], snapshot.elapsed, roundi(server_tick) - int(snapshot.tick))
		else:
			prediction.reconcile(snapshot.states[slot], snapshot.elapsed, snapshot.tick)


func attach_prediction(state: VehicleState, car: CarDefinition, query: WorldQuery, track: TrackDefinition, laps: int) -> void:
	prediction = PredictionBuffer.new()
	prediction.state = state
	prediction.car = car
	prediction.query = query
	prediction.track = track
	prediction.lap_count = laps
	if not latest_snapshot.is_empty():
		prediction.reconcile(latest_snapshot.states[slot], latest_snapshot.elapsed, latest_snapshot.tick)


func _exit_tree() -> void:
	wire.close()


func mark_loaded(race: int) -> void:
	if race == loading_race and connected:
		loaded_race = race
		wire.event(1, {"type":"loaded", "race":race})


func command(type: String, values: Dictionary = {}) -> void:
	var event := values.duplicate(true)
	event.type = type
	wire.event(1, event)


func leave_room() -> void:
	deliberate_leave = true
	command("leave")
	wire.poll()
	if wire.peer.get_connection_status()==MultiplayerPeer.CONNECTION_CONNECTED:
		wire.peer.get_host().flush()
	connected = false


func expand_resume(event: Dictionary) -> Dictionary:
	var names: Dictionary = {}
	for source: Variant in [lobby.get("members", []), config.get("roster", [])]:
		for row: Dictionary in source:
			names[row.id] = row.name
	var roster: Array[Dictionary] = []
	for row: Array in event.cars:
		var name_string := str(names.get(row[0], ""))
		if name_string == "" and bool(row[3]):
			for bot_name: String in RaceSetup.BOT_NAMES:
				if row[0] == "bot_" + bot_name.to_lower():
					name_string = bot_name
		if not PlayerName.validate(name_string).valid:
			return {}
		roster.append({"id":row[0], "name":name_string, "car":int(row[1]), "paint":int(row[2]), "bot":bool(row[3])})
	var result := event.duplicate(true)
	result.erase("cars")
	result.type = "start"
	result.roster = roster
	return result


func apply_presence(event: Dictionary) -> void:
	if int(event.race) != race_id or start_tick < 0 or int(event.revision) < lobby_revision or not config.has("roster"):
		return
	var members: Array[Dictionary] = []
	for entry: Array in event.members:
		var index := int(entry[0])
		if index >= config.roster.size() or bool(config.roster[index].bot):
			return
		var row: Dictionary = config.roster[index].duplicate(true)
		row.erase("bot")
		row.merge({"slot":index, "connected":bool(entry[1]), "ping":int(entry[2]), "ready":true, "loaded":true}, true)
		members.append(row)
	var host_slot := int(event.host_slot)
	if host_slot >= config.roster.size():
		return
	lobby.host = "" if host_slot < 0 else config.roster[host_slot].id
	lobby.members = members
	lobby.phase = LobbyState.Phase.ACTIVE
	lobby.revision = int(event.revision)
	lobby.tick = int(event.tick)
	lobby_revision = int(event.revision)
	lobby_changed.emit(lobby)


func receive_start(event: Dictionary) -> void:
	if int(event.race) < race_id:
		return
	var new_race := int(event.race) != race_id
	race_id = int(event.race)
	slot = int(event.slot)
	if new_race:
		latest_snapshot.clear()
		next_input_tick = -1
		sequence = 0
		latest_snapshot_tick = -1
	config = event
	start_tick = int(event.start_tick)
	control_tick = int(event.get("control_tick", start_tick + 300))
	if prediction == null:
		race_started.emit(event)
	status_changed.emit(("Official room" if official else "Community server") + " — race connected")

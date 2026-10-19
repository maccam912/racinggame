class_name RoomServer
extends Node3D
## Dedicated authority; no visuals, cameras, fonts, or client account secrets.

var wire := WirePeer.new()
var lobby := LobbyState.new()
var players: Array[Dictionary]:
	get: return lobby.members
var session: RaceSession
var collision: RouteCollision
var tick: int = 0
var start_tick: int = -1
var result_sent: bool = false
var empty_ticks: int = 0
var contact_events: int = 0
var rejected_packets: int = 0
var port: int = 27020
var crypto := Crypto.new()
var test_rig: RefCounted
var connections: Dictionary = {}
var auto_start: bool = false
var last_broadcast: int = -1
var race_number: int = 0
var final_results: Array[Dictionary] = []
var auth_mode: String = "direct_guest"
var directory_link: WorkerDirectory
var retiring: bool = false


func _ready() -> void:
	Catalog.load_all()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--port="): port = int(arg.trim_prefix("--port="))
		elif arg.begins_with("--track="): lobby.rules.track = int(arg.trim_prefix("--track="))
		elif arg.begins_with("--laps="): lobby.rules.laps = int(arg.trim_prefix("--laps="))
		elif arg == "--no-bot-fill": lobby.rules.bot_fill = false
		elif arg.begins_with("--room-code="):
			lobby.code = arg.trim_prefix("--room-code=").replace("-", "").to_upper()
			lobby.private_room = true
		elif arg.begins_with("--auth-mode="): auth_mode = arg.trim_prefix("--auth-mode=")
		elif arg.begins_with("--latency-ms="): wire.latency_ms = int(arg.trim_prefix("--latency-ms="))
		elif arg.begins_with("--jitter-ms="): wire.jitter_ms = int(arg.trim_prefix("--jitter-ms="))
		elif arg.begins_with("--loss="): wire.loss = float(arg.trim_prefix("--loss="))
		elif arg == "--auto-start": auto_start = true
		elif arg == "--contact-fixture":
			if ResourceLoader.exists("res://tests/contact_rig.gd"):
				test_rig = load("res://tests/contact_rig.gd").new()
			else:
				fail_start("Contact fixture requires source checkout")
				return
	if (lobby.private_room and (lobby.code.length() != 8 or not PeerAddress.parse_code(lobby.code).valid)) or port < 1024 or port > 65535 or not LobbyState.valid_rules(lobby.rules) or auth_mode not in ["direct_guest", "ticket_required"] or (auto_start and not ResourceLoader.exists("res://tests/network_bot_client.gd")):
		fail_start("Invalid worker configuration")
		return
	if auth_mode == "ticket_required":
		directory_link = WorkerDirectory.new()
		if not directory_link.configure():
			fail_start("Invalid managed worker configuration")
			return
		port = int(directory_link.settings.port)
		lobby.rules = LobbyState.normalize_rules(directory_link.settings.rules)
		lobby.name_value = directory_link.settings.name
		lobby.region = directory_link.settings.region
		lobby.private_room = directory_link.settings.private
		lobby.code = directory_link.settings.code if lobby.private_room else ""
		directory_link.state_provider = directory_state
		directory_link.admitted.connect(official_admitted)
		directory_link.denied.connect(func(sender: int) -> void: wire.event(sender, {"type":"error", "message":"Join expired or room unavailable — return to browser"}))
		directory_link.leave_requested.connect(remove_guest)
		directory_link.retire_requested.connect(func() -> void: retiring = true)
		add_child(directory_link)
	var error := wire.peer.create_server(port, 16, 4)
	if error != OK:
		fail_start("Cannot bind worker UDP port: " + error_string(error))
		return
	wire.peer.peer_disconnected.connect(disconnect_peer)
	print("PACIFIC_RUSH_SERVER_READY port=%d protocol=%d mode=%s" % [port, NetCodec.PROTOCOL, auth_mode])


func fail_start(message: String) -> void:
	push_error(message)
	get_tree().quit(2)


func player_for_peer(peer_id: int) -> Dictionary:
	for player: Dictionary in players:
		if int(player.get("peer", 0)) == peer_id:
			return player
	return {}


func _physics_process(_dt: float) -> void:
	tick += 1
	wire.racing = session != null and not result_sent and tick >= start_tick + 300
	if retiring and (session == null or result_sent):
		get_tree().quit()
		return
	for packet: Dictionary in wire.poll():
		receive(packet)
	for peer_id: int in wire.active_peers.keys():
		if not connections.has(peer_id):
			connections[peer_id] = new_meter()
		if tick - int(connections[peer_id].joined) > 600 and player_for_peer(peer_id).is_empty():
			drop_peer(peer_id)
	for player: Dictionary in players.duplicate():
		if player.connected and tick - int(player.last_seen) >= 180:
			drop_peer(int(player.peer))
	if lobby.phase == LobbyState.Phase.LOBBY and auto_start and players.size() >= 2:
		for player: Dictionary in players:
			lobby.set_ready(player.id, true)
		if lobby.request_start(lobby.host_id, tick):
			send_loading()
	var transition := lobby.step(tick)
	match transition:
		"load": send_loading()
		"start": start_race()
		"lobby": reset_race()
		"close": get_tree().quit()
	if lobby.revision != last_broadcast or tick % 300 == 0:
		broadcast_lobby()
	if session and tick > start_tick:
		step_race()
	var active := players.filter(func(player: Dictionary) -> bool: return player.connected).size()
	empty_ticks = empty_ticks + 1 if active == 0 else 0
	if empty_ticks >= 1800:
		get_tree().quit()


func step_race() -> void:
	var frames: Dictionary = {}
	for player: Dictionary in players:
		var state := session.states[int(player.slot)]
		if player.connected:
			frames[player.slot] = player.buffer.sample(tick) if tick >= int(player.control_tick) else player.bot.sample(state, session.cars[player.slot], session.track, session.queries[player.slot], session.states)
			var input: InputFrame = frames[player.slot]
			if absf(input.steer) > .01 or input.throttle > 0 or input.brake > 0 or input.handbrake or input.recover:
				player.last_driving = tick
			if not state.finished and session.phase in [RaceSession.Phase.RACING, RaceSession.Phase.GRACE] and tick - int(player.last_driving) >= 2700:
				state.dnf_reason = "Input inactive"
		else:
			frames[player.slot] = player.bot.sample(state, session.cars[player.slot], session.track, session.queries[player.slot], session.states)
			if tick - int(player.disconnected_tick) >= 1200 and not state.finished:
				state.dnf_reason = "Reconnect expired"
		if not player.connected or tick < int(player.control_tick):
			frames[player.slot].sequence = player.buffer.last_sequence
	session.step(frames)
	if test_rig:
		test_rig.call("apply", session)
	var before := contact_events
	for state: VehicleState in session.states:
		if "bump" in state.events:
			contact_events += 1
	if contact_events > before:
		print("PACIFIC_RUSH_CONTACT_EVENT tick=%d" % tick)
	if tick % 3 == 0:
		var packet := NetCodec.encode_snapshot(session, tick, Compatibility.content_hash().hex_decode())
		for player: Dictionary in players:
			if player.connected:
				wire.send(int(player.peer), 2, packet)
	if session.phase == RaceSession.Phase.RESULTS and not result_sent:
		result_sent = true
		wire.racing = false
		final_results.clear()
		for state: VehicleState in session.standings():
			var record: Dictionary = session.roster[state.slot]
			final_results.append({"slot":state.slot, "id":record.id, "name":record.name, "car":int(record.car), "paint":int(record.paint), "bot":bool(record.bot), "time":state.finish_time, "dnf":state.dnf_reason, "best_lap":state.best_lap_time, "distance_m":state.distance_m})
		lobby.finish(tick)
		for player: Dictionary in players:
			if player.connected:
				send_results(player)
		if "--network-evidence" in OS.get_cmdline_user_args():
			print("PACIFIC_RUSH_AUTHORITATIVE_RESULTS " + JSON.stringify(final_results))
		else:
			print("PACIFIC_RUSH_AUTHORITATIVE_RESULTS race=%d racers=%d" % [race_number, final_results.size()])


func new_meter() -> Dictionary:
	return {"joined":tick, "rate_tick":tick, "packets":0, "bytes":0, "over":false, "violation_tick":-1}


func receive(packet: Dictionary) -> void:
	if not connections.has(packet.sender):
		connections[packet.sender] = new_meter()
	var meter: Dictionary = connections[packet.sender]
	if tick - int(meter.rate_tick) >= 60:
		if not meter.over:
			meter.violation_tick = -1
		meter.rate_tick = tick
		meter.packets = 0
		meter.bytes = 0
		meter.over = false
	meter.packets += 1
	meter.bytes += packet.bytes.size()
	if meter.packets > 120 or meter.bytes > 65536:
		rejected_packets += 1
		meter.over = true
		if int(meter.violation_tick) < 0:
			meter.violation_tick = tick
		elif tick - int(meter.violation_tick) >= 300:
			drop_peer(packet.sender)
		return
	var player := player_for_peer(packet.sender)
	if not player.is_empty():
		player.last_seen = tick
	if packet.channel == 1:
		if player.is_empty() or session == null or not player.connected:
			return
		var inputs := NetCodec.decode_inputs(packet.bytes, session.race_id)
		if inputs.is_empty():
			rejected_packets += 1
		for frame: InputFrame in inputs:
			player.buffer.push(frame, tick)
		return
	var event := WirePeer.decode_event(packet.bytes)
	if packet.channel == 3:
		if not player.is_empty() and event.get("type") == "ping" and NetEvents.integer(event.get("sent"), 0, 9007199254740991):
			wire.event(packet.sender, {"type":"pong", "sent":event.sent, "tick":tick}, 3)
		return
	if packet.channel != 0:
		return
	if event.get("type") == "hello":
		if meter.packets <= 5:
			hello(packet.sender, event)
		return
	if player.is_empty() or not player.connected:
		return
	match event.get("type", ""):
		"loaded":
			if lobby.phase == LobbyState.Phase.LOADING and event.get("race") == race_number + 1:
				player.loaded = true
				lobby.revision += 1
		"ready":
			if event.get("value") is bool:
				lobby.set_ready(player.id, event.value)
		"select_car":
			if NetEvents.integer(event.get("car"), 0, 3) and NetEvents.integer(event.get("paint"), 0, 7):
				lobby.select_car(player.id, int(event.car), int(event.paint))
		"rules":
			if event.get("rules") is Dictionary:
				lobby.set_rules(player.id, event.rules)
		"start":
			if lobby.request_start(player.id, tick):
				send_loading()
		"kick":
			if event.get("id") is String:
				var target := lobby.member(event.id)
				if not target.is_empty():
					var peer_id := int(target.peer)
					if lobby.kick(player.id, event.id, tick):
						wire.event(peer_id, {"type":"error", "message":"Kicked from room"})
		"return_lobby":
			if lobby.phase == LobbyState.Phase.RESULTS:
				player.return_ready = true
		"leave":
			if lobby.phase == LobbyState.Phase.LOBBY:
				lobby.leave(player.id)
				if is_instance_valid(directory_link): directory_link.next_heartbeat = 0
			else:
				if session and not session.states[int(player.slot)].finished:
					session.states[int(player.slot)].dnf_reason = "Left race"
				disconnect_peer(packet.sender)
		"away": disconnect_peer(packet.sender)


func hello(sender: int, event: Dictionary) -> void:
	if auth_mode == "ticket_required" and event.get("token", "") == "":
		if player_for_peer(sender).is_empty() and lobby.phase == LobbyState.Phase.LOBBY:
			directory_link.admit(sender, event)
		else:
			wire.event(sender, {"type":"error", "message":"Room unavailable"})
		return
	if event.get("protocol") != NetCodec.PROTOCOL or event.get("content") != Compatibility.content_hash():
		wire.event(sender, {"type":"error", "message":"Update required — incompatible game content"})
		return
	if not event.get("name") is String or not event.get("token", "") is String:
		return
	var checked := PlayerName.validate(event.name)
	if not checked.valid:
		return
	var token: String = event.get("token", "")
	if token.length() not in [0, 64] or (token != "" and not token.is_valid_hex_number(false)):
		return
	var player: Dictionary = {}
	if token != "":
		for record: Dictionary in players:
			if crypto.constant_time_compare(record.token.to_utf8_buffer(), token.to_utf8_buffer()) and tick - int(record.disconnected_tick) <= 1200:
				player = record
				break
		if player.is_empty():
			wire.event(sender, {"type":"error", "message":"Reconnect expired — return to lobby"})
			return
	else:
		if not player_for_peer(sender).is_empty():
			return
		if lobby.private_room and event.get("code", "") != lobby.code:
			wire.event(sender, {"type":"error", "message":"Room not available"})
			return
		if not NetEvents.integer(event.get("car", 0), 0, 3) or not NetEvents.integer(event.get("paint", 0), 0, 7):
			return
		var car := int(event.get("car", 0))
		var paint := int(event.get("paint", 0))
		player = lobby.join(RaceSetup.uuid(), checked.value, tick, car, paint)
		if player.is_empty():
			wire.event(sender, {"type":"error", "message":"Room full or race already started"})
			return
		player.merge({"token":crypto.generate_random_bytes(32).hex_encode(), "buffer":InputBuffer.new(), "bot":BotDriver.new(), "last_driving":tick})
	complete_hello(sender, player)


func complete_hello(sender: int, player: Dictionary) -> void:
	player.peer = sender
	player.connected = true
	player.last_seen = tick
	player.disconnected_tick = tick
	player.control_tick = tick + 30 if session else 0
	if session:
		player.buffer.frames.clear()
		player.buffer.missing_ticks = 7
		player.last_driving = tick
	wire.event(sender, {"type":"welcome", "id":player.id, "slot":player.slot, "race":race_number, "token":player.token, "tick":tick, "ack":player.buffer.last_sequence, "official":auth_mode == "ticket_required"})
	if session:
		send_resume(player)
		if result_sent:
			send_results(player)
	elif lobby.phase == LobbyState.Phase.LOADING:
		send_loading(player)
	broadcast_lobby()


func broadcast_lobby() -> void:
	last_broadcast = lobby.revision
	var event := racing_presence() if lobby.phase == LobbyState.Phase.ACTIVE else lobby.public_state(tick)
	for player: Dictionary in players:
		if player.connected:
			wire.event(int(player.peer), event)


func send_loading(recipient: Dictionary = {}) -> void:
	var event := {"type":"loading", "race":race_number + 1, "track":int(lobby.rules.track), "laps":int(lobby.rules.laps), "roster":lobby.roster(), "contact":bool(lobby.rules.contact)}
	for player: Dictionary in players:
		if player.connected and (recipient.is_empty() or recipient.id == player.id):
			wire.event(int(player.peer), event)


func start_race() -> void:
	race_number += 1
	var track: TrackDefinition = Catalog.tracks[int(lobby.rules.track)]
	collision = RouteCollision.new()
	collision.build(track)
	add_child(collision)
	session = RaceSession.new()
	session.race_id = race_number
	session.race_uuid = RaceSetup.uuid()
	var roster := lobby.roster()
	session.setup(track, RaceSetup.car_indices(roster), get_world_3d(), int(lobby.rules.laps))
	session.contact_enabled = bool(lobby.rules.contact)
	session.configure_bots(roster, -1, int(lobby.rules.difficulty))
	start_tick = tick
	for index in range(players.size()):
		var player: Dictionary = players[index]
		player.slot = index
		player.last_driving = tick
		player.buffer = InputBuffer.new()
		player.control_tick = tick + 300
		player.bot.difficulty = int(lobby.rules.difficulty)
		send_start(player)
	print("PACIFIC_RUSH_RACE_STARTED racers=%d tick=%d race=%d" % [roster.size(), start_tick, race_number])


func send_start(player: Dictionary) -> void:
	wire.event(int(player.peer), {"type":"start", "race":session.race_id, "race_uuid":session.race_uuid, "slot":int(player.slot), "start_tick":start_tick, "control_tick":int(player.control_tick), "count":session.states.size(), "track":int(lobby.rules.track), "laps":session.lap_count, "roster":session.roster, "contact":session.contact_enabled, "excluded":lobby.excluded})


func send_results(player: Dictionary) -> void:
	wire.event(int(player.peer), {"type":"results", "race":session.race_id, "race_uuid":session.race_uuid, "results":final_results, "return_tick":lobby.results_tick + 1200})


func reset_race() -> void:
	session = null
	if is_instance_valid(collision):
		remove_child(collision)
		collision.queue_free()
		collision = null
	start_tick = -1
	result_sent = false
	final_results.clear()
	for player: Dictionary in players:
		player.buffer = InputBuffer.new()
	broadcast_lobby()


func drop_peer(peer_id: int) -> void:
	disconnect_peer(peer_id)
	wire.disconnect_target(peer_id)


func disconnect_peer(peer_id: int) -> void:
	connections.erase(peer_id)
	var player := player_for_peer(peer_id)
	if player.is_empty() or not player.connected:
		return
	if lobby.phase == LobbyState.Phase.LOBBY:
		lobby.leave(player.id)
		if is_instance_valid(directory_link): directory_link.next_heartbeat = 0
	else:
		player.connected = false
		player.disconnected_tick = tick
		if player.id == lobby.host_id:
			lobby.transfer_host()
		lobby.revision += 1


func _exit_tree() -> void:
	wire.close()


func directory_state() -> Dictionary:
	var guests: Array[String] = []
	for player: Dictionary in players:
		guests.append(player.id)
	var phases := ["Lobby", "Loading", "InRace", "Results", "Closed"]
	return {"state":phases[int(lobby.phase)], "ready":not retiring, "guests":guests, "rules":lobby.rules, "name":lobby.name_value, "private":lobby.private_room}


func official_admitted(sender: int, claims: Dictionary, car: int, paint: int) -> void:
	if not wire.active_peers.has(sender) or not player_for_peer(sender).is_empty() or not lobby.member(claims.g).is_empty() or retiring:
		wire.event(sender, {"type":"error", "message":"Room unavailable"})
		return
	var player := lobby.join(claims.g, claims.n, tick, car, paint)
	if player.is_empty():
		wire.event(sender, {"type":"error", "message":"Room full or race already started"})
		return
	player.merge({"token":crypto.generate_random_bytes(32).hex_encode(), "buffer":InputBuffer.new(), "bot":BotDriver.new(), "last_driving":tick})
	complete_hello(sender, player)


func remove_guest(id: String) -> void:
	var player := lobby.member(id)
	if player.is_empty():
		return
	var peer_id := int(player.get("peer", 0))
	wire.event(peer_id, {"type":"error", "message":"Left room"})
	if lobby.phase == LobbyState.Phase.LOBBY:
		lobby.leave(id)
		if is_instance_valid(directory_link): directory_link.next_heartbeat = 0
	else:
		if session and not session.states[int(player.slot)].finished:
			session.states[int(player.slot)].dnf_reason = "Left race"
		disconnect_peer(peer_id)


func racing_presence() -> Dictionary:
	var rows: Array = []
	var host_slot := -1
	for player: Dictionary in players:
		rows.append([int(player.slot), bool(player.connected), int(player.ping)])
		if player.id == lobby.host_id:
			host_slot = int(player.slot)
	return {"type":"presence", "race":race_number, "revision":lobby.revision, "tick":tick, "host_slot":host_slot, "members":rows}


func send_resume(player: Dictionary) -> void:
	var rows: Array = []
	for row: Dictionary in session.roster:
		rows.append([row.id, int(row.car), int(row.paint), bool(row.bot)])
	wire.event(int(player.peer), {"type":"resume", "race":session.race_id, "race_uuid":session.race_uuid, "slot":int(player.slot), "start_tick":start_tick, "control_tick":int(player.control_tick), "count":session.states.size(), "track":int(lobby.rules.track), "laps":session.lap_count, "cars":rows, "contact":session.contact_enabled})

class_name RoomServer
extends Node3D
## Server entry point deliberately has no visual, UI, audio, or font dependencies.

var wire := WirePeer.new()
var players: Array[Dictionary] = []
var session: RaceSession
var collision := RouteCollision.new()
var tick: int = 0
var start_tick: int = -1
var minimum_humans: int = 2
var result_sent: bool = false
var empty_ticks: int = 0
var contact_events: int = 0
var rejected_packets: int = 0
var port: int = 27020
var lap_count: int = 1
var private_code: String = ""
var crypto := Crypto.new()
var test_rig: RefCounted
var connections: Dictionary = {}


func _ready() -> void:
	Catalog.load_all()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--port="):
			port = int(arg.trim_prefix("--port="))
		if arg.begins_with("--min-humans="):
			minimum_humans = clampi(int(arg.trim_prefix("--min-humans=")), 1, 8)
		if arg.begins_with("--latency-ms="):
			wire.latency_ms = int(arg.trim_prefix("--latency-ms="))
		if arg.begins_with("--jitter-ms="):
			wire.jitter_ms = int(arg.trim_prefix("--jitter-ms="))
		if arg.begins_with("--loss="):
			wire.loss = float(arg.trim_prefix("--loss="))
		if arg.begins_with("--laps="):
			lap_count = clampi(int(arg.trim_prefix("--laps=")), 1, 3)
		if arg == "--contact-fixture":
			if not ResourceLoader.exists("res://tests/contact_rig.gd"):
				push_error("Contact fixture requires the source checkout")
				get_tree().quit(2)
				return
			var script: Script = load("res://tests/contact_rig.gd")
			test_rig = script.new()
	if port < 1024 or port > 65535:
		push_error("Invalid worker port")
		get_tree().quit(2)
		return
	# Extra transport connections permit reconnect while an old socket expires.
	# The roster, reservations and simulation remain capped at eight humans.
	var error := wire.peer.create_server(port, 16, 4)
	if error != OK:
		push_error("Cannot bind worker UDP port: %s" % error_string(error))
		get_tree().quit(2)
		return
	add_child(collision)
	collision.build(Catalog.tracks[0])
	wire.peer.peer_disconnected.connect(disconnect_peer)
	print("PACIFIC_RUSH_SERVER_READY port=%d protocol=1 mode=direct_guest" % port)


func _physics_process(_dt: float) -> void:
	tick += 1
	for packet: Dictionary in wire.poll():
		receive(packet)
	for peer_id: int in wire.active_peers.keys():
		if not connections.has(peer_id):
			connections[peer_id] = tick
		elif tick - int(connections[peer_id]) > 600 and not players.any(func(p: Dictionary) -> bool: return p.peer == peer_id):
			wire.peer.disconnect_peer(peer_id, true)
	if session == null:
		if players.size() >= minimum_humans and players.all(func(p: Dictionary) -> bool: return p.loaded and p.connected):
			start_race()
		return
	var frames: Dictionary = {}
	var active := 0
	for player: Dictionary in players:
		var state := session.states[player.slot]
		if player.connected and tick - int(player.last_seen) >= 180:
			player.connected = false
			player.disconnected_tick = tick
			wire.peer.disconnect_peer(player.peer, true)
		if player.connected:
			active += 1
			frames[player.slot] = player.buffer.sample(tick) if tick >= int(player.control_tick) else player.bot.sample(state, session.cars[player.slot], session.track, session.queries[player.slot], session.states)
			var input: InputFrame = frames[player.slot]
			if absf(input.steer) > .01 or input.throttle > 0 or input.brake > 0 or input.handbrake or input.recover:
				player.last_driving = tick
			if not state.finished and tick - int(player.last_driving) >= 2700:
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
	var contacts_before := contact_events
	for state: VehicleState in session.states:
		if "bump" in state.events:
			contact_events += 1
	if contact_events > contacts_before:
		print("PACIFIC_RUSH_CONTACT_EVENT tick=%d" % tick)
	empty_ticks = empty_ticks + 1 if active == 0 else 0
	if empty_ticks >= 1800:
		get_tree().quit()
	if tick % 3 == 0:
		var packet := NetCodec.encode_snapshot(session, tick, Compatibility.content_hash().hex_decode())
		for player: Dictionary in players:
			if player.connected:
				wire.send(player.peer, 2, packet)
	if session.phase == RaceSession.Phase.RESULTS and not result_sent:
		result_sent = true
		var results: Array = []
		for state: VehicleState in session.standings():
			results.append({"slot":state.slot, "name":players[state.slot].name, "time":state.finish_time, "dnf":state.dnf_reason})
		for player: Dictionary in players:
			if player.connected:
				wire.event(player.peer, {"type":"results", "race":session.race_id, "results":results})
		print("PACIFIC_RUSH_AUTHORITATIVE_RESULTS " + JSON.stringify(results))


func receive(packet: Dictionary) -> void:
	var player: Dictionary = {}
	for record: Dictionary in players:
		if record.peer == packet.sender:
			player = record
			break
	if not player.is_empty():
		player.last_seen = tick
		if tick - int(player.rate_tick) >= 60:
			player.rate_tick = tick
			player.packets = 0
			player.bytes = 0
		player.packets += 1
		player.bytes += packet.bytes.size()
		if player.packets > 120 or player.bytes > 65536:
			rejected_packets += 1
			if player.violation_tick < 0:
				player.violation_tick = tick
			elif tick - int(player.violation_tick) >= 300:
				wire.peer.disconnect_peer(packet.sender)
			return
		elif tick - int(player.rate_tick) > 30 and player.packets < 60:
			player.violation_tick = -1
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
	match event.get("type", ""):
		"hello":
			hello(packet.sender, event)
		"loaded":
			if not player.is_empty():
				player.loaded = true
		"ping":
			if not player.is_empty() and NetEvents.integer(event.get("sent"), 0, 9007199254740991):
				wire.event(packet.sender, {"type":"pong", "sent":event.sent, "tick":tick}, 3)
		"away":
			if not player.is_empty():
				player.connected = false
				player.disconnected_tick = tick


func hello(sender: int, event: Dictionary) -> void:
	if event.get("protocol") != NetCodec.PROTOCOL or event.get("content") != Compatibility.content_hash():
		wire.event(sender, {"type":"error", "message":"Update required — incompatible game content"})
		return
	if not event.get("name") is String or not event.get("token", "") is String:
		return
	var display_name: String = event.name
	if display_name.length() < 3 or display_name.length() > 16 or display_name.to_utf8_buffer().size() > 96:
		return
	for character: String in display_name:
		if character.unicode_at(0) < 32 or character.unicode_at(0) == 127 or character in ["[", "]", "<", ">"]:
			return
	var token: String = event.get("token", "")
	if token.length() not in [0, 64]:
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
		if session != null or players.size() >= 8:
			wire.event(sender, {"type":"error", "message":"Room full or race already started"})
			return
		for record: Dictionary in players:
			if record.peer == sender:
				return
		player = {"slot":players.size(), "name":display_name, "token":crypto.generate_random_bytes(32).hex_encode(), "buffer":InputBuffer.new(), "bot":BotDriver.new(), "loaded":false, "last_driving":tick, "rate_tick":tick, "packets":0, "bytes":0, "violation_tick":-1}
		players.append(player)
	player.peer = sender
	player.connected = true
	player.last_seen = tick
	player.disconnected_tick = tick
	player.control_tick = tick + 30 if session else 0
	if session:
		player.buffer.frames.clear()
		player.buffer.missing_ticks = 7
		player.last_driving = tick
	wire.event(sender, {"type":"welcome", "slot":player.slot, "race":1, "token":player.token, "tick":tick})
	if session:
		send_start(player)


func start_race() -> void:
	session = RaceSession.new()
	var cars: Array[int] = []
	for _player: Dictionary in players:
		cars.append(0)
	session.setup(Catalog.tracks[0], cars, get_world_3d(), lap_count)
	start_tick = tick
	for player: Dictionary in players:
		send_start(player)
	print("PACIFIC_RUSH_RACE_STARTED racers=%d tick=%d" % [players.size(), start_tick])


func send_start(player: Dictionary) -> void:
	wire.event(player.peer, {"type":"start", "race":1, "start_tick":start_tick, "control_tick":player.control_tick, "count":players.size(), "track":0, "laps":lap_count})


func disconnect_peer(peer_id: int) -> void:
	connections.erase(peer_id)
	if session == null:
		players = players.filter(func(p: Dictionary) -> bool: return p.peer != peer_id)
		for index in range(players.size()):
			players[index].slot = index
			var player: Dictionary = players[index]
			wire.event(player.peer, {"type":"welcome", "slot":index, "race":1, "token":player.token, "tick":tick})
		return
	for player: Dictionary in players:
		if player.peer == peer_id:
			player.connected = false
			player.disconnected_tick = tick


func _exit_tree() -> void:
	wire.close()


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
var departure_started: bool = false
var suspended: bool = false
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
var initial_deadline_ms: int = 0
var tick_counter: int = 0
var prediction: PredictionBuffer
var remotes := RemoteBuffer.new()
var input_provider: Callable
var config: Dictionary = {}
var host: String = "127.0.0.1"
var port: int = 27020
var iroh_endpoint: String = ""
var retry_at: int = 0
var retry_count: int = 0
var disconnected_at: int = 0
var clock_ready: bool = false
var restoring_reconnect: bool = false
var large_racing_events: int = 0
var resume_count: int = 0
var clock_rebase_count: int = 0
var clock_samples: Array[Dictionary] = []
var coalesced_snapshots: int = 0
var feedback_sequence: int = 0
var feedback_events: Array[Dictionary] = []
var feedback_seen: Dictionary = {}
var quality := NetworkQuality.new()
var evidence_channels: Array[int] = [0,0,0,0,0]
var evidence_rejected_events: int = 0
var evidence_rejected_snapshots: int = 0
var evidence_wrong_channels: int = 0
var evidence_next_ms: int = 0
var evidence_bad_types: Dictionary = {}


func _init() -> void:
	wire.accept_fragments = true


func connect_to(address: String, udp_port: int, display_name: String = "Driver") -> Error:
	host = address
	port = udp_port
	iroh_endpoint = ""
	name_value = display_name
	var error := open_transport()
	if error != OK:
		status_changed.emit("Unable to connect")
		return error
	last_received_ms = Time.get_ticks_msec()
	initial_deadline_ms = last_received_ms+10000
	status_changed.emit("Connecting")
	return OK


func connect_iroh(endpoint: String, display_name: String = "Driver") -> Error:
	if not IrohTransport.valid_endpoint(endpoint) or not IrohTransport.available(): return ERR_UNAVAILABLE
	iroh_endpoint = endpoint
	name_value = display_name
	var error := open_transport()
	if error!=OK: return error
	last_received_ms = Time.get_ticks_msec()
	initial_deadline_ms = last_received_ms+20000
	status_changed.emit("Connecting by code")
	return OK


func open_transport() -> Error:
	if not iroh_endpoint.is_empty():
		var transport := IrohTransport.client(iroh_endpoint)
		if transport==null: return ERR_CANT_CONNECT
		wire.replace_peer(transport)
		return OK
	if not wire.peer is ENetMultiplayerPeer: wire.replace_peer(ENetMultiplayerPeer.new())
	return wire.peer.create_client(host,port,4)


func _process(_dt: float) -> void:
	if suspended: return
	if "--network-evidence" in OS.get_cmdline_user_args() and Time.get_ticks_msec()>=evidence_next_ms:
		evidence_next_ms = Time.get_ticks_msec()+2000
		print("NETWORK_HEALTH "+JSON.stringify({"channels":evidence_channels,"invalid_events":evidence_rejected_events,"invalid_snapshots":evidence_rejected_snapshots,"wrong_channels":evidence_wrong_channels,"raw_bytes":wire.received_bytes,"discarded":wire.discarded_packets,"fragment_pending":wire.fragments.pending.size(),"last_valid_age_ms":Time.get_ticks_msec()-last_received_ms,"connected":connected,"slot":slot,"suspended":suspended}))
	# ENet connectivity alone does not complete admission. A silent/invalid
	# Welcome stream cannot keep the initial Connect action pending forever.
	if slot<0 and initial_deadline_ms>0 and Time.get_ticks_msec()>=initial_deadline_ms:
		initial_deadline_ms = 0
		leave_room()
		status_changed.emit("Connection timed out — Retry or Back")
		return
	receive_packets(wire.poll())
	var status := wire.peer.get_connection_status()
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
		open_transport()
		retry_at = Time.get_ticks_msec() + [1000, 2000, 4000, 5000][mini(retry_count, 3)]
		retry_count += 1


func begin_reconnect() -> void:
	connected = false
	if disconnected_at == 0:
		disconnected_at = Time.get_ticks_msec()
		retry_at = disconnected_at + 1000
	status_changed.emit("Reconnecting")


func route_changed() -> void:
	if suspended or deliberate_leave or reconnect_token.is_empty(): return
	wire.peer.close()
	wire.pending.clear()
	wire.active_peers.clear()
	wire.fragments.pending.clear()
	hello_sent = false
	begin_reconnect()
	retry_at = Time.get_ticks_msec()
	retry_count = 0


func set_suspended(value: bool) -> void:
	if suspended==value or deliberate_leave: return
	if value and slot<0 and reconnect_token.is_empty():
		# Before Welcome there is no reservation credential to reconnect with.
		# Cancel this transport explicitly instead of creating another guest.
		suspended = true
		initial_deadline_ms = 0
		leave_room()
		status_changed.emit("Connection interrupted — Retry or Back")
		return
	suspended = value
	if value:
		# Drop queued controls before the best-effort Away. No background
		# processing is needed for takeover: missed Away falls back to liveness.
		wire.pending.clear()
		if connected and wire.peer.get_connection_status()==MultiplayerPeer.CONNECTION_CONNECTED:
			wire.event(1,{"type":"away"})
			wire.poll()
			wire.flush()
		wire.peer.close()
		wire.pending.clear()
		wire.active_peers.clear()
		wire.fragments.pending.clear()
		hello_sent = false
		connected = false
		if disconnected_at==0: disconnected_at = Time.get_ticks_msec()
		if prediction: prediction.history.clear()
		reset_feedback()
		status_changed.emit("Reconnecting")
	else:
		# The wall-clock deadline includes time spent with the OS suspended.
		# Reuse the token and seat; never manufacture a fresh local race.
		retry_at = Time.get_ticks_msec()
		retry_count = 0


func _physics_process(_dt: float) -> void:
	if suspended: return
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
	if next_input_tick < 0:
		next_input_tick = roundi(server_tick)
	else:
		rebase_input_clock()
	var frame: InputFrame = input_provider.call() if input_provider.is_valid() else InputFrame.make()
	sequence = (sequence + 1) & 0xffffffff
	frame.sequence = sequence
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
			initial_deadline_ms = 0
			quality.reset(int(event.race))
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
			server_tick = float(event.tick) + clock_transit_ticks()
			clock_ready = true
			if restoring_reconnect:
				next_input_tick = -1
				sequence = int(event.get("ack", sequence))
				control_tick = roundi(server_tick) + 30
				prediction.history.clear()
				remotes.clear()
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
					reset_feedback()
					latest_snapshot_tick = -1
					remotes.clear()
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
			reset_feedback()
			latest_snapshot_tick = -1
			remotes.clear()
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
			quality.observe_pong(rtt_ms)
			clock_samples.append({"at":Time.get_ticks_msec(),"rtt":rtt_ms})
			observe_clock(int(event.tick),.25)
		"results":
			if int(event.race) != race_id:
				return
			result_event = event
			phase = RaceSession.Phase.RESULTS
			if "--network-evidence" in OS.get_cmdline_user_args():
				# Android console records are bounded and may truncate mid-UTF-8.
				# Hash complete parsed rows before presentation/stat work.
				print("PACIFIC_RUSH_CLIENT_RESULTS_DIGEST %d %d %s" % [race_id,event.results.size(),JSON.stringify(event.results).sha256_text()])
			results_received.emit(event.results)
		"error":
			var message := str(event.get("message", "Connection failed"))
			status_changed.emit(message)
			deliberate_leave = true
			disconnected_at = 0
			connected = false
			wire.peer.close()
			disconnected_permanently.emit(message)


func receive_packets(packets: Array[Dictionary]) -> void:
	var newest: Dictionary = {}
	var newest_race: int = -1
	for packet: Dictionary in packets:
		if deliberate_leave: break
		evidence_channels[int(packet.channel) if int(packet.channel) in [0,1,2,3] else 4] += 1
		if packet.channel==2:
			var decoded := NetCodec.decode_snapshot(packet.bytes,race_id,Compatibility.content_hash().hex_decode())
			if decoded.is_empty():
				evidence_rejected_snapshots += 1
				continue
			last_received_ms = Time.get_ticks_msec()
			quality.observe_snapshot(race_id,int(decoded.tick))
			observe_feedback(decoded)
			if newest_race!=race_id:
				newest.clear()
				newest_race = race_id
			if not newest.is_empty(): coalesced_snapshots += 1
			if newest.is_empty() or int(decoded.tick)>int(newest.tick): newest = decoded
		elif packet.channel in [0,3]:
			var event := WirePeer.decode_event(packet.bytes)
			if not NetEvents.server_event(event):
				evidence_rejected_events += 1
				trace_rejected_event(event)
				continue
			if (event.get("type")=="pong")!=(packet.channel==3):
				evidence_wrong_channels += 1
				continue
			last_received_ms = Time.get_ticks_msec()
			receive_event(event)
	if newest_race==race_id and not newest.is_empty(): apply_snapshot(newest)

func trace_rejected_event(event: Dictionary) -> void:
	if not "--network-evidence" in OS.get_cmdline_user_args(): return
	var kind: String = event.get("type","") if event.get("type","") in ["welcome","lobby","loading","start","presence","resume","pong","error","results"] else "unknown"
	if evidence_bad_types.has(kind): return
	evidence_bad_types[kind] = true
	var names: Array[Dictionary] = []
	var roster: Variant = event.get("members",event.get("roster",event.get("results",[])))
	if roster is Array:
		for index in range(mini(8,roster.size())):
			if roster[index] is Dictionary and roster[index].get("name") is String:
				var name_value: String = roster[index].name
				names.append({"index":index,"characters":name_value.length(),"bytes":name_value.to_utf8_buffer().size(),"native_graphemes":TextServerManager.get_primary_interface().string_get_character_breaks(name_value).size(),"portable_graphemes":PlayerName.grapheme_count(name_value) if name_value.to_utf8_buffer().size()<=384 else -1,"valid":PlayerName.validate(name_value).valid})
	print("NETWORK_REJECTED_SCHEMA "+JSON.stringify({"type":kind,"names":names}))


func receive_snapshot(bytes: PackedByteArray) -> void:
	var snapshot := NetCodec.decode_snapshot(bytes,race_id,Compatibility.content_hash().hex_decode())
	if not snapshot.is_empty(): quality.observe_snapshot(race_id,int(snapshot.tick))
	apply_snapshot(snapshot)


func apply_snapshot(snapshot: Dictionary) -> void:
	if start_tick < 0 or not connected or phase==RaceSession.Phase.RESULTS:
		return
	if snapshot.is_empty() or int(snapshot.tick) <= latest_snapshot_tick:
		return
	var route: TrackDefinition = Catalog.tracks[int(config.get("track", 0))]
	for state: VehicleState in snapshot.states:
		if state.last_gate >= route.bake.gates.size() or state.laps > int(config.get("laps", 3)):
			return
	observe_feedback(snapshot)
	latest_snapshot_tick = snapshot.tick
	latest_snapshot = snapshot
	observe_clock(int(snapshot.tick),.10)
	elapsed_ticks = snapshot.elapsed
	if snapshot.phase >= RaceSession.Phase.GRACE:
		phase = snapshot.phase
	remotes.push(snapshot.tick, snapshot.states)
	if prediction and slot >= 0 and slot < snapshot.states.size() and int(snapshot.phase) >= RaceSession.Phase.RACING:
		if restoring_reconnect or server_tick < control_tick:
			prediction.restore_reconnect(snapshot.states[slot], snapshot.elapsed, roundi(server_tick) - int(snapshot.tick), snapshot.tick)
		elif rebase_input_clock():
			prediction.snapshot_count += 1
		else:
			prediction.reconcile(snapshot.states[slot], snapshot.elapsed, snapshot.tick)

func observe_feedback(snapshot: Dictionary) -> void:
	if start_tick<0 or not connected or phase==RaceSession.Phase.RESULTS or snapshot.is_empty(): return
	var tick_value := int(snapshot.tick)
	if tick_value<=latest_snapshot_tick or feedback_seen.has(tick_value): return
	var route: TrackDefinition = Catalog.tracks[int(config.get("track",0))]
	for state: VehicleState in snapshot.states:
		if state.last_gate>=route.bake.gates.size() or state.laps>int(config.get("laps",3)): return
	feedback_seen[tick_value] = true
	for old: int in feedback_seen.keys():
		if old<tick_value-180: feedback_seen.erase(old)
	while feedback_seen.size()>64: feedback_seen.erase(feedback_seen.keys()[0])
	var now := Time.get_ticks_msec()
	for state: VehicleState in snapshot.states:
		if state.events.is_empty(): continue
		feedback_sequence += 1
		feedback_events.append({"sequence":feedback_sequence,"at_ms":now,"state":state.copy()})
	while feedback_events.size()>128 or not feedback_events.is_empty() and now-int(feedback_events[0].at_ms)>500: feedback_events.pop_front()

func feedback_since(cursor: int) -> Array[VehicleState]:
	var result: Array[VehicleState] = []
	var now := Time.get_ticks_msec()
	for row: Dictionary in feedback_events:
		if int(row.sequence)>cursor and now-int(row.at_ms)<=500: result.append(row.state)
	return result

func reset_feedback() -> void:
	feedback_events.clear()
	feedback_seen.clear()
	# Keep the local cursor monotonic across races and reconnects.


func rebase_input_clock() -> bool:
	if prediction==null or next_input_tick<0 or absi(next_input_tick-roundi(server_tick))<=6: return false
	if not latest_snapshot.is_empty() and slot>=0 and slot<latest_snapshot.states.size():
		var authority: VehicleState = latest_snapshot.states[slot]
		if authority.finished or authority.dnf_reason!="": return false
	# Keep half of the unchanged +/-12-tick server window for transport.
	# A dropped physics backlog must not strand all later input in the past.
	next_input_tick = roundi(server_tick)
	clock_rebase_count += 1
	prediction.history.clear()
	if not latest_snapshot.is_empty() and slot>=0 and slot<latest_snapshot.states.size():
		prediction.restore_clock(latest_snapshot.states[slot],latest_snapshot.elapsed,roundi(server_tick)-int(latest_snapshot.tick),latest_snapshot.tick)
	return true


func clock_transit_ticks() -> float:
	var now := Time.get_ticks_msec()
	clock_samples = clock_samples.filter(func(sample: Dictionary) -> bool: return now-int(sample.at)<=20000)
	var best := rtt_ms
	for sample: Dictionary in clock_samples: best = minf(best,float(sample.rtt))
	return maxf(0,best)/2000.0*60


func observe_clock(tick: int, smoothing: float) -> void:
	# A queued pre-stall pong cannot rewind a newer authoritative snapshot.
	# Minimum recent RTT avoids treating local scheduling delay as transit.
	var estimate := maxi(tick,latest_snapshot_tick)+clock_transit_ticks()
	server_tick = estimate if not clock_ready or absf(server_tick-estimate)>12 else lerpf(server_tick,estimate,smoothing)
	clock_ready = true


func attach_prediction(state: VehicleState, car: CarDefinition, query: WorldQuery, track: TrackDefinition, laps: int) -> void:
	prediction = PredictionBuffer.new()
	prediction.state = state
	prediction.car = car
	prediction.query = query
	prediction.track = track
	prediction.lap_count = laps
	prediction.driving_assist = int(config.get("driving_assist", 0))
	remotes.configure(query.world, track)
	if not latest_snapshot.is_empty(): remotes.push(latest_snapshot.tick, latest_snapshot.states)
	prediction.remotes = remotes
	prediction.contact_enabled = bool(config.get("contact", true))
	if not latest_snapshot.is_empty():
		prediction.reconcile(latest_snapshot.states[slot], latest_snapshot.elapsed, latest_snapshot.tick)


func remote_state(remote_slot: int) -> VehicleState:
	# Rendering and local contact use the same estimate, including the server's
	# input-buffer lead. Predicted pushes affect only these disposable proxies.
	if prediction and not prediction.state.finished and prediction.state.dnf_reason == "" and prediction.prediction_tick >= latest_snapshot_tick and remote_slot >= 0 and remote_slot < prediction.remote_states.size():
		return prediction.remote_states[remote_slot]
	return remotes.predict(remote_slot, roundi(server_tick))


func _exit_tree() -> void:
	if not departure_started:
		wire.close()


func mark_loaded(race: int) -> void:
	if race == loading_race:
		loaded_race = race
		if connected and not suspended: wire.event(1, {"type":"loaded", "race":race})


func command(type: String, values: Dictionary = {}) -> void:
	var event := values.duplicate(true)
	event.type = type
	wire.event(1, event)


func leave_room() -> void:
	if departure_started:
		return
	deliberate_leave = true
	command("leave")
	wire.poll()
	if wire.peer.get_connection_status()==MultiplayerPeer.CONNECTION_CONNECTED:
		wire.flush()
	connected = false
	if is_inside_tree() and wire.peer.get_connection_status() != MultiplayerPeer.CONNECTION_DISCONNECTED:
		departure_started = true
		set_process(false)
		set_physics_process(false)
		var departure := NetworkDeparture.new()
		departure.wire = wire
		get_tree().root.add_child(departure)


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
		quality.reset(race_id)
		remotes.clear()
		latest_snapshot.clear()
		reset_feedback()
		next_input_tick = -1
		sequence = 0
		latest_snapshot_tick = -1
	config = event
	if prediction: prediction.driving_assist = int(event.get("driving_assist", 0))
	start_tick = int(event.start_tick)
	control_tick = int(event.get("control_tick", start_tick + 300))
	if prediction == null:
		race_started.emit(event)
	status_changed.emit(("Official room" if official else "Community server") + " — race connected")

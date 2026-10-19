class_name NetworkClient
extends Node

signal status_changed(message: String)
signal race_started(config: Dictionary)
signal results_received(results: Array)

var wire := WirePeer.new()
var slot: int = -1
var race_id: int = 1
var server_tick: float = 0
var start_tick: int = -1
var control_tick: int = 0
var latest_snapshot_tick: int = -1
var latest_snapshot: Dictionary = {}
var phase: int = RaceSession.Phase.LOBBY
var elapsed_ticks: int = 0
var sequence: int = 0
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
		wire.event(1, {"type":"hello", "protocol":NetCodec.PROTOCOL, "content":Compatibility.content_hash(), "name":name_value, "token":reconnect_token})
	if connected and Time.get_ticks_msec() - last_received_ms >= 3000:
		begin_reconnect()
	if status == MultiplayerPeer.CONNECTION_DISCONNECTED and hello_sent and disconnected_at == 0:
		begin_reconnect()
	if disconnected_at > 0 and Time.get_ticks_msec() >= retry_at:
		if Time.get_ticks_msec() - disconnected_at > 20000:
			status_changed.emit("Reconnect expired — return to lobby")
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
	if hello_sent and tick_counter % 30 == 0:
		wire.event(1, {"type":"ping", "sent":Time.get_ticks_msec()}, 3)
	if not connected or prediction == null or start_tick < 0:
		return
	if phase < RaceSession.Phase.GRACE:
		phase = RaceSession.Phase.GRID if server_tick < start_tick + 120 else RaceSession.Phase.COUNTDOWN if server_tick < start_tick + 300 else RaceSession.Phase.RACING
	if phase not in [RaceSession.Phase.RACING, RaceSession.Phase.GRACE] or server_tick < control_tick:
		return
	var frame: InputFrame = input_provider.call() if input_provider.is_valid() else InputFrame.make()
	sequence = (sequence + 1) & 0xffffffff
	frame.sequence = sequence
	frame.tick = roundi(server_tick)
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
	match event.get("type", ""):
		"welcome":
			slot = int(event.slot)
			race_id = int(event.race)
			reconnect_token = event.token
			connected = true
			disconnected_at = 0
			retry_count = 0
			server_tick = float(event.tick) + rtt_ms / 2000 * 60
			clock_ready = true
			status_changed.emit("Community server — waiting for racers")
			wire.event(1, {"type":"loaded"})
		"start":
			config = event
			start_tick = int(event.start_tick)
			control_tick = int(event.get("control_tick", start_tick + 300))
			if prediction == null:
				race_started.emit(event)
			status_changed.emit("Community server — race connected")
		"pong":
			rtt_ms = Time.get_ticks_msec() - float(event.sent)
			var estimate := float(event.tick) + rtt_ms / 2000.0 * 60
			server_tick = estimate if not clock_ready else lerpf(server_tick, estimate, .25)
			clock_ready = true
		"results":
			phase = RaceSession.Phase.RESULTS
			if "--network-evidence" in OS.get_cmdline_user_args():
				print("PACIFIC_RUSH_CLIENT_RESULTS " + JSON.stringify(event.results))
			results_received.emit(event.results)
		"error":
			status_changed.emit(str(event.get("message", "Connection failed")))


func receive_snapshot(bytes: PackedByteArray) -> void:
	var snapshot := NetCodec.decode_snapshot(bytes, race_id, Compatibility.content_hash().hex_decode())
	if snapshot.is_empty() or int(snapshot.tick) <= latest_snapshot_tick:
		return
	var route: TrackDefinition = Catalog.tracks[int(config.get("track", 0))]
	for state: VehicleState in snapshot.states:
		if state.last_gate >= route.bake.gates.size() or state.laps > 3:
			return
	latest_snapshot_tick = snapshot.tick
	latest_snapshot = snapshot
	elapsed_ticks = snapshot.elapsed
	if snapshot.phase >= RaceSession.Phase.GRACE:
		phase = snapshot.phase
	remotes.push(snapshot.tick, snapshot.states)
	if prediction and slot >= 0 and slot < snapshot.states.size() and int(snapshot.phase) >= RaceSession.Phase.RACING:
		prediction.reconcile(snapshot.states[slot], snapshot.elapsed)


func attach_prediction(state: VehicleState, car: CarDefinition, query: WorldQuery, track: TrackDefinition, laps: int) -> void:
	prediction = PredictionBuffer.new()
	prediction.state = state
	prediction.car = car
	prediction.query = query
	prediction.track = track
	prediction.lap_count = laps
	if not latest_snapshot.is_empty():
		prediction.reconcile(latest_snapshot.states[slot], latest_snapshot.elapsed)


func _exit_tree() -> void:
	wire.close()

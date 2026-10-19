extends SceneTree
var server: RoomServer
var healthy: NetworkClient
var malicious := ENetMultiplayerPeer.new()
var raw_race: int = -1
var invalid_vectors: int = 0
var valid_vectors: int = 0
var burst: Dictionary = {}
func _initialize() -> void: call_deferred("run")
func until(condition: Callable, milliseconds: int = 6000) -> void:
	var deadline := Time.get_ticks_msec()+milliseconds
	while not condition.call() and Time.get_ticks_msec()<deadline:
		pump()
		await process_frame
	assert(condition.call(),"packet-fault fixture condition before deadline")
func raw_send(bytes: PackedByteArray, channel: int = 0) -> void:
	if malicious.get_connection_status()!=MultiplayerPeer.CONNECTION_CONNECTED: return
	malicious.set_target_peer(1)
	malicious.transfer_channel = channel
	malicious.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
	assert(malicious.put_packet(bytes)==OK)
func event(value: Dictionary) -> PackedByteArray: return "PRJS".to_ascii_buffer()+JSON.stringify(value).to_utf8_buffer()
func pump() -> void:
	if malicious.get_connection_status()==MultiplayerPeer.CONNECTION_DISCONNECTED: return
	malicious.poll()
	while malicious.get_available_packet_count()>0:
		var value := WirePeer.decode_event(malicious.get_packet())
		if value.get("type")=="loading":
			raw_race = int(value.race)
			raw_send(event({"type":"loaded","race":raw_race}))
func invalid(bytes: PackedByteArray) -> void:
	assert(not WirePeer.valid_utf8(bytes),"invalid encoding is rejected before conversion")
	var packet := "PRJS{\"type\":\"hello\",\"name\":\"Bad".to_ascii_buffer()+bytes+"\"}".to_ascii_buffer()
	assert(WirePeer.decode_event(packet).is_empty(),"invalid bytes cannot become a replacement-character name")
	invalid_vectors += 1
func text_vectors() -> void:
	for lead in range(0x80,0xc2): invalid(PackedByteArray([lead]))
	for lead in range(0xf5,0x100): invalid(PackedByteArray([lead,0x80,0x80,0x80]))
	for bytes: Array in [[0xc2],[0xdf],[0xe0,0xa0],[0xed,0x9f],[0xf0,0x90,0x80],[0xf4,0x8f,0xbf],[0xc0,0x80],[0xc1,0xbf],[0xe0,0x9f,0xbf],[0xed,0xa0,0x80],[0xed,0xbf,0xbf],[0xf0,0x8f,0xbf,0xbf],[0xf4,0x90,0x80,0x80],[0xc2,0x7f],[0xe1,0x80,0xc0],[0xf1,0x80,0xff,0x80]]:
		invalid(PackedByteArray(bytes))
	var random := RandomNumberGenerator.new()
	random.seed = 30491
	var points: Array[int] = [0,0x7f,0x80,0x7ff,0x800,0xd7ff,0xe000,0xffff,0x10000,0x10ffff]
	for index in range(1024):
		var point := random.randi_range(0,0x10ffff)
		if point<0xd800 or point>0xdfff: points.append(point)
	for point: int in points:
		if point==0:
			assert(WirePeer.valid_utf8(PackedByteArray([0])))
			valid_vectors += 1
			continue
		var text := "Pacific "+String.chr(point)+" Rush"
		var bytes := text.to_utf8_buffer()
		assert(WirePeer.valid_utf8(bytes))
		if point!=0: assert(bytes.get_string_from_utf8()==text)
		valid_vectors += 1
	var names := {"type":"fixture","name":"Café 👨‍👩‍👧‍👦 한글 العربية"}
	assert(WirePeer.decode_event(event(names))==names)
	assert(WirePeer.decode_event("PRJS{\"type\":\"bad".to_ascii_buffer()+PackedByteArray([0])+"\"}".to_ascii_buffer()).is_empty(),"raw NUL is invalid JSON and never reaches the decoder")
	var null_escape := "PRJS{\"name\":\"bad"+String.chr(92)+"u0000name\"}"
	assert(WirePeer.decode_event(null_escape.to_ascii_buffer()).is_empty(),"escaped NUL cannot become a replacement-character identity")
	var literal := {"type":"fixture","name":"Bad"+String.chr(92)+"u0000Driver"}
	assert(WirePeer.decode_event(event(literal))==literal,"literal backslashes remain valid")
	assert(not WirePeer.valid_utf8(PackedByteArray([65]),-1) and not WirePeer.valid_utf8(PackedByteArray([65]),2))
func queued_burst() -> void:
	var receiver := WirePeer.new()
	assert(receiver.peer.create_server(0,2,4)==OK)
	var port := receiver.peer.get_host().get_local_port()
	var sender := ENetMultiplayerPeer.new()
	assert(sender.create_client("127.0.0.1",port,4)==OK)
	var deadline := Time.get_ticks_msec()+5000
	while sender.get_connection_status()!=MultiplayerPeer.CONNECTION_CONNECTED and Time.get_ticks_msec()<deadline:
		receiver.peer.poll()
		sender.poll()
		await process_frame
	assert(sender.get_connection_status()==MultiplayerPeer.CONNECTION_CONNECTED)
	sender.transfer_mode = MultiplayerPeer.TRANSFER_MODE_RELIABLE
	sender.transfer_channel = 0
	sender.set_target_peer(1)
	for index in range(512):
		var bytes := PackedByteArray()
		if index%3==0:
			bytes.resize(1300)
			bytes.fill(255)
		else: bytes = event({"type":"fixture","sequence":index})
		assert(sender.put_packet(bytes)==OK)
		if index%32==31:
			# Fill the application queue without overflowing the OS UDP buffer.
			# Only underlying ENet is polled; WirePeer has not consumed any data.
			sender.get_host().flush()
			receiver.peer.poll()
			sender.poll()
			await process_frame
	sender.get_host().flush()
	deadline = Time.get_ticks_msec()+5000
	while receiver.peer.get_available_packet_count()<512 and Time.get_ticks_msec()<deadline:
		receiver.peer.poll()
		sender.poll()
		await process_frame
	assert(receiver.peer.get_available_packet_count()==512,"a real queued burst exceeds the application read budget; queued="+str(receiver.peer.get_available_packet_count()))
	var first := receiver.poll()
	assert(first.size()<=WirePeer.RECEIVE_BUDGET and receiver.peer.get_available_packet_count()==256)
	var second := receiver.poll()
	assert(first.size()+second.size()==341 and receiver.discarded_packets==171)
	assert(receiver.deferred_receive_passes==1 and receiver.peer.get_available_packet_count()==0)
	var seen: Dictionary = {}
	for packet: Dictionary in first+second:
		var decoded := WirePeer.decode_event(packet.bytes)
		assert(not seen.has(int(decoded.sequence)))
		seen[int(decoded.sequence)] = true
	burst = {"raw_packets":512,"discarded_oversize":171,"delivered_once":341,"packets_per_pass":256,"deferred_passes":receiver.deferred_receive_passes}
	receiver.close()
	sender.close()
func run() -> void:
	Catalog.load_all()
	text_vectors()
	await queued_burst()
	var socket := PacketPeerUDP.new()
	assert(socket.bind(0,"127.0.0.1")==OK)
	var port := socket.get_local_port()
	socket.close()
	server = RoomServer.new()
	server.port = port
	root.add_child(server)
	healthy = NetworkClient.new()
	root.add_child(healthy)
	healthy.loading_requested.connect(func(configuration: Dictionary) -> void: healthy.mark_loaded(int(configuration.race)))
	healthy.race_started.connect(func(_configuration: Dictionary) -> void:
		var track := Catalog.tracks[0]
		var state := server.session.states[healthy.slot].copy()
		healthy.attach_prediction(state,server.session.cars[healthy.slot],WorldQuery.new(server.get_world_3d(),track,state.route_s),track,2)
		healthy.input_provider = func() -> InputFrame: return InputFrame.make(0,1))
	assert(healthy.connect_to("127.0.0.1",port,"Healthy Driver")==OK)
	await until(func() -> bool: return healthy.connected and not healthy.lobby.is_empty())
	var identity := healthy.guest_id
	assert(malicious.create_client("127.0.0.1",port,4)==OK)
	await until(func() -> bool: return malicious.get_connection_status()==MultiplayerPeer.CONNECTION_CONNECTED)
	raw_send(event({"type":"hello","protocol":NetCodec.PROTOCOL,"content":Compatibility.content_hash(),"name":"Fault Driver","token":""}))
	await until(func() -> bool: return server.players.size()==2)
	var offender: Dictionary = server.players[1]
	var offender_peer: int = offender.peer
	healthy.command("ready",{"value":true})
	raw_send(event({"type":"ready","value":true}))
	await until(func() -> bool: return server.lobby.all_ready())
	healthy.command("start")
	await until(func() -> bool: return server.session!=null)
	assert(server.session.states.size()==8 and raw_race==server.session.race_id)
	var first_snapshot := healthy.latest_snapshot_tick
	# Stay below rate limits while testing malformed lengths/race/buttons/text.
	for index in range(120):
		pump()
		if index%30==0: raw_send(event({"type":"ping","sent":Time.get_ticks_msec()}),3)
		var frame := InputFrame.make()
		frame.sequence = index+1
		frame.tick = server.tick
		var inputs := NetCodec.encode_inputs(raw_race,[frame])
		match index%6:
			0: raw_send(inputs.slice(0,inputs.size()-1),1)
			1: raw_send(NetCodec.encode_inputs(raw_race+1,[frame]),1)
			2:
				inputs[21] = 128
				raw_send(inputs,1)
			3: raw_send("PRJS{\"name\":\"bad".to_ascii_buffer()+PackedByteArray([255])+"\"}".to_ascii_buffer())
			4: raw_send(event({"type":"finish","laps":999,"time":0}))
			5: raw_send("PRFR".to_ascii_buffer()+PackedByteArray([0,0,0,0,0,1,0,0,1]))
		await process_frame
	assert(server.rejected_packets>=40 and healthy.connected and healthy.latest_snapshot_tick>first_snapshot)
	var flood_started := Time.get_ticks_msec()
	var deadline := flood_started+9000
	while offender.connected and Time.get_ticks_msec()<deadline:
		pump()
		raw_send(event({"type":"ping","sent":Time.get_ticks_msec()}),3)
		for index in range(32): raw_send(event({"type":"ignored","padding":"x".repeat(90)}))
		if malicious.get_connection_status()==MultiplayerPeer.CONNECTION_CONNECTED: malicious.get_host().flush()
		await process_frame
	var flood_ms := Time.get_ticks_msec()-flood_started
	assert(not offender.connected and not server.wire.active_peers.has(offender_peer),"sustained offender is disconnected without removing the healthy racer")
	assert(flood_ms>=4900 and flood_ms<9000)
	assert(healthy.connected and healthy.guest_id==identity and server.players.size()==2)
	assert(server.session.states.all(func(state: VehicleState) -> bool: return state.position.is_finite() and state.velocity.is_finite() and not state.finished))
	assert(server.session.elapsed_ticks>100 and server.session.states[0].speed()>1 and healthy.prediction.state.speed()>1,"ordinary healthy controls and authority continue while the offender is removed")
	# Reconnect the same owned reservation, then send malformed-only traffic
	# below the rate cap. Garbage is not an input or heartbeat.
	malicious.close()
	assert(malicious.create_client("127.0.0.1",port,4)==OK)
	await until(func() -> bool: return malicious.get_connection_status()==MultiplayerPeer.CONNECTION_CONNECTED)
	raw_send(event({"type":"hello","protocol":NetCodec.PROTOCOL,"content":Compatibility.content_hash(),"name":"Fault Driver","token":offender.token}))
	await until(func() -> bool: return offender.connected)
	var valid_seen: int = offender.last_seen
	var invalid_started := Time.get_ticks_msec()
	deadline = invalid_started+4500
	while offender.connected and Time.get_ticks_msec()<deadline:
		pump()
		raw_send("PRJSnot json".to_ascii_buffer())
		await process_frame
	var invalid_ms := Time.get_ticks_msec()-invalid_started
	assert(not offender.connected and offender.last_seen==valid_seen and server.tick-valid_seen>=180,"malformed-only packets cannot extend server liveness")
	assert(invalid_ms>=2850 and invalid_ms<4500 and healthy.connected and healthy.guest_id==identity)
	var client := NetworkClient.new()
	client.last_received_ms = 1
	var malformed: Array[Dictionary] = [{"channel":0,"bytes":"PRJSnot json".to_ascii_buffer()},{"channel":2,"bytes":"PRSNbad".to_ascii_buffer()},{"channel":1,"bytes":event({"type":"pong","sent":1,"tick":1})}]
	client.receive_packets(malformed)
	assert(client.last_received_ms==1,"invalid or wrong-channel server traffic cannot extend client liveness")
	client.receive_packets([{"channel":3,"bytes":event({"type":"pong","sent":Time.get_ticks_msec(),"tick":1})}])
	assert(client.last_received_ms>1)
	client.wire.close()
	client.free()
	var rejected := server.rejected_packets
	var available := server.connections.size()
	server.receive({"sender":offender_peer,"channel":0,"bytes":event({"type":"hello"})})
	assert(server.connections.size()==available,"stale packets after a forced drop cannot recreate meters or membership")
	var file := FileAccess.open("res://reports/m5-packet-faults.json",FileAccess.WRITE)
	assert(file!=null)
	file.store_string(JSON.stringify({"passed":true,"platform":OS.get_name(),"valid_utf8_vectors":valid_vectors,"invalid_utf8_vectors":invalid_vectors,"burst":burst,"real_enet_eight_car_worker":true,"sustained_offender_ms":flood_ms,"malformed_only_liveness_ms":invalid_ms,"client_liveness_valid_packets_only":true,"worker_rejected_packets":rejected,"healthy_same_identity":true,"healthy_authority_speed_mps":server.session.states[0].speed(),"authority_elapsed_ticks":server.session.elapsed_ticks,"no_fabricated_finish":true,"boundary":"Owned local ENet application traffic, bounded read batches, malformed input and sustained rate offender. Not volumetric Internet denial-of-service protection, physical radio validation or a complete race/result soak."},"  "))
	file.close()
	healthy.queue_free()
	server.queue_free()
	malicious.close()
	await process_frame
	print("REAL_ENET_512_PACKET_BURST_UTF8_5S_OFFENDER_3S_MALFORMED_LIVENESS_HEALTHY_EIGHT_CAR_WORKER_PASS")
	quit()

extends SceneTree


func _initialize() -> void:
	call_deferred("run_tests")


func run_tests() -> void:
	Catalog.load_all()
	var probe := PacketPeerUDP.new()
	assert(probe.bind(0, "127.0.0.1") == OK)
	var port := probe.get_local_port()
	probe.close()
	var server := RoomServer.new()
	server.port = port
	root.add_child(server)
	var alpha := NetworkClient.new()
	root.add_child(alpha)
	assert(alpha.connect_to("127.0.0.1", port, "Lobby Alpha") == OK)
	var until := Time.get_ticks_msec() + 3000
	while alpha.lobby.is_empty() and Time.get_ticks_msec() < until:
		await process_frame
	assert(not alpha.lobby.is_empty())
	var identity := alpha.guest_id
	var token := alpha.reconnect_token
	var beta := NetworkClient.new()
	root.add_child(beta)
	assert(beta.connect_to("127.0.0.1", port, "Lobby Beta") == OK)
	until = Time.get_ticks_msec() + 3000
	while beta.lobby.is_empty() and Time.get_ticks_msec() < until:
		await process_frame
	assert(server.players.size() == 2 and server.lobby.host_id == identity)
	alpha.process_mode = Node.PROCESS_MODE_DISABLED
	alpha.wire.peer.close()
	until = Time.get_ticks_msec() + 5000
	while not server.lobby.member(identity).is_empty() and server.lobby.member(identity).connected and Time.get_ticks_msec() < until:
		await process_frame
	assert(not server.lobby.member(identity).is_empty(), "an unexpected lobby drop must reserve the same identity for reconnect")
	assert(not server.lobby.member(identity).connected and not server.lobby.member(identity).ready)
	assert(server.lobby.host_id == beta.guest_id)
	alpha.process_mode = Node.PROCESS_MODE_INHERIT
	alpha.begin_reconnect()
	until = Time.get_ticks_msec() + 6000
	while not alpha.connected and Time.get_ticks_msec() < until:
		await process_frame
	assert(alpha.connected and alpha.guest_id == identity and alpha.reconnect_token == token)
	assert(server.players.size() == 2 and server.lobby.host_id == beta.guest_id)
	assert(server.lobby.member(identity).connected and not server.lobby.member(identity).ready)
	# An explicit leave still releases immediately; reconnect expiry releases only the reserved seat.
	alpha.leave_room()
	until = Time.get_ticks_msec() + 1000
	while server.players.size() != 1 and Time.get_ticks_msec() < until:
		await process_frame
	assert(server.players.size() == 1)
	var reserved := server.lobby.join("expired", "Expired Driver", server.tick)
	reserved.merge({"peer":999, "connected":false, "disconnected_tick":server.tick - 1199}, true)
	server._physics_process(1.0 / 60)
	assert(server.lobby.member("expired").is_empty())
	var handover := RoomServer.new()
	handover.tick = 2000
	var row := handover.lobby.join(RaceSetup.uuid(), "One Way Driver", 0)
	row.merge({"peer":99, "token":"ab".repeat(32), "buffer":InputBuffer.new(), "bot":BotDriver.new(), "last_seen":2000, "disconnected_tick":1})
	var hello := {"protocol":NetCodec.PROTOCOL, "content":Compatibility.content_hash(), "name":"One Way Driver", "token":row.token}
	handover.hello(100, hello)
	assert(handover.players.size() == 1 and row.peer == 100 and row.connected)
	row.connected = false
	row.disconnected_tick = 799
	handover.hello(101, hello)
	assert(row.peer == 100 and not row.connected, "expired disconnected tokens cannot hand over a seat")
	handover.wire.close()
	handover.free()
	beta.leave_room()
	alpha.queue_free()
	beta.queue_free()
	server.queue_free()
	await process_frame
	print("LOBBY_RECONNECT_PASS: real ENet identity reservation, host transfer, rejoin, explicit leave and expiry")
	quit()

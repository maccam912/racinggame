extends SceneTree

func _initialize() -> void: call_deferred("run_tests")

func run_tests() -> void:
	Catalog.load_all()
	var port_probe := PacketPeerUDP.new()
	assert(port_probe.bind(0,"127.0.0.1")==OK)
	var port := port_probe.get_local_port()
	port_probe.close()
	var server := RoomServer.new()
	server.port = port
	root.add_child(server)
	var beta := NetworkClient.new()
	root.add_child(beta)
	assert(beta.connect_to("127.0.0.1",port,"Leave Beta")==OK)
	var until := Time.get_ticks_msec()+3000
	while beta.lobby.is_empty() and Time.get_ticks_msec()<until: await process_frame
	assert(not beta.lobby.is_empty())
	for attempt in range(3):
		var alpha := NetworkClient.new()
		root.add_child(alpha)
		assert(alpha.connect_to("127.0.0.1",port,"Leave Alpha")==OK)
		until = Time.get_ticks_msec()+3000
		while (alpha.lobby.is_empty() or beta.lobby.members.size()!=2) and Time.get_ticks_msec()<until: await process_frame
		assert(not alpha.lobby.is_empty() and beta.lobby.members.size()==2)
		alpha.wire.latency_ms = attempt * 75
		alpha.leave_room()
		alpha.queue_free()
		until = Time.get_ticks_msec()+1000
		while beta.lobby.members.size()!=1 and Time.get_ticks_msec()<until: await process_frame
		assert(beta.lobby.members.size()==1,"explicit leave must arrive before the three-second liveness timeout")
		until = Time.get_ticks_msec()+2500
		while root.get_children().any(func(node: Node) -> bool: return node is NetworkDeparture) and Time.get_ticks_msec()<until: await process_frame
		assert(not root.get_children().any(func(node: Node) -> bool: return node is NetworkDeparture),"acknowledged departure must release its temporary transport owner")
	beta.queue_free()
	server.queue_free()
	await process_frame
	print("ENET_EXPLICIT_LEAVE_BEFORE_DISPOSAL_PASS")
	quit()

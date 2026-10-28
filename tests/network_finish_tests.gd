extends SceneTree
## Actual room creation and ENet delivery of authoritative wrap-up results.
func _initialize() -> void: call_deferred("run")

func wait_for(condition: Callable) -> void:
	var deadline := Time.get_ticks_msec()+5000
	while not condition.call() and Time.get_ticks_msec()<deadline: await process_frame
	assert(condition.call(),"finish network fixture timed out")

func run() -> void:
	Catalog.load_all()
	for all_humans_done: bool in [true,false]: await network_case(all_humans_done)
	print("ONLINE_ROOM_5S_HUMAN_WRAP_60S_ACTIVE_HUMAN_DEADLINE_IDENTICAL_ENET_RESULTS_PASS")
	quit()

func network_case(all_humans_done: bool) -> void:
	var probe := PacketPeerUDP.new()
	assert(probe.bind(0,"127.0.0.1")==OK)
	var port := probe.get_local_port()
	probe.close()
	var server := RoomServer.new()
	server.port = port
	root.add_child(server)
	var host := NetworkClient.new()
	root.add_child(host)
	assert(host.connect_to("127.0.0.1",port,"Finish Host")==OK)
	await wait_for(func() -> bool: return not host.lobby.is_empty())
	var child := NetworkClient.new()
	root.add_child(child)
	assert(child.connect_to("127.0.0.1",port,"Finish Guest")==OK)
	await wait_for(func() -> bool: return host.lobby.get("members",[]).size()==2 and child.lobby.get("members",[]).size()==2)
	host.command("driving_assist",{"id":child.guest_id,"level":DrivingAssist.RELAXED})
	await wait_for(func() -> bool: return server.lobby.member(child.guest_id).driving_assist==DrivingAssist.RELAXED)
	for client: NetworkClient in [host,child]:
		client.loading_requested.connect(func(config: Dictionary) -> void: client.mark_loaded(int(config.race)))
		client.command("ready",{"value":true})
	await wait_for(func() -> bool: return server.lobby.all_ready())
	host.command("start")
	await wait_for(func() -> bool: return child.config.get("type")=="start" and host.config.get("type")=="start")
	server.set_physics_process(false)
	assert(server.session.mode=="online" and server.session.finish_grace_limit()==3600)
	assert(server.session.states.size()==8 and server.session.bots.size()==6)
	server.session.phase = RaceSession.Phase.GRACE
	server.session.elapsed_ticks = 100
	server.session.first_finish_tick = 100
	server.session.states[0].finished = true
	server.session.states[0].finish_time = 1.234567
	if all_humans_done:
		server.session.states[1].finished = true
		server.session.states[1].finish_time = 1.5
		for tick in range(299): server.session.step({})
		assert(server.session.phase==RaceSession.Phase.GRACE)
	else:
		server.session.elapsed_ticks = 3699
		# This human is still connected and driving; inactivity is not the deadline.
		server.players[1].buffer = InputBuffer.new()
		server.players[1].buffer.last_frame = InputFrame.make(0,1)
	server.tick = server.start_tick+300+server.session.elapsed_ticks
	for player: Dictionary in server.players:
		player.last_driving = server.tick
		player.last_seen = server.tick
	server.step_race()
	assert(server.result_sent and server.session.phase==RaceSession.Phase.RESULTS)
	assert(server.session.elapsed_ticks==(400 if all_humans_done else 3700))
	server.set_physics_process(true)
	await wait_for(func() -> bool: return not host.result_event.is_empty() and not child.result_event.is_empty())
	assert(JSON.stringify(host.result_event.results)==JSON.stringify(child.result_event.results))
	assert(host.result_event.results==JSON.parse_string(JSON.stringify(server.final_results)))
	var guest: Dictionary = server.final_results.filter(func(row: Dictionary) -> bool: return row.slot==1)[0]
	assert(guest.dnf==("" if all_humans_done else "Finish grace expired"))
	assert(server.final_results[0].slot==0 and server.final_results[0].time==1.234567)
	for row: Dictionary in server.final_results:
		if row.bot: assert(row.dnf==("Race complete" if all_humans_done else "Finish grace expired"))
	for client: NetworkClient in [host,child]:
		client.wire.close()
		client.queue_free()
	server.wire.close()
	server.queue_free()
	await create_timer(.2).timeout

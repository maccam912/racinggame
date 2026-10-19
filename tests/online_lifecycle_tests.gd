extends SceneTree
var app: Node
var server: RoomServer
var folder: String
func _initialize() -> void: call_deferred("run")
func until(condition: Callable, milliseconds: int = 5000) -> void:
	var deadline := Time.get_ticks_msec()+milliseconds
	while not condition.call() and Time.get_ticks_msec()<deadline: await process_frame
	assert(condition.call(),"online lifecycle condition before deadline")
func run() -> void:
	Catalog.load_all()
	var probe := PacketPeerUDP.new()
	assert(probe.bind(0,"127.0.0.1")==OK)
	var port := probe.get_local_port()
	probe.close()
	server = RoomServer.new()
	server.port = port
	root.add_child(server)
	folder = "user://tests/online-lifecycle-"+RaceSetup.uuid()
	app = load("res://game/client_app.gd").new()
	root.add_child(app)
	await process_frame
	app.data = AppData.new(folder,true)
	app.data.profile.first_run_complete = true
	app.touch_demo = true
	app.show_connection_form()
	app.connect_address("127.0.0.1:"+str(port))
	await until(func() -> bool: return app.page=="lobby")
	var client: NetworkClient = app.network
	var identity := client.guest_id
	var token := client.reconnect_token
	client.command("ready",{"value":true})
	await until(func() -> bool: return server.lobby.all_ready())
	client.command("start")
	await until(func() -> bool: return app.page=="loading")
	app.handle_background()
	await until(func() -> bool: return not server.players[0].connected,750)
	await until(func() -> bool: return app.prepared_world!=null)
	assert(client.loaded_race==client.loading_race and server.session==null,"completed local loading latches readiness without sending while suspended")
	app.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await until(func() -> bool: return client.connected and server.players[0].loaded)
	assert(client.guest_id==identity and server.players.size()==1,"loading resume re-acknowledges preparation for the same reservation")
	await until(func() -> bool: return app.page=="race" and client.phase==RaceSession.Phase.RACING and client.elapsed_ticks>15,12000)
	var slot := client.slot
	var race_uuid: String = server.session.race_uuid
	var player: Dictionary = server.players[0]
	var source_position: Vector3 = server.session.states[slot].position
	app.handle_background()
	assert(client.suspended and not client.connected and app.drive.paused and app.page=="pause")
	var away_at := client.disconnected_at
	var sent := client.wire.sent_bytes
	var sequence := client.sequence
	var ticks := client.tick_counter
	var predicted: Vector3 = client.prediction.state.position
	app.handle_background()
	assert(client.disconnected_at==away_at,"duplicate OS notifications keep the original deadline")
	await until(func() -> bool: return not player.connected,750)
	var disconnected_tick: int = player.disconnected_tick
	await create_timer(.6).timeout
	assert(client.wire.sent_bytes==sent and client.sequence==sequence and client.tick_counter==ticks and client.prediction.state.position==predicted,"no suspended input, heartbeat, retry or prediction")
	assert(server.session.states[slot].position.distance_to(source_position)>.1,"authority bot drives while local simulation is stopped")
	assert(not FileAccess.file_exists(app.data.store.path("suspended_race")),"online state has no local resurrection save")
	app.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	app.drive.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await until(func() -> bool: return client.connected and player.connected and client.resume_count>0 and client.latest_snapshot_tick>disconnected_tick)
	assert(client.guest_id==identity and client.reconnect_token==token and server.players.size()==1 and server.session.race_uuid==race_uuid)
	assert(server.session.roster.size()==8 and app.drive.paused,"reconnect preserves one identity and waits for explicit overlay Resume")
	assert(int(player.control_tick)>disconnected_tick)
	app.resume_drive()
	assert(app.page=="race" and app.drive.resume_ticks==0 and not app.drive.paused,"online Resume never grants a frozen countdown")
	var resumed := client.resume_count
	client.route_changed()
	var route_deadline := client.disconnected_at
	client.route_changed()
	assert(client.disconnected_at==route_deadline,"route changes never extend an existing reservation deadline")
	await until(func() -> bool: return client.connected and client.resume_count>resumed and client.latest_snapshot_tick>disconnected_tick)
	assert(client.guest_id==identity and client.reconnect_token==token and server.players.size()==1 and server.session.race_uuid==race_uuid,"default-route replacement reconnects the same identity and race")
	app.handle_background()
	await until(func() -> bool: return not player.connected,750)
	await create_timer(20.1).timeout
	assert(server.session.states[slot].dnf_reason=="Reconnect expired")
	app.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	await until(func() -> bool: return app.page=="connection_lost")
	assert(app.network==null and app.drive==null and app.data.profile.races_completed==0 and app.data.records.times.is_empty(),"expired local state never manufactures results")
	app.queue_free()
	server.queue_free()
	await create_timer(.6).timeout
	assert(AppData.remove_tree(ProjectSettings.globalize_path(folder))==OK)
	print("REAL_ENET_MOBILE_AWAY_IMMEDIATE_BOT_NO_BACKGROUND_TRAFFIC_SAME_ID_SNAPSHOT_RESUME_EXPIRED_DNF_NO_LOCAL_STATS_PASS")
	quit()

extends SceneTree
var app: Node
var server: RoomServer
var folder: String
func _initialize() -> void: call_deferred("run")
func until(condition: Callable) -> void:
	var deadline := Time.get_ticks_msec()+5000
	while not condition.call() and Time.get_ticks_msec()<deadline: await process_frame
	assert(condition.call(),"direct-connect condition before deadline")
func start_server() -> int:
	if is_instance_valid(server): server.free()
	var socket := PacketPeerUDP.new()
	assert(socket.bind(0,"127.0.0.1")==OK)
	var port := socket.get_local_port()
	socket.close()
	server = RoomServer.new()
	server.port = port
	root.add_child(server)
	return port
func run() -> void:
	Catalog.load_all()
	var port := start_server()
	folder = "user://tests/direct-connect-"+RaceSetup.uuid()
	app = load("res://game/client_app.gd").new()
	root.add_child(app)
	await process_frame
	app.data = AppData.new(folder,false)
	app.data.profile.first_run_complete = true
	app.show_connection_form()
	app.connect_address("127.0.0.1:"+str(port))
	var first: NetworkClient = app.network
	# Multiple same-frame presses cannot replace a live attempt or admission.
	for index in range(5): app.connect_address("127.0.0.1:"+str(port))
	assert(app.network==first,"Connect reentry keeps one transport")
	await until(func() -> bool: return first.hello_sent)
	first.set_process(false) # Authority can admit before its Welcome is consumed.
	first.wire.poll()
	first.wire.peer.get_host().flush()
	await until(func() -> bool: return server.players.size()==1)
	assert(app.page=="connect" and first.guest_id.is_empty())
	app.back_action.call() # The keyboard/Android Back route, not just the button.
	first.loading_requested.emit({"track":0,"race":1})
	first.race_started.emit({})
	first.results_received.emit([])
	first.disconnected_permanently.emit("obsolete attempt")
	assert(app.page=="online" and app.network==null)
	assert(app.drive==null and app.track_loader==null,"late callbacks from a cancelled attempt cannot own navigation")
	await until(func() -> bool: return server.players.is_empty())
	assert(not is_instance_valid(first),"Back sends Leave even when Welcome has not been consumed")
	port = start_server()
	app.show_connection_form()
	var address: LineEdit = app.menu.root.find_child("direct_address",true,false)
	var connect_button: Button = app.menu.root.find_child("direct_connect",true,false)
	address.text = "127.0.0.1:"+str(port)
	connect_button.pressed.emit()
	assert(connect_button.disabled and app.network!=null)
	assert(app.connection_back.has_focus(),"pending Connect leaves keyboard focus on the active Back action")
	await until(func() -> bool: return app.page=="lobby")
	var identity: String = app.network.guest_id
	app.connect_address("127.0.0.1:"+str(port))
	assert(app.network.guest_id==identity and server.players.size()==1)
	app.lobby_page.leave()
	await until(func() -> bool: return server.players.is_empty())
	# OS interruption before Welcome explicitly cancels the uncredentialed join.
	port = start_server()
	app.show_connection_form()
	app.connect_address("127.0.0.1:"+str(port))
	var interrupted: NetworkClient = app.network
	await until(func() -> bool: return interrupted.hello_sent)
	interrupted.set_process(false)
	interrupted.wire.poll()
	interrupted.wire.peer.get_host().flush()
	await until(func() -> bool: return server.players.size()==1)
	interrupted.set_suspended(true)
	interrupted.set_suspended(false)
	await until(func() -> bool: return server.players.is_empty())
	assert(interrupted.deliberate_leave and interrupted.reconnect_token.is_empty())
	app.back_action.call()
	# A transport that connects but never sends Welcome still has a hard deadline.
	var silent := ENetMultiplayerPeer.new()
	server.queue_free()
	await process_frame
	var socket := PacketPeerUDP.new()
	assert(socket.bind(0,"127.0.0.1")==OK)
	var silent_port := socket.get_local_port()
	socket.close()
	assert(silent.create_server(silent_port,8,4)==OK)
	app.show_connection_form()
	address = app.menu.root.find_child("direct_address",true,false)
	connect_button = app.menu.root.find_child("direct_connect",true,false)
	address.text = "127.0.0.1:"+str(silent_port)
	connect_button.pressed.emit()
	var pending: NetworkClient = app.network
	var connected_by := Time.get_ticks_msec()+5000
	while not pending.hello_sent and Time.get_ticks_msec()<connected_by:
		silent.poll()
		await process_frame
	assert(pending.hello_sent and not pending.connected and connect_button.disabled)
	var timed_out_by := Time.get_ticks_msec()+11000
	while not pending.deliberate_leave and Time.get_ticks_msec()<timed_out_by:
		silent.poll()
		await process_frame
	await until(func() -> bool: return not connect_button.disabled)
	assert(connect_button.has_focus(),"a timed-out attempt returns focus to Retry")
	assert(app.page=="connect" and pending.deliberate_leave and not pending.is_processing())
	assert(app.connection_label.text==I18n.t("online.timeout"))
	connect_button.pressed.emit()
	assert(app.network!=pending and connect_button.disabled,"explicit Retry creates one new attempt after expiry")
	app.back_action.call()
	silent.close()
	# A terminal error ends the packet batch before a queued stale Welcome.
	var closed := NetworkClient.new()
	var packets: Array[Dictionary] = [
		{"channel":0,"bytes":"PRJS".to_ascii_buffer()+JSON.stringify({"type":"error","message":"fixture failure"}).to_utf8_buffer()},
		{"channel":0,"bytes":"PRJS".to_ascii_buffer()+JSON.stringify({"type":"welcome","id":RaceSetup.uuid(),"slot":0,"race":0,"tick":1,"token":"a".repeat(64)}).to_utf8_buffer()}]
	closed.receive_packets(packets)
	assert(closed.deliberate_leave and not closed.connected and closed.guest_id.is_empty())
	closed.wire.close()
	closed.free()
	app.queue_free()
	await create_timer(.6).timeout
	assert(AppData.remove_tree(ProjectSettings.globalize_path(folder))==OK)
	print("REAL_ENET_DIRECT_CONNECT_SINGLE_ADMISSION_BACK_BACKGROUND_BEFORE_WELCOME_LEAVE_10S_SILENT_TIMEOUT_RETRY_STALE_CALLBACK_BATCH_PASS")
	quit()

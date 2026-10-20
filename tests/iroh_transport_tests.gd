extends SceneTree


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	assert(IrohTransport.available(),"Iroh native runtime is required for this gate")
	var server := WirePeer.new()
	server.replace_peer(IrohTransport.server())
	assert(server.peer!=null)
	var endpoint := str(server.peer.call("connection_string"))
	assert(IrohTransport.valid_endpoint(endpoint))
	var cancelled := IrohTransport.client(endpoint)
	cancelled.close()
	assert(cancelled.get_connection_status()==MultiplayerPeer.CONNECTION_DISCONNECTED,"closing an in-flight connect must cancel it")
	cancelled = null
	var client := WirePeer.new()
	client.replace_peer(IrohTransport.client(endpoint))
	var deadline := Time.get_ticks_msec()+25000
	while (client.active_peers.is_empty() or server.active_peers.is_empty()) and Time.get_ticks_msec()<deadline:
		server.poll()
		client.poll()
		await process_frame
	assert(client.active_peers.has(1) and server.active_peers.has(client.peer.get_unique_id()))
	var received_client: Dictionary = {}
	var received_server: Dictionary = {}
	for index in range(30):
		for channel in range(4):
			var payload := PackedByteArray()
			payload.resize([1200,82,727,64][channel])
			payload.fill(channel+10)
			server.send(client.peer.get_unique_id(),channel,payload,channel==0)
			client.send(1,channel,payload,channel==0)
		for frame in range(3):
			collect(server.poll(),received_server)
			collect(client.poll(),received_client)
			await create_timer(.02).timeout
	deadline = Time.get_ticks_msec()+5000
	while Time.get_ticks_msec()<deadline and (received_client.size()<4 or received_server.size()<4):
		collect(server.poll(),received_server)
		collect(client.poll(),received_client)
		await process_frame
	assert(received_client.size()==4 and received_server.size()==4,"all four raw channels must work in both directions")
	server.disconnect_target(client.peer.get_unique_id())
	deadline = Time.get_ticks_msec()+5000
	while client.peer.get_connection_status()!=MultiplayerPeer.CONNECTION_DISCONNECTED and Time.get_ticks_msec()<deadline:
		client.poll()
		await process_frame
	assert(client.peer.get_connection_status()==MultiplayerPeer.CONNECTION_DISCONNECTED)
	client.close()
	server.close()
	print("Iroh raw transport: four bidirectional channels, 1200-byte reliable / 727-byte snapshots, connect cancellation and forced disconnect pass")
	quit()


func collect(packets: Array[Dictionary], counts: Dictionary) -> void:
	for packet: Dictionary in packets:
		var channel: int = packet.channel
		assert(channel>=0 and channel<4)
		assert(packet.bytes.size()==[1200,82,727,64][channel])
		for value: int in packet.bytes: assert(value==channel+10)
		counts[channel] = int(counts.get(channel,0))+1

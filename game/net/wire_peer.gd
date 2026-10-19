class_name WirePeer
extends RefCounted
## Raw ENet channels. Fault injection is opt-in and only affects test traffic.

var peer := ENetMultiplayerPeer.new()
var fragments := ReliableFragments.new()
var accept_fragments: bool = false
var pending: Array[Dictionary] = []
var latency_ms: int = 0
var jitter_ms: int = 0
var loss: float = 0.0
var random := RandomNumberGenerator.new()
var sent_bytes: int = 0
var received_bytes: int = 0
var dropped_packets: int = 0
var active_peers: Dictionary = {}


func _init() -> void:
	random.seed = 94723
	peer.peer_connected.connect(func(id: int) -> void: active_peers[id] = true)
	peer.peer_disconnected.connect(func(id: int) -> void: active_peers.erase(id))


func send(target: int, channel: int, bytes: PackedByteArray, reliable: bool = false) -> void:
	if bytes.is_empty() or bytes.size() > 1200:
		return
	if not reliable and random.randf() < loss:
		dropped_packets += 1
		return
	var delay := maxi(0, latency_ms + random.randi_range(-jitter_ms, jitter_ms))
	pending.append({"target":target, "channel":channel, "bytes":bytes, "mode":MultiplayerPeer.TRANSFER_MODE_RELIABLE if reliable else MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED, "due":Time.get_ticks_msec() + delay})


func event(target: int, data: Dictionary, channel: int = 0) -> void:
	var bytes := "PRJS".to_ascii_buffer() + JSON.stringify(data).to_utf8_buffer()
	if bytes.size() <= 1200:
		send(target, channel, bytes, channel == 0)
	elif channel == 0 and data.get("type", "") in ["lobby", "loading", "start", "results"]:
		for part: PackedByteArray in fragments.split(bytes):
			send(target, 0, part, true)


func poll() -> Array[Dictionary]:
	var packets: Array[Dictionary] = []
	if peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		return packets
	peer.poll()
	var now := Time.get_ticks_msec()
	var remainder: Array[Dictionary] = []
	for item: Dictionary in pending:
		if item.due > now or peer.get_connection_status() != MultiplayerPeer.CONNECTION_CONNECTED:
			remainder.append(item)
			continue
		if not active_peers.has(item.target):
			continue
		peer.set_target_peer(item.target)
		peer.transfer_channel = item.channel
		peer.transfer_mode = item.mode
		var error := peer.put_packet(item.bytes)
		if error == OK:
			sent_bytes += item.bytes.size()
	pending = remainder
	while peer.get_available_packet_count() > 0:
		var sender := peer.get_packet_peer()
		var channel := peer.get_packet_channel()
		var bytes := peer.get_packet()
		received_bytes += bytes.size()
		if bytes.size() <= 1200:
			if bytes.slice(0, 4).get_string_from_ascii() == "PRFR":
				if not accept_fragments or channel != 0:
					continue
				bytes = fragments.receive(sender, bytes, now)
				if bytes.is_empty():
					continue
			packets.append({"sender":sender, "channel":channel, "bytes":bytes})
	return packets


static func decode_event(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() < 6 or bytes.size() > ReliableFragments.LIMIT or bytes.slice(0, 4).get_string_from_ascii() != "PRJS":
		return {}
	var parser := JSON.new()
	if parser.parse(bytes.slice(4).get_string_from_utf8()) != OK:
		return {}
	return parser.data if parser.data is Dictionary else {}


func close() -> void:
	peer.close()
	pending.clear()
	fragments.pending.clear()
	for signal_name in ["peer_connected", "peer_disconnected"]:
		for connection: Dictionary in peer.get_signal_connection_list(signal_name):
			peer.disconnect(signal_name, connection.callable)

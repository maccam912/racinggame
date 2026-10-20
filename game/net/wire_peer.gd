class_name WirePeer
extends RefCounted
## Application channels over ENet or Iroh. Fault injection is opt-in.

const RECEIVE_BUDGET: int = 256

var peer: MultiplayerPeer = ENetMultiplayerPeer.new()
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
var racing: bool = false
var rejected_large_racing_events: int = 0
var deferred_receive_passes: int = 0
var discarded_packets: int = 0


func _init() -> void:
	random.seed = 94723
	connect_signals()


func connect_signals() -> void:
	peer.peer_connected.connect(func(id: int) -> void: active_peers[id] = true)
	peer.peer_disconnected.connect(func(id: int) -> void: active_peers.erase(id))


func replace_peer(value: MultiplayerPeer) -> void:
	close()
	peer = value
	connect_signals()


func flush() -> void:
	# QUIC owns its asynchronous send tasks; only ENet has a host to flush.
	if peer is ENetMultiplayerPeer and peer.get_connection_status()==MultiplayerPeer.CONNECTION_CONNECTED:
		peer.get_host().flush()


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
	elif racing:
		rejected_large_racing_events += 1
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
		elif item.mode==MultiplayerPeer.TRANSFER_MODE_RELIABLE and error==ERR_BUSY:
			remainder.append(item)
	pending = remainder
	var scanned := 0
	while peer.get_available_packet_count() > 0 and scanned<RECEIVE_BUDGET:
		scanned += 1
		var sender := peer.get_packet_peer()
		var channel := peer.get_packet_channel()
		var bytes := peer.get_packet()
		received_bytes += bytes.size()
		if bytes.size() <= 1200 and active_peers.has(sender):
			if bytes.slice(0, 4).get_string_from_ascii() == "PRFR":
				if not accept_fragments or channel != 0:
					discarded_packets += 1
					continue
				bytes = fragments.receive(sender, bytes, now)
				if bytes.is_empty():
					continue
			packets.append({"sender":sender, "channel":channel, "bytes":bytes})
		else: discarded_packets += 1
	if peer.get_available_packet_count()>0: deferred_receive_passes += 1
	return packets


static func decode_event(bytes: PackedByteArray) -> Dictionary:
	if bytes.size() < 6 or bytes.size() > ReliableFragments.LIMIT or bytes.slice(0, 4).get_string_from_ascii() != "PRJS":
		return {}
	if not valid_event_text(bytes): return {}
	var parser := JSON.new()
	if parser.parse(bytes.slice(4).get_string_from_utf8()) != OK:
		return {}
	return parser.data if parser.data is Dictionary else {}


static func valid_event_text(bytes: PackedByteArray) -> bool:
	if bytes.has(0) or not valid_utf8(bytes,4): return false
	if not bytes.has(92): return true
	# Godot also replaces/logs JSON's otherwise legal escaped NUL. Protocol
	# strings never need it. An escaped backslash followed by u0000 is literal.
	var index := 4
	while index+1<bytes.size():
		if bytes[index]==92:
			if index+5<bytes.size() and bytes[index+1]==117 and bytes[index+2]==48 and bytes[index+3]==48 and bytes[index+4]==48 and bytes[index+5]==48: return false
			index += 2
		else: index += 1
	return true


static func valid_utf8(bytes: PackedByteArray, offset: int = 0) -> bool:
	# Validate bytes before Godot's decoder can replace/log invalid sequences.
	# Exclude overlong encodings, surrogate code points and values > U+10FFFF.
	if offset<0 or offset>bytes.size(): return false
	var index := offset
	while index<bytes.size():
		var first := bytes[index]
		if first<0x80:
			index += 1
			continue
		var length := 2 if first>=0xc2 and first<=0xdf else 3 if first>=0xe0 and first<=0xef else 4 if first>=0xf0 and first<=0xf4 else 0
		if length==0 or index+length>bytes.size(): return false
		for next in range(index+1,index+length):
			if bytes[next]<0x80 or bytes[next]>0xbf: return false
		var second := bytes[index+1]
		if first==0xe0 and second<0xa0 or first==0xed and second>0x9f or first==0xf0 and second<0x90 or first==0xf4 and second>0x8f: return false
		index += length
	return true


func disconnect_target(id: int) -> void:
	# ENet forced removal does not emit the local peer_disconnected signal.
	# Remove our mirror and queued sends before asking ENet to drop it once.
	if not active_peers.has(id):
		return
	active_peers.erase(id)
	pending = pending.filter(func(item: Dictionary) -> bool: return int(item.target) != id)
	if peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		peer.disconnect_peer(id, true)


func close() -> void:
	peer.close()
	pending.clear()
	fragments.pending.clear()
	active_peers.clear()
	for signal_name in ["peer_connected", "peer_disconnected"]:
		for connection: Dictionary in peer.get_signal_connection_list(signal_name):
			peer.disconnect(signal_name, connection.callable)

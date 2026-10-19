class_name NetworkDeparture
extends Node
## Keep only the departing transport alive until Leave is acknowledged or bounded out.

var wire: WirePeer
var deadline_ms: int


func _ready() -> void:
	deadline_ms = Time.get_ticks_msec() + 2000


func _process(_dt: float) -> void:
	for packet: Dictionary in wire.poll():
		if packet.sender == 1 and packet.channel == 0 and WirePeer.decode_event(packet.bytes).get("type") == "left":
			queue_free()
			return
	if Time.get_ticks_msec() >= deadline_ms or wire.peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		queue_free()


func _exit_tree() -> void:
	wire.close()

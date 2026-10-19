extends SceneTree
## Owned loopback/Android fixture: admit a transport but suppress Welcome.
class SilentAdmission extends RoomServer:
	func broadcast_lobby() -> void:
		last_broadcast = lobby.revision
	func complete_hello(sender: int, player: Dictionary) -> void:
		super.complete_hello(sender,player)
		wire.pending = wire.pending.filter(func(item: Dictionary) -> bool:
			return not WirePeer.decode_event(item.bytes).get("type","") in ["welcome","lobby"])
		print("TEST_ADMITTED_WITHOUT_WELCOME count="+str(players.size()))
var server := SilentAdmission.new()
var output: String = ""
var events: Array[Dictionary] = []
var previous: String = ""
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--admission-report="): output = argument.trim_prefix("--admission-report=")
	assert(not output.is_empty())
	root.add_child(server)
func _process(_dt: float) -> bool:
	if not server.is_inside_tree(): return false
	var humans: Array[Dictionary] = []
	for player: Dictionary in server.players:
		humans.append({"id":player.id,"slot":player.slot,"connected":player.connected})
	var signature := JSON.stringify(humans)
	if signature==previous: return false
	previous = signature
	events.append({"tick":server.tick,"humans":humans})
	var file := FileAccess.open(output,FileAccess.WRITE)
	assert(file!=null)
	file.store_string(JSON.stringify({"events":events,"boundary":"Owned independent real authority, with Welcome/lobby suppressed in this test-only subclass. Normal ping and Leave acknowledgement remain active. No tokens or names."},"  "))
	file.close()
	return false

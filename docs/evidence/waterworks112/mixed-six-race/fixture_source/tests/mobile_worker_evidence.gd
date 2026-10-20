extends SceneTree
## Test-only authority observer for an installed Android handover fixture.
var server := RoomServer.new()
var output: String = ""
var rows: Array[Dictionary] = []
var previous: String = ""
func _initialize() -> void: call_deferred("run")
func run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--authority-report="): output = argument.trim_prefix("--authority-report=")
	assert(not output.is_empty())
	root.add_child(server)
func _process(_dt: float) -> bool:
	if not server.is_inside_tree(): return false
	var humans: Array[Dictionary] = []
	for player: Dictionary in server.players:
		humans.append({"id":player.id,"slot":player.slot,"peer":player.peer,"connected":player.connected})
	var race_uuid := server.session.race_uuid if server.session else ""
	var signature := JSON.stringify({"humans":humans,"race_uuid":race_uuid})
	if signature==previous: return false
	previous = signature
	rows.append({"tick":server.tick,"race_uuid":race_uuid,"humans":humans})
	var file := FileAccess.open(output,FileAccess.WRITE)
	assert(file!=null)
	file.store_string(JSON.stringify({"events":rows,"boundary":"Independent authority observer for owned fixture identities; no reconnect tokens, names, tickets or credentials."},"  "))
	file.close()
	return false

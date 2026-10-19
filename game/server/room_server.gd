extends Node
## Server entry point deliberately has no visual, UI, audio, or font dependencies.

var peer := ENetMultiplayerPeer.new()


func _ready() -> void:
	var port := 27020
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--port="):
			port = int(arg.trim_prefix("--port="))
	if port < 1024 or port > 65535:
		push_error("Invalid worker port")
		get_tree().quit(2)
		return
	var error := peer.create_server(port, 8, 4)
	if error != OK:
		push_error("Cannot bind worker UDP port: %s" % error_string(error))
		get_tree().quit(2)
		return
	multiplayer.multiplayer_peer = peer
	print("PACIFIC_RUSH_SERVER_READY port=%d protocol=1" % port)


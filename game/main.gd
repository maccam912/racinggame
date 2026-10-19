extends Node3D
## Keep the dedicated bootstrap independent of client/UI script dependencies.


func _ready() -> void:
	var server := "--server" in OS.get_cmdline_user_args() or OS.has_feature("dedicated_server")
	var entrypoint := "res://game/server/room_server.gd" if server else "res://game/client_app.gd"
	var script: GDScript = load(entrypoint)
	add_child(script.new())

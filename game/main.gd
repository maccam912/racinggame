extends Node3D
## Keep the dedicated bootstrap independent of client/UI script dependencies.


func _ready() -> void:
	if "--platform-probe" in OS.get_cmdline_user_args():
		if not ClassDB.class_exists("PacificPlatform"):
			push_error("PACIFIC_PLATFORM_MISSING")
			get_tree().quit(1)
			return
		var platform: Object = ClassDB.instantiate("PacificPlatform")
		print("PACIFIC_PLATFORM_READY "+str(platform.backend_name()))
		get_tree().quit()
		return
	var server := "--server" in OS.get_cmdline_user_args() or OS.has_feature("dedicated_server")
	var entrypoint := "res://game/server/room_server.gd" if server else "res://game/client_app.gd"
	var script: GDScript = load(entrypoint)
	add_child(script.new())

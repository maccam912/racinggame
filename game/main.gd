extends Node3D
## Keep the dedicated bootstrap independent of client/UI script dependencies.


func _ready() -> void:
	if "--save-files-probe" in OS.get_cmdline_user_args():
		add_child(load("res://game/platform/save_files_probe.gd").new())
		return
	if "--protected-store-probe" in OS.get_cmdline_user_args():
		add_child(load("res://game/platform/protected_store_probe.gd").new())
		return
	if "--platform-probe" in OS.get_cmdline_user_args():
		if not ClassDB.class_exists("PacificPlatform") or not ClassDB.class_exists("PacificSaveFiles"):
			push_error("PACIFIC_PLATFORM_MISSING")
			get_tree().quit(1)
			return
		var platform: Object = ClassDB.instantiate("PacificPlatform")
		if not platform.has_method("screen_modes") or platform.screen_modes(-1,0,0,0,0)!=[]:
			push_error("PACIFIC_PLATFORM_DISPLAY_API_MISSING")
			get_tree().quit(1)
			return
		print("PACIFIC_PLATFORM_READY "+str(platform.backend_name()))
		get_tree().quit()
		return
	var server := "--server" in OS.get_cmdline_user_args() or OS.has_feature("dedicated_server")
	var entrypoint := "res://game/server/room_server.gd" if server else "res://game/client_app.gd"
	var script: GDScript = load(entrypoint)
	var application: Node = script.new()
	add_child(application)
	if not server:
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--smoke-frames="):
				var frames := clampi(int(argument.trim_prefix("--smoke-frames=")),1,600)
				await get_tree().create_timer(frames/60.0).timeout
				application.finish_quit()

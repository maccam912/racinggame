extends Node3D


func _ready() -> void:
	if "--server" in OS.get_cmdline_user_args() or OS.has_feature("dedicated_server"):
		var server := preload("res://game/server/room_server.gd").new()
		add_child(server)
		return
	var label := Label.new()
	label.text = "PACIFIC RUSH\nToolchain & content foundation\nDriving slice in development"
	label.position = Vector2(80, 80)
	label.add_theme_font_size_override("font_size", 36)
	add_child(label)
	print("PACIFIC_RUSH_CLIENT_READY")


extends Node3D

var menu: CanvasLayer
var drive: RaceDrive
var touch_demo: bool = false
var reduce_motion: bool = false
var capture_path: String = ""
var rendered_frames: int = 0


func _ready() -> void:
	if "--server" in OS.get_cmdline_user_args() or OS.has_feature("dedicated_server"):
		var server := preload("res://game/server/room_server.gd").new()
		add_child(server)
		return
	Catalog.load_all()
	DrivingInput.register_defaults()
	touch_demo = "--touch" in OS.get_cmdline_user_args()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			capture_path = arg.trim_prefix("--capture=")
	if "--drive" in OS.get_cmdline_user_args():
		start_drive()
	else:
		show_menu()
	print("PACIFIC_RUSH_CLIENT_READY")


func show_menu() -> void:
	menu = CanvasLayer.new()
	add_child(menu)
	var background := ColorRect.new()
	background.color = Color.html("172C40")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(background)
	var list := VBoxContainer.new()
	list.position = Vector2(100, 60)
	list.custom_minimum_size.x = 640
	list.add_theme_constant_override("separation", 20)
	menu.add_child(list)
	var title := Label.new()
	title.text = "PACIFIC\nRUSH"
	title.add_theme_font_size_override("font_size", 84)
	title.add_theme_color_override("font_color", Color.html("F3CD48"))
	list.add_child(title)
	var caption := Label.new()
	caption.text = "SUNNY COAST. CLEAN LINES. FULL THROTTLE.\n3D driving slice • Comet • Palm Bay"
	caption.add_theme_font_size_override("font_size", 24)
	list.add_child(caption)
	var start := Button.new()
	start.text = "Drive Palm Bay  →"
	start.custom_minimum_size = Vector2(440, 64)
	start.add_theme_font_size_override("font_size", 30)
	start.pressed.connect(start_drive)
	list.add_child(start)
	var motion := CheckButton.new()
	motion.text = "Reduce Motion"
	motion.button_pressed = reduce_motion
	motion.toggled.connect(func(value: bool) -> void: reduce_motion = value)
	list.add_child(motion)
	var touch_toggle := CheckButton.new()
	touch_toggle.text = "Show touch controls / auto acceleration"
	touch_toggle.button_pressed = touch_demo
	touch_toggle.toggled.connect(func(value: bool) -> void: touch_demo = value)
	list.add_child(touch_toggle)
	start.grab_focus()


func start_drive() -> void:
	if is_instance_valid(menu):
		menu.queue_free()
	if is_instance_valid(drive):
		drive.queue_free()
	drive = RaceDrive.new()
	drive.show_touch = touch_demo
	drive.reduce_motion = reduce_motion
	drive.leave_requested.connect(return_to_menu)
	add_child(drive)


func return_to_menu() -> void:
	if is_instance_valid(drive):
		drive.queue_free()
		drive = null
	show_menu()


func _process(_dt: float) -> void:
	if capture_path.is_empty():
		return
	rendered_frames += 1
	if rendered_frames == 150:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(capture_path)
		print("PACIFIC_RUSH_CAPTURE_SAVED")
		get_tree().quit()


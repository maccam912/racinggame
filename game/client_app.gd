extends Node3D

var menu: CanvasLayer
var drive: RaceDrive
var touch_demo: bool = false
var reduce_motion: bool = false
var capture_path: String = ""
var rendered_frames: int = 0
var capture_frame: int = 150
var network: NetworkClient
var connection_label: Label


func _ready() -> void:
	Catalog.load_all()
	DrivingInput.register_defaults()
	touch_demo = "--touch" in OS.get_cmdline_user_args()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--capture="):
			capture_path = arg.trim_prefix("--capture=")
		elif arg.begins_with("--capture-frame="):
			capture_frame = maxi(1, int(arg.trim_prefix("--capture-frame=")))
	if "--drive" in OS.get_cmdline_user_args():
		start_drive()
	else:
		show_menu()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--connect="):
			show_connection_form()
			connect_address(arg.trim_prefix("--connect="))
	print("PACIFIC_RUSH_CLIENT_READY")


func show_menu() -> void:
	if is_instance_valid(menu):
		menu.queue_free()
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
	var connect_button := Button.new()
	connect_button.text = "Direct Connect  •  Community server"
	connect_button.custom_minimum_size.y = 54
	connect_button.pressed.connect(show_connection_form)
	list.add_child(connect_button)
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
	if is_instance_valid(network):
		network.queue_free()
		network = null
	if is_instance_valid(drive):
		drive.queue_free()
		drive = null
	show_menu()


func show_connection_form() -> void:
	if is_instance_valid(menu):
		menu.queue_free()
	menu = CanvasLayer.new()
	add_child(menu)
	var background := ColorRect.new()
	background.color = Color.html("172C40")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(background)
	var list := VBoxContainer.new()
	list.position = Vector2(160, 150)
	list.custom_minimum_size.x = 900
	list.add_theme_constant_override("separation", 20)
	menu.add_child(list)
	var title := Label.new()
	title.text = "DIRECT CONNECT"
	title.add_theme_font_size_override("font_size", 48)
	list.add_child(title)
	var address := LineEdit.new()
	address.placeholder_text = "hostname:27020 or [IPv6]:27020"
	address.text = "127.0.0.1:27020"
	address.custom_minimum_size.y = 64
	address.add_theme_font_size_override("font_size", 28)
	list.add_child(address)
	connection_label = Label.new()
	connection_label.text = "Community server • two racers start the M2 test race."
	connection_label.add_theme_font_size_override("font_size", 24)
	list.add_child(connection_label)
	for text: String in ["Connect / Retry", "Back"]:
		var button := Button.new()
		button.text = text
		button.custom_minimum_size.y = 60
		button.pressed.connect(func() -> void: connect_address(address.text)) if text.begins_with("Connect") else button.pressed.connect(return_to_menu)
		list.add_child(button)
	address.grab_focus()


func connect_address(value: String) -> void:
	var address := PeerAddress.parse(value)
	if address.is_empty():
		connection_label.text = "Enter hostname:port, or [IPv6]:port. Port must be 1–65535."
		return
	if is_instance_valid(network):
		network.queue_free()
	network = NetworkClient.new()
	add_child(network)
	network.race_started.connect(func(_config: Dictionary) -> void:
		if is_instance_valid(menu):
			menu.queue_free()
		drive = RaceDrive.new()
		drive.network = network
		drive.show_touch = touch_demo
		drive.reduce_motion = reduce_motion
		drive.leave_requested.connect(return_to_menu)
		add_child(drive))
	network.status_changed.connect(func(message: String) -> void:
		if is_instance_valid(connection_label):
			connection_label.text = message
		print("NETWORK_STATUS " + message))
	network.connect_to(address.host, address.port, "Driver")


func _process(_dt: float) -> void:
	if capture_path.is_empty():
		return
	rendered_frames += 1
	if rendered_frames == capture_frame:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(capture_path)
		print("PACIFIC_RUSH_CAPTURE_SAVED")
		get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_inside_tree():
		if is_instance_valid(drive):
			if drive.paused:
				drive.resume()
			else:
				drive.show_pause()
		else:
			return_to_menu()


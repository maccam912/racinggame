class_name RaceDrive
extends Node3D

signal leave_requested

var state := VehicleState.new()
var frame := InputFrame.make()
var driver := DrivingInput.new()
var track: TrackDefinition
var car: CarDefinition
var world := TrackWorld.new()
var query: WorldQuery
var visual := CarVisual.new()
var camera := ChaseCamera.new()
var hud := RaceHUD.new()
var touch := TouchDriving.new()
var ui := CanvasLayer.new()
var phase: String = "Grid"
var phase_ticks: int = 0
var race_ticks: int = 0
var lap_count: int = 2
var paused: bool = false
var pause_panel: Control
var resume_ticks: int = 0
var show_touch: bool = false
var reduce_motion: bool = false


func _ready() -> void:
	track = Catalog.tracks[0]
	car = Catalog.cars[0]
	world.build(track)
	add_child(world)
	var pose := track.pose(-8, -2.5)
	state.position = pose.origin + Vector3.UP * .35
	state.yaw = atan2(-pose.basis.z.x, pose.basis.z.z)
	query = WorldQuery.new(get_world_3d(), track, -8)
	visual.build(Catalog.paints[0])
	add_child(visual)
	add_child(camera)
	camera.current = true
	camera.reduce_motion = reduce_motion
	add_child(ui)
	hud.track = track
	hud.state = state
	hud.lap_count = lap_count
	ui.add_child(hud)
	ui.add_child(touch)
	touch.visible = show_touch or OS.has_feature("mobile")
	touch.auto_accelerate = touch.visible
	touch.action_pressed.connect(touch_action)
	var help := Label.new()
	help.text = "W / ↑  Accelerate     A D / ← →  Steer     S / ↓  Brake     SPACE  Slide     Hold R  Recover     C  Camera     ESC  Pause"
	help.add_theme_font_size_override("font_size", 16)
	help.position = Vector2(180, 690)
	help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(help)
	if touch.visible:
		help.hide()
	print("PACIFIC_RUSH_DRIVING_READY")


func _physics_process(_dt: float) -> void:
	if paused:
		return
	if resume_ticks > 0:
		resume_ticks -= 1
		hud.phase = "Countdown"
		hud.phase_ticks = 180 - resume_ticks
		return
	if phase in ["Grid", "Countdown"]:
		phase_ticks += 1
		if phase == "Grid" and phase_ticks >= 120:
			phase = "Countdown"
			phase_ticks = 0
		elif phase == "Countdown" and phase_ticks >= 180:
			phase = "Racing"
			phase_ticks = 0
		frame = InputFrame.make()
	elif phase == "Racing" and not state.finished:
		race_ticks += 1
		frame = driver.sample(true, touch if touch.visible else null)
		var previous := state.position
		VehicleSim.step(state, frame, car, query)
		ProgressTracker.advance(state, previous, track, race_ticks, lap_count)
		ProgressTracker.safety(state, frame, track, query)
		if "recovery" in state.events:
			touch.clear()
		if state.finished:
			show_pause(true)
	hud.ticks = race_ticks
	hud.phase = phase
	hud.phase_ticks = phase_ticks
	hud.queue_redraw()


func _process(dt: float) -> void:
	visual.present(state, frame, dt)
	camera.follow(state, dt, Input.is_action_pressed("look_back") or touch.held("look_back"))


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if paused:
			resume()
		else:
			show_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("camera") and not paused:
		camera.mode = (camera.mode + 1) % 3


func touch_action(action: String) -> void:
	if action == "pause":
		show_pause()
	elif action == "camera":
		camera.mode = (camera.mode + 1) % 3


func show_pause(finished: bool = false) -> void:
	if paused:
		return
	paused = true
	touch.clear()
	touch.enabled = false
	frame = InputFrame.make()
	pause_panel = PanelContainer.new()
	pause_panel.position = Vector2(440, 170)
	pause_panel.custom_minimum_size = Vector2(400, 330)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 16)
	pause_panel.add_child(list)
	var title := Label.new()
	title.text = "FINISH  " + hud.time(state.finish_time) if finished else "PAUSED"
	title.add_theme_font_size_override("font_size", 36)
	list.add_child(title)
	if not finished:
		button(list, "Resume", resume)
	button(list, "Restart", restart)
	button(list, "Main Menu", func() -> void: leave_requested.emit())
	ui.add_child(pause_panel)
	list.get_child(1).grab_focus()


func button(parent: Node, text: String, action: Callable) -> void:
	var control := Button.new()
	control.text = text
	control.custom_minimum_size = Vector2(350, 54)
	control.add_theme_font_size_override("font_size", 24)
	control.pressed.connect(action)
	parent.add_child(control)


func resume() -> void:
	if state.finished:
		return
	paused = false
	touch.enabled = true
	touch.clear()
	if pause_panel:
		pause_panel.queue_free()
	resume_ticks = 180


func restart() -> void:
	get_parent().call_deferred("start_drive")


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED] and is_inside_tree() and not Array(OS.get_cmdline_user_args()).any(func(arg: String) -> bool: return arg.begins_with("--capture=")):
		show_pause()

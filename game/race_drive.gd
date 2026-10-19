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
var session: RaceSession
var network: NetworkClient
var remote_visuals: Dictionary = {}
var demo_driver := BotDriver.new()


func _ready() -> void:
	track = Catalog.tracks[0]
	car = Catalog.cars[0]
	world.build(track)
	add_child(world)
	session = RaceSession.new()
	var cars: Array[int] = [0]
	if network:
		cars.clear()
		for _racer in range(int(network.config.count)):
			cars.append(0)
		lap_count = int(network.config.laps)
	session.setup(track, cars, get_world_3d(), lap_count)
	state = session.states[network.slot if network else 0]
	query = session.queries[network.slot if network else 0]
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
	hud.mobile = touch.visible
	hud.mobile_unit = touch.unit
	hud.racers = session.states.size()
	touch.action_pressed.connect(touch_action)
	var help := Label.new()
	help.text = "W / ↑  Accelerate     A D / ← →  Steer     S / ↓  Brake     SPACE  Slide     Hold R  Recover     C  Camera     ESC  Pause"
	help.add_theme_font_size_override("font_size", 16)
	help.position = Vector2(180, 690)
	help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(help)
	if touch.visible:
		help.hide()
	if network:
		network.attach_prediction(state, car, query, track, lap_count)
		network.input_provider = func() -> InputFrame: return driver.sample(not paused, touch if touch.visible else null)
		if "--autodrive" in OS.get_cmdline_user_args():
			network.input_provider = func() -> InputFrame: return demo_driver.sample(state, car, track, query)
			state.trial_valid = false
		for index in range(session.states.size()):
			if index == state.slot:
				continue
			var rival := CarVisual.new()
			rival.build(Catalog.paints[(index + 1) % 8])
			remote_visuals[index] = rival
			add_child(rival)
	print("PACIFIC_RUSH_DRIVING_READY")


func _physics_process(_dt: float) -> void:
	if network:
		race_ticks = network.prediction.elapsed_ticks
		phase = ["Lobby", "Loading", "Grid", "Countdown", "Racing", "Finish Grace", "Results"][network.phase]
		phase_ticks = maxi(0, roundi(network.server_tick) - network.start_tick - 120)
		hud.ticks = race_ticks
		hud.phase = phase
		hud.phase_ticks = phase_ticks
		hud.queue_redraw()
		return
	if paused:
		return
	if resume_ticks > 0:
		resume_ticks -= 1
		hud.phase = "Countdown"
		hud.phase_ticks = 180 - resume_ticks
		return
	frame = driver.sample(session.phase in [RaceSession.Phase.RACING, RaceSession.Phase.GRACE], touch if touch.visible else null)
	if "--autodrive" in OS.get_cmdline_user_args():
		frame = demo_driver.sample(state, car, track, query)
		state.trial_valid = false
	session.step({0:frame})
	race_ticks = session.elapsed_ticks
	phase = ["Lobby", "Loading", "Grid", "Countdown", "Racing", "Finish Grace", "Results"][session.phase]
	phase_ticks = session.phase_ticks
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
	var rendered := state
	if network and network.prediction:
		rendered = state.copy()
		rendered.position += network.prediction.render_offset(dt)
		visual.position = rendered.position
		hud.rivals.clear()
		for slot: int in remote_visuals:
			var rival := network.remotes.sample(slot, network.server_tick)
			if rival:
				remote_visuals[slot].present(rival, InputFrame.make(), dt)
				hud.rivals.append(rival)
	camera.follow(rendered, dt, Input.is_action_pressed("look_back") or touch.held("look_back"))


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
	title.text = "FINISH  " + hud.time(state.finish_time) if finished else "RACE CONTINUES ONLINE" if network else "PAUSED"
	title.add_theme_font_size_override("font_size", 36)
	list.add_child(title)
	if not finished:
		button(list, "Resume", resume)
	if not network:
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
	resume_ticks = 0 if network else 180


func restart() -> void:
	get_parent().call_deferred("start_drive")


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED] and is_inside_tree() and not Array(OS.get_cmdline_user_args()).any(func(arg: String) -> bool: return arg.begins_with("--capture=")):
		show_pause()

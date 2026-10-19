class_name RaceDrive
extends Node3D

signal leave_requested
signal pause_requested
signal results_ready
signal school_completed
signal school_skipped

var config: Dictionary = {}
var app_data: AppData
var external_menus: bool = false
var result_sent: bool = false
var ghost_samples: Array[Dictionary] = []
var best_ghost: Dictionary = {}
var ghost_visual: CarVisual
var local_slot: int = 0
var show_ghost: bool = true
var lesson: SchoolLesson
var school_overlay: SchoolOverlay
var spectator_slot: int = -1
var spectator_button: Button
var help_label: Label

var state := VehicleState.new()
var frame := InputFrame.make()
var driver := DrivingInput.new()
var track: TrackDefinition
var car: CarDefinition
var world: TrackWorld
var prepared_world: TrackWorld
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
	if network:
		config = network.config.duplicate(true)
		config.mode = "online"
		config.car = int(config.roster[network.slot].car)
		config.paint = int(config.roster[network.slot].paint)
	track = Catalog.tracks[int(config.get("track", 0))]
	var selected_car := int(config.get("car", 0))
	car = Catalog.cars[selected_car]
	lap_count = int(config.get("laps", 2))
	if prepared_world:
		world = prepared_world
		if world.get_parent():
			world.get_parent().remove_child(world)
	else:
		world = TrackWorld.new()
		world.build(track)
	add_child(world)
	session = RaceSession.new()
	var roster: Array[Dictionary] = []
	roster.assign(config.get("roster", RaceSetup.roster(int(config.get("opponents", 0)), selected_car, int(config.get("paint", 0)), "Driver")))
	var cars := RaceSetup.car_indices(roster)
	if network:
		cars = RaceSetup.car_indices(roster)
		lap_count = int(network.config.laps)
		local_slot = network.slot
	else:
		for index in range(roster.size()):
			if not roster[index].bot:
				local_slot = index
	session.setup(track, cars, get_world_3d(), lap_count)
	session.mode = config.get("mode", "quick")
	session.race_uuid = config.get("race_uuid", RaceSetup.uuid())
	session.cup_event = int(config.get("cup_event", -1))
	session.event_uuid = str(config.get("cup_id", ""))
	session.seed = int(config.get("seed", 1))
	session.roster = roster
	session.human_slot = local_slot
	session.contact_enabled = bool(config.get("contact", true)) and session.mode != "trial"
	if not network:
		session.configure_bots(roster, local_slot, int(config.get("difficulty", 1)))
	state = session.states[local_slot]
	query = session.queries[local_slot]
	if session.mode == "school":
		lesson = SchoolLesson.new()
		lesson.configure(int(config.get("lesson", 0)), track)
		var pose := track.pose(lesson.spawn_s)
		state.position = pose.origin + Vector3.UP * .35
		state.yaw = atan2(-pose.basis.z.x, pose.basis.z.z)
		state.route_s = lesson.spawn_s
		query.hint = track.sample_index(lesson.spawn_s)
		session.phase = RaceSession.Phase.RACING
		session.contact_enabled = false
		for marker: Vector3 in lesson.markers:
			for side in [-4, 4]:
				var cone := MeshInstance3D.new()
				var mesh := CylinderMesh.new()
				mesh.top_radius = .05
				mesh.bottom_radius = .45
				mesh.height = 1.2
				cone.mesh = mesh
				cone.material_override = world.material(UIFactory.CORAL)
				cone.position = marker + Vector3(side, .6, 0)
				world.add_child(cone)
	visual.build(Catalog.paints[int(config.get("paint", 0))])
	add_child(visual)
	for index in range(session.states.size()):
		if index == local_slot:
			continue
		var rival := CarVisual.new()
		rival.build(Catalog.paints[int(roster[index].paint) if not network else (index + 1) % 8])
		remote_visuals[index] = rival
		add_child(rival)
	if session.mode == "trial" and app_data and bool(config.get("ghost", true)):
		best_ghost = app_data.load_ghost(track.id, car.id)
		if not best_ghost.is_empty():
			ghost_visual = CarVisual.new()
			ghost_visual.build(Catalog.paints[int(config.get("paint", 0))])
			ghost_visual.set_ghost(.35)
			add_child(ghost_visual)
	add_child(camera)
	camera.current = true
	camera.reduce_motion = reduce_motion
	add_child(ui)
	hud.track = track
	hud.state = state
	hud.lap_count = lap_count
	ui.add_child(hud)
	spectator_button = Button.new()
	spectator_button.text = I18n.t("hud.next_racer")
	spectator_button.position = Vector2(540, 110)
	spectator_button.custom_minimum_size = Vector2(180, 48)
	spectator_button.hide()
	spectator_button.pressed.connect(next_racer)
	ui.add_child(spectator_button)
	ui.add_child(touch)
	if lesson:
		hud.hide()
		school_overlay = SchoolOverlay.new()
		school_overlay.lesson = lesson
		school_overlay.state = state
		school_overlay.unit = touch.unit if show_touch or OS.has_feature("mobile") else (float(app_data.settings.ui_scale) / 100 if app_data else 1.0)
		ui.add_child(school_overlay)
		var skip := Button.new()
		skip.text = I18n.t("button.skip")
		skip.position = Vector2(30, 30)
		skip.custom_minimum_size = Vector2(120, 48)
		skip.pressed.connect(func() -> void: school_skipped.emit())
		ui.add_child(skip)
	touch.visible = show_touch or OS.has_feature("mobile")
	touch.auto_accelerate = touch.visible
	hud.mobile = touch.visible
	hud.mobile_unit = touch.unit
	hud.racers = session.states.size()
	hud.trial = session.mode == "trial"
	apply_settings()
	driver.attach_touch(touch)
	driver.device_changed.connect(func(_device: String) -> void: update_control_hints())
	Input.joy_connection_changed.connect(controller_connection)
	touch.action_pressed.connect(touch_action)
	help_label = Label.new()
	help_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	help_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_label.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ui.add_child(help_label)
	get_viewport().size_changed.connect(update_control_hints)
	update_control_hints()
	if network:
		network.attach_prediction(state, car, query, track, lap_count)
		network.input_provider = func() -> InputFrame: return driver.sample(not paused and state.recovery_ticks == 0, touch if touch.visible else null)
		if "--autodrive" in OS.get_cmdline_user_args():
			network.input_provider = func() -> InputFrame: return demo_driver.sample(state, car, track, query)
			state.trial_valid = false
	print("PACIFIC_RUSH_DRIVING_READY")


func _physics_process(_dt: float) -> void:
	if network:
		race_ticks = network.prediction.elapsed_ticks
		if not result_sent and not network.latest_snapshot.is_empty():
			session.states.assign(network.latest_snapshot.states)
			var ranking := session.standings()
			for index in range(ranking.size()):
				if ranking[index].slot == state.slot:
					hud.rank = index + 1
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
	frame = driver.sample(session.phase in [RaceSession.Phase.RACING, RaceSession.Phase.GRACE] and state.recovery_ticks == 0, touch if touch.visible else null)
	if "--autodrive" in OS.get_cmdline_user_args():
		frame = demo_driver.sample(state, car, track, query)
		state.trial_valid = false
	var previous := state.copy()
	if session.mode == "trial" and session.phase == RaceSession.Phase.RACING and session.elapsed_ticks == 0:
		ghost_samples.append({"time":0.0, "position":state.position, "yaw":state.yaw})
	if lesson:
		VehicleSim.step(state, frame, car, query)
		ProgressTracker.safety(state, frame, track, query)
		lesson.update(state, frame, track)
		if lesson.done and not result_sent:
			result_sent = true
			paused = true
			touch.clear()
			school_completed.emit()
		return
	session.step({local_slot:frame})
	if session.mode == "trial" and session.elapsed_ticks > 0 and not previous.finished:
		if state.finished:
			var alpha := clampf(state.finish_time * 60 - (session.elapsed_ticks - 1), 0, 1)
			ghost_samples.append({"time":state.finish_time, "position":previous.position.lerp(state.position, alpha), "yaw":lerp_angle(previous.yaw, state.yaw, alpha)})
		elif session.elapsed_ticks % 3 == 0:
			ghost_samples.append({"time":session.elapsed_ticks / 60.0, "position":state.position, "yaw":state.yaw})
	race_ticks = session.elapsed_ticks
	phase = ["Lobby", "Loading", "Grid", "Countdown", "Racing", "Finish Grace", "Results"][session.phase]
	phase_ticks = session.phase_ticks
	if "recovery" in state.events:
		touch.clear()
	if session.phase == RaceSession.Phase.RESULTS and not result_sent:
		result_sent = true
		touch.clear()
		touch.enabled = false
		results_ready.emit()
		if not external_menus:
			show_pause(true)
	hud.ticks = race_ticks
	hud.phase = phase
	hud.phase_ticks = phase_ticks
	hud.rank = session.standings().find(state) + 1
	hud.queue_redraw()


func _process(dt: float) -> void:
	var rendered := state
	if spectator_button:
		spectator_button.visible = state.finished and session.states.size() > 1 and not paused and not result_sent
	if not network:
		hud.rivals.clear()
		for slot: int in remote_visuals:
			remote_visuals[slot].present(session.states[slot], session.inputs[slot], dt)
			hud.rivals.append(session.states[slot])
	if ghost_visual:
		var pose := GhostCodec.at_time(best_ghost, race_ticks / 60.0)
		var ghost_state := VehicleState.new()
		ghost_state.position = pose.position
		ghost_state.yaw = pose.yaw
		ghost_visual.present(ghost_state, InputFrame.make(), dt)
		ghost_visual.visible = show_ghost and race_ticks / 60.0 <= float(best_ghost.time)
	if network and network.prediction:
		if state.finished or state.dnf_reason != "":
			var buffered := network.remotes.sample(state.slot, network.server_tick)
			if buffered:
				rendered = buffered
		else:
			rendered = state.copy()
			rendered.position += network.prediction.render_offset(dt)
		hud.rivals.clear()
		for slot: int in remote_visuals:
			var rival := network.remotes.sample(slot, network.server_tick)
			if rival:
				remote_visuals[slot].present(rival, InputFrame.make(), dt)
				hud.rivals.append(rival)
	visual.present(rendered, frame, dt)
	var target := rendered
	if state.finished and spectator_slot >= 0 and spectator_slot != state.slot:
		var spectated: VehicleState = network.remotes.sample(spectator_slot, network.server_tick) if network else session.states[spectator_slot]
		if spectated and not spectated.finished and spectated.dnf_reason == "":
			target = spectated
		else:
			spectator_slot = state.slot
	camera.follow(target, dt, driver.held("look_back", touch if touch.visible else null))


func _input(event: InputEvent) -> void:
	if not paused:
		driver.observe(event)


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
	driver.context_reset(network != null)
	touch.clear()
	touch.enabled = false
	frame = InputFrame.make()
	if external_menus:
		pause_requested.emit()
		return
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
	paused = false
	driver.context_reset(network != null)
	if network:
		hud.control_notice = I18n.t("hud.controls_active")
		hud.notice_until_ms = Time.get_ticks_msec() + 500
	touch.enabled = true
	touch.clear()
	if pause_panel:
		pause_panel.queue_free()
	resume_ticks = 0 if network else 180


func restart() -> void:
	get_parent().call_deferred("start_drive")


func _notification(what: int) -> void:
	if not is_inside_tree():
		return
	if what in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED]:
		driver.set_focus(true)
	elif what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED] and not Array(OS.get_cmdline_user_args()).any(func(arg: String) -> bool: return arg.begins_with("--capture=")):
		driver.set_focus(false)
		show_pause()


func controller_connection(device: int, connected: bool) -> void:
	if connected or driver.owner_device != "gamepad" or driver.joy_device != device:
		return
	driver.claim("keyboard")
	driver.context_reset(network != null)
	if network:
		hud.control_notice = I18n.t("hud.controller_lost")
		hud.notice_until_ms = Time.get_ticks_msec() + 5000
	else:
		show_pause()


func apply_settings() -> void:
	if app_data == null:
		return
	var settings := app_data.settings
	BindingBook.apply(settings.bindings)
	SettingsRuntime.apply(self, settings)
	reduce_motion = bool(settings.reduce_motion)
	camera.reduce_motion = reduce_motion
	camera.base_fov = float(settings.base_fov)
	camera.dynamic_fov = bool(settings.dynamic_fov)
	camera.mode = ["near", "far", "hood"].find(settings.camera)
	camera.far = float(settings.draw_distance)
	hud.mph = settings.units == "mph"
	driver.auto_accelerate = bool(settings.auto_accelerate)
	driver.deadzone = float(settings.deadzone)
	driver.sensitivity = float(settings.sensitivity)
	touch.auto_accelerate = bool(settings.get("touch_auto_accelerate", true)) if touch.visible else false
	touch.steering_style = str(settings.get("steering_style", "slider"))
	touch.button_scale = float(settings.get("button_size", 100)) / 100
	touch.opacity = float(settings.get("opacity", 60)) / 100
	touch.left_handed = bool(settings.get("left_handed", false))
	touch.rebuild()
	update_control_hints()


func next_racer() -> void:
	if not state.finished:
		return
	var candidates: Array[int] = []
	for rival: VehicleState in session.states:
		if not rival.finished and rival.dnf_reason == "" and rival.slot != state.slot:
			candidates.append(rival.slot)
	candidates.sort()
	candidates.append(state.slot)
	spectator_slot = candidates[(candidates.find(spectator_slot) + 1) % candidates.size()]
	camera.initialized = false


func update_control_hints() -> void:
	var values: Dictionary = app_data.settings if app_data else SettingsCatalog.defaults(OS.has_feature("mobile"))
	var book := BindingBook.sanitize(values.bindings)
	var device_name := driver.owner_device
	var icons := str(values.prompts)
	if device_name != "touch":
		if icons == "keyboard":
			device_name = "keyboard"
		elif icons in ["xbox","playstation"]:
			device_name = "gamepad"
	var hints: Dictionary = {}
	for action: String in BindingBook.DRIVING:
		if device_name == "touch":
			hints[action] = I18n.t("touch.hint." + action)
			if action == "accelerate" and touch.auto_accelerate:
				hints[action] = I18n.t("touch.hint.auto")
		else:
			var labels: Array[String] = []
			for binding: Variant in book[device_name][action]:
				if binding != null:
					labels.append(BindingBook.caption(binding, icons))
			hints[action] = " / ".join(labels) if not labels.is_empty() else I18n.t("binding.empty")
	if is_instance_valid(school_overlay):
		school_overlay.hints = hints
	if not is_instance_valid(help_label):
		return
	help_label.visible = not touch.visible and lesson == null and bool(values.driving_hints)
	var parts: Array[String] = []
	for action: String in ["accelerate","steer_left","steer_right","brake","handbrake","recover","camera","look_back","pause"]:
		parts.append(I18n.t("action." + action) + ": " + str(hints[action]))
	help_label.text = "   •   ".join(parts)
	help_label.add_theme_font_override("font",load("res://assets/fonts/Barlow-SemiBold.ttf"))
	help_label.add_theme_font_size_override("font_size",int(16 * float(values.ui_scale) / 100))
	help_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	var canvas := get_viewport().get_visible_rect().size
	help_label.offset_left = canvas.x * .25
	help_label.offset_right = -canvas.x * .25
	help_label.offset_top = -100 * float(values.ui_scale) / 100
	help_label.offset_bottom = -15

extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var app: Node = load("res://game/client_app.gd").new()
	app.capture_path = "user://unused-accessibility-fixture.png"
	app.capture_frame = 1000000
	root.add_child(app)
	await process_frame
	var folder := "user://tests/accessibility-"+RaceSetup.uuid()
	app.data = AppData.new(folder,false)
	app.data.settings.trial_ghost = false
	var receipt := RaceSession.new()
	receipt.track = Catalog.tracks[0]
	receipt.cars = [Catalog.cars[0]]
	receipt.mode = "trial"
	receipt.race_uuid = RaceSetup.uuid()
	var finished := VehicleState.new()
	finished.finished = true
	finished.finish_time = .2
	receipt.states = [finished]
	var samples: Array[Dictionary] = []
	for index in range(5): samples.append({"time":index*.05,"position":receipt.track.pose(0).origin,"yaw":0.0})
	assert(app.data.commit_result(receipt,samples).saved)
	app.start_drive({"mode":"trial","track":0,"car":0,"laps":1})
	app.drive.set_physics_process(false)
	assert(not app.drive.show_ghost and not app.pending_config.ghost,"trial entry uses the global preference")
	assert(not app.drive.best_ghost.is_empty() and is_instance_valid(app.drive.ghost_visual) and not app.drive.ghost_visual.visible,"a hidden matching ghost stays available to the pause toggle")
	app.set_trial_ghost(true)
	app.drive._process(.016)
	assert(app.drive.ghost_visual.visible and app.drive.hud.ghost_position is Vector3)
	var prior_drive: RaceDrive = app.drive
	app.retry_drive()
	assert(not root.size_changed.is_connected(prior_drive.update_control_hints),"a detached race relinquishes window callbacks before its deferred deletion")
	root.size_changed.emit()
	app.drive.set_physics_process(false)
	assert(app.drive.show_ghost and app.pending_config.ghost,"retry retains the latest pause choice even when the global default differs")
	app.set_trial_ghost(false)
	app.settings_page.show_tab("gameplay",app.show_pause)
	for definition: Dictionary in SettingsCatalog.rows:
		if definition.id=="trial_ghost": app.settings_page.changed(definition,true)
	assert(app.drive.show_ghost and AppData.new(folder,false).settings.trial_ghost,"gameplay setting applies to the current race and persists")
	app.data.settings.ui_scale = 150
	app.data.settings.high_contrast = true
	app.data.settings.palette = "deuteranopia"
	app.drive.apply_settings()
	assert(app.drive.hud.ui_scale==1.5 and app.drive.hud.high_contrast and app.drive.hud.palette=="deuteranopia")
	assert(app.drive.hud.panel().bg_color.a==1 and app.drive.hud.panel().border_width_left==2)
	for key: String in RaceHUD.PALETTES:
		app.drive.hud.palette = key
		var colors: Array[Color] = []
		for slot in range(8):
			var color: Color = app.drive.hud.rival_color(slot)
			assert(not color in colors)
			colors.append(color)
	var ui := UIFactory.new(root,app.data.settings)
	assert(ui.theme.get_stylebox("normal","Button").border_width_left>=2,"high contrast strengthens actual menu outlines")
	app.events.mode = "trial"
	app.events.show_event()
	assert(app.events.ghost,"new event selection reflects the persisted ghost setting")
	ui = null
	if "--visual-evidence" in OS.get_cmdline_user_args():
		app.data.settings.window_mode = "windowed"
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_size(Vector2i(1920,1080))
		app.start_drive({"mode":"quick","track":0,"opponents":7})
		app.drive.set_physics_process(false)
		app.drive.hud.phase = "Racing"
		app.drive.hud.ticks = 3690
		for index in range(8): app.drive.session.states[index].position = app.drive.track.pose(index*app.drive.track.length/8).origin
		app.drive._process(.016)
		app.drive.hud.queue_redraw()
		for index in range(6): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://docs/evidence/m3-accessibility-hud-150.png")
	app.queue_free()
	for index in range(6): await process_frame
	assert(AppData.remove_tree(ProjectSettings.globalize_path(folder))==OK)
	print("ACCESSIBILITY_HUD_SCALE_CONTRAST_NUMBERED_PALETTES_GHOST_ENTRY_PAUSE_RETRY_PASS")
	await create_timer(.5).timeout # Retire stopped audio on the mixer thread.
	quit()

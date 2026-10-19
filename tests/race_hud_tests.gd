extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	Catalog.load_all()
	var track := Catalog.tracks[0]
	var samples: Array[Dictionary] = []
	var total := (track.length+8)/40.0
	for index in range(ceili(total*20)+1):
		var at := minf(total,index/20.0)
		samples.append({"time":at,"position":track.pose(at*40-8).origin+Vector3.UP*.35,"yaw":0.0})
	var comparison := TrialDelta.new()
	comparison.build(track,{"time":total,"samples":samples})
	assert(comparison.progress.size()>1000)
	var state := VehicleState.new()
	state.route_s = 400
	state.last_gate = 1
	assert(absf(float(comparison.delta(state,10.45))-.25)<.003,"delta interpolates recorded time at equal route progress")
	state.finished = true
	state.finish_time = total-.5
	assert(is_equal_approx(float(comparison.delta(state,0)),-.5),"finish uses exact sub-tick record time")
	state.trial_valid = false
	assert(comparison.delta(state,0)==null)
	var layout_hud := RaceHUD.new()
	layout_hud.mobile = true
	layout_hud.mobile_unit = 1.75
	for dimensions: Vector2 in [Vector2(1600,720),Vector2(1152,720),Vector2(1280,800)]:
		layout_hud.size = dimensions
		var controls := TouchDriving.build_layout(Rect2(Vector2.ZERO,dimensions/1.75),true,"slider",1,false)
		layout_hud.pause_bounds = Rect2(controls.pause.position*1.75,controls.pause.size*1.75)
		for scale_value: float in [1,1.5]:
			layout_hud.ui_scale = scale_value
			var regions := layout_hud.timing_rects()
			assert(not regions.position.intersects(regions.elapsed) and not regions.elapsed.intersects(regions.lap))
			for area: Rect2 in regions.values():
				assert(not Rect2(area.position*scale_value,area.size*scale_value).intersects(layout_hud.pause_bounds),"native Pause stays unobstructed at 100/150% across phone/tablet aspects")
	layout_hud.free()
	var hud := RaceHUD.new()
	hud.track = track
	hud.state = VehicleState.new()
	root.add_child(hud)
	hud.ticks = 3690
	hud.state.lap_start_time = 54.125
	assert(is_equal_approx(hud.current_lap(),7.375))
	hud.state.best_lap_time = 54.125
	hud.advance(0)
	hud.state.laps = 1
	hud.advance(.01)
	assert(hud.announcement==I18n.t("hud.final_lap"))
	hud.phase = "Racing"
	assert(hud.banner_text()==I18n.t("hud.final_lap"))
	hud.state.wrong_way_ticks = 60
	assert(hud.banner_text()==I18n.t("hud.wrong_way"))
	hud.state.recovery_ticks = 20
	assert(hud.banner_text()==I18n.t("hud.recovering"))
	hud.state.recovery_ticks = 0
	hud.state.wrong_way_ticks = 0
	hud.advance(1.3)
	assert(hud.banner_text()=="")
	hud.state.dnf_reason = "Fixture"
	hud.advance(0)
	var stopped := hud.current_lap()
	hud.ticks += 600
	assert(hud.current_lap()==stopped and hud.banner_text()==I18n.t("results.dnf"))
	hud.queue_free()
	var drive := RaceDrive.new()
	drive.config = {"track":0,"opponents":7,"laps":2}
	root.add_child(drive)
	drive.set_physics_process(false)
	drive.set_process(false)
	var pose := track.pose(50)
	drive.state.position = pose.origin+Vector3.UP*.35
	drive.camera.position = track.pose(45).origin+Vector3.UP*3
	drive.camera.look_at(track.pose(90).origin+Vector3.UP,Vector3.UP)
	drive.hud.rivals.clear()
	var slots: Array[int] = []
	for slot in range(8):
		if slot!=drive.local_slot: slots.append(slot)
	for index in range(slots.size()):
		var rival := drive.session.states[slots[index]]
		rival.position = track.pose(50+[4,10,20,30,40,50,100][index]).origin+Vector3.UP*.35
		drive.hud.rivals.append(rival)
	await physics_frame
	await process_frame
	var visible := drive.nameplates.candidates(drive.camera)
	assert(visible==[slots[1],slots[2],slots[3],slots[4]],"four nearest; close and distant rivals excluded")
	var blocker := StaticBody3D.new()
	blocker.collision_layer = 2
	var box := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(20,8,.5)
	box.shape = shape
	blocker.add_child(box)
	drive.add_child(blocker)
	blocker.transform = track.pose(65)
	blocker.position += Vector3.UP*3
	await physics_frame
	await process_frame
	assert(drive.nameplates.candidates(drive.camera)==[slots[1]],"actual scenery collision occludes distant nameplates")
	drive.nameplates.enabled = false
	drive.nameplates._process(.2)
	assert(drive.nameplates.plates.all(func(plate: PanelContainer) -> bool:return not plate.visible))
	var presentation := WorldPresentation.new()
	root.add_child(presentation)
	var settings := SettingsCatalog.defaults(false)
	settings.retro = true
	presentation.apply(settings)
	for index in range(3): await process_frame
	var point := presentation.camera.to_global(Vector3(0,0,-20))
	var projected: Vector2 = drive.nameplates.project(presentation.camera,point,presentation)
	assert(projected.distance_to(presentation.image.get_global_rect().get_center())<.01,"Retro letterbox projection places native-resolution labels at the real image center")
	presentation.queue_free()
	drive.result_sent = true
	drive.update_control_hints()
	assert(not drive.help_label.visible,"finished results cannot restore driving hints on the next rotation")
	drive.queue_free()
	await create_timer(.5).timeout
	print("HUD_AUTHORITATIVE_LAP_CLOCK_BANNERS_RECORDED_PROGRESS_DELTA_FOUR_NEAREST_ENVIRONMENT_OCCLUSION_PASS")
	quit()

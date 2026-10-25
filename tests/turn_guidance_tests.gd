extends SceneTree
func _initialize() -> void: call_deferred("run")
func circle(direction: float, radius: float = 60) -> TrackDefinition:
	var track := TrackDefinition.new()
	track.length = TAU*radius
	for i in range(128):
		var theta := TAU*i/128
		track.points.append(Vector3(direction*radius*(1-cos(theta)),0,-radius*sin(theta)))
		track.forwards.append(Vector3(direction*sin(theta),0,-cos(theta)))
		track.distances.append(track.length*i/128)
	return track
func run() -> void:
	Catalog.load_all()
	for direction: int in [-1,1]:
		var track := circle(direction)
		for s: float in [0,50,track.length-12]:
			assert(TurnGuidance.next_turn(track,s,30).direction==direction, "physical left/right and seam agree")
		assert(TurnGuidance.next_turn(track,0,0).is_empty())
		assert(TurnGuidance.next_turn(track,-1,30).is_empty())
	assert(TurnGuidance.next_turn(circle(1,250),0,30).is_empty(), "broad sweepers do not constantly announce turns")
	var layout := RaceHUD.new()
	layout.mobile = true
	layout.mobile_unit = 1.75
	for dimensions: Vector2 in [Vector2(1600,720),Vector2(1152,720),Vector2(1280,800)]:
		layout.size = dimensions
		var controls := TouchDriving.build_layout(Rect2(Vector2.ZERO,dimensions/1.75),true,"slider",1,false)
		layout.pause_bounds = Rect2(controls.pause.position*1.75,controls.pause.size*1.75)
		for scale: float in [1,1.5]:
			layout.ui_scale = scale
			var cue := layout.turn_hint_rect()
			assert(Rect2(Vector2.ZERO,dimensions/scale).encloses(cue))
			for area: Rect2 in layout.timing_rects().values(): assert(not cue.intersects(area))
			assert(not Rect2(cue.position*scale,cue.size*scale).intersects(layout.pause_bounds))
	layout.free()
	var track: TrackDefinition = Catalog.tracks[0]
	var distance := -1.0
	for s in range(0,int(track.length),8):
		var cue := TurnGuidance.next_turn(track,s,35)
		if not cue.is_empty() and cue.distance>=32:
			distance = s
			break
	assert(distance>=0)
	for mobile: bool in [false,true]:
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
		root.size = Vector2i(1600,720) if mobile else Vector2i(1280,720)
		var drive := RaceDrive.new()
		drive.config = {"mode":"quick","track":0,"car":0,"opponents":0,"laps":1}
		drive.show_touch = mobile
		root.add_child(drive)
		drive.set_physics_process(false)
		drive.set_process(false)
		for i in range(2): await process_frame
		var pose := track.pose(distance)
		drive.state.position = pose.origin+Vector3.UP*.35
		drive.state.yaw = atan2(-pose.basis.z.x,pose.basis.z.z)
		drive.state.velocity = drive.state.forward()*35
		drive.state.route_s = distance
		drive.visual.present(drive.state,InputFrame.make(),.016)
		drive.camera.initialized = false
		drive.camera.mode = 1
		drive.camera.follow(drive.state,.016)
		drive.hud.pause_bounds = drive.touch.controls.get("pause",Rect2()) if mobile else Rect2()
		drive.hud.secondary_bounds = drive.touch.controls.get("camera",Rect2()).merge(drive.touch.controls.get("look_back",Rect2())) if mobile else Rect2()
		drive.hud.phase = "Racing"
		drive.hud.ticks = 600
		drive.hud.turn_hints = true
		drive.hud.advance(.2)
		assert(not drive.hud.next_turn.is_empty())
		if mobile:
			assert(drive.touch.layout_supported and not drive.touch.controls.is_empty())
			for area: Rect2 in drive.touch.controls.values():
				assert(not drive.hud.turn_hint_rect().intersects(area), "arrow leaves every touch control clear")
		var saved := RaceArchive.pack(drive.state)
		for i in range(20): drive.hud.advance(.016)
		assert(RaceArchive.pack(drive.state)==saved, "guidance cannot change the car or input")
		if "--capture" in OS.get_cmdline_user_args():
			for i in range(8): await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://reports/turn-hints-"+("phone" if mobile else "desktop")+".png")
		for phase: String in ["Grid","Countdown","Results"]:
			drive.hud.phase = phase
			drive.hud.advance(.2)
			assert(drive.hud.next_turn.is_empty())
		drive.hud.phase = "Racing"
		drive.state.wrong_way_ticks = 60
		drive.hud.advance(.2)
		assert(drive.hud.next_turn.is_empty())
		drive.state.wrong_way_ticks = 0
		drive.state.recovery_ticks = 30
		drive.hud.advance(.2)
		assert(drive.hud.next_turn.is_empty())
		drive.state.recovery_ticks = 0
		drive.hud.turn_hints = false
		drive.hud.advance(.2)
		assert(drive.hud.next_turn.is_empty())
		drive.queue_free()
		await create_timer(.5).timeout
	print("TURN_GUIDANCE_DIRECTION_SEAM_PRIORITY_READ_ONLY_PHONE_SAFE_AREA_PASS")
	quit()

extends SceneTree
## Real rendered RaceDrive sessions; scripted input is not a human feel/performance claim.


func _initialize() -> void: call_deferred("run")


func run() -> void:
	Catalog.load_all()
	DrivingInput.register_defaults()
	assert("--autodrive" in OS.get_cmdline_user_args())
	assert(Array(OS.get_cmdline_user_args()).any(func(arg: String) -> bool: return arg.begins_with("--capture=")),"native capture fixture must opt into background capture so another review window cannot pause its race")
	root.size = Vector2i(1920,1080)
	var folder := "user://tests/native-course-races-"+RaceSetup.uuid()
	var data := AppData.new(folder,false)
	data.settings.frame_cap = 0
	data.settings.vsync = false
	var reports: Array[Dictionary] = []
	for index in range(Catalog.tracks.size()):
		var selected := ""
		for argument: String in OS.get_cmdline_user_args():
			if argument.begins_with("--track="): selected = argument.trim_prefix("--track=")
		if selected!="" and Catalog.tracks[index].id!=selected: continue
		var drive := RaceDrive.new()
		drive.app_data = data
		drive.external_menus = true
		drive.config = {"mode":"quick","track":index,"car":index%4,"paint":Catalog.cars[index%4].default_paint,"opponents":7,"laps":1,"difficulty":1,"seed":104729+index,"contact":true}
		root.add_child(drive)
		var screenshot_done := false
		var physics_ticks: int = 0
		while drive.session.phase!=RaceSession.Phase.RESULTS and physics_ticks<12000:
			await physics_frame
			physics_ticks += 1
			if physics_ticks%1800==0:
				print("NATIVE_RACE_STATUS track=%s paused=%s phase=%d elapsed=%d s=%.1f speed=%.1f"%[drive.track.id,drive.paused,drive.session.phase,drive.session.elapsed_ticks,drive.state.route_s,drive.state.speed()])
			if not screenshot_done and drive.race_ticks>=1800:
				screenshot_done = true
				await RenderingServer.frame_post_draw
				root.get_texture().get_image().save_png("res://reports/m4-native-race-"+drive.track.id+".png")
		if drive.session.phase!=RaceSession.Phase.RESULTS:
			print("NATIVE_RACE_TIMEOUT track=%s paused=%s phase=%d elapsed_ticks=%d"%[drive.track.id,drive.paused,drive.session.phase,drive.session.elapsed_ticks])
		assert(drive.session.phase==RaceSession.Phase.RESULTS)
		var rows: Array[Dictionary] = []
		for state: VehicleState in drive.session.standings():
			assert(state.finished and state.dnf_reason=="")
			rows.append({"slot":state.slot,"car":drive.session.cars[state.slot].id,"time":state.finish_time,"dnf":state.dnf_reason})
		assert(rows.size()==8)
		reports.append({"track":drive.track.id,"physics_ticks":physics_ticks,"rows":rows,"route_hash":drive.track.content_hash})
		print("NATIVE_COURSE_RACE_FINISHED ",drive.track.id)
		drive.queue_free()
		for frame in range(8): await process_frame
	assert(AppData.remove_tree(ProjectSettings.globalize_path(folder))==OK)
	var suffix := "" if reports.size()==Catalog.tracks.size() else "-"+str(reports[0].track)
	var file := FileAccess.open("res://reports/m4-native-course-races"+suffix+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":true,"renderer":RenderingServer.get_current_rendering_method(),"resolution":[1920,1080],"content_hash":Compatibility.content_hash(),"asset_hash":JSON.parse_string(FileAccess.get_file_as_string("res://assets/checksums.json")).asset_hash,"boundary":"Scripted rendered sessions with fixed 60 Hz simulation; not human input, real-time performance, or physical-device acceptance","races":reports},"\t")+"\n")
	file.close()
	print("NATIVE_EIGHT_CAR_COURSE_RACES_PASS count=",reports.size())
	quit()

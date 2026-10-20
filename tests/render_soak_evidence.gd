extends SceneTree
## Live, normally paced presentation and scene-retirement exercise, not a movie.

var app: Node
var frames: Array[float] = []
var races: Array[Dictionary] = []
var output: String
var began_us: int
var duration: int = 900
var serial: int = 0
var last_heartbeat: int = -1
var last_draw_us: int = 0


func _initialize() -> void: call_deferred("run")


func drawn() -> void:
	var now := Time.get_ticks_usec()
	if last_draw_us>0 and is_instance_valid(app) and app.page=="race" and is_instance_valid(app.drive) and not app.drive.paused and app.drive.session.phase in [RaceSession.Phase.RACING,RaceSession.Phase.GRACE]:
		frames.append((now-last_draw_us)/1000.0)
	last_draw_us = now


func stats() -> Dictionary:
	var sorted := frames.duplicate()
	sorted.sort()
	var total: float = 0
	var slow: int = 0
	for value: float in sorted:
		total += value
		if value>33: slow += 1
	return {"samples":sorted.size(),"mean_ms":total/maxi(1,sorted.size()),
		"p95_ms":sorted[clampi(ceili(sorted.size()*.95)-1,0,sorted.size()-1)] if not sorted.is_empty() else 0,
		"p99_ms":sorted[clampi(ceili(sorted.size()*.99)-1,0,sorted.size()-1)] if not sorted.is_empty() else 0,
		"max_ms":sorted[-1] if not sorted.is_empty() else 0,"over_33ms":slow}


func report(passed: bool, final: bool = false) -> void:
	var snapshot: Dictionary = app.diagnostics.snapshot()
	var value := {"passed":passed,"final":final,"elapsed_seconds":(Time.get_ticks_usec()-began_us)/1000000.0,
		"requested_seconds":duration,"races":races,"racing_frames":frames.size(),
		"frame_timing":"Wall-clock microseconds between RenderingServer.frame_post_draw callbacks, including OS scheduling; excludes loading/menu/countdown. No engine simulation-delta or fixed-fps movie timing.",
		"content_hash":Compatibility.content_hash(),"asset_hash":JSON.parse_string(FileAccess.get_file_as_string("res://assets/checksums.json")).asset_hash,
		"renderer":RenderingServer.get_current_rendering_method(),"gpu":RenderingServer.get_video_adapter_name(),
		"platform":snapshot["platform.json"],"settings":snapshot["settings.json"],"last_60_seconds":snapshot["performance.json"],
		"boundary":"Live source client, normally paced eight-car races across eight courses, production loading/HUD/render-scale path, ordinary diagnostic AI inputs. Repeated scene lifetime exercise on this host; not exported-template, minimum-hardware, continuous worst-track, human driving, physical Android or thermal acceptance."}
	if final: value["racing_frame_times"] = stats()
	var file := FileAccess.open(output,FileAccess.WRITE)
	assert(file!=null)
	file.store_string(JSON.stringify(value,"\t")+"\n")
	file.close()


func start_next() -> void:
	var track := serial%Catalog.tracks.size()
	app.request_drive({"mode":"quick","track":track,"car":serial%4,"paint":serial%8,
		"opponents":7,"laps":1,"difficulty":1,"contact":true,"seed":0x534f4100+serial},app.show_menu)
	serial += 1


func run() -> void:
	assert(DisplayServer.get_name()!="headless")
	assert("--autodrive" in OS.get_cmdline_user_args())
	var profile := ""
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--report="): output = argument.trim_prefix("--report=")
		elif argument.begins_with("--seconds="): duration = clampi(int(argument.trim_prefix("--seconds=")),1,3600)
		elif argument.begins_with("--profile="): profile = argument.trim_prefix("--profile=")
	assert(not output.is_empty() and profile.begins_with("render_soak_") and GhostCodec.valid_id(profile))
	root.size = Vector2i(1920,1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1280,720)
	RenderingServer.frame_post_draw.connect(drawn)
	app = load("res://game/client_app.gd").new()
	app.capture_path = "user://unused-render-soak.png"
	app.capture_frame = 1000000000
	root.add_child(app)
	await process_frame
	app.data.profile.first_run_complete = true
	app.data.apply_preset("medium")
	app.data.settings.frame_cap = 60
	app.data.settings.vsync = false
	SettingsRuntime.apply(app,app.data.settings,false)
	app.show_menu()
	began_us = Time.get_ticks_usec()
	start_next()
	while true:
		await process_frame
		var elapsed := (Time.get_ticks_usec()-began_us)/1000000.0
		if app.page=="results":
			var rows: Array[Dictionary] = []
			for state: VehicleState in app.drive.session.standings():
				assert(state.finished and state.dnf_reason.is_empty(),"every actual race must finish all eight cars")
				rows.append({"slot":state.slot,"car":app.drive.session.cars[state.slot].id,"time":state.finish_time})
			assert(rows.size()==8)
			races.append({"track":app.drive.track.id,"finished_at_seconds":elapsed,"rows":rows})
			print("RENDER_SOAK_RACE_FINISHED track=%s races=%d elapsed=%.1f"%[app.drive.track.id,races.size(),elapsed])
			if elapsed>=duration: break
			app.show_menu()
			start_next()
		if int(elapsed)/30>last_heartbeat:
			last_heartbeat = int(elapsed)/30
			report(false)
			print("RENDER_SOAK_PROGRESS seconds=%.1f races=%d frames=%d"%[elapsed,races.size(),frames.size()])
	assert(not frames.is_empty() and not races.is_empty())
	report(true,true)
	print("LIVE_RENDER_SOAK_ALL_EIGHT_FINISHERS_NORMAL_PACE_SCENE_RETIREMENT_PASS races=",races.size())
	app.finish_quit()

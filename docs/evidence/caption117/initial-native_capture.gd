extends SceneTree
var app: Node
var report := {"passed":false,"scope":"Actual native 1920x1080 render; constructed pause/settings case holds a live GO caption deadline to make masking observable."}
func _initialize() -> void: call_deferred("run")
func settle() -> void:
	for index in range(6): await process_frame
func capture(name: String) -> void:
	await settle()
	app.game_audio._process(.016)
	assert(Time.get_ticks_msec()<app.game_audio.caption_until)
	assert(not app.game_audio.caption.visible,"live race caption cannot cover menu controls")
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://reports/caption117/"+name+".png")==OK)
func run() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_size(Vector2i(1920,1080))
	app = load("res://game/client_app.gd").new()
	root.add_child(app)
	await settle()
	app.data.settings.reduce_motion = true
	app.data.settings.captions = true
	app.start_drive({"mode":"quick","track":0,"car":0,"opponents":7})
	app.drive.set_physics_process(false)
	app.drive.audio.set_physics_process(false)
	app.game_audio.set_process(false)
	app.game_audio.say("go")
	app.game_audio.caption_until = Time.get_ticks_msec()+60000
	app.drive.show_pause()
	await capture("pause-live-go-hidden")
	app.settings_page.show_tab("audio",app.show_pause)
	await capture("settings-live-go-hidden")
	report["passed"] = true
	report["pause_and_settings_live_caption_hidden"] = true
	report["resolution"] = [root.size.x,root.size.y]
	var file := FileAccess.open("res://reports/caption117/native.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  ")+"\n")
	app.queue_free()
	await settle()
	await create_timer(.5).timeout
	print("NATIVE_LIVE_GO_PAUSE_SETTINGS_CAPTION_HIDDEN_PASS")
	quit()

extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
	var app: Node = load("res://game/client_app.gd").new()
	root.add_child(app)
	app.start_drive({"mode":"trial","track":0,"car":0,"paint":0,"opponents":0,"laps":1})
	app.drive.set_physics_process(false)
	var evidence: Dictionary = {"physical_device":false,"renderer":RenderingServer.get_current_rendering_method(),"host_pixels":root.size,"variants":[]}
	for retro: bool in [false,true,false]:
		app.data.settings.render_scale = 80
		app.data.settings.retro = retro
		SettingsRuntime.apply(app,app.data.settings)
		await create_timer(.3).timeout
		await RenderingServer.frame_post_draw
		var name := "retro" if retro else "restored" if evidence.variants.size()>1 else "scaled"
		root.get_texture().get_image().save_png("res://reports/presentation-"+name+".png")
		var pixels: Image = app.presentation.viewport.get_texture().get_image()
		assert(pixels.get_size()==(Vector2i(640,360) if retro else Vector2i(1024,576)))
		evidence.variants.append({"name":name,"world_pixels":pixels.get_size(),"hud_pixels":root.get_texture().get_image().get_size()})
	var file := FileAccess.open("res://reports/presentation-native.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(evidence,"  "))
	file.close()
	app.queue_free()
	await process_frame
	await process_frame
	print("PRESENTATION_NATIVE_TEXTURE_SIZE_HUD_CAPTURE_PASS")
	quit()

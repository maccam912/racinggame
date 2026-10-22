extends SceneTree
## Native pixels prove animated geometry moves and Reduce Motion freezes it.
func _initialize() -> void: call_deferred("run")

func capture(path: String) -> Image:
	for frame in range(8): await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image()
	assert(result.save_png(path)==OK)
	return result

func changed_samples(a: Image, b: Image) -> int:
	assert(a.get_size()==b.get_size())
	var changed := 0
	for y in range(0,a.get_height(),2):
		for x in range(0,a.get_width(),2):
			var first := a.get_pixel(x,y)
			var last := b.get_pixel(x,y)
			if maxf(absf(first.r-last.r),maxf(absf(first.g-last.g),absf(first.b-last.b)))>.015: changed += 1
	return changed

func run() -> void:
	assert(DisplayServer.get_name()!="headless")
	Catalog.load_all()
	root.size = Vector2i(960,540)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	DisplayServer.window_move_to_foreground()
	var output := "res://reports/set-piece-motion"
	DirAccess.make_dir_recursive_absolute(output)
	var reports: Array[Dictionary] = []
	for id: String in ["windfarm_run","festival_speedway","reactor_rift","storm_chase","cloudforest_climb"]:
		var track: TrackDefinition = Catalog.tracks.filter(func(item: TrackDefinition) -> bool: return item.id==id)[0]
		var world := TrackWorld.new()
		world.build(track)
		root.add_child(world)
		var hero := world.find_children("HeroSetPiece_*","Node3D",false,false)[0] as Node3D
		var camera := Camera3D.new()
		camera.current = true
		camera.far = 3000
		camera.fov = 60
		world.add_child(camera)
		camera.global_position = hero.to_global(Vector3(55,42,110))
		camera.look_at(hero.to_global(Vector3(0,34,0)),Vector3.UP)
		var settings := SettingsCatalog.defaults(false)
		settings.frame_cap = 60
		settings.vsync = false
		settings.reduce_motion = false
		SettingsRuntime.apply(world,settings)
		var first := await capture(output+"/"+id+"-moving-before.png")
		for frame in range(45): await process_frame
		var last := await capture(output+"/"+id+"-moving-after.png")
		var moving := changed_samples(first,last)
		assert(moving>30,"real rendered geometry must move: "+id)
		settings.reduce_motion = true
		SettingsRuntime.apply(world,settings)
		first = await capture(output+"/"+id+"-reduced-before.png")
		for frame in range(45): await process_frame
		last = await capture(output+"/"+id+"-reduced-after.png")
		var reduced := changed_samples(first,last)
		assert(reduced==0,"Reduce Motion must freeze all set-piece motion pixels: "+id)
		reports.append({"track":id,"moving_changed_samples":moving,"reduced_changed_samples":reduced})
		print("SET_PIECE_NATIVE_MOTION ",id," moving=",moving," reduced=",reduced)
		world.queue_free()
		for frame in range(4): await process_frame
	var file := FileAccess.open(output+"/native.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":true,"renderer":RenderingServer.get_current_rendering_method(),"resolution":[960,540],"content_hash":Compatibility.content_hash(),"shader_sha256":FileAccess.get_sha256("res://assets/exported/shaders/set_piece_motion.gdshader"),"source_sha256":FileAccess.get_sha256("res://game/world/expansion_set_pieces.gd"),"cases":reports,"boundary":"Native macOS pixels at a fixed diagnostic camera, every second pixel with 0.015 channel tolerance, 45 frames between samples. Moving and reduced captures share the same scene/settings; Reduce Motion freezes the three turbines, wheel and upright cabins, reactor rings and storm funnel. Not APK/physical-device or frame-time acceptance."},"\t")+"\n")
	file.close()
	print("NATIVE_SET_PIECE_VERTEX_MOTION_AND_REDUCED_MOTION_PIXELS_PASS")
	quit()

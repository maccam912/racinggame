extends SceneTree
## Native actual-world captures plus fixed diagnostic views of all ground types.
func _initialize() -> void: call_deferred("run")
func capture(path: String) -> Image:
	for frame in range(8): await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image()
	assert(result.save_png(path)==OK)
	return result
func difference(a: Image, b: Image) -> int:
	var changed := 0
	for y in range(0,a.get_height(),2):
		for x in range(0,a.get_width(),2):
			var first := a.get_pixel(x,y)
			var last := b.get_pixel(x,y)
			if maxf(absf(first.r-last.r),maxf(absf(first.g-last.g),absf(first.b-last.b)))>.012: changed += 1
	return changed
func run() -> void:
	assert(DisplayServer.get_name()!="headless")
	Catalog.load_all()
	root.size = Vector2i(1280,720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	DisplayServer.window_move_to_foreground()
	var folder := "res://reports/biome-surface-native"
	DirAccess.make_dir_recursive_absolute(folder)
	var rows: Array[Dictionary] = []
	for track: TrackDefinition in Catalog.tracks.slice(10):
		var world := TrackWorld.new()
		world.build(track)
		root.add_child(world)
		var settings := SettingsCatalog.defaults(false)
		settings.reduce_motion = true
		settings.vsync = false
		settings.frame_cap = 60
		SettingsRuntime.apply(world,settings)
		var camera := Camera3D.new()
		camera.current = true
		camera.far = 4000
		camera.fov = 72
		world.add_child(camera)
		var s := CourseArt.original_s(track,.23)
		camera.global_position = track.pose(s).origin+Vector3.UP*6
		camera.look_at(track.pose(s+65).origin+Vector3.UP*2,Vector3.UP)
		await capture(folder+"/"+track.id+"-route.png")
		if world.art.space:
			var seed: float = world.art.sky_seed
			camera.global_position += Vector3.UP*65
			camera.look_at(camera.global_position+Vector3(cos(seed),.55,sin(seed)),Vector3.UP)
			await capture(folder+"/"+track.id+"-sky.png")
		rows.append({"track":track.id,"biome":ExpansionBiome.STYLES[track.id][0],"space":world.art.space,"route_s":s})
		world.queue_free()
		for frame in range(3): await process_frame
	# Neutral-light plane comparisons isolate material detail from scenery.
	var probe := Node3D.new()
	root.add_child(probe)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("627A92")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = .4
	probe.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-52,20,0)
	sun.light_energy = .55
	probe.add_child(sun)
	var plane := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(250,250)
	plane.mesh = mesh
	probe.add_child(plane)
	var camera := Camera3D.new()
	probe.add_child(camera)
	camera.position = Vector3(0,95,80)
	camera.look_at(Vector3.ZERO)
	camera.current = true
	var patterns: Array[Dictionary] = []
	for id: String in ["alpine_meadow","glacier_ridge","dune_serpent","lantern_market","saltflat_velocity","lunar_freight","crystal_chasm","mars_badlands","reactor_rift","monsoon_delta"]:
		var flat := StandardMaterial3D.new()
		flat.albedo_color = Color.html(CourseArt.spec(id).ground)
		plane.material_override = flat
		var before := await capture(folder+"/"+id+"-flat.png")
		plane.material_override = ExpansionBiome.material(id)
		var after := await capture(folder+"/"+id+"-pattern.png")
		var changed := difference(before,after)
		assert(changed>1000,"actual ground material produces native detail pixels: "+id)
		for frame in range(30): await process_frame
		var still := await capture(folder+"/"+id+"-static.png")
		assert(difference(after,still)==0,"static world-space material must not shimmer or animate at a fixed camera")
		patterns.append({"track":id,"changed_samples":changed,"static_changed_samples":0})
	var file := FileAccess.open(folder+"/native.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":true,"renderer":RenderingServer.get_current_rendering_method(),"resolution":[1280,720],"cases":rows,"ground_patterns":patterns,"ground_shader_sha256":FileAccess.get_sha256("res://assets/exported/shaders/biome_ground.gdshader"),"sky_shader_sha256":FileAccess.get_sha256("res://assets/exported/shaders/expansion_sky.gdshader"),"boundary":"Thirty native actual-world approach captures and five sky views, ten neutral-light material comparisons with every second pixel and 0.012 channel tolerance. Static samples thirty frames apart. Native macOS Compatibility, not Android runtime or performance acceptance."},"\t")+"\n")
	file.close()
	print("NATIVE_THIRTY_BIOME_WORLDS_FIVE_SKIES_TEN_GROUND_PATTERNS_AND_STATIC_PIXELS_PASS")
	quit()

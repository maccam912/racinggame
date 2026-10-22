extends SceneTree
## Production object library and actual road-camera views across all additions.
func _initialize() -> void: call_deferred("run")
func capture(path: String) -> void:
	for frame in range(8): await process_frame
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png(path)==OK)
func run() -> void:
	assert(DisplayServer.get_name()!="headless")
	Catalog.load_all()
	root.size = Vector2i(1280,720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	DisplayServer.window_move_to_foreground()
	var output := "res://reports/expansion-roadside-life-native"
	DirAccess.make_dir_recursive_absolute(output)
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
		var first_kind: String = ExpansionRoadsideLife.KINDS[track.id][0]
		var site: Dictionary = {}
		var best := INF
		for candidate: Dictionary in world.decor_sites:
			if candidate.kind!=first_kind: continue
			var distance := absf(float(candidate.s)-track.length*.35)
			if distance<best:
				best = distance
				site = candidate
		assert(not site.is_empty())
		var camera := Camera3D.new()
		camera.current = true
		camera.fov = 62
		camera.far = 3000
		world.add_child(camera)
		camera.global_position = track.pose(float(site.s)-36).origin+Vector3.UP*4
		camera.look_at(site.pose.origin+Vector3.UP*1.4,Vector3.UP)
		await capture(output+"/"+track.id+"-roadside.png")
		rows.append({"track":track.id,"kind":site.kind,"route_s":site.s,"root":[site.pose.origin.x,site.pose.origin.y,site.pose.origin.z]})
		print("NATIVE_ROADSIDE_VIEW ",track.id," ",site.kind)
		world.queue_free()
		for frame in range(3): await process_frame
	var groups := [["ski_rack","weather_station","rescue_sled","fuel_locker","harbor_catch","fjord_buoy"],["trail_camp","river_gauge","surf_rack","fishing_rack","coffee_crates","stone_idol"],["cycle_rack","bamboo_cart","market_cart","tea_baskets","stone_lantern","wayside_shrine"],["timing_booth","water_tank","shade_shelter","core_samples","weather_probe","survey_tripod"],["steel_rack","cargo_pallet","bus_shelter","service_cabinet","snack_cart","tire_stack"],["cargo_pod","hydroponic_tray","survey_beacon","rover_battery","coolant_station","antenna_dish"]]
	for family in range(groups.size()):
		var parent := Node3D.new()
		root.add_child(parent)
		var env := WorldEnvironment.new()
		env.environment = Environment.new()
		env.environment.background_mode = Environment.BG_COLOR
		env.environment.background_color = Color("B8C5CE")
		env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		env.environment.ambient_light_color = Color.WHITE
		env.environment.ambient_light_energy = .4
		parent.add_child(env)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-48,-30,0)
		sun.light_energy = .6
		parent.add_child(sun)
		var floor_node := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(160,160)
		floor_node.mesh = plane
		var floor_material := StandardMaterial3D.new()
		floor_material.albedo_color = Color("899DA3")
		floor_node.material_override = floor_material
		parent.add_child(floor_node)
		var surface := ShaderMaterial.new()
		surface.shader = load("res://assets/exported/shaders/set_piece_motion.gdshader")
		for index in range(6):
			var node := MeshInstance3D.new()
			node.mesh = ExpansionLifeProps.mesh(groups[family][index])
			node.position = Vector3((index%3-1)*8,0,(index/3-.5)*9)
			node.material_override = surface
			parent.add_child(node)
		var camera := Camera3D.new()
		parent.add_child(camera)
		camera.fov = 45
		camera.position = Vector3(-6,9,-21)
		camera.look_at(Vector3(0,1,0))
		camera.current = true
		await capture(output+"/family-"+str(family)+".png")
		parent.queue_free()
		for frame in range(3): await process_frame
	var file := FileAccess.open(output+"/native.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":true,"renderer":RenderingServer.get_current_rendering_method(),"resolution":[1280,720],"cases":rows,"model_families":groups,"models_sha256":FileAccess.get_sha256("res://game/world/expansion_life_props.gd"),"placement_sha256":FileAccess.get_sha256("res://game/world/expansion_roadside_life.gd"),"boundary":"Thirty actual-world diagnostic road-camera views aimed at a selected roadside object, plus six neutral-light production-library grids showing all 36 models. These aimed views are separate from the ordinary Far Chase approach captures. Native macOS Compatibility, not Android runtime or performance acceptance."},"\t")+"\n")
	file.close()
	print("NATIVE_THIRTY_ROADSIDE_WORLD_VIEWS_AND_THIRTY_SIX_PRODUCTION_OBJECTS_PASS")
	quit()

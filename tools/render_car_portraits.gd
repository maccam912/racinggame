extends SceneTree
## Render actual shipped models once; garage cards need no extra live 3D worlds.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	Catalog.load_all()
	var folder := "res://assets/exported/car_portraits"
	DirAccess.make_dir_recursive_absolute(folder)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(384,216)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color(0,0,0,0)
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("D6E4FF")
	environment.environment.ambient_light_energy = .8
	world.add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40,-125,0)
	sun.light_color = Color("FFF1D2")
	sun.light_energy = 1.1
	world.add_child(sun)
	var camera := Camera3D.new()
	world.add_child(camera)
	camera.position = Vector3(4,2.6,-5.7)
	camera.look_at(Vector3(0,.85,0))
	camera.fov = 28
	camera.current = true
	var rows: Array[Dictionary] = []
	for car: CarDefinition in Catalog.cars:
		var visual := CarVisual.new()
		visual.build(Color("DFE5ED"),car.mesh_id)
		world.add_child(visual)
		var state := VehicleState.new()
		state.position.y = .35
		visual.present(state,InputFrame.make(),.016)
		for frame in range(8): await process_frame
		await RenderingServer.frame_post_draw
		var path := folder+"/"+car.id+".png"
		var picture := viewport.get_texture().get_image()
		assert(picture.save_png(path)==OK)
		rows.append({"id":car.id,"path":path.trim_prefix("res://"),"sha256":FileAccess.get_sha256(path),"model":car.mesh_id,"paint":"DFE5ED"})
		visual.queue_free()
		await process_frame
	FileAccess.open(folder+"/catalog.json",FileAccess.WRITE).store_string(JSON.stringify({"source":"tools/render_car_portraits.gd","license":"MIT","resolution":[384,216],"model_inventory_sha256":FileAccess.get_sha256("res://assets/exported/cars/inventory.json"),"portraits":rows},"\t")+"\n")
	viewport.queue_free()
	await process_frame
	print("EIGHT_ACTUAL_MODEL_TRANSPARENT_GARAGE_PORTRAITS_RENDERED")
	quit()

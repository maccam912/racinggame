extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	Catalog.load_all()
	var inventory: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/exported/cars/inventory.json"))
	var scene := Node3D.new()
	root.add_child(scene)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.current = true
	for index in range(4):
		var visual := CarVisual.new()
		visual.build(Catalog.paints[index],Catalog.cars[index].mesh_id,index)
		scene.add_child(visual)
		assert(visual.model_id==Catalog.cars[index].mesh_id and visual.lods.size()==3)
		var row: Dictionary
		for candidate: Dictionary in inventory.cars:
			if candidate.id==visual.model_id: row = candidate
		for level in range(3):
			visual.choose_lod(level)
			var triangles: int = 0
			var count: int = 0
			for mesh: MeshInstance3D in visual.lods[level].find_children("*","MeshInstance3D",true,false):
				count += 1
				assert(mesh.mesh.get_surface_count()==1,"one shared atlas surface per body/wheel mesh")
				var arrays := mesh.mesh.surface_get_arrays(0)
				assert(not arrays[Mesh.ARRAY_COLOR].is_empty(),"role masks must survive glTF import")
				triangles += (arrays[Mesh.ARRAY_INDEX].size() if not arrays[Mesh.ARRAY_INDEX].is_empty() else arrays[Mesh.ARRAY_VERTEX].size())/3
			assert(count==5 and triangles==int(row.lods[level].triangles) and triangles<=int(row.lods[level].ceiling))
			assert(visual.lods.filter(func(node: Node3D) -> bool: return node.visible).size()==1)
		visual.position = Vector3.ZERO
		camera.position = Vector3(0,2,34)
		visual._process(0)
		assert(visual.active_lod==0)
		camera.position.z = 36
		visual._process(0)
		assert(visual.active_lod==1)
		camera.position.z = 91
		visual._process(0)
		assert(visual.active_lod==2 and not visual.number_labels[0].visible)
		var state := VehicleState.new()
		state.position.y = .35
		state.velocity = Vector3.FORWARD*35
		state.steer_filter = 1
		visual.choose_lod(0)
		visual.present(state,InputFrame.make(1,0,1),1.0/60)
		assert(visual.surface.get_shader_parameter("braking")==1.0 and visual.tire_rotation!=0)
		state.braking = true
		visual.present(state,InputFrame.make(),0)
		assert(visual.surface.get_shader_parameter("braking")==1.0,"remote authority lights brakes without receiving human input frames")
		state.braking = false
		visual.present(state,InputFrame.make(),0)
		assert(visual.surface.get_shader_parameter("braking")==0.0)
		for wheel: Node3D in visual.wheels:
			var rest: Transform3D = visual.wheel_rest[wheel]
			assert(absf(wheel.global_position.y-(state.position.y+rest.origin.y))<.001,"body roll/pitch cannot push wheels below the road")
			var turn := (rest.basis.inverse()*visual.global_basis.inverse()*wheel.global_basis).get_euler().y
			assert(absf(absf(rad_to_deg(turn))-(25 if rest.origin.z<0 else 0))<.01,"only front wheels steer, with a 25 degree cap")
		assert(visual.number_labels[0].text==str(index+1))
		visual.set_ghost(.35)
		assert(not visual.shadow.visible and not visual.number_labels[0].visible)
		assert(visual.ghost_surface.get_shader_parameter("ghost_alpha")==.35)
		visual.queue_free()
		await process_frame
	var atlas: Texture2D = load("res://assets/exported/textures/cars_atlas.png")
	assert(atlas.get_size()==Vector2(1024,1024) and atlas.get_image().has_mipmaps())
	scene.queue_free()
	await process_frame
	var app: Node = load("res://game/client_app.gd").new()
	root.add_child(app)
	await process_frame
	assert(app.missing_car_asset().is_empty())
	app.show_installation_error("Comet")
	assert(app.page=="installation_error" and app.menu.visible and not app.back_action.is_valid(),"missing content has a visible installation error with explicit retry")
	app.queue_free()
	for index in range(3): await process_frame
	print("FOUR_ORIGINAL_CARS_GLTF_TRIANGLE_BUDGETS_ROLE_MASKS_LODS_WHEELS_PAINT_GHOST_PASS")
	await create_timer(.5).timeout # Retire stopped audio on the mixer thread.
	quit()

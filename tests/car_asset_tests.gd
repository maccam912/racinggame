extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	Catalog.load_all()
	var inventory: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/exported/cars/inventory.json"))
	var scene := Node3D.new()
	var lamp_cases: Array[Dictionary] = []
	root.add_child(scene)
	var camera := Camera3D.new()
	scene.add_child(camera)
	camera.current = true
	for index in range(Catalog.cars.size()):
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
			lamp_cases.append(await assert_lamps_attached(visual,level,scene))
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
	var file := FileAccess.open("res://reports/car-lamp-attachment.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":true,"cases":lamp_cases,"rays":lamp_cases.size()*20,
		"boundary":"Actual exported body triangles only, excluding lamp geometry. Twenty centre/corner attachment rays per car/LOD, all eight cars and all three LODs. No handling or synthetic mesh substitute."},"\t")+"\n")
	file.close()
	print("ALL_EIGHT_CARS_THREE_LODS_480_LAMP_BODY_ATTACHMENT_RAYS_PASS")
	print("EIGHT_ORIGINAL_CARS_GLTF_TRIANGLE_BUDGETS_ROLE_MASKS_LODS_WHEELS_PAINT_GHOST_PASS")
	await create_timer(.5).timeout # Retire stopped audio on the mixer thread.
	quit()


func assert_lamps_attached(visual: CarVisual, level: int, scene: Node3D) -> Dictionary:
	# Ray only against exported painted body triangles, excluding the lamps
	# themselves. Check their centre and four inset corners on every actual LOD.
	var body_faces := PackedVector3Array()
	var lamps: Dictionary = {}
	for mesh: MeshInstance3D in visual.lods[level].find_children("*","MeshInstance3D",true,false):
		var local := visual.relative_transform(mesh)
		var arrays: Array = mesh.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		if indices.is_empty():
			for index in range(vertices.size()): indices.append(index)
		for index in range(0,indices.size(),3):
			if colors[indices[index]].r>.9 and colors[indices[index+1]].r>.9 and colors[indices[index+2]].r>.9:
				for corner in range(3): body_faces.append(local*vertices[indices[index+corner]])
		for index in range(vertices.size()):
			var role: Color = colors[index]
			var front := role.r<.01 and role.g<.01 and role.b<.01 and absf(role.a-.3)<.02
			var rear := role.b>.9 and role.r<.01 and role.g<.01
			if not front and not rear: continue
			var point: Vector3 = local*vertices[index]
			var key := ("front" if front else "rear")+str(signf(point.x))
			if not lamps.has(key): lamps[key] = []
			lamps[key].append(point)
	assert(lamps.size()==4,"Each exported LOD needs two headlamps and two brake lamps")
	var body := StaticBody3D.new()
	body.collision_layer = 8
	var collider := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(body_faces)
	collider.shape = shape
	body.add_child(collider)
	scene.add_child(body)
	await physics_frame
	await physics_frame
	for key: String in lamps:
		var bounds := AABB(lamps[key][0],Vector3.ZERO)
		for point: Vector3 in lamps[key]: bounds = bounds.expand(point)
		var center := bounds.get_center()
		var forward := Vector3.FORWARD if key.begins_with("front") else Vector3.BACK
		for corner: Vector2 in [Vector2.ZERO,Vector2(-.4,-.4),Vector2(.4,-.4),Vector2(-.4,.4),Vector2(.4,.4)]:
			var point := center+Vector3(corner.x*bounds.size.x,corner.y*bounds.size.y,0)
			var ray := PhysicsRayQueryParameters3D.create(point+forward*.05,point-forward*.20,8)
			var hit := scene.get_world_3d().direct_space_state.intersect_ray(ray)
			assert(not hit.is_empty(),"Lamp floats off the actual body: %s LOD%d %s %s"%[visual.model_id,level,key,corner])
	body.queue_free()
	await process_frame
	return {"car":visual.model_id,"lod":level,"lamps":lamps.size(),"attachment_rays":20}

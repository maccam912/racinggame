extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var scene := Node3D.new()
	root.add_child(scene)
	var document := GLTFDocument.new()
	var state := GLTFState.new()
	assert(document.append_from_file("res://reports/legacy-needle.glb",state)==OK)
	var model := document.generate_scene(state)
	var visual := CarVisual.new()
	visual.model_id = "legacy_needle"
	visual.add_child(model)
	for node: Node3D in model.find_children("LOD*","Node3D",true,false):
		if str(node.name).begins_with("LOD0"): visual.lods.append(node)
	scene.add_child(visual)
	await assert_lamps_attached(visual,0,scene)
	quit(1)

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

extends SceneTree
## The showroom apron must never overlap the real pavement in plan view.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	Catalog.load_all()
	var track := Catalog.tracks[0]
	var before := var_to_bytes(RouteGeometry.meshes(track).asphalt.surface_get_arrays(0))
	var stage := MenuStage.new()
	stage.reduce_motion = true
	root.add_child(stage)
	stage.set_process(false)
	var aprons := stage.find_children("ShowroomApron","MeshInstance3D",true,false)
	assert(aprons.size()==1)
	var apron := aprons[0] as MeshInstance3D
	var bounds := apron.mesh.get_aabb()
	var footprint := PackedVector2Array()
	for corner: Vector3 in [bounds.position,Vector3(bounds.end.x,bounds.position.y,bounds.position.z),bounds.end,Vector3(bounds.position.x,bounds.position.y,bounds.end.z)]:
		var at := apron.global_transform*corner
		footprint.append(Vector2(at.x,at.z))
	var road: PackedVector3Array = RouteGeometry.meshes(track).asphalt.get_faces()
	for first in range(0,road.size(),3):
		var polygon := PackedVector2Array()
		for j in range(3): polygon.append(Vector2(road[first+j].x,road[first+j].z))
		assert(Geometry2D.intersect_polygons(footprint,polygon).is_empty(),"the display platform cannot cover any pavement triangle or fight its depth")
	var top := apron.global_position.y+bounds.end.y
	assert(absf(stage.center.y-top)<.001 and bounds.size.y>=.4)
	for car_index in range(4):
		stage.set_selection(car_index,car_index*2)
		assert(is_equal_approx(stage.car.position.y,top+.35))
		for angle in range(8):
			stage.rotation_offset=angle*TAU/8
			stage._process(0)
			assert(stage.camera.position.y>top+3 and stage.camera.position.is_finite())
	assert(before==var_to_bytes(RouteGeometry.meshes(track).asphalt.surface_get_arrays(0)),"the menu fix cannot change the racing road")
	stage.queue_free()
	await process_frame
	print("MENU_APRON_CLEARS_ALL_ACTUAL_ROAD_TRIANGLES_FOUR_CARS_EIGHT_ORBITS_UNCHANGED_RACING_ROAD_PASS")
	quit()

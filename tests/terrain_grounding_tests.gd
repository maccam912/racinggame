extends SceneTree


func _initialize() -> void: call_deferred("run")


func run() -> void:
	Catalog.load_all()
	var cases: Array[Dictionary] = []
	for track: TrackDefinition in Catalog.tracks:
		var terrain := CourseArt.terrain(track.id)
		var checked := check_triangles(terrain,Transform3D.IDENTITY,track.id)
		assert(checked>1000,"grounding is checked against the actual exported triangle mesh")
		var world := TrackWorld.new()
		world.track = track
		world.terrain_grid = CourseArt.terrain_heights[track.id]
		for index in range(0,track.points.size(),31):
			for lateral: float in [-48.0,-18.0,18.0,48.0]:
				var pose := world.scenery_pose(track.distances[index],lateral)
				var terrain_y := CourseArt.terrain_height(track.id,pose.origin,INF)
				var verge_y := world.verge_height(track.distances[index],lateral,pose.origin)
				assert(absf(pose.origin.y-maxf(terrain_y,verge_y))<.001,"roots meet the highest visible terrain or road-verge surface")
				assert(pose.basis.y.is_equal_approx(Vector3.UP),"billboard roots stay upright on hills")
		assert(terrain.find_children("*","CollisionObject3D",true,false).is_empty(),"terrain remains cosmetic")
		cases.append({"track":track.id,"triangle_samples":checked,"grid_vertices":CourseArt.terrain_heights[track.id].size()})
		var before := world.scenery_pose(track.length*.35,-135)
		CourseArt.terrain_heights.clear()
		assert(world.scenery_pose(track.length*.35,-135).is_equal_approx(before),"memory warning during staged loading retains the active world's terrain grid")
		world.free()
		terrain.free()
	CourseArt.terrain_heights.clear()
	assert(CourseArt.terrain_height("absent",Vector3.ZERO,17)==17)
	DirAccess.make_dir_recursive_absolute("res://reports")
	var file := FileAccess.open("res://reports/terrain-grounding.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":true,"cases":cases},"\t")+"\n")
	file.close()
	print("SIX_COURSE_SCENERY_ROOTS_MATCH_EXPORTED_TERRAIN_TRIANGLES_NO_COLLISION_PASS")
	quit()


func check_triangles(node: Node, parent_pose: Transform3D, track_id: String) -> int:
	var pose: Transform3D = parent_pose*node.transform if node is Node3D else parent_pose
	var checked := 0
	if node is MeshInstance3D:
		for surface in range(node.mesh.get_surface_count()):
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			# Both triangles of every cell, with asymmetric interior weights
			# to detect the wrong diagonal or grid axis.
			for first in range(0,indices.size(),3):
				var a: Vector3 = pose*vertices[indices[first]]
				var b: Vector3 = pose*vertices[indices[first+1]]
				var c: Vector3 = pose*vertices[indices[first+2]]
				var point := a*.17+b*.31+c*.52
				assert(absf(CourseArt.terrain_height(track_id,point,INF)-point.y)<.001,"root must meet the rendered terrain triangle")
				checked+=1
	for child: Node in node.get_children(): checked+=check_triangles(child,pose,track_id)
	return checked

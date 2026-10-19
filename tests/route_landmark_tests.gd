extends SceneTree


func _initialize() -> void: call_deferred("run")


func run() -> void:
	Catalog.load_all()
	var report: Array[Dictionary] = []
	for pair: Array in [[3,"timber_bridge",.47,54],[5,"viaduct",.69,126]]:
		var track: TrackDefinition = Catalog.tracks[int(pair[0])]
		var anchor_s := CourseArt.original_s(track,float(pair[2]))
		var world := TrackWorld.new()
		world.track = track
		var anchor := world.ground_pose(anchor_s,0)
		var model := CourseArt.model(pair[1])
		model.transform = anchor
		RouteLandmark.conform(model,track,anchor_s,anchor)
		assert(model.get_meta("route_conformed"))
		var levels := [0,0,0]
		for node: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
			var level := CourseArt.level_of(str(node.name))
			var pose := node.transform
			var parent := node.get_parent() as Node3D
			while parent!=null and parent!=model:
				pose = parent.transform*pose
				parent = parent.get_parent() as Node3D
			pose = anchor*pose
			var vertices := node.mesh.get_faces()
			levels[level]+=vertices.size()/3
			assert(levels[level]<20000)
			var points := PackedVector3Array()
			for vertex: Vector3 in vertices: points.append(pose*vertex)
			for offset in range(-int(pair[3])*.5+2,int(pair[3])*.5-1,4):
				for lateral: float in [-7.0,0.0,7.0]:
					var s: float = anchor_s+offset
					var center := track.pose(s,lateral).origin
					var i := track.sample_index(s)
					var next := (i+1)%track.points.size()
					var end := track.distances[next] if next>0 else track.length
					var t := (fposmod(s,track.length)-track.distances[i])/(end-track.distances[i])
					center.y = lerpf(RouteGeometry.point(track,i,lateral).y,RouteGeometry.point(track,next,lateral).y,t)
					for first in range(0,points.size(),3):
						assert(Geometry3D.segment_intersects_triangle(center+Vector3.UP*.05,center+Vector3.UP*4,points[first],points[first+1],points[first+2])==null,"all bridge LODs must stay below the climbing/descending driving surface")
		assert(levels.min()>0)
		report.append({"track":track.id,"model":pair[1],"triangles_by_lod":levels,"span_m":pair[3]})
		model.free()
		world.free()
	DirAccess.make_dir_recursive_absolute("res://reports")
	var file := FileAccess.open("res://reports/route-landmarks.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":true,"cases":report},"\t")+"\n")
	file.close()
	print("TIMBER_VIADUCT_ALL_LODS_FOLLOW_BANKED_RAMPED_STEEP_ROAD_CLEAR_DRIVING_VIEW_PASS")
	quit()

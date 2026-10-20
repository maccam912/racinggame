extends SceneTree
## Actual collision levels and complete bounded mesh footprints for the new routes.
const CROSSINGS := {
	"spillway_sprint":[Vector2(4210,822),Vector2(5754,1744),Vector2(6676,3288)],
	"caldera_crosscut":[Vector2(4550,262),Vector2(5334,742),Vector2(5816,1530),Vector2(6602,2018),Vector2(7084,2806),Vector2(7868,3288),Vector2(8348,4070)]}
func _initialize() -> void: call_deferred("run")
func run() -> void:
	Catalog.load_all()
	var frozen: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/content8/tracks.json"))
	for index in range(6,8):
		assert(Catalog.tracks[index].definition.ordered_control_points==frozen.tracks[index].ordered_control_points,"the layered city crossing and quarry hairpins retain their authored geometry")
	var evidence: Array[Dictionary] = []
	for track: TrackDefinition in Catalog.tracks:
		if not CROSSINGS.has(track.id): continue
		var world := TrackWorld.new()
		world.build(track)
		root.add_child(world)
		await physics_frame
		await physics_frame
		assert(world.art.elevated and world.has_node("ElevatedDeck") and not world.has_node("Road_verges"))
		assert(world.poster_sites.size()==3 and world.spectacle_sites.size()>=12)
		for site: Dictionary in world.spectacle_sites:
			assert(world.clear_of_road(site.pose.origin,site.radius))
			assert(not RoadsidePosterArt.blocks_sightline(world.poster_sites,site.pose.origin))
		var structures := 0
		for node: MeshInstance3D in world.find_children("*","MeshInstance3D",false,false):
			if not node.has_meta("spectacle"): continue
			structures += 1
			assert(node.find_children("*","CollisionObject3D",true,false).is_empty())
			assert(node.material_override is ShaderMaterial and node.mesh.get_faces().size()/3<3000)
			var vertices: PackedVector3Array = node.mesh.get_faces()
			var radius: float = node.get_meta("footprint_radius_m")
			for vertex: Vector3 in vertices:
				assert(vertex.is_finite() and Vector2(vertex.x,vertex.z).length()<=radius+.01,"every mesh fits its road-clearance footprint")
			if str(node.get_meta("spectacle")) in ["ReservoirCliff","VolcanicRidge"]:
				var below_floor := false
				for vertex: Vector3 in vertices:
					var at := node.transform*vertex
					var floor_y := CourseArt.height_from_grid(world.terrain_grid,at,-INF)
					assert(is_finite(floor_y),"the entire distant-cliff footprint needs actual exported terrain beneath it")
					if at.y<floor_y: below_floor = true
					var base_limit := node.get_aabb().position.y+node.get_aabb().size.y*.15
					if vertex.y<=base_limit:
						assert(at.y<=floor_y+.01,"the broad lower formation footprint, not only its center point, embeds in the ground")
				assert(below_floor,"large formation bases embed in the terrain")
			var arrays := node.mesh.surface_get_arrays(0)
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			for index in range(0,vertices.size(),3):
				assert((vertices[index+1]-vertices[index]).cross(vertices[index+2]-vertices[index]).dot(normals[index])<=.0001,"front winding and outward normal agree")
		for pair: Vector2 in CROSSINGS[track.id]:
			var first := world.ground_pose(pair.x,0).origin
			var last := world.ground_pose(pair.y,0).origin
			assert(Vector2(first.x,first.z).distance_to(Vector2(last.x,last.z))<4 and absf(first.y-last.y)>65)
			for s: float in [pair.x,pair.y]:
				var state := VehicleState.new()
				state.position = world.ground_pose(s,0).origin+Vector3.UP*.35
				state.yaw = atan2(-track.pose(s).basis.z.x,track.pose(s).basis.z.z)
				var query := WorldQuery.new(world.get_world_3d(),track,s)
				var ground := query.ground(state)
				assert(ground.supported and absf(ground.height-state.position.y+.35)<.15,"probes stay on each actual crossing level")
				assert(minf(absf(ground.s-s),track.length-absf(ground.s-s))<3)
				query = null
		if track.id=="caldera_crosscut":
			assert(world.clear_of_road(Vector3.ZERO,300) and world.has_node("CalderaCrater") and world.has_node("CraterLava"))
			await assert_crater_channels(world)
		evidence.append({"track":track.id,"structures":structures,"crossings":CROSSINGS[track.id].size(),"sites":world.spectacle_sites.size()})
		world.queue_free()
		await process_frame
	DirAccess.make_dir_recursive_absolute("res://reports")
	var file := FileAccess.open("res://reports/course-spectacles.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":true,"content_hash":Compatibility.content_hash(),"cases":evidence},"\t")+"\n")
	file.close()
	print("TEN_ROUTE_RETAINED_EXPANSIONS_TEN_LAYERED_CROSSINGS_WATERWORKS_CALDERA_BOUNDS_WINDING_NO_COLLISION_PASS")
	quit()


func assert_crater_channels(world: TrackWorld) -> void:
	var cone := world.get_node("CalderaCrater") as MeshInstance3D
	var pool := world.get_node("CraterLava") as MeshInstance3D
	var streams := world.get_node("CraterStreams") as MeshInstance3D
	assert(streams.material_override==pool.material_override,"channels reuse the pool material and shader")
	var body := StaticBody3D.new()
	body.collision_layer = 8
	var collider := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(cone.mesh.get_faces())
	collider.shape = shape
	body.add_child(collider)
	world.add_child(body)
	await physics_frame
	await physics_frame
	var vertices := streams.mesh.get_faces()
	var arrays := streams.mesh.surface_get_arrays(0)
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var visible_from_road := 0
	for index in range(0,vertices.size(),3):
		var center: Vector3 = (vertices[index]+vertices[index+1]+vertices[index+2])/3
		var normal: Vector3 = normals[index]
		var ray := PhysicsRayQueryParameters3D.create(center+normal*.1,center-normal*6,8)
		var hit := world.get_world_3d().direct_space_state.intersect_ray(ray)
		assert(not hit.is_empty() and center.distance_to(hit.position)<6,"each actual channel face stays just above the actual cone surface")
		for fraction: float in [.0,.25,.5,.75]:
			var eye := world.ground_pose(world.track.length*fraction,0).origin+Vector3.UP*1.8
			ray = PhysicsRayQueryParameters3D.create(eye,center,8)
			if world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): visible_from_road += 1
	assert(visible_from_road>0,"actual road-level views can see exterior lava without looking over the rim")
	body.queue_free()
	await process_frame
	print("ACTUAL_CALDERA_CHANNEL_FACE_SUPPORT_AND_ROAD_LEVEL_LINE_OF_SIGHT_PASS faces="+str(vertices.size()/3)+" visible_pairs="+str(visible_from_road))

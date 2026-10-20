extends SceneTree
## Actual physics-space layered crossing and bounded original decoration checks.

func _initialize() -> void: call_deferred("run")

func run() -> void:
	Catalog.load_all()
	assert(Catalog.tracks.size()==8 and Catalog.tracks[6].id=="skyline_splice" and Catalog.tracks[7].id=="quarry_switchback")
	assert(LobbyState.valid_rules({"track":7,"laps":1,"bot_fill":true,"difficulty":1,"contact":true}))
	assert(not LobbyState.valid_rules({"track":8,"laps":1,"bot_fill":true,"difficulty":1,"contact":true}))
	var frozen: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/content5/tracks.json"))
	for index in range(6):
		assert(Catalog.tracks[index].definition==frozen.tracks[index],"classic six routes retain their exact gameplay definitions")
	var records: Array[Dictionary] = []
	for track: TrackDefinition in Catalog.tracks:
		var world := TrackWorld.new()
		world.build(track)
		root.add_child(world)
		await physics_frame
		await physics_frame
		var counts := {"Rocks":0,"Logs":0,"Waterfall":0,"Tower":0,"Bluff":0}
		for site: Dictionary in world.decor_sites:
			assert(world.clear_of_road(site.pose.origin,float(site.radius)))
			assert(not RoadsidePosterArt.blocks_sightline(world.poster_sites,site.pose.origin))
			counts[site.kind] += 1
		for node: MeshInstance3D in world.find_children("Decor*","MeshInstance3D",false,false):
			assert(node.mesh.get_faces().size()/3<500 and node.find_children("*","CollisionObject3D",true,false).is_empty())
			assert(node.is_in_group("scenery_distance") and node.get_aabb().size.length()<(300 if node.get_meta("kind")=="Tower" else 60))
		if track.id!="skyline_splice": assert(counts.Rocks>=8)
		if track.id in ["citrus_pass","redwood_run","pacific_summit","quarry_switchback"]: assert(counts.Logs>=3)
		if track.id in ["redwood_run","pacific_summit","quarry_switchback"]: assert(counts.Waterfall==2)
		if track.id=="skyline_splice":
			assert(counts.Tower>=40)
			assert(world.has_node("ElevatedDeck") and not world.has_node("Road_verges"))
			var deck: Array = world.get_node("ElevatedDeck").mesh.surface_get_arrays(0)
			var normals: PackedVector3Array = deck[Mesh.ARRAY_NORMAL]
			assert(normals.size()==track.points.size()*18)
			for index in range(track.points.size()):
				var right := track.forwards[index].cross(Vector3.UP).normalized()
				assert(normals[index*18].dot(-right)>.9 and normals[index*18+6].dot(right)>.9,"both bridge side faces point outward")
				assert(normals[index*18+12].y<-.9,"bridge underside faces downward and is visible from below")
			assert(world.find_children("BridgePylon_*","MeshInstance3D",false,false).size()>100)
			var lower_s := CourseArt.original_s(track,0)
			var upper_s := CourseArt.original_s(track,.5)
			var lower := track.pose(lower_s).origin
			var upper := track.pose(upper_s).origin
			assert(Vector2(lower.x,lower.z).distance_to(Vector2(upper.x,upper.z))<2 and upper.y-lower.y>175,"figure-eight roads cross at distinct physical heights")
			for s: float in [lower_s,upper_s]:
				var state := VehicleState.new()
				state.position = world.ground_pose(s,0).origin+Vector3.UP*.35
				state.yaw = atan2(-track.pose(s).basis.z.x,track.pose(s).basis.z.z)
				var query := WorldQuery.new(world.get_world_3d(),track,s)
				var ground := query.ground(state)
				assert(ground.supported and absf(ground.height-state.position.y+.35)<.15,"ground probes hit the correct crossing level")
				assert(minf(absf(ground.s-s),track.length-absf(ground.s-s))<3,"route hint remains on the same crossing branch")
				query = null
			for column: MeshInstance3D in world.find_children("BridgePylon_*","MeshInstance3D",false,false):
				var s := float(column.get_meta("route_s"))
				for index in range(0,track.points.size(),4):
					var delta := absf(track.distances[index]-s)
					if minf(delta,track.length-delta)<80 or track.points[index].y>column.position.y+column.mesh.size.y*.5+3.4: continue
					assert(Vector2(column.position.x-track.points[index].x,column.position.z-track.points[index].z).length()>=float(track.bake.samples[index][8])*.5+9,"pylons cannot intersect another crossing branch")
		if track.id=="quarry_switchback":
			assert(counts.Bluff>=15 and world.art.verge_extent==18)
			assert(world.verge_height(0,48,track.pose(0,48).origin)==-INF)
		if counts.Waterfall>0:
			var texture: Texture2D = load("res://assets/exported/decorations/waterfall-v1.png")
			var pixels := texture.get_image()
			assert(pixels.has_mipmaps() and pixels.get_pixel(0,0).a==0 and pixels.get_pixel(600,600).a>.9)
			var cutouts := world.find_children("IllustratedWaterfall","MeshInstance3D",true,false)
			assert(cutouts.size()==2)
			for cutout: MeshInstance3D in cutouts:
				assert(cutout.custom_aabb.size==Vector3(27,26,27) and cutout.material_override.billboard_mode==BaseMaterial3D.BILLBOARD_FIXED_Y)
		records.append({"track":track.id,"decorations":counts})
		world.queue_free()
		await process_frame
	var file := FileAccess.open("res://reports/content6-course-variety.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":true,"content_hash":Compatibility.content_hash(),"cases":records},"\t")+"\n")
	file.close()
	print("EIGHT_ROUTES_CLASSIC_BYTES_LAYERED_CROSSING_DECK_SUPPORTS_ROCKS_LOGS_WATERFALLS_PASS")
	quit()

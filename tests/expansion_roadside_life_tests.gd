extends SceneTree
## Model bounds and actual road/terrain/sightline placements across the additions.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	Catalog.load_all()
	var before := Compatibility.content_hash()
	var kinds: Dictionary = {}
	var shapes: Dictionary = {}
	var model_rows: Array[Dictionary] = []
	for choices: Array in ExpansionRoadsideLife.KINDS.values():
		for kind: String in choices: kinds[kind] = true
	assert(kinds.size()==36)
	for kind: String in kinds:
		var mesh := ExpansionLifeProps.mesh(kind)
		var arrays := mesh.surface_get_arrays(0)
		var faces := mesh.get_faces()
		assert(faces.size()/3>20 and faces.size()/3<1500)
		for point: Vector3 in faces: assert(point.is_finite() and Vector2(point.x,point.z).length()<7.5)
		for normal: Vector3 in arrays[Mesh.ARRAY_NORMAL]: assert(normal.is_finite() and absf(normal.length()-1)<.01)
		var shape := (str(arrays[Mesh.ARRAY_VERTEX])+str(arrays[Mesh.ARRAY_COLOR])).sha256_text()
		assert(not shapes.has(shape),"every roadside object has a distinct authored mesh/color composition")
		shapes[shape] = true
		model_rows.append({"kind":kind,"triangles":faces.size()/3,"shape":shape})
	var rows: Array[Dictionary] = []
	for index in range(Catalog.tracks.size()):
		var track: TrackDefinition = Catalog.tracks[index]
		var world := TrackWorld.new()
		world.build(track)
		root.add_child(world)
		if index<10:
			assert(not world.has_node("ExpansionRoadsideLife"),"the established ten retain their existing props")
			world.queue_free()
			await process_frame
			continue
		var parent := world.get_node("ExpansionRoadsideLife")
		var sites: Array = parent.get_meta("sites")
		assert(sites.size()>4 and sites.size()<100)
		var seen: Dictionary = {}
		var expected_triangles := 0
		var landmarks: Array[Dictionary] = []
		for description: Dictionary in world.art.landmarks:
			var landmark := ExpansionCourseArt.landmark_site(world,description)
			landmarks.append(landmark)
			var found := false
			for node: Node in world.get_children():
				if node is Node3D and node.has_meta("anchor_u") and is_equal_approx(float(node.get_meta("anchor_u")),float(description.u)):
					assert((node as Node3D).position.distance_to(landmark.pose.origin)<.01)
					found = true
			assert(found,"visibility reservations use the actual placed landmark roots")
		for site: Dictionary in sites:
			var at: Vector3 = site.pose.origin
			seen[site.kind] = true
			assert(site.kind in ExpansionRoadsideLife.KINDS[track.id])
			assert(world.clear_of_road(at,7.5),"all model vertices clear every road branch")
			assert(not RoadsidePosterArt.blocks_sightline(world.poster_sites,at))
			assert(ExpansionRoadsideLife.landmark_clear(landmarks,at,track.pose(site.s-36).origin),"large authored landmarks cannot cover a small roadside object")
			assert(not ExpansionSetPieces.blocks_sightline(world.hero_sites,at))
			for hero: Dictionary in world.hero_sites:
				for clearing: Dictionary in hero.clearings:
					var delta: Vector3 = at-clearing.center
					assert(Vector2(delta.x,delta.z).length()>=float(clearing.radius)+7.5)
			var surface_y := maxf(CourseArt.height_from_grid(world.terrain_grid,at,INF),world.verge_height(site.s,site.lateral,at))
			assert(is_finite(surface_y) and absf(at.y-surface_y)<.01,"roots meet the real exported terrain or banked verge")
			if world.art.water: assert(at.y>=float(CourseArt.terrain_info[track.id].sea_level)+1)
			var toward := track.pose(site.s).origin-at
			toward.y = 0
			assert((-site.pose.basis.z).dot(toward.normalized())>.99,"front panels face the road")
			expected_triangles += ExpansionLifeProps.mesh(site.kind).get_faces().size()/3
		assert(seen.size()==3,"all three authored object types appear on every course")
		assert(parent.find_children("*","CollisionObject3D",true,false).is_empty())
		var actual_triangles := 0
		var settings := SettingsCatalog.defaults(false)
		settings.draw_distance = 700
		settings.vsync = false
		SettingsRuntime.apply(world,settings)
		var batches := parent.find_children("*","MeshInstance3D",false,false)
		assert(batches.size()<=sites.size())
		for node: MeshInstance3D in batches:
			assert(node.visibility_range_end==180 and node.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
			assert(node.mesh.get_aabb().size.x<240 and node.mesh.get_aabb().size.z<240)
			actual_triangles += node.mesh.get_faces().size()/3
		assert(actual_triangles==expected_triangles,"all retained authored objects become actual geometry")
		rows.append({"track":track.id,"sites":sites.size(),"kinds":seen.keys(),"batches":batches.size(),"triangles":actual_triangles})
		print("EXPANSION_ROADSIDE_LIFE ",track.id," sites=",sites.size()," kinds=",seen.keys())
		world.queue_free()
		await process_frame
	assert(before==Compatibility.content_hash())
	var file := FileAccess.open("res://reports/expansion-roadside-life.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":true,"content_hash":before,"models":model_rows,"cases":rows},"\t")+"\n")
	file.close()
	print("THIRTY_COURSES_THIRTY_SIX_ROADSIDE_OBJECTS_REAL_CLEARANCE_GROUNDING_SIGHTLINES_AND_CLASSIC_EXCLUSION_PASS")
	quit()

extends SceneTree

const EXPECTED: Array = [
	[["surf_shop",.12,-25],["lighthouse",.28,45],["pier",.42,0],["beach_hotel",.65,-40],["sun_sign",.82,25]],
	[["fruit_stand",.15,-25],["water_tower",.32,45],["packing_shed",.49,-30],["orange_arch",.68,0],["windmill",.86,35]],
	[["arcade",.12,-22],["marina_wheel",.31,65],["underpass",.46,0],["sailboats",.64,48],["seafood_diner",.81,-24]],
	[["ranger_kiosk",.13,-24],["giant_tree",.30,28],["timber_bridge",.47,0],["visitor_center",.63,-40],["tree_display",.82,25]],
	[["dinosaur",.16,-30],["twin_mesas",.33,165],["rail_trestle",.48,-60],["tunnel_portal",.60,0],["motel_sign",.79,30]],
	[["observatory",.14,-65],["overlook",.33,35],["mountain_lodge",.50,-45],["viaduct",.69,0],["balloons",.84,85]]]


func _initialize() -> void: call_deferred("run")


func run() -> void:
	Catalog.load_all()
	CourseArt.load_catalog()
	assert(CourseArt.library.size()==47 and CourseArt.courses.size()==6)
	for id: String in CourseArt.library:
		var row: Dictionary = CourseArt.library[id]
		for level in range(3):
			var mesh := CourseArt.mesh(id,level)
			assert(mesh.get_surface_count()==1)
			var arrays := mesh.surface_get_arrays(0)
			assert(arrays[Mesh.ARRAY_INDEX].size()/3==int(row.triangles[level]))
			if row.category=="foliage" and level<2:
				var texture: Texture2D = load("res://assets/exported/textures/foliage_atlas.png")
				var pixels := texture.get_image()
				for uv: Vector2 in arrays[Mesh.ARRAY_TEX_UV]:
					assert(pixels.get_pixel(clampi(int(uv.x*512),0,511),clampi(int(uv.y*512),0,511)).a>.9,"solid foliage LODs must not sample transparent silhouette space")
	for index in range(Catalog.tracks.size()):
		var track: TrackDefinition = Catalog.tracks[index]
		var raw := RouteGeometry.meshes(track,true)
		var before := var_to_bytes(raw.asphalt.surface_get_arrays(0))
		var face_mesh := CourseRoadMesh.front_faces(raw.asphalt)
		var arrays := face_mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		for first in range(0,vertices.size(),3):
			assert((vertices[first+1]-vertices[first]).cross(vertices[first+2]-vertices[first]).dot(normals[first])<=.00001,"rendered road must use clockwise front winding")
		assert(before==var_to_bytes(raw.asphalt.surface_get_arrays(0)),"visual winding correction cannot mutate collision inputs")
		var world := TrackWorld.new()
		world.begin_build(track)
		var steps: int = 0
		while true:
			steps += 1
			if world.advance_build(): break
		assert(steps==world.build_steps())
		root.add_child(world)
		assert(world.start_lamps.size()==3)
		world.set_start_lamps("Countdown",0,0)
		assert(world.start_lamps[0].material_override.albedo_color==Color("F16B50") and world.start_lamps[1].material_override.albedo_color==Color("343C49"))
		world.set_start_lamps("Countdown",120,0)
		assert(world.start_lamps[2].material_override.albedo_color==Color("F16B50"))
		world.set_start_lamps("Racing",0,0)
		assert(world.start_lamps[2].material_override.albedo_color==Color("5E9654"))
		world.set_start_lamps("Racing",60,60)
		assert(world.start_lamps[0].material_override.albedo_color==Color("343C49"))
		for row: Array in EXPECTED[index]:
			var landmark := world.get_node("Landmark_"+str(row[0])) as Node3D
			assert(landmark.get_meta("anchor_u")==row[1] and landmark.get_meta("anchor_lateral")==row[2])
			var s := float(landmark.get_meta("anchor_s"))
			var actual_u := float(track.bake.samples[track.sample_index(s)][7])
			assert(absf(actual_u-float(row[1]))*track.length<2,"original-u anchor remains within longitudinal tolerance after start rotation")
			var expected := track.pose(s,float(row[2])).origin
			assert(Vector2(expected.x,expected.z).distance_to(Vector2(landmark.position.x,landmark.position.z))<.001)
		var values := SettingsCatalog.defaults(false)
		values.draw_distance = 400
		SettingsRuntime.apply(world,values)
		for node: GeometryInstance3D in get_nodes_in_group("scenery_distance"):
			assert(node.visibility_range_end==minf(400,float(node.get_meta("lod_limit",400))))
		assert(world.get_node("RoadsideBarriers").visibility_range_end==0)
		if track.id in ["marina_lights","sunstone_canyon"]:
			await physics_frame
			await physics_frame
			var point := track.pose(CourseArt.original_s(track,.46 if track.id=="marina_lights" else .60)).origin
			var ray := PhysicsRayQueryParameters3D.create(point+Vector3.UP*12,point+Vector3.UP,1)
			assert(world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"decorative roofs must not enter the shared driving collision layer")
			ray.collision_mask = 2
			assert(not world.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(),"camera collision must see the tunnel roof")
		if track.id=="pacific_summit":
			assert(world.has_node("LandingStripe") and world.find_children("JumpWarningBar_*","MeshInstance3D",true,false).size()==3)
		world.queue_free()
		for frame in range(2): await process_frame
	assert(CourseArt.library.marina_wheel.size_m[0]>=45 and CourseArt.library.marina_wheel.size_m[0]<49)
	assert(CourseArt.courses.citrus_pass.landmarks[3].clearance==8)
	assert(CourseArt.courses.marina_lights.landmarks[2].clearance==7)
	assert(CourseArt.courses.sunstone_canyon.landmarks[3].clearance==8)
	print("SCENERY_47_ASSETS_30_ORIGINAL_U_ANCHORS_LODS_ATLAS_ALPHA_COLLISION_IMMUTABILITY_PASS")
	quit()

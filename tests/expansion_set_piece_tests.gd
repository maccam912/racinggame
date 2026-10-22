extends SceneTree
## Real mesh/route clearance, bounded geometry and accessibility on all additions.
func _initialize() -> void: call_deferred("run")

func run() -> void:
	Catalog.load_all()
	var content_hash := Compatibility.content_hash()
	var reports: Array[Dictionary] = []
	for track: TrackDefinition in Catalog.tracks.slice(10):
		var world := TrackWorld.new()
		world.build(track)
		root.add_child(world)
		assert(world.hero_sites.size()==1,"every new course needs its own actual 3D set piece: "+track.id)
		assert(float(world.hero_sites[0].approach_alignment)>.82,"the landmark must be visible in the ordinary forward approach")
		var roots := world.find_children("HeroSetPiece_*","Node3D",false,false)
		assert(roots.size()==1)
		var hero := roots[0] as Node3D
		assert(int(hero.get_meta("grounded_base_vertices"))>0,"foundations meet the actual surrounding terrain")
		assert(hero.find_children("*","CollisionObject3D",true,false).is_empty())
		var triangles := 0
		var tested_rays := 0
		var bounds := AABB()
		var first_vertex := true
		var faces := PackedVector3Array()
		for mesh: MeshInstance3D in hero.find_children("*","MeshInstance3D",true,false):
			assert(mesh.is_in_group("scenery_distance") and mesh.visibility_range_end==700)
			assert(mesh.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
			for surface in range(mesh.mesh.get_surface_count()):
				var arrays: Array = mesh.mesh.surface_get_arrays(surface)
				for normal: Vector3 in arrays[Mesh.ARRAY_NORMAL]: assert(normal.is_finite() and absf(normal.length()-1)<.01)
			for point: Vector3 in mesh.mesh.get_faces():
				assert(point.is_finite())
				var at := hero.global_transform.affine_inverse()*mesh.global_transform*point
				if at.y<=.1 and not mesh.is_in_group("scenery_motion"):
					var global_at := hero.global_transform*at
					assert(global_at.y<=CourseArt.height_from_grid(world.terrain_grid,global_at,-INF)+.01,"set-piece foundations cannot float above the real terrain")
				faces.append(at)
				if first_vertex:
					bounds = AABB(at,Vector3.ZERO)
					first_vertex = false
				else: bounds = bounds.expand(at)
			triangles += mesh.mesh.get_faces().size()/3
		assert(triangles>100 and triangles<6000,"each feature has a bounded low-poly budget")
		if hero.get_meta("spanning"):
			for index in range(0,track.points.size(),4):
				var route_point := hero.to_local(track.points[index])
				if absf(route_point.x)>bounds.size.x*.5+30 or absf(route_point.z)>bounds.size.z*.5+30: continue
				var width := float(track.bake.samples[index][8])
				for lateral: float in [-width*.45,0.0,width*.45]:
					var at := RouteGeometry.point(track,index,lateral)
					var low := hero.to_local(at+Vector3.UP*.2)
					var high := hero.to_local(at+Vector3.UP*12)
					for first in range(0,faces.size(),3):
						assert(Geometry3D.segment_intersects_triangle(low,high,faces[first],faces[first+1],faces[first+2])==null,"set-piece geometry clips the real road/camera corridor: "+track.id)
					tested_rays += 1
			assert(tested_rays>0)
		else:
			var radius: float = hero.get_meta("radius")
			assert(world.clear_of_road(hero.position,radius+5))
			for at: Vector3 in faces:
				assert(Vector2(at.x,at.z).length()<=radius,"the entire standalone footprint, including moving silhouettes, stays in its reserved clearing")
		if track.id in ["frostbite_fjord","cloudforest_climb"]: check_waterfall_lip(hero)
		var settings := SettingsCatalog.defaults(false)
		settings.reduce_motion = true
		settings.vsync = false
		SettingsRuntime.apply(world,settings)
		for mesh: MeshInstance3D in hero.find_children("*","MeshInstance3D",true,false):
			if mesh.is_in_group("scenery_motion"): assert(mesh.material_override.get_shader_parameter("animation_enabled")==0)
		settings.reduce_motion = false
		SettingsRuntime.apply(world,settings)
		for mesh: MeshInstance3D in hero.find_children("*","MeshInstance3D",true,false):
			if mesh.is_in_group("scenery_motion"): assert(mesh.material_override.get_shader_parameter("animation_enabled")==1)
		reports.append({"track":track.id,"kind":hero.get_meta("set_piece_kind"),"route_s":hero.get_meta("route_s"),"triangles":triangles,"corridor_rays":tested_rays,"spanning":hero.get_meta("spanning"),"approach_alignment":world.hero_sites[0].approach_alignment})
		print("HERO_SET_PIECE ",track.id," triangles=",triangles," corridor_rays=",tested_rays)
		world.queue_free()
		await process_frame
	assert(content_hash==Compatibility.content_hash(),"cosmetic landmarks cannot change gameplay compatibility")
	var file := FileAccess.open("res://reports/expansion-set-pieces.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":true,"content_hash":content_hash,"cases":reports,"boundary":"Actual 3D meshes, road/camera corridor rays, conservative standalone and animated footprint bounds, no driving collision, bounded triangles and Reduce Motion material settings. Native appearance and motion pixels are separate."},"\t")+"\n")
	file.close()
	print("THIRTY_UNIQUE_3D_SET_PIECES_REAL_ROAD_CLEARANCE_BOUNDS_AND_REDUCED_MOTION_PASS")
	quit()

func check_waterfall_lip(hero: Node3D) -> void:
	var cliff := (hero.get_node("Architecture") as MeshInstance3D).mesh.get_faces()
	var ice := (hero.get_node("Accents") as MeshInstance3D).mesh.get_faces()
	var crest := -INF
	for at: Vector3 in ice: crest = maxf(crest,at.y)
	var checked := 0
	for at: Vector3 in ice:
		if at.y<crest*.85: continue
		var front := -INF
		for first in range(0,cliff.size(),3):
			var hit: Variant = Geometry3D.segment_intersects_triangle(at+Vector3(0,0,100),at-Vector3(0,0,100),cliff[first],cliff[first+1],cliff[first+2])
			if hit!=null: front = maxf(front,(hit as Vector3).z)
		assert(is_finite(front) and at.z<=front+.1,"the waterfall sheets emerge from the actual cliff instead of hanging above its crest: %s front=%s"%[at,front])
		checked += 1
	assert(checked>=18)

extends SceneTree
## Full swept bounds stay above the real road and its chase-camera corridor.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	Catalog.load_all()
	var records: Array[Dictionary] = []
	for id: String in ["alpine_meadow","neon_underpass"]:
		var track: TrackDefinition = Catalog.tracks.filter(func(item: TrackDefinition) -> bool: return item.id==id)[0]
		var world := TrackWorld.new()
		world.build(track)
		root.add_child(world)
		var hero := world.find_children("HeroSetPiece_*","Node3D",false,false)[0] as Node3D
		var moving: Array[MeshInstance3D] = []
		for node: MeshInstance3D in hero.find_children("*","MeshInstance3D",false,false):
			if str(node.name).begins_with("CableCabin_") or node.name=="MetroShuttle": moving.append(node)
		assert(moving.size()==(8 if id=="alpine_meadow" else 1))
		var road_points := 0
		var min_margin := INF
		for node: MeshInstance3D in moving:
			assert(node.is_in_group("scenery_motion") and node.has_meta("travel_bounds"))
			assert(node.custom_aabb==node.get_meta("travel_bounds") and node.extra_cull_margin==0)
			var bounds: AABB = node.custom_aabb
			var material := node.material_override as ShaderMaterial
			for index in range(track.points.size()):
				var width := float(track.bake.samples[index][8])
				for lateral: float in [-width*.45,0.0,width*.45]:
					var at := hero.to_local(RouteGeometry.point(track,index,lateral))
					if at.x<bounds.position.x or at.x>bounds.end.x or at.z<bounds.position.z or at.z>bounds.end.z: continue
					var margin := bounds.position.y-at.y-12
					assert(margin>0,"the full animated silhouette stays above road/camera space at every phase")
					min_margin = minf(min_margin,margin)
					road_points += 1
			var vertices := node.mesh.get_faces()
			for phase in range(65):
				var offset := Vector3.ZERO
				if id=="alpine_meadow":
					var extent: Vector2 = node.get_meta("travel_extent")
					var length := 4*extent.x+TAU*extent.y
					var initial: float = node.get_meta("cable_phase")
					var delta := ExpansionTransport.cable_position(initial+length*phase/64,extent.x,extent.y)-ExpansionTransport.cable_position(initial,extent.x,extent.y)
					offset = Vector3(delta.x,0,delta.y)
				else: offset.x = sin(TAU*phase/64)*float(node.get_meta("travel_distance"))
				for vertex: Vector3 in vertices: assert(bounds.grow(.01).has_point(vertex+offset),"swept culling bounds include every moving vertex")
			assert(material.get_shader_parameter("animation_enabled")==1.0)
		assert(road_points>0)
		var settings := SettingsCatalog.defaults(false)
		settings.reduce_motion = true
		settings.vsync = false
		SettingsRuntime.apply(world,settings)
		for node: MeshInstance3D in moving: assert(node.material_override.get_shader_parameter("animation_enabled")==0.0)
		records.append({"track":id,"moving_meshes":moving.size(),"road_camera_checks":road_points,"minimum_camera_clearance_m":min_margin,"swept_vertex_phases":65})
		world.queue_free()
		await process_frame
	var file := FileAccess.open("res://reports/expansion-transport.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":true,"content_hash":Compatibility.content_hash(),"cases":records},"\t")+"\n")
	file.close()
	print("TWO_OVERHEAD_TRANSPORTS_COMPLETE_SWEPT_BOUNDS_REAL_ROAD_CAMERA_CLEARANCE_AND_REDUCED_MOTION_PASS")
	quit()

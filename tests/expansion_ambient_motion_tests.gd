extends SceneTree
## Actual swept silhouettes and accessibility across the regional motion additions.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	Catalog.load_all()
	var hash_before := Compatibility.content_hash()
	var rows: Array[Dictionary] = []
	for id: String in ["temple_coast","sakura_ring","copper_mesa","oasis_citadel","palm_bay","redwood_run"]:
		var track: TrackDefinition = Catalog.tracks.filter(func(item: TrackDefinition) -> bool: return item.id==id)[0]
		var world := TrackWorld.new()
		world.build(track)
		root.add_child(world)
		var settings := SettingsCatalog.defaults(false)
		settings.vsync = false
		settings.reduce_motion = false
		SettingsRuntime.apply(world,settings)
		var moving := 0
		var road_checks := 0
		var margin := INF
		var water_nodes := 0
		for node: MeshInstance3D in world.find_children("*","MeshInstance3D",true,false):
			var material := node.material_override as ShaderMaterial
			if material==null: continue
			if material.shader.resource_path=="res://assets/exported/shaders/water.gdshader":
				assert(node.is_in_group("scenery_motion") and material.get_shader_parameter("animation_enabled")==1.0)
				water_nodes += 1
			if not node.has_meta("motion_kind"): continue
			moving += 1
			assert(node.is_in_group("scenery_motion") and node.extra_cull_margin==0)
			var bounds: AABB = node.get_meta("travel_bounds")
			assert(node.custom_aabb==bounds and material.get_shader_parameter("animation_enabled")==1.0)
			var vertices := node.mesh.get_faces()
			var arrays := node.mesh.surface_get_arrays(0)
			for normal: Vector3 in arrays[Mesh.ARRAY_NORMAL]: assert(normal.is_finite() and absf(normal.length()-1)<.01)
			for phase in range(129):
				var pose := Transform3D.IDENTITY
				if node.get_meta("motion_kind")=="sway_x":
					var angle: float = node.get_meta("sway_angle")
					var pivot: Vector3 = node.get_meta("sway_pivot")
					pose.basis = Basis(Vector3.RIGHT,lerpf(-angle,angle,phase/128.0))
					pose.origin = pivot-pose.basis*pivot
				else:
					var span: float = node.get_meta("belt_span")
					pose.origin.x = lerpf(-span,span,phase/128.0)-float(node.get_meta("belt_start"))
				for point: Vector3 in vertices: assert(bounds.has_point(pose*point),"bounds contain every moving vertex, including between construction samples")
			var hero := node.get_parent() as Node3D
			for index in range(track.points.size()):
				var width := float(track.bake.samples[index][8])
				for lateral: float in [-width*.45,0.0,width*.45]:
					var point := hero.to_local(RouteGeometry.point(track,index,lateral))
					if point.x<bounds.position.x or point.x>bounds.end.x or point.z<bounds.position.z or point.z>bounds.end.z: continue
					var clearance := bounds.position.y-point.y-12
					assert(clearance>0,"full swept silhouettes stay above actual road and camera space")
					margin = minf(margin,clearance)
					road_checks += 1
		if id in ["temple_coast","sakura_ring","copper_mesa"]:
			assert(moving=={"temple_coast":1,"sakura_ring":9,"copper_mesa":8}[id] and road_checks>0)
		if id=="oasis_citadel":
			var hero := world.find_children("HeroSetPiece_*","Node3D",false,false)[0] as Node3D
			var water := hero.get_node("Accents") as MeshInstance3D
			assert(water.is_in_group("scenery_motion") and water.material_override.get_shader_parameter("water_flow"))
			assert(water.material_override.get_shader_parameter("flow_axis")==0)
		if id in ["temple_coast","palm_bay","redwood_run"]: assert(water_nodes>0,"ocean and pool materials participate in Reduce Motion")
		settings.reduce_motion = true
		SettingsRuntime.apply(world,settings)
		for node: MeshInstance3D in world.find_children("*","MeshInstance3D",true,false):
			if node.is_in_group("scenery_motion"): assert(node.material_override.get_shader_parameter("animation_enabled")==0.0)
		rows.append({"track":id,"moving_meshes":moving,"road_camera_checks":road_checks,"minimum_camera_clearance_m":margin if is_finite(margin) else null,"water_nodes":water_nodes,"swept_vertex_phases":129})
		world.queue_free()
		await process_frame
	assert(hash_before==Compatibility.content_hash())
	var file := FileAccess.open("res://reports/expansion-ambient-motion.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":true,"content_hash":hash_before,"cases":rows},"\t")+"\n")
	file.close()
	print("REGIONAL_BELL_LANTERNS_CONVEYOR_FLOWING_AQUEDUCT_SWEPT_BOUNDS_AND_WATER_REDUCED_MOTION_PASS")
	quit()

extends SceneTree
## Isolate distant-landform changes using the exact pre-change float32 grids.
func _initialize() -> void: call_deferred("run")

func restore_terrain(world: TrackWorld, old: Dictionary) -> void:
	for node: MeshInstance3D in world.get_node("CosmeticTerrain").find_children("*","MeshInstance3D",true,false):
		var arrays := node.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var tool := ExpansionSetPieces.tool()
		for first in range(0,indices.size(),3):
			var points: Array[Vector3] = []
			for corner in range(3):
				var point := vertices[indices[first+corner]]
				point.y = old[Vector2i(roundi(point.x/32),roundi(point.z/32))]
				points.append(point)
			var normal := -(points[1]-points[0]).cross(points[2]-points[0]).normalized()
			for corner in range(3):
				tool.set_normal(normal)
				tool.set_color(colors[indices[first+corner]])
				tool.add_vertex(points[corner])
		node.mesh = tool.commit()
	world.terrain_grid = old.duplicate()
	CourseArt.terrain_heights[world.track.id] = world.terrain_grid

func freeze_water(world: TrackWorld, shader: Shader) -> void:
	# Diagnostic only: keep pre-existing ocean waves at the same phase in pairs.
	for node: MeshInstance3D in world.find_children("*","MeshInstance3D",true,false):
		var surface := node.material_override as ShaderMaterial
		if surface!=null and surface.shader.resource_path=="res://assets/exported/shaders/water.gdshader":
			var still := surface.duplicate() as ShaderMaterial
			still.shader = shader
			node.material_override = still

func capture(path: String) -> Image:
	for frame in range(8): await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image()
	assert(result.save_png(path)==OK)
	return result

func changed(a: Image, b: Image) -> int:
	var count := 0
	for y in range(0,a.get_height(),2):
		for x in range(0,a.get_width(),2):
			var p := a.get_pixel(x,y)
			var q := b.get_pixel(x,y)
			if maxf(absf(p.r-q.r),maxf(absf(p.g-q.g),absf(p.b-q.b)))>.015: count += 1
	return count

func view_for(world: TrackWorld, old: Dictionary) -> Dictionary:
	var candidates: Array[Dictionary] = []
	for cell: Vector2i in world.terrain_grid:
		var delta := float(world.terrain_grid[cell])-float(old[cell])
		if absf(delta)>.001: candidates.append({"cell":cell,"delta":delta})
	candidates.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return absf(a.delta)>absf(b.delta))
	for candidate: Dictionary in candidates:
		var at := Vector3(candidate.cell.x*32,world.terrain_grid[candidate.cell],candidate.cell.y*32)
		var nearest := INF
		var anchor := 0
		for i in range(0,world.track.points.size(),8):
			var point := world.track.points[i]
			var distance := Vector2(at.x-point.x,at.z-point.z).length_squared()
			if distance<nearest:
				nearest = distance
				anchor = i
		for i in range(anchor-9,anchor+10):
			var index := posmod(i,world.track.points.size())
			var point := world.track.points[index]
			var distance := Vector2(at.x-point.x,at.z-point.z).length_squared()
			if distance<nearest:
				nearest = distance
				anchor = index
		if nearest>550*550: continue
		var position := world.track.points[anchor]+Vector3.UP*32
		return {"position":position,"target":at+Vector3.UP*8,"delta":candidate.delta,"distance_m":sqrt(nearest),"route_s":world.track.distances[anchor]}
	assert(false,"a changed landform must be visible inside the normal draw range")
	return {}

func run() -> void:
	assert(DisplayServer.get_name()!="headless")
	var snapshot_path := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--baseline="): snapshot_path = arg.trim_prefix("--baseline=")
	assert(not snapshot_path.is_empty())
	var snapshot: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(snapshot_path))
	Catalog.load_all()
	root.size = Vector2i(1280,720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	DisplayServer.window_move_to_foreground()
	var output := "res://reports/terrain-landform-native"
	DirAccess.make_dir_recursive_absolute(output)
	var rows: Array[Dictionary] = []
	var still_water := Shader.new()
	still_water.code = FileAccess.get_file_as_string("res://assets/exported/shaders/water.gdshader").replace("TIME","0.0")
	for track: TrackDefinition in Catalog.tracks.slice(10):
		var old: Dictionary = {}
		for point: Array in snapshot.grids[track.id]: old[Vector2i(roundi(float(point[0])/32),roundi(float(point[1])/32))] = float(point[2])
		var view: Dictionary = {}
		var before: Image
		for phase in range(2):
			var world := TrackWorld.new()
			world.begin_build(track)
			assert(not world.advance_build())
			if phase==0:
				view = view_for(world,old)
				restore_terrain(world,old)
			while not world.advance_build(): pass
			root.add_child(world)
			freeze_water(world,still_water)
			var settings := SettingsCatalog.defaults(false)
			settings.reduce_motion = true
			settings.vsync = false
			settings.frame_cap = 60
			settings.draw_distance = 700
			SettingsRuntime.apply(world,settings)
			var camera := Camera3D.new()
			camera.current = true
			camera.far = 3000
			camera.fov = 62
			world.add_child(camera)
			camera.global_position = view.position
			camera.look_at(view.target,Vector3.UP)
			var image := await capture(output+"/"+track.id+("-before.png" if phase==0 else "-after.png"))
			if phase==0: before = image
			else:
				var pixels := changed(before,image)
				assert(pixels>100,"actual exported landforms produce visible landscape changes")
				rows.append({"track":track.id,"changed_samples":pixels,"target_delta_m":view.delta,"target_distance_m":view.distance_m,"road_route_s":view.route_s,"camera_position":[view.position.x,view.position.y,view.position.z],"camera_target":[view.target.x,view.target.y,view.target.z]})
				print("NATIVE_TERRAIN_LANDFORM ",track.id," delta=",view.delta," changed=",pixels)
			world.queue_free()
			for frame in range(3): await process_frame
	var file := FileAccess.open(output+"/native.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":true,"renderer":RenderingServer.get_current_rendering_method(),"resolution":[1280,720],"baseline_sha256":FileAccess.get_sha256(snapshot_path),"water_time_frozen":true,"profiles_sha256":FileAccess.get_sha256("res://assets/source/terrain_profiles.py"),"cases":rows,"boundary":"Thirty paired native landscape views from a fixed diagnostic overlook 32 m above the road, targeting a changed point inside 550 m. Before restores exact prior float32 terrain grids before scenery is constructed, so distant scenery is re-grounded consistently; all other current world code is shared. Existing water waves are held at the same zero-time phase for both images, and other motion is reduced. This isolates landform changes, not a historical-build comparison. Ordinary Far Chase approaches are separate. Native macOS Compatibility, not Android runtime or frame-time acceptance."},"\t")+"\n")
	file.close()
	print("NATIVE_THIRTY_ACTUAL_EXPORTED_LANDFORM_COMPARISONS_PASS")
	quit()

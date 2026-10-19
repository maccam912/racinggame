class_name CourseArt
extends RefCounted
## Cosmetic scenery catalog. Original-u anchors never alter the canonical route.

static var courses: Dictionary = {}
static var library: Dictionary = {}
static var terrain_info: Dictionary = {}
static var meshes: Dictionary = {}
static var materials: Dictionary = {}
static var terrain_heights: Dictionary = {}


static func load_catalog() -> void:
	if not courses.is_empty(): return
	for row: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://assets/exported/scenery/courses.json")).courses:
		courses[row.id] = row
	for row: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://assets/exported/scenery/library.json")).assets:
		library[row.id] = row
	for row: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://assets/exported/scenery/terrain.json")).courses:
		terrain_info[row.id] = row


static func spec(id: String) -> Dictionary:
	load_catalog()
	return courses[id]


static func original_s(track: TrackDefinition, u: float) -> float:
	var closest: int = 0
	var difference: float = INF
	for index in range(track.bake.samples.size()):
		var delta := absf(float(track.bake.samples[index][7])-u)
		delta = minf(delta,1.0-delta)
		if delta < difference:
			difference = delta
			closest = index
	return track.distances[closest]


static func palette(category: String, emission: float = 0) -> Material:
	var key := category+str(emission)
	if materials.has(key): return materials[key]
	if category=="foliage":
		var leaf := StandardMaterial3D.new()
		leaf.albedo_texture = load("res://assets/exported/textures/foliage_atlas.png")
		leaf.roughness = .9
		leaf.cull_mode = BaseMaterial3D.CULL_DISABLED
		leaf.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
		leaf.alpha_scissor_threshold = .5
		leaf.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		materials[key] = leaf
	else:
		var surface := ShaderMaterial.new()
		surface.shader = load("res://assets/exported/shaders/scenery.gdshader")
		surface.set_shader_parameter("atlas",load("res://assets/exported/textures/"+("props_atlas" if category=="prop" else "scenery_atlas")+".png"))
		surface.set_shader_parameter("window_glow",emission)
		materials[key] = surface
	return materials[key]


static func model(id: String, emission: float = 0) -> Node3D:
	load_catalog()
	var row: Dictionary = library[id]
	var scene: PackedScene = load("res://"+row.path)
	var result := scene.instantiate() as Node3D
	result.name = "Landmark_"+id
	result.set_meta("asset_id",id)
	for node: MeshInstance3D in result.find_children("*","MeshInstance3D",true,false):
		var level := level_of(str(node.name))
		node.material_override = palette(row.category,emission)
		apply_lod(node,level,row.lod_distances)
		if id in ["underpass","tunnel_portal"]:
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return result


static func level_of(node_name: String) -> int:
	return 0 if node_name.contains("LOD0") else 1 if node_name.contains("LOD1") else 2


static func apply_lod(node: GeometryInstance3D, level: int, distances: Array) -> void:
	node.visibility_range_begin = float(distances[level])
	node.visibility_range_end = float(distances[level+1]) if level<2 else 700.0
	if level<2: node.set_meta("lod_limit",float(distances[level+1]))
	node.add_to_group("scenery_distance")
	if level==2: node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func mesh(id: String, level: int) -> Mesh:
	load_catalog()
	var key := id+str(level)
	if meshes.has(key): return meshes[key]
	var packed: PackedScene = load("res://"+library[id].path)
	var temporary := packed.instantiate()
	for node: MeshInstance3D in temporary.find_children("*","MeshInstance3D",true,false):
		if level_of(str(node.name))==level:
			meshes[key] = node.mesh
			break
	temporary.free()
	return meshes[key]


static func batch(id: String, transforms: Array[Transform3D], parent: Node3D, emission: float = 0) -> void:
	if transforms.is_empty(): return
	load_catalog()
	if BillboardArt.supports(id):
		BillboardArt.batch(id,transforms,parent,emission)
		return
	var row: Dictionary = library[id]
	for level in range(3):
		var node := MultiMeshInstance3D.new()
		node.name = id+"_Batch_LOD"+str(level)
		var multi := MultiMesh.new()
		multi.transform_format = MultiMesh.TRANSFORM_3D
		multi.mesh = mesh(id,level)
		multi.instance_count = transforms.size()
		for index in range(transforms.size()): multi.set_instance_transform(index,transforms[index])
		node.multimesh = multi
		node.material_override = palette(row.category,emission)
		apply_lod(node,level,row.lod_distances)
		parent.add_child(node)


static func terrain(track_id: String) -> Node3D:
	load_catalog()
	var packed: PackedScene = load("res://"+terrain_info[track_id].path)
	var result := packed.instantiate() as Node3D
	result.name = "CosmeticTerrain"
	var heights: Dictionary = {}
	collect_terrain_heights(result,Transform3D.IDENTITY,heights)
	terrain_heights[track_id] = heights
	var ground := StandardMaterial3D.new()
	ground.albedo_color = Color.html(courses[track_id].ground)
	ground.vertex_color_use_as_albedo = true
	ground.roughness = .95
	for node: MeshInstance3D in result.find_children("*","MeshInstance3D",true,false):
		node.material_override = ground
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_to_group("scenery_distance")
		node.visibility_range_end = 700
	return result


static func collect_terrain_heights(node: Node, parent_pose: Transform3D, heights: Dictionary) -> void:
	var pose: Transform3D = parent_pose*node.transform if node is Node3D else parent_pose
	if node is MeshInstance3D:
		for surface in range(node.mesh.get_surface_count()):
			var arrays: Array = node.mesh.surface_get_arrays(surface)
			for vertex: Vector3 in arrays[Mesh.ARRAY_VERTEX]:
				var point: Vector3 = pose*vertex
				heights[Vector2i(roundi(point.x/32),roundi(point.z/32))] = point.y
	for child: Node in node.get_children(): collect_terrain_heights(child,pose,heights)


static func terrain_height(track_id: String, point: Vector3, fallback: float) -> float:
	var heights: Dictionary = terrain_heights.get(track_id,{})
	return height_from_grid(heights,point,fallback)


static func height_from_grid(heights: Dictionary, point: Vector3, fallback: float) -> float:
	var cell := Vector2i(floori(point.x/32),floori(point.z/32))
	for corner: Vector2i in [Vector2i.ZERO,Vector2i(1,0),Vector2i(0,1),Vector2i.ONE]:
		if not heights.has(cell+corner): return fallback
	var x := point.x/32-cell.x
	var z := point.z/32-cell.y
	var a: float = heights[cell]
	var b: float = heights[cell+Vector2i(1,0)]
	var c: float = heights[cell+Vector2i(0,1)]
	var d: float = heights[cell+Vector2i.ONE]
	# Interpolate the exported grid's two triangles, including its diagonal.
	return a+x*(b-a)+z*(d-b) if x>=z else a+z*(c-a)+x*(d-c)

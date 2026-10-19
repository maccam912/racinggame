class_name BillboardArt
extends RefCounted
## Cylindrical cutout foliage; shared collision and original 3D landmarks stay separate.

static var rows: Dictionary = {}
static var cards: Dictionary = {}
static var materials: Dictionary = {}
static var shadows: Dictionary = {}
static var shadow_material: ShaderMaterial

static func release_cache() -> void:
	cards.clear()
	materials.clear()
	shadows.clear()
	shadow_material = null

static func load_catalog() -> void:
	if not rows.is_empty(): return
	var value: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/exported/billboards/catalog.json"))
	for row: Dictionary in value.assets: rows[row.id] = row

static func supports(id: String) -> bool:
	load_catalog()
	return rows.has(id)

static func card(id: String) -> QuadMesh:
	if cards.has(id): return cards[id]
	var dimensions: Array = CourseArt.library[id].size_m
	var mesh := QuadMesh.new()
	mesh.size = Vector2(float(dimensions[0]),float(dimensions[2]))
	mesh.center_offset = Vector3(0,mesh.size.y*.5,0)
	cards[id] = mesh
	return mesh

static func material(id: String, emission: float) -> StandardMaterial3D:
	var key := id+str(emission)
	if materials.has(key): return materials[key]
	var row: Dictionary = rows[id]
	var result := StandardMaterial3D.new()
	result.albedo_texture = load("res://"+str(row.path))
	result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	result.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	result.billboard_keep_scale = true
	result.cull_mode = BaseMaterial3D.CULL_DISABLED
	result.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	result.alpha_scissor_threshold = .5
	result.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	result.texture_repeat = false
	result.albedo_color = Color(1,1,1) if emission<=0 else Color(.64,.74,.84)
	var bounds: Array = row.uv_bounds_pixels
	result.uv1_offset = Vector3(float(bounds[0])/float(row.pixels[0]),float(bounds[1])/float(row.pixels[1]),0)
	result.uv1_scale = Vector3(float(bounds[2])/float(row.pixels[0]),float(bounds[3])/float(row.pixels[1]),1)
	materials[key] = result
	return result

static func batch(id: String, transforms: Array[Transform3D], parent: Node3D, emission: float) -> void:
	var mesh := card(id)
	var radius := mesh.size.x*.5
	# Flat source geometry needs a rotation-invariant AABB after billboarding.
	var one := AABB(Vector3(-radius,0,-radius),Vector3(radius*2,mesh.size.y,radius*2))
	var bounds := transforms[0]*one
	for pose: Transform3D in transforms: bounds = bounds.merge(pose*one)
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	multi.custom_aabb = bounds.grow(.1)
	for index in range(transforms.size()): multi.set_instance_transform(index,transforms[index])
	var node := MultiMeshInstance3D.new()
	node.name = "IllustratedBillboard_"+id
	node.set_meta("asset_id",id)
	node.multimesh = multi
	node.material_override = material(id,emission)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visibility_range_end = 700
	node.add_to_group("scenery_distance")
	parent.add_child(node)
	# A cheap stationary soft footprint anchors the painted trunks at close range.
	if not shadows.has(id):
		var plane := PlaneMesh.new()
		plane.size = Vector2(mesh.size.x*.6,mesh.size.x*.45)
		shadows[id] = plane
	if shadow_material==null:
		shadow_material = ShaderMaterial.new()
		shadow_material.shader = load("res://assets/exported/shaders/blob_shadow.gdshader")
		shadow_material.set_shader_parameter("opacity",.55)
	var shadow := MultiMeshInstance3D.new()
	shadow.name = "BillboardFootprint_"+id
	var instances := MultiMesh.new()
	instances.transform_format = MultiMesh.TRANSFORM_3D
	instances.mesh = shadows[id]
	instances.instance_count = transforms.size()
	for index in range(transforms.size()):
		var pose := transforms[index]
		pose.origin.y += .035
		instances.set_instance_transform(index,pose)
	shadow.multimesh = instances
	shadow.material_override = shadow_material
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	shadow.visibility_range_end = 120
	shadow.set_meta("lod_limit",120)
	shadow.add_to_group("scenery_distance")
	parent.add_child(shadow)

class_name RoadsidePosterArt
extends RefCounted
## Painted travel signs on static 3D frames; foliage uses a separate billboard path.

static var rows: Dictionary = {}
static var materials: Dictionary = {}
static var frame_material: StandardMaterial3D


static func load_catalog() -> void:
	if not rows.is_empty(): return
	for row: Dictionary in JSON.parse_string(FileAccess.get_file_as_string("res://assets/exported/posters/catalog.json")).assets:
		rows[row.id] = row


static func release_cache() -> void:
	materials.clear()
	frame_material = null


static func poster_material(id: String) -> StandardMaterial3D:
	load_catalog()
	if not materials.has(id):
		var result := StandardMaterial3D.new()
		result.albedo_texture = load("res://"+str(rows[id].path))
		result.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		result.texture_repeat = false
		result.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		result.cull_mode = BaseMaterial3D.CULL_BACK
		materials[id] = result
	return materials[id]


static func plan(world: TrackWorld) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in range(3):
		var s := CourseArt.original_s(world.track,[.105,.405,.805][index])
		var edge := float(world.track.bake.samples[world.track.sample_index(s)][8])*.5
		var side := -1.0 if index%2==0 else 1.0
		var selected := Transform3D.IDENTITY
		var found := false
		for lateral: float in [side*(edge+17),-side*(edge+17),side*(edge+28),-side*(edge+28)]:
			var candidate := world.ground_pose(s,lateral) if world.art.get("elevated",false) else world.scenery_pose(s,lateral)
			if not world.clear_of_road(candidate.origin,7): continue
			selected = candidate
			side = signf(lateral)
			found = true
			break
		if not found: continue
		selected.basis = selected.basis*Basis(Vector3.UP,-side*deg_to_rad(18))
		result.append({"index":index,"s":s,"pose":selected,"side":side,"approach":world.track.pose(s-52).origin})
	return result


static func blocks_sightline(sites: Array[Dictionary], point: Vector3) -> bool:
	var p := Vector2(point.x,point.z)
	for site: Dictionary in sites:
		var first := Vector2(site.approach.x,site.approach.z)
		var last := Vector2(site.pose.origin.x,site.pose.origin.z)
		var direction := last-first
		var fraction := (p-first).dot(direction)/direction.length_squared()
		if fraction<-.1 or fraction>1.1: continue
		# Include the tree canopy, not just its trunk, in the view clearance.
		var nearest := first+direction*clampf(fraction,0,1)
		if p.distance_to(nearest)<8+6.3*clampf(fraction,0,1): return true
	return false


static func build(world: TrackWorld) -> void:
	load_catalog()
	if frame_material==null:
		frame_material = StandardMaterial3D.new()
		frame_material.vertex_color_use_as_albedo = true
		frame_material.roughness = .85
	for site: Dictionary in world.poster_sites:
		var index: int = site.index
		var root := Node3D.new()
		root.name = "RoadsidePoster_"+world.track.id+"_"+str(index)
		root.transform = site.pose
		root.set_meta("poster_id",world.track.id)
		root.set_meta("route_s",site.s)
		root.set_meta("clearance_radius_m",7)
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		CourseSetPieces.cuboid(tool,Transform3D(Basis.IDENTITY,Vector3(0,7,-.2)),Vector3(12.6,8.6,.35),Color("865435"))
		for x: float in [-4.6,4.6]:
			CourseSetPieces.cuboid(tool,Transform3D(Basis.IDENTITY,Vector3(x,1.35,-.3)),Vector3(.4,4,.5),Color("8CA2AA"))
		if world.art.get("elevated",false):
			var anchors := PackedVector3Array()
			for x: float in [-4.6,4.6]:
				var s := float(site.s)+x*.35
				var half := float(world.track.bake.samples[world.track.sample_index(s)][8])*.5
				var at := world.ground_pose(s,float(site.side)*(half+2.2)).origin-Vector3.UP*1.4
				anchors.append(at)
				var anchor: Vector3 = site.pose.affine_inverse()*at
				var bottom := anchor-Vector3.UP*3.5
				var foot := Vector3(x,-.65,-.3)
				CourseSetPieces.beam(tool,anchor,foot,.4,Color("8CA2AA"))
				CourseSetPieces.beam(tool,bottom,foot,.3,Color("8CA2AA"))
				CourseSetPieces.cuboid(tool,Transform3D(Basis.IDENTITY,(anchor+bottom)*.5),Vector3(.4,3.5,.4),Color("8CA2AA"))
				CourseSetPieces.cuboid(tool,Transform3D(Basis.IDENTITY,anchor),Vector3(.9,.6,.9),Color("BCC6C2"))
			root.set_meta("bridge_anchors",anchors)
		var frame := MeshInstance3D.new()
		frame.name = "Frame"
		frame.mesh = tool.commit()
		frame.material_override = frame_material
		root.add_child(frame)
		var front := MeshInstance3D.new()
		front.name = "PaintedFront"
		var card := QuadMesh.new()
		card.size = Vector2(12,8)
		front.mesh = card
		front.position = Vector3(0,7,0)
		front.material_override = poster_material(world.track.id)
		root.add_child(front)
		for node: GeometryInstance3D in [frame,front]:
			node.add_to_group("scenery_distance")
			node.visibility_range_end = 700
			node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(root)

class_name ExpansionCourseArt
extends RefCounted
## Original static 3D scenery and generated cutouts for the thirty new courses.
## No per-frame callbacks, driving collision, or full-course scenery batches.

static func build_batch(world: TrackWorld, first: int, last: int) -> void:
	BillboardArt.load_catalog()
	var tree: String = world.art.vegetation
	var width: float = BillboardArt.rows[tree].size_m[0]
	var spacing := 64 if world.art.theme in ["industry","space","desert"] else 32
	var batches: Dictionary = {}
	for s in range(first,last,spacing):
		var edge := float(world.track.bake.samples[world.track.sample_index(s)][8])*.5
		for side: float in [-1.0,1.0]:
			var pose := world.scenery_pose(s,side*(edge+width*.65+11))
			if not world.clear_of_road(pose.origin,width*.5+3) or not world.decoration_allowed(pose.origin): continue
			pose.basis = pose.basis.scaled(Vector3.ONE*(.85+.20*CourseLandscape.noise_at(s,side,13)))
			if not batches.has(tree): batches[tree] = [] as Array[Transform3D]
			batches[tree].append(pose)
	# Occasional secondary silhouettes break up each tree/utility ribbon.
	if first%240==0:
		var landmark: Dictionary = world.art.landmarks[(first/240)%5]
		var id: String = landmark.id
		var prop_width: float = BillboardArt.rows[id].size_m[0]
		var pose := world.scenery_pose(first+36,-90-prop_width*.5)
		if world.clear_of_road(pose.origin,prop_width*.5+5) and world.decoration_allowed(pose.origin):
			if not batches.has(id): batches[id] = [] as Array[Transform3D]
			batches[id].append(pose)
	for id: String in batches:
		BillboardArt.batch(id,batches[id],world,float(world.art.emission),false)


static func landscape(world: TrackWorld) -> void:
	var low := Vector3(INF,INF,INF)
	var high := Vector3(-INF,-INF,-INF)
	for at: Vector3 in world.track.points:
		low = low.min(at)
		high = high.max(at)
	var parent := Node3D.new()
	parent.name = "ExpansionLandscape"
	world.add_child(parent)
	var buckets: Dictionary = {}
	var tree: String = world.art.vegetation
	var width: float = BillboardArt.rows[tree].size_m[0]
	var dense: bool = world.art.theme in ["polar","tropical","east_asia"]
	for x in range(int(low.x)-120,int(high.x)+120,112):
		for z in range(int(low.z)-120,int(high.z)+120,112):
			var seed := CourseLandscape.noise_at(x,z,17)
			if seed>(.58 if dense else .24): continue
			var at := Vector3(x+seed*35,0,z+sin(seed*TAU)*35)
			at.y = CourseArt.height_from_grid(world.terrain_grid,at,-INF)
			if not is_finite(at.y) or not world.clear_of_road(at,maxf(42,width*.55)) or not world.decoration_allowed(at): continue
			if world.art.water and at.y<float(CourseArt.terrain_info[world.track.id].sea_level)+1: continue
			var key := Vector2i(floori(at.x/224),floori(at.z/224))
			if not buckets.has(key): buckets[key] = [] as Array[Transform3D]
			buckets[key].append(Transform3D(Basis.from_scale(Vector3.ONE*(.85+seed*.5)),at))
	for key: Vector2i in buckets:
		BillboardArt.batch(tree,buckets[key],parent,float(world.art.emission),false)
	if not world.art.space: CourseLandscape.horizon(world)


static func structures(world: TrackWorld) -> void:
	var theme: String = world.art.theme
	var accent := Color.html(world.art.accent)
	var stone := Color.html(world.art.ground).lightened(.17)
	for gate in range(3):
		var s := CourseArt.original_s(world.track,[.21,.53,.78][gate])
		var pose := world.ground_pose(s,0)
		pose.basis = Basis(Vector3.UP,pose.basis.get_euler().y)
		var half := float(world.track.bake.samples[world.track.sample_index(s)][8])*.5+8
		var height := 26.0+gate*2
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for side: float in [-1.0,1.0]:
			CourseSetPieces.cuboid(tool,Transform3D(Basis.IDENTITY,Vector3(side*half,height*.5-2,0)),Vector3(2,height+4,3),stone)
			CourseSetPieces.cuboid(tool,Transform3D(Basis.IDENTITY,Vector3(side*half,1,0)),Vector3(5,2,6),accent)
		if theme=="polar":
			CourseSetPieces.beam(tool,Vector3(-half,height,0),Vector3(0,height+7,0),1.5,accent)
			CourseSetPieces.beam(tool,Vector3(0,height+7,0),Vector3(half,height,0),1.5,accent)
		elif theme=="tropical":
			for tier in range(3):
				CourseSetPieces.cuboid(tool,Transform3D(Basis.IDENTITY,Vector3(0,height+tier*1.3,0)),Vector3(half*2+5-tier*3,1.4,5-tier),stone if tier%2 else accent)
		elif theme=="east_asia":
			CourseSetPieces.beam(tool,Vector3(-half-4,height+1,0),Vector3(half+4,height+1,0),2,accent)
			CourseSetPieces.beam(tool,Vector3(-half,height-3,0),Vector3(half,height-3,0),1,accent)
			for side: float in [-1.0,1.0]:
				CourseSetPieces.beam(tool,Vector3(side*half,height+1,0),Vector3(side*(half+6),height+3,0),1.2,stone)
		elif theme=="desert":
			for part in range(8):
				var a := PI*part/8
				var b := PI*(part+1)/8
				CourseSetPieces.beam(tool,Vector3(cos(a)*half,height+sin(a)*half*.4,0),Vector3(cos(b)*half,height+sin(b)*half*.4,0),2.4,stone)
		elif theme=="industry":
			for layer: float in [height,height+3]: CourseSetPieces.beam(tool,Vector3(-half-2,layer,0),Vector3(half+2,layer,0),.9,accent)
			for part in range(8):
				var x := lerpf(-half,half,part/8.0)
				CourseSetPieces.beam(tool,Vector3(x,height,0),Vector3(x+half*.25,height+3,0),.4,stone)
		else:
			# Tall faceted containment arches; their lowest inner edge is 25 m.
			for part in range(10):
				var a := PI*part/10
				var b := PI*(part+1)/10
				CourseSetPieces.beam(tool,Vector3(cos(a)*half,height+sin(a)*half*.5,0),Vector3(cos(b)*half,height+sin(b)*half*.5,0),1.4,accent)
		var node := MeshInstance3D.new()
		node.name = "ExpansionStructure_"+world.track.id+"_"+str(gate)
		node.mesh = tool.commit()
		node.transform = pose
		node.set_meta("route_s",s)
		node.set_meta("clearance_m",height-4)
		var material := StandardMaterial3D.new()
		material.vertex_color_use_as_albedo = true
		material.roughness = .85
		if theme=="space" or world.art.emission>0:
			material.emission_enabled = true
			material.emission = accent
			material.emission_energy_multiplier = .25
		node.material_override = material
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_to_group("scenery_distance")
		node.visibility_range_end = 700
		world.add_child(node)

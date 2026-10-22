class_name ExpansionCourseArt
extends RefCounted
## Original static 3D scenery and generated cutouts for the thirty new courses.
## No per-frame callbacks, driving collision, or full-course scenery batches.

static func species(world: TrackWorld, s: float, lateral: float) -> String:
	var choices: Array = world.art.plantings
	var sector := int(s/world.track.length*7)
	return str(choices[posmod(sector+int(s/43)+int(absf(lateral)/19),choices.size())])


static func add_sprite(buckets: Dictionary, id: String, pose: Transform3D) -> void:
	var key := "%d:%d:%s"%[floori(pose.origin.x/224),floori(pose.origin.z/224),id]
	if not buckets.has(key): buckets[key] = {"id":id,"poses":[] as Array[Transform3D]}
	buckets[key].poses.append(pose)


static func build_batch(world: TrackWorld, first: int, last: int) -> void:
	BillboardArt.load_catalog()
	var urban := not str(world.art.district).is_empty()
	var spacing := 40 if urban or world.art.theme in ["space","desert"] else 24
	for s in range(ceili(float(first)/spacing)*spacing,last,spacing):
		var edge := float(world.track.bake.samples[world.track.sample_index(s)][8])*.5
		for side: float in [-1.0,1.0]:
			# Different setbacks and gaps make groves, rather than parallel walls.
			for layer in range(1 if urban else 2):
				var seed := CourseLandscape.noise_at(s,side,13+layer)
				if layer==1 and seed<.32: continue
				var lateral := side*(edge+18+layer*32+seed*17)
				var id := species(world,s,lateral)
				if urban and int(s/40)%4!=0: continue
				var width: float = BillboardArt.card(id).size.x
				lateral += side*width*.35
				var pose := world.scenery_pose(s+layer*9,lateral)
				var scale := .72+seed*.5
				if not valid_site(world,pose.origin,width*scale*.55+3): continue
				pose.basis = pose.basis.rotated(Vector3.UP,seed*TAU).scaled(Vector3(scale,scale*(.90+seed*.2),scale))
				add_sprite(world.scenery_batches,id,pose)
		if urban:
			var lamps: Array[Transform3D] = []
			for side: float in [-1.0,1.0]:
				var pose := world.scenery_pose(s,side*(edge+7))
				if world.clear_of_road(pose.origin,1) and world.decoration_allowed(pose.origin):
					pose.basis = pose.basis.rotated(Vector3.UP,0 if side<0 else PI)
					lamps.append(pose)
					if float(world.art.emission)>0:
						world.lamp_glow_sites.append({"s":float(s),"side":side,"at":pose.origin})
			if not lamps.is_empty():
				var key := "lamps:"+str(first/224)
				if not world.scenery_batches.has(key): world.scenery_batches[key] = {"id":"streetlight","poses":[] as Array[Transform3D]}
				world.scenery_batches[key].poses.append_array(lamps)


static func valid_site(world: TrackWorld, at: Vector3, radius: float) -> bool:
	if not is_finite(at.y) or not world.clear_of_road(at,radius) or not world.decoration_allowed(at,radius): return false
	return not world.art.water or at.y>float(CourseArt.terrain_info[world.track.id].sea_level)+1


static func landscape(world: TrackWorld) -> void:
	# Fill actual terrain bounds, including the infield and 360 m outer margin.
	var bounds: Array = CourseArt.terrain_info[world.track.id].bounds_xz_m
	var parent := Node3D.new()
	parent.name = "ExpansionLandscape"
	world.add_child(parent)
	# A tiny persistent ground skirt closes the view below distant silhouettes
	# after detailed terrain chunks cull, especially from high mountain roads.
	var floor_y := INF
	for height: float in world.terrain_grid.values(): floor_y = minf(floor_y,height)
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size = Vector2(float(bounds[2])-float(bounds[0])+1800,float(bounds[3])-float(bounds[1])+1800)
	var floor_node := MeshInstance3D.new()
	floor_node.name = "LandscapeGroundSkirt"
	floor_node.mesh = floor_mesh
	floor_node.position = Vector3((float(bounds[0])+float(bounds[2]))*.5,floor_y-15,(float(bounds[1])+float(bounds[3]))*.5)
	floor_node.material_override = ExpansionBiome.material(world.track.id)
	floor_node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(floor_node)
	var buckets: Dictionary = {}
	var districts: Dictionary = {}
	var sites: Array[Dictionary] = []
	var urban := not str(world.art.district).is_empty()
	var dense: bool = world.art.theme in ["polar","tropical","east_asia"] and not urban
	var spacing := 56 if dense or urban else 80
	for x in range(int(bounds[0])+48,int(bounds[2])-48,spacing):
		for z in range(int(bounds[1])+48,int(bounds[3])-48,spacing):
			var seed := CourseLandscape.noise_at(x,z,17)
			var at := Vector3(x+(seed-.5)*30,0,z+(CourseLandscape.noise_at(x,z,18)-.5)*30)
			var nearest := INF
			var anchor := 0
			for i in range(0,world.track.points.size(),12):
				var point := world.track.points[i]
				var distance := Vector2(at.x-point.x,at.z-point.z).length()
				if distance<nearest:
					nearest = distance
					anchor = i
			if nearest<65 or nearest>590: continue
			var patch := sin(at.x*.009+sin(at.z*.006)*2)+cos(at.z*.012-at.x*.003)
			if patch<(-.85 if urban else -.55 if dense else .1): continue
			at.y = CourseArt.height_from_grid(world.terrain_grid,at,-INF)
			var s: float = world.track.distances[anchor]
			var id := species(world,s,at.x+at.z)
			# Built districts get real facades behind the close lamps/props.
			var building: bool = urban and seed>.25 and world.art.theme!="space"
			var width := 23.0 if building else float(BillboardArt.card(id).size.x)*.75+3
			if not valid_site(world,at,width): continue
			var key := "%d:%d"%[floori(at.x/224),floori(at.z/224)]
			if building:
				if not districts.has(key): districts[key] = [] as Array[Transform3D]
				districts[key].append(Transform3D(Basis.IDENTITY,at))
				sites.append({"at":at,"id":"district","distance":nearest})
				continue
			for member in range(3 if dense else 1):
				var root := at+Vector3(sin(seed*TAU+member*2.4),0,cos(seed*TAU+member*2.4))*member*11
				root.y = CourseArt.height_from_grid(world.terrain_grid,root,-INF)
				if not valid_site(world,root,width): continue
				var scale := .85+seed*.65-member*.06
				add_sprite(buckets,id,Transform3D(Basis(Vector3.UP,seed*TAU+member).scaled(Vector3.ONE*scale),root))
				sites.append({"at":root,"id":id,"distance":nearest})
	parent.set_meta("sites",sites)
	for key: String in buckets:
		var bucket: Dictionary = buckets[key]
		BillboardArt.batch(bucket.id,bucket.poses,parent,float(world.art.emission),false)
	for key: String in districts:
		CourseLandscape.city_block(world,parent,districts[key],key)
	# Even lunar valleys need a terrain silhouette masking the ground cut-off.
	CourseLandscape.horizon(world)


static func structures(world: TrackWorld) -> void:
	var theme: String = world.art.theme
	var accent := Color.html(world.art.accent)
	var stone := Color.html(world.art.ground).lightened(.17)
	var anchors: Array = world.art.get("road_gates",[.21,.53,.78])
	for gate in range(anchors.size()):
		var s := CourseArt.original_s(world.track,float(anchors[gate]))
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


static func landmark_site(world: TrackWorld, description: Dictionary) -> Dictionary:
	BillboardArt.load_catalog()
	var s := CourseArt.original_s(world.track,float(description.u))
	var lateral := float(description.lateral)
	var radius := float(BillboardArt.rows[description.id].size_m[0])*.55
	for offset: float in [lateral,-lateral,lateral*1.5,-lateral*1.5,lateral*2.2,-lateral*2.2]:
		var pose := world.scenery_pose(s,offset)
		if world.clear_of_road(pose.origin,radius+3): return {"id":description.id,"s":s,"pose":pose,"lateral":offset,"radius":radius}
	assert(false,"new landmark must clear every road branch")
	return {}

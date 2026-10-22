class_name AuthoredCourseScenery
extends RefCounted
## Named area parcels replace continuous rows along both sides of every road.
static var compound_surface: ShaderMaterial

static func material() -> ShaderMaterial:
	if compound_surface==null:
		compound_surface = ShaderMaterial.new()
		compound_surface.shader = load("res://assets/exported/shaders/set_piece_motion.gdshader")
		compound_surface.set_shader_parameter("animation_enabled",0.0)
	return compound_surface

static func nearest(world: TrackWorld, at: Vector3) -> Dictionary:
	var best := INF
	var anchor := 0
	var point := Vector2(at.x,at.z)
	for i in range(0,world.track.points.size(),16):
		var p := world.track.points[i]
		var distance := point.distance_squared_to(Vector2(p.x,p.z))
		if distance<best:
			best = distance
			anchor = i
	best = INF
	var distance_s := 0.0
	for offset in range(-16,17):
		var i := posmod(anchor+offset,world.track.points.size())
		var j := (i+1)%world.track.points.size()
		var a := Vector2(world.track.points[i].x,world.track.points[i].z)
		var b := Vector2(world.track.points[j].x,world.track.points[j].z)
		var weight := clampf((point-a).dot(b-a)/(b-a).length_squared(),0,1)
		var distance := point.distance_squared_to(a.lerp(b,weight))
		if distance<best:
			best = distance
			var end := world.track.distances[j] if j>0 else world.track.length
			distance_s = lerpf(world.track.distances[i],end,weight)
	var pose := world.track.pose(distance_s)
	return {"s":distance_s,"distance":sqrt(best),"lateral":(at-pose.origin).dot(pose.basis.x)}

static func height(world: TrackWorld, at: Vector3, road: Dictionary) -> float:
	var terrain_y := CourseArt.height_from_grid(world.terrain_grid,at,-INF)
	if not is_finite(terrain_y): return -INF
	return maxf(terrain_y,world.verge_height(road.s,road.lateral,at))

static func clear(world: TrackWorld, at: Vector3, radius: float) -> bool:
	if not is_finite(at.y) or not world.clear_of_road(at,radius) or not world.decoration_allowed(at,radius): return false
	if RoadsidePosterArt.blocks_sightline(world.poster_sites,at): return false
	return not world.art.water or at.y>float(CourseArt.terrain_info[world.track.id].sea_level)+1.5

static func roadside(world: TrackWorld, first: int, last: int) -> void:
	for section: Array in world.art.get("light_sections",[]):
		for s in range(ceili(float(first)/36)*36,last,36):
			var u := world.track.original_u(s)
			if u<float(section[0]) or u>float(section[1]): continue
			var side := float(section[2])
			var edge := float(world.track.bake.samples[world.track.sample_index(s)][8])*.5
			var pose := world.scenery_pose(s,side*(edge+7))
			if not clear(world,pose.origin,1.5): continue
			pose.basis = pose.basis.rotated(Vector3.UP,0 if side<0 else PI)
			var key := "authored_lamps:"+str(first/224)
			if not world.scenery_batches.has(key): world.scenery_batches[key] = {"id":"streetlight","poses":[] as Array[Transform3D]}
			world.scenery_batches[key].poses.append(pose)
			if float(world.art.get("emission",0))>0: world.lamp_glow_sites.append({"s":float(s),"side":side,"at":pose.origin})

static func build(world: TrackWorld) -> void:
	BillboardArt.load_catalog()
	var parent := Node3D.new()
	parent.name = "ExpansionLandscape" if world.art.get("expansion40",false) else "LandscapeDistricts"
	world.add_child(parent)
	floor_skirt(world,parent)
	var sites: Array[Dictionary] = []
	var regions: Array[Dictionary] = []
	var buckets: Dictionary = {}
	var occupied: Dictionary = {}
	for region: Dictionary in world.art.scenery_regions:
		var s := CourseArt.original_s(world.track,float(region.u))
		var pose := world.track.pose(s,float(region.side)*float(region.setback))
		pose.basis = Basis(Vector3.UP,pose.basis.get_euler().y)
		var first := sites.size()
		if region.kind in ["grove","rocks"]: grove(world,region,pose,buckets,sites,occupied)
		else: compound(world,parent,region,pose,sites)
		regions.append({"name":region.name,"kind":region.kind,"u":region.u,"side":region.side,"sites":sites.size()-first,"center":pose.origin})
	for bucket: Dictionary in buckets.values():
		if bucket.id=="moon_rock": rock_batch(bucket.poses,parent)
		else: BillboardArt.batch(bucket.id,bucket.poses,parent,float(world.art.get("emission",0)),false)
	parent.set_meta("sites",sites)
	parent.set_meta("regions",regions)
	CourseLandscape.horizon(world)

static func grove(world: TrackWorld, region: Dictionary, pose: Transform3D, buckets: Dictionary, sites: Array[Dictionary], occupied: Dictionary) -> void:
	var spacing := int(region.spacing)
	var size_range: Array = region.get("size_range",[.68,1.30])
	assert(size_range.size()==2 and float(size_range[0])>0 and float(size_range[1])>=float(size_range[0]))
	var seed := float(posmod(str(region.name).hash(),1009))
	for x in range(-int(region.depth),int(region.depth)+1,spacing):
		for z in range(-int(region.along),int(region.along)+1,spacing):
			var noise := CourseLandscape.noise_at(x,z,seed)
			var across := x+(noise-.5)*spacing*.78
			var along := z+(CourseLandscape.noise_at(x,z,seed+1)-.5)*spacing*.78
			var ellipse := pow(across/float(region.depth),2)+pow(along/float(region.along),2)
			if ellipse>1 or noise<.08+maxf(0,ellipse-.55)*.45: continue
			var at := pose*Vector3(across,0,along)
			var cell := Vector2i(floori(at.x/12),floori(at.z/12))
			if occupied.has(cell): continue
			var plants: Array = region.plants
			var id: String = plants[mini(plants.size()-1,int(CourseLandscape.noise_at(x,z,seed+2)*plants.size()))]
			var scale := lerpf(float(size_range[0]),float(size_range[1]),CourseLandscape.noise_at(x,z,seed+3))
			var radius := (22.0 if id=="moon_rock" else float(BillboardArt.card(id).size.x)*.55)*scale+2
			var road := nearest(world,at)
			at.y = height(world,at,road)
			if not clear(world,at,radius): continue
			occupied[cell] = true
			var basis := Basis(Vector3.UP,noise*TAU).scaled(Vector3(scale,scale*(.90+noise*.2),scale))
			ExpansionCourseArt.add_sprite(buckets,id,Transform3D(basis,at))
			sites.append({"at":at,"id":id,"radius":radius,"distance":road.distance,"s":road.s,"lateral":road.lateral,"region":region.name})

static func rock_batch(poses: Array, parent: Node3D) -> void:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.mesh = CourseCompoundArt.mesh("moon_rock")
	multi.instance_count = poses.size()
	for i in range(poses.size()): multi.set_instance_transform(i,poses[i])
	var node := MultiMeshInstance3D.new()
	node.name = "MoonBoulderField"
	node.multimesh = multi
	node.material_override = material()
	node.visibility_range_end = 700
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_to_group("scenery_distance")
	parent.add_child(node)

static func compound(world: TrackWorld, parent: Node3D, region: Dictionary, pose: Transform3D, sites: Array[Dictionary]) -> void:
	var cluster := Node3D.new()
	cluster.name = "Compound_"+str(region.name).to_pascal_case()
	cluster.set_meta("region",region.name)
	cluster.set_meta("kind",region.kind)
	parent.add_child(cluster)
	var surface := material()
	for entry: Array in region.get("modules",CourseCompoundArt.layout(region.kind)):
		var mesh := CourseCompoundArt.mesh(entry[0],int(entry[3]))
		var bounds := mesh.get_aabb()
		var natural: bool = entry[0] in ["mesa_outcrop","terraced_field","basalt_crag","martian_butte","crater_outcrop","ice_wall","glacial_erratic"]
		var foundation_limit := 60.0 if natural else 16.0
		var radius := Vector2(maxf(absf(bounds.position.x),absf(bounds.end.x)),maxf(absf(bounds.position.z),absf(bounds.end.z))).length()+2
		var at := pose*Vector3(float(entry[1]),0,float(entry[2]))
		var basis := pose.basis*Basis(Vector3.UP,float(entry[4]))
		var road := nearest(world,at)
		var floor_y := height(world,at,road)
		var minimum_y := floor_y
		for x: float in [bounds.position.x,bounds.end.x]:
			for z: float in [bounds.position.z,bounds.end.z]:
				var corner := at+basis*Vector3(x,0,z)
				var y := height(world,corner,nearest(world,corner))
				if not is_finite(y): minimum_y = -INF
				else:
					floor_y = maxf(floor_y,y)
					minimum_y = minf(minimum_y,y)
		at.y = floor_y
		if not is_finite(minimum_y) or floor_y-minimum_y>foundation_limit or not clear(world,at,radius): continue
		var node := MeshInstance3D.new()
		node.name = str(entry[0]).to_pascal_case()+str(cluster.get_child_count())
		node.mesh = mesh
		node.set_meta("module",str(entry[0]))
		node.material_override = surface
		node.transform = Transform3D(basis,at)
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.visibility_range_end = 700
		node.add_to_group("scenery_distance")
		cluster.add_child(node)
		# Geological bases and descending field steps extend 64 m below the crest.
		if not natural:
			var pad := MeshInstance3D.new()
			var plinth := BoxMesh.new()
			plinth.size = Vector3(bounds.size.x+1,floor_y-minimum_y+2,bounds.size.z+1)
			pad.mesh = plinth
			pad.material_override = world.material(Color.html(world.art.ground).darkened(.23))
			pad.transform = Transform3D(basis,at+basis*Vector3(bounds.get_center().x,-plinth.size.y*.5,bounds.get_center().z))
			pad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			pad.visibility_range_end = 700
			pad.add_to_group("scenery_distance")
			cluster.add_child(pad)
		sites.append({"at":at,"id":str(region.kind)+"/"+str(entry[0]),"radius":radius,"distance":road.distance,"s":road.s,"lateral":road.lateral,"region":region.name,"foundation_min":minimum_y,"foundation_limit":foundation_limit,"module":entry[0]})

static func floor_skirt(world: TrackWorld, parent: Node3D) -> void:
	var bounds: Array = CourseArt.terrain_info[world.track.id].bounds_xz_m
	var floor_y := INF
	for y: float in world.terrain_grid.values(): floor_y = minf(floor_y,y)
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(float(bounds[2])-float(bounds[0])+1800,float(bounds[3])-float(bounds[1])+1800)
	var node := MeshInstance3D.new()
	node.name = "LandscapeGroundSkirt"
	node.mesh = mesh
	node.position = Vector3((float(bounds[0])+float(bounds[2]))*.5,floor_y-15,(float(bounds[1])+float(bounds[3]))*.5)
	node.material_override = ExpansionBiome.material(world.track.id) if world.art.get("expansion40",false) else world.material(Color.html(world.art.ground))
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(node)

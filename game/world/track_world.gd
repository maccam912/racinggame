class_name TrackWorld
extends Node3D
## Original course scenery surrounds the unchanged road/collision bake.

var track: TrackDefinition
var materials: Dictionary = {}
var build_stage: int = 0
var scenery_cursor: int = 0
var pending_geometry: Dictionary = {}
var scenery_batches: Dictionary = {}
var art: Dictionary = {}
var landmark_cursor: int = 0
var start_lamps: Array[MeshInstance3D] = []
var warmed_resources: Array[Resource] = []
var shader_warmup: Dictionary = {}
var terrain_grid: Dictionary = {}
var poster_sites: Array[Dictionary] = []
var scenery_clearings: Array[Dictionary] = []
var decor_sites: Array[Dictionary] = []
var spectacle_sites: Array[Dictionary] = []
var hero_sites: Array[Dictionary] = []
static var skies: Dictionary = {}


func material(color: Color, roughness: float = 0.9) -> StandardMaterial3D:
	var key := color.to_html() + str(roughness)
	if materials.has(key):
		return materials[key]
	var result := StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = roughness
	result.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	materials[key] = result
	return result


func build(data: TrackDefinition) -> void:
	begin_build(data)
	while not advance_build(): pass


func begin_build(data: TrackDefinition) -> void:
	track = data
	art = CourseArt.spec(track.id)
	build_stage = 0
	scenery_cursor = 0
	landmark_cursor = 0
	scenery_batches.clear()


func build_steps() -> int:
	return 4+ceili(float(int(track.length))/80.0)+art.landmarks.size()


func advance_build() -> bool:
	match build_stage:
		0: build_environment()
		1: build_road()
		2: build_collision()
		_:
			if scenery_cursor<int(track.length):
				build_scenery_batch(scenery_cursor,mini(scenery_cursor+80,int(track.length)))
				scenery_cursor += 80
			elif landmark_cursor<art.landmarks.size():
				place_landmark(art.landmarks[landmark_cursor])
				landmark_cursor += 1
			else:
				for bucket: Dictionary in scenery_batches.values():
					if art.get("expansion40",false) and BillboardArt.supports(bucket.id):
						BillboardArt.batch(bucket.id,bucket.poses,self,float(art.get("emission",0)),false)
					else:
						CourseArt.batch(bucket.id,bucket.poses,self,float(art.get("emission",0)))
				scenery_batches.clear()
				CourseLandscape.build(self)
				gantry()
				build_direction_signs()
				build_covers()
				build_jump_markings()
				CourseSetPieces.build(self)
				CourseDecor.build(self)
				CourseSpectacles.build(self)
				ArcadeCourseDetail.build(self)
				ExpansionSetPieces.build(self,hero_sites)
				if art.get("elevated",false): CourseRoadMesh.elevated_supports(self)
				RoadsidePosterArt.build(self)
				build_stage += 1
				return true
	build_stage += 1
	return false


func build_environment() -> void:
	var environment := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_SKY
	if not skies.has(track.id):
		var shared_sky := Sky.new()
		if art.get("space",false) and not art.get("expansion40",false):
			var orbital := ShaderMaterial.new()
			orbital.shader = load("res://assets/exported/shaders/orbital_sky.gdshader")
			shared_sky.sky_material = orbital
		elif art.get("expansion40",false):
			var themed := ShaderMaterial.new()
			themed.shader = load("res://assets/exported/shaders/expansion_sky.gdshader")
			themed.set_shader_parameter("sky_top",Color.html(art.sky_top))
			themed.set_shader_parameter("horizon",Color.html(art.horizon))
			themed.set_shader_parameter("night",float(art.emission)>0)
			themed.set_shader_parameter("aurora",track.id=="aurora_harbor")
			themed.set_shader_parameter("storm",track.id in ["storm_chase","monsoon_delta"])
			themed.set_shader_parameter("space",bool(art.space))
			themed.set_shader_parameter("sky_seed",float(art.sky_seed))
			themed.set_shader_parameter("style",int(art.sky_style))
			shared_sky.sky_material = themed
		else:
			var sky_material := ShaderMaterial.new()
			sky_material.shader = load("res://assets/exported/shaders/painted_sky.gdshader")
			sky_material.set_shader_parameter("panorama",load("res://assets/exported/billboards/arcade-sky-v1.png"))
			var tint := Color(1,1,1)
			if float(art.get("emission",0))>0: tint = Color(.34,.28,.52)
			sky_material.set_shader_parameter("tint",tint)
			shared_sky.sky_material = sky_material
		skies[track.id] = shared_sky
		# Forty courses must not retain forty radiance cubemaps indefinitely.
		# Active environments own their Sky, so evicting an old cache entry
		# cannot retire resources still used by a race or loading preview.
		while skies.size()>6: skies.erase(skies.keys()[0])
	settings.sky = skies[track.id]
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color.html(art.horizon)
	settings.ambient_light_energy = float(art.ambient)
	settings.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	environment.environment = settings
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(art.sun_rotation[0],art.sun_rotation[1],art.sun_rotation[2])
	sun.light_color = Color.html(art.sun)
	sun.light_energy = float(art.sun_energy)
	add_child(sun)
	add_child(CourseArt.terrain(track.id))
	terrain_grid = CourseArt.terrain_heights[track.id]
	poster_sites = RoadsidePosterArt.plan(self)
	decor_sites = CourseDecor.plan(self)
	spectacle_sites = CourseSpectacles.plan(self)
	hero_sites = ExpansionSetPieces.plan(self)
	if art.water:
		var water := MeshInstance3D.new()
		var plane := PlaneMesh.new()
		plane.size = Vector2(9000,9000)
		water.mesh = plane
		water.position = Vector3(500,float(CourseArt.terrain_info[track.id].sea_level),-200)
		var surface := ShaderMaterial.new()
		surface.shader = load("res://assets/exported/shaders/water.gdshader")
		water.material_override = surface
		water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(water)


func build_road() -> void:
	pending_geometry = RouteGeometry.meshes(track,true)
	var geometry := pending_geometry
	var sand := material(Color.html(art.ground))
	for key: String in geometry:
		if key in ["walls","shoulder"]: continue
		if key=="verges" and art.get("elevated",false): continue
		var instance := MeshInstance3D.new()
		instance.name = "Road_"+key
		instance.mesh = CourseRoadMesh.front_faces(geometry[key],track if key=="asphalt" else null)
		if key=="verges" and art.has("verge_extent"): instance.mesh = CourseRoadMesh.verges(track,float(art.verge_extent))
		if key=="asphalt":
			instance.material_override = paving_material()
		else:
			var mat: StandardMaterial3D = material(Color.html("F3E4C4")) if key == "markings" else sand
			mat.cull_mode = BaseMaterial3D.CULL_BACK
			if key=="markings" and art.get("space",false):
				mat.albedo_color = Color("65F6ED")
				mat.emission_enabled = true
				mat.emission = Color("36C6DF")
			instance.material_override = mat
		# Pavement/paint receive scenery shadows but do not need to cast an
		# entire duplicate road into the sun atlas. Elevated decks cast below.
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		CourseRoadMesh.partition(instance)
		add_child(instance)
	var shoulders := CourseRoadMesh.shoulders(track)
	for surface: String in shoulders:
		var instance := MeshInstance3D.new()
		instance.name = "Shoulder_"+surface
		instance.mesh = shoulders[surface]
		var color := Color("646B75") if surface=="asphalt" else Color("D8BD83") if surface=="sand" and track.definition.surface!="sand" else Color(art.ground)
		instance.material_override = paving_material(true) if surface=="asphalt" else material(color)
		instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		CourseRoadMesh.partition(instance)
		add_child(instance)
	var barrier := MeshInstance3D.new()
	barrier.name = "RoadsideBarriers"
	barrier.mesh = CourseRoadMesh.barriers(track,art)
	barrier.material_override = material(Color.html("F3E4C4"))
	CourseRoadMesh.partition(barrier)
	add_child(barrier)
	if art.get("elevated",false):
		var deck := MeshInstance3D.new()
		deck.name = "ElevatedDeck"
		deck.mesh = CourseRoadMesh.elevated_deck(track)
		deck.material_override = material(Color("677C8A"))
		CourseRoadMesh.partition(deck)
		add_child(deck)


func paving_material(shoulder: bool = false) -> ShaderMaterial:
	var key := "paving_shoulder" if shoulder else "paving_road"
	if materials.has(key): return materials[key]
	var result := ShaderMaterial.new()
	if not shoulder and track.road_surface()=="dirt":
		result.shader = load("res://assets/exported/shaders/dirt.gdshader")
		result.set_shader_parameter("soil_color",Color.html(art.get("soil","A56C38")))
	else:
		result.shader = load("res://assets/exported/shaders/asphalt.gdshader")
		result.set_shader_parameter("lane_wear",0.0 if shoulder else 0.13)
		if art.get("space",false): result.set_shader_parameter("paving_color",Color("33304D"))
	materials[key] = result
	return result


func build_collision() -> void:
	var collision := RouteCollision.new()
	for key in ["asphalt", "shoulder", "walls"]:
		collision.add_mesh(pending_geometry[key])
	add_child(collision)
	pending_geometry.clear()


func box(at: Vector3, size: Vector3, color: Color, parent: Node3D = null) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	node.mesh = mesh
	node.material_override = material(color)
	node.position = at
	(parent if parent else self).add_child(node)
	return node


func ground_pose(s: float, lateral: float) -> Transform3D:
	var pose := track.pose(s,lateral)
	var index := track.sample_index(s)
	var next := (index+1)%track.points.size()
	var end := track.distances[next] if next>0 else track.length
	var weight := (fposmod(s,track.length)-track.distances[index])/(end-track.distances[index])
	pose.origin.y = lerpf(RouteGeometry.point(track,index,lateral).y,RouteGeometry.point(track,next,lateral).y,weight)-2.5*clampf((absf(lateral)-float(track.bake.samples[index][8])/2-3)/(float(art.get("verge_extent",65))-3),0,1)
	pose.basis = Basis(Vector3.UP,pose.basis.get_euler().y)
	return pose


func scenery_pose(s: float, lateral: float) -> Transform3D:
	var pose := ground_pose(s,lateral)
	var heights: Dictionary = terrain_grid if not terrain_grid.is_empty() else CourseArt.terrain_heights.get(track.id,{})
	var terrain_y := CourseArt.height_from_grid(heights,pose.origin,pose.origin.y)
	pose.origin.y = maxf(terrain_y,verge_height(s,lateral,pose.origin))
	return pose


func verge_height(s: float, lateral: float, point: Vector3) -> float:
	if art.get("elevated",false): return -INF
	var i := track.sample_index(s)
	var j := (i+1)%track.points.size()
	var side := signf(lateral)
	var wa := float(track.bake.samples[i][8])*.5
	var wb := float(track.bake.samples[j][8])*.5
	var extent := float(art.get("verge_extent",65))
	if absf(lateral)<wa+3 or absf(lateral)>maxf(wa,wb)+extent: return -INF
	var a := RouteGeometry.point(track,i,side*(wa+3))
	var b := RouteGeometry.point(track,j,side*(wb+3))
	var c := RouteGeometry.point(track,j,side*(wb+extent))-Vector3.UP*2.5
	var d := RouteGeometry.point(track,i,side*(wa+extent))-Vector3.UP*2.5
	var above := Vector3(point.x,10000,point.z)
	var below := Vector3(point.x,-10000,point.z)
	var hit: Variant = Geometry3D.segment_intersects_triangle(above,below,a,b,c)
	if hit==null: hit = Geometry3D.segment_intersects_triangle(above,below,a,c,d)
	return float(hit.y) if hit!=null else -INF


func build_scenery_batch(first: int, last: int) -> void:
	if art.get("expansion40",false):
		ExpansionCourseArt.build_batch(self,first,last)
		return
	if art.get("space",false): return
	var batches: Dictionary = {}
	var species: String = art.vegetation
	var spacing := 10 if species=="orchard" else 16 if species=="palm" else 20
	for s in range(first,last,spacing):
		var edge := float(track.bake.samples[track.sample_index(s)][8])*.5
		var offsets: Array = [-edge-9,-edge-20,-edge-31,edge+9,edge+20] if species=="orchard" else [-edge-8,-edge-25,edge+9,edge+28] if species=="redwood" else [-edge-7,-edge-25,edge+7] if species=="palm" else [-edge-8,edge+10,edge+27]
		for lateral: float in offsets:
			if species=="palm" and lateral>0 and s%48!=0: continue
			var pose := scenery_pose(s,lateral)
			if RoadsidePosterArt.blocks_sightline(poster_sites,pose.origin): continue
			pose.basis = pose.basis.rotated(Vector3.UP,sin(s*.071+lateral)*PI)
			pose.basis = pose.basis.scaled(Vector3.ONE*(1+.12*sin(s*.11+lateral)))
			var variant := ArcadeSpriteVariety.tree(track.id,species,s,lateral,track.length)
			if not batches.has(variant): batches[variant] = [] as Array[Transform3D]
			batches[variant].append(pose)
	for s in range(first,last,16):
		for side: float in [-1.0,1.0]:
			var lateral := side*(float(track.bake.samples[track.sample_index(s)][8])/2+8)
			var pose := scenery_pose(s,lateral)
			pose.basis = pose.basis.rotated(Vector3.UP,s*.3)
			if not batches.has("grass"): batches.grass = [] as Array[Transform3D]
			batches.grass.append(pose)
	if track.id in ["palm_bay","marina_lights","skyline_splice"]:
		for s in range(first,last,40):
			var id := "streetlight" if track.id!="palm_bay" else "umbrella" if s%80==0 else "bench"
			if not batches.has(id): batches[id] = [] as Array[Transform3D]
			var edge := float(track.bake.samples[track.sample_index(s)][8])*.5
			batches[id].append(ground_pose(s,-edge-1.7) if art.get("elevated",false) else scenery_pose(s,-18))
	if track.id in ["marina_lights","skyline_splice"] or track.id=="palm_bay" and first%160==0:
		var id := ("marina_shops" if first%160==0 else "marina_hotel") if track.id!="palm_bay" else "coastal_home"
		var pose := scenery_pose(first+40,-48 if track.id!="palm_bay" else -65)
		pose.basis = pose.basis.rotated(Vector3.UP,PI/2)
		batches[id] = [pose] as Array[Transform3D]
	if first%160==0 and track.id in ["sunstone_canyon","pacific_summit"]:
		var id := "sandstone_rock" if track.id=="sunstone_canyon" else "summit_peak"
		var lateral := (-95 if first%320==0 else 100) if track.id=="sunstone_canyon" else -135
		var pose := scenery_pose(first+40,lateral)
		pose.basis = pose.basis.rotated(Vector3.UP,float((first/160)%7-3)*.17)
		if clear_of_road(pose.origin,25 if id=="sandstone_rock" else 52): batches[id] = [pose] as Array[Transform3D]
	if track.id=="pacific_summit":
		var pose := scenery_pose(first+20,-48)
		if not RoadsidePosterArt.blocks_sightline(poster_sites,pose.origin): batches.redwood = [pose] as Array[Transform3D]
	BillboardArt.load_catalog()
	ArcadeSpriteVariety.props(self,first,last,batches)
	for id: String in batches:
		var retained: Array[Transform3D] = []
		for pose: Transform3D in batches[id]:
			if decoration_allowed(pose.origin): retained.append(pose)
		if track.id=="pacific_summit":
			# Route-distance batches overlap heavily in views into the infield.
			# Keep every pose, but submit each species once per spatial cell.
			for pose: Transform3D in retained:
				var cell := Vector2i(floori(pose.origin.x/256),floori(pose.origin.z/256))
				var key := id+str(cell)
				if not scenery_batches.has(key): scenery_batches[key] = {"id":id,"poses":[] as Array[Transform3D]}
				scenery_batches[key].poses.append(pose)
		else:
			CourseArt.batch(id,retained,self,float(art.get("emission",0)))


func decoration_allowed(at: Vector3) -> bool:
	if ExpansionSetPieces.blocks_sightline(hero_sites,at): return false
	for clearing: Dictionary in scenery_clearings:
		var center: Vector3 = clearing.center
		if Vector2(at.x-center.x,at.z-center.z).length()<float(clearing.radius): return false
	return true


func clear_of_road(position: Vector3, radius: float) -> bool:
	for index in range(0,track.points.size(),4):
		var distance := Vector2(position.x,position.z).distance_to(Vector2(track.points[index].x,track.points[index].z))
		if distance<radius+float(track.bake.samples[index][8])/2+5: return false
	return true


func place_landmark(description: Dictionary) -> void:
	var result := CourseArt.model(description.id,float(art.get("emission",0)))
	var s := CourseArt.original_s(track,float(description.u))
	var lateral := float(description.lateral)
	var pose := scenery_pose(s,lateral) if art.get("elevated",false) else ground_pose(s,lateral)
	if art.get("expansion40",false):
		var radius: float = float(BillboardArt.rows[description.id].size_m[0])*.55
		for offset: float in [lateral,-lateral,lateral*1.5,-lateral*1.5,lateral*2.2,-lateral*2.2]:
			var candidate := scenery_pose(s,offset)
			if clear_of_road(candidate.origin,radius+3):
				pose = candidate
				lateral = offset
				break
		assert(clear_of_road(pose.origin,radius+3),"new landmark must clear every road branch")
	if description.get("align", "roadside")=="roadside": pose.basis = pose.basis.rotated(Vector3.UP,-signf(lateral)*PI/2)
	pose.origin.y += float(description.get("height_offset",0))
	result.transform = pose
	if description.id in ["timber_bridge","viaduct"]: RouteLandmark.conform(result,track,s,pose)
	if art.get("expansion40",false): result.name += "_"+str(roundi(float(description.u)*100))
	result.set_meta("anchor_u",description.u)
	result.set_meta("anchor_s",s)
	result.set_meta("anchor_lateral",lateral)
	if description.id in ["surf_shop","lighthouse","beach_hotel","fruit_stand","packing_shed","arcade","seafood_diner","ranger_kiosk","visitor_center","mountain_lodge","observatory"]:
		var size: Array = CourseArt.library[description.id].size_m
		var base := box(Vector3(0,-1.6,0),Vector3(float(size[0])+.4,3.2,float(size[1])+.4),Color.html("A9B7A8"),result)
		base.add_to_group("scenery_distance")
		base.visibility_range_end = 700
	add_child(result)
	if lateral!=0 and description.id not in ["sailboats","balloons","rail_trestle","twin_mesas"]:
		add_camera_bounds(result)


func add_camera_bounds(model: Node3D) -> void:
	var bounds := AABB()
	var first := true
	for node: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		if CourseArt.level_of(str(node.name))!=0: continue
		var box := node.transform*node.get_aabb()
		bounds = box if first else bounds.merge(box)
		first = false
	if first: return
	var body := StaticBody3D.new()
	body.name = "SceneryCameraBounds"
	body.collision_layer = 2
	body.collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = bounds.size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = bounds.get_center()
	body.add_child(collision)
	model.add_child(body)


func build_direction_signs() -> void:
	var last: float = -1000
	for index in range(track.points.size()):
		var curve := float(track.bake.samples[index][6])
		if absf(curve)<1.0/80 or track.distances[index]-last<160: continue
		last = track.distances[index]
		var s := fposmod(last-80,track.length)
		var side := -signf(curve)
		var board := CourseArt.model("chevron")
		board.transform = ground_pose(s,side*(float(track.bake.samples[track.sample_index(s)][8])/2+6))
		if curve<0: board.scale.x = -1
		# Route guidance is retained beyond the optional scenery distance.
		for node: MeshInstance3D in board.find_children("*","MeshInstance3D",true,false):
			if node.is_in_group("scenery_distance"): node.remove_from_group("scenery_distance")
			node.visible = CourseArt.level_of(str(node.name))==0
			node.visibility_range_begin = 0
			node.visibility_range_end = 0
		add_child(board)
		if absf(curve)>1.0/45:
			var warning := CourseArt.model("warning")
			warning.transform = ground_pose(s-30,side*(float(track.bake.samples[track.sample_index(s)][8])/2+6))
			for node: MeshInstance3D in warning.find_children("*","MeshInstance3D",true,false):
				node.remove_from_group("scenery_distance")
				node.visible = CourseArt.level_of(str(node.name))==0
				node.visibility_range_begin = 0
				node.visibility_range_end = 0
			add_child(warning)


func build_covers() -> void:
	for description: Dictionary in art.landmarks:
		if not description.has("interval"): continue
		var roof := MeshInstance3D.new()
		roof.name = "RouteCover_"+str(description.id)
		roof.mesh = CourseRoadMesh.cover(track,description.interval,float(description.clearance))
		roof.material_override = material(Color.html("D58C53") if track.id=="sunstone_canyon" else Color.html("A9B7B8"))
		roof.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(roof)
		var body := StaticBody3D.new()
		body.name = "TunnelCameraBounds"
		body.collision_layer = 2
		body.collision_mask = 0
		var collision := CollisionShape3D.new()
		var shape := roof.mesh.create_trimesh_shape()
		shape.backface_collision = true
		collision.shape = shape
		body.add_child(collision)
		add_child(body)
		var lamp_material := StandardMaterial3D.new()
		lamp_material.albedo_color = Color("FFF1D2")
		lamp_material.emission_enabled = true
		lamp_material.emission = Color("FFF1D2")
		lamp_material.emission_energy_multiplier = .4
		for s in range(0,int(track.length),12):
			var u := float(track.bake.samples[track.sample_index(s)][7])
			if u<float(description.interval[0]) or u>float(description.interval[1]): continue
			var lamp := box(Vector3.ZERO,Vector3(2,.12,.6),Color("FFF1D2"))
			lamp.transform = track.pose(s)
			lamp.position.y += float(description.clearance)-.18
			lamp.material_override = lamp_material
			lamp.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for u: float in description.interval:
			var portal := CourseArt.model(description.id)
			portal.name = "Portal_"+str(u)
			portal.transform = ground_pose(CourseArt.original_s(track,u),0)
			add_child(portal)


func build_jump_markings() -> void:
	for marker: float in track.definition.ramp_markers:
		build_jump_marker(marker)


func build_jump_marker(marker: float) -> void:
	var crest := CourseArt.original_s(track,marker)
	for distance: float in [-10.0,-7.0,-4.0,50.0]:
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var before := track.sample_index(crest+distance-.18)
		var after := track.sample_index(crest+distance+.18)
		if before==after: after = (before+1)%track.points.size()
		var width := float(track.bake.samples[before][8])/2-.4
		CourseRoadMesh.quad(tool,RouteGeometry.point(track,after,-width)+Vector3.UP*.026,RouteGeometry.point(track,after,width)+Vector3.UP*.026,RouteGeometry.point(track,before,width)+Vector3.UP*.026,RouteGeometry.point(track,before,-width)+Vector3.UP*.026)
		var stripe := MeshInstance3D.new()
		stripe.name = "LandingStripe" if distance>0 else "JumpWarningBar_"+str(absf(distance))
		stripe.mesh = tool.commit()
		stripe.material_override = material(Color("F3E4C4") if distance>0 else Color("F3CD48"))
		add_child(stripe)


func gantry() -> void:
	var root := Node3D.new()
	root.transform = track.pose(0)
	add_child(root)
	for side: float in [-1.0, 1.0]:
		box(Vector3(side * 11, 3, 0), Vector3(.65, 6, .65), Color.html("F3E4C4"), root)
	box(Vector3(0, 6, 0), Vector3(22, 1, .7), Color.html("172C40"), root)
	for x in range(-11, 11):
		box(Vector3(x + .5, 5.95, -.38), Vector3(1, .8, .06), Color.html("F5EBD3") if x % 2 == 0 else Color.html("343C49"), root)
	var label := Label3D.new()
	label.text = track.definition.name.to_upper()
	label.font_size = 80
	label.pixel_size = .012
	label.position = Vector3(0, 7.1, .0)
	label.modulate = Color.html("F5EBD3")
	label.no_depth_test = false
	root.add_child(label)
	for index in range(3):
		var lamp := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = .25
		sphere.height = .5
		sphere.radial_segments = 12
		sphere.rings = 6
		lamp.mesh = sphere
		lamp.position = Vector3((index-1)*1.1,5.4,.48)
		var surface := StandardMaterial3D.new()
		surface.albedo_color = Color("343C49")
		surface.emission_enabled = true
		lamp.material_override = surface
		root.add_child(lamp)
		start_lamps.append(lamp)


func set_start_lamps(phase: String, phase_ticks: int, racing_ticks: int) -> void:
	var count := clampi(1+phase_ticks/60,0,3) if phase=="Countdown" else 3 if phase=="Racing" and racing_ticks<60 else 0
	for index in range(start_lamps.size()):
		var surface := start_lamps[index].material_override as StandardMaterial3D
		var active := index<count
		var color := Color("5E9654") if phase=="Racing" else Color("F16B50")
		surface.albedo_color = color if active else Color("343C49")
		surface.emission = color*.4 if active else Color.BLACK

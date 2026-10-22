class_name CourseLandscape
extends RefCounted
## Area-based scenery breaks up the empty infield and the roadside ribbon.
## Small spatial batches retain useful culling; the cheap horizon stays visible.


static func noise_at(x: float, z: float, seed: float) -> float:
	return fposmod(sin(x*12.9898+z*78.233+seed*37.719)*43758.5453,1.0)


static func build(world: TrackWorld) -> void:
	if world.art.get("composition_version",0)>=14:
		AuthoredCourseScenery.build(world)
		return
	if world.art.get("expansion40",false):
		ExpansionCourseArt.landscape(world)
		return
	var low := Vector2(INF,INF)
	var high := Vector2(-INF,-INF)
	for cell: Vector2i in world.terrain_grid:
		low = low.min(Vector2(cell)*32)
		high = high.max(Vector2(cell)*32)
	var buckets: Dictionary = {}
	var sites: Array[Dictionary] = []
	var city := world.track.id in ["marina_lights","skyline_splice"]
	var dry := world.track.id in ["sunstone_canyon","quarry_switchback","caldera_crosscut"]
	var reservoir := world.track.id=="spillway_sprint"
	var sea := float(CourseArt.terrain_info[world.track.id].sea_level)
	# Work in world space, independently of route tangents and roadside spacing.
	for x in range(int(low.x)+64,int(high.x)-64,56):
		for z in range(int(low.y)+64,int(high.y)-64,56):
			var at := Vector3(x+noise_at(x,z,1)*36-18,0,z+noise_at(x,z,2)*36-18)
			var nearest := INF
			var anchor := 0
			for i in range(0,world.track.points.size(),8):
				var point := world.track.points[i]
				var distance := Vector2(at.x-point.x,at.z-point.z).length()
				if distance<nearest:
					nearest = distance
					anchor = i
			if nearest<85 or nearest>540: continue
			# Broad groves/districts with clearings, rather than another offset row.
			var patch := sin(at.x*.009+sin(at.z*.006)*2)+cos(at.z*.012-at.x*.003)
			if patch<(-.65 if city else -.35): continue
			at.y = CourseArt.height_from_grid(world.terrain_grid,at,-INF)
			if not is_finite(at.y) or world.art.water and not reservoir and at.y<sea+1.5: continue
			if not world.decoration_allowed(at) or RoadsidePosterArt.blocks_sightline(world.poster_sites,at): continue
			var seed := noise_at(x,z,3)
			if reservoir and (seed>.28 or patch<.4): continue
			var id := ArcadeSpriteVariety.tree(world.track.id,str(world.art.vegetation),world.track.distances[anchor],at.x+at.z,world.track.length)
			if reservoir:
				id = "islet"
			elif dry:
				id = "hoodoo_cluster" if seed>.45 else "flowering_cactus" if world.track.id!="caldera_crosscut" else "shrub"
			elif city:
				id = "district"
			elif world.track.id=="palm_bay" and seed>.82:
				id = "coastal_home"
			elif world.track.id=="citrus_pass" and seed>.94:
				id = "trail_cabin"
			var scale := .8+seed*.65
			var radius := 23.0 if id=="district" else 18.0
			if not world.clear_of_road(at,radius): continue
			var key := str(floori(at.x/224))+":"+str(floori(at.z/224))+":"+id
			if not buckets.has(key): buckets[key] = {"id":id,"poses":[] as Array[Transform3D]}
			for member in range(1 if city or dry or reservoir or id in ["coastal_home","trail_cabin"] else 4):
				var root := at+Vector3(sin(seed*TAU+member*2.4),0,cos(seed*TAU+member*2.4))*member*7
				root.y = CourseArt.height_from_grid(world.terrain_grid,root,-INF)
				if not is_finite(root.y) or world.art.water and not reservoir and root.y<sea+1.5: continue
				if not world.clear_of_road(root,radius) or not world.decoration_allowed(root): continue
				if RoadsidePosterArt.blocks_sightline(world.poster_sites,root): continue
				var pose := Transform3D(Basis(Vector3.UP,seed*TAU+member).scaled(Vector3.ONE*(scale-member*.07)),root)
				buckets[key].poses.append(pose)
				sites.append({"at":root,"id":id,"radius":radius,"distance":nearest})
	var parent := Node3D.new()
	parent.name = "LandscapeDistricts"
	parent.set_meta("sites",sites)
	world.add_child(parent)
	for key: String in buckets:
		var bucket: Dictionary = buckets[key]
		if bucket.poses.is_empty(): continue
		if bucket.id=="district":
			city_block(world,parent,bucket.poses,key)
		elif bucket.id=="islet":
			islets(world,parent,bucket.poses,key)
		elif BillboardArt.supports(bucket.id):
			# These groves start beyond the close-range footprint shadows.
			BillboardArt.batch(bucket.id,bucket.poses,parent,float(world.art.get("emission",0)),false)
		else:
			CourseArt.batch(bucket.id,bucket.poses,parent,float(world.art.get("emission",0)))
	# Waterworks and the caldera already have their own persistent skyline.
	if world.track.id not in ["spillway_sprint","caldera_crosscut"]:
		horizon(world)


static func islets(world: TrackWorld, parent: Node3D, poses: Array[Transform3D], key: String) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for pose: Transform3D in poses:
		var seed := noise_at(pose.origin.x,pose.origin.z,9)
		CourseDecor.stone(tool,pose.origin-Vector3.UP*6,Vector3(16,18+seed*30,14),Color("78978A"),int(seed*100))
	var node := MeshInstance3D.new()
	node.name = "ReservoirIslets_"+key.replace(":","_")
	node.mesh = tool.commit()
	if not world.materials.has("landscape_islets"):
		world.materials.landscape_islets = CourseSpectacles.surface()
	node.material_override = world.materials.landscape_islets
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_to_group("scenery_distance")
	node.visibility_range_end = 700
	parent.add_child(node)


static func city_block(world: TrackWorld, parent: Node3D, poses: Array[Transform3D], key: String) -> void:
	if world.art.get("district","") in ["festival","citadel"]:
		ExpansionDistrictDetail.blocks(world,parent,poses,key)
		return
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for pose: Transform3D in poses:
		var seed := noise_at(pose.origin.x,pose.origin.z,7)
		var height := 22+seed*85
		var color := Color("45657D").lerp(Color("849197"),seed)
		var district: String = world.art.get("district","")
		if district in ["harbor","port","works"]:
			height = 12+seed*38
			color = Color("596875").lerp(Color("AD7462"),seed)
		elif district in ["market","citadel","festival"]:
			height = 8+seed*24
			color = Color("A3534B").lerp(Color.html(world.art.ground).lightened(.25),seed)
		# Grid-aligned blocks read as a neighborhood from the elevated road.
		var base := Transform3D(Basis.IDENTITY,pose.origin)
		CourseDecor.facade_box(tool,base*Transform3D(Basis.IDENTITY,Vector3(0,height*.5,0)),Vector3(23,height,27),color,pose.origin.y+height,true)
		CourseDecor.facade_box(tool,base*Transform3D(Basis.IDENTITY,Vector3(0,height+1,0)),Vector3(25,2,29),Color("BECAD0"),pose.origin.y+height,false)
		if district=="market":
			for tier in range(3):
				CourseDecor.facade_box(tool,base*Transform3D(Basis.IDENTITY,Vector3(0,height+2+tier*1.3,0)),Vector3(31-tier*6,1.4,35-tier*6),Color("5D3A54"),pose.origin.y+height,false)
		elif district=="works":
			CourseDecor.facade_box(tool,base*Transform3D(Basis.IDENTITY,Vector3(6,height+12,0)),Vector3(5,24,5),Color("AD806D"),pose.origin.y+height,false)
		for floor_index in range(6,int(height)-3,9):
			CourseDecor.facade_box(tool,base*Transform3D(Basis.IDENTITY,Vector3(0,floor_index,0)),Vector3(23.15,1.1,27.15),Color("B6C9CD"),pose.origin.y+height,false)
	var node := MeshInstance3D.new()
	node.name = "DistantBlock_"+key.replace(":","_")
	node.mesh = tool.commit()
	if not world.materials.has("landscape_city"):
		var surface := ShaderMaterial.new()
		surface.shader = load("res://assets/exported/shaders/scenery.gdshader")
		surface.set_shader_parameter("city_facade",true)
		surface.set_shader_parameter("window_glow",float(world.art.get("emission",0)))
		world.materials.landscape_city = surface
	node.material_override = world.materials.landscape_city
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_to_group("scenery_distance")
	node.visibility_range_end = 700
	parent.add_child(node)


static func horizon(world: TrackWorld) -> void:
	if world.art.get("expansion40",false):
		ExpansionHorizon.build(world)
		return
	var low := Vector3(INF,INF,INF)
	var high := Vector3(-INF,-INF,-INF)
	for at: Vector3 in world.track.points:
		low = low.min(at)
		high = high.max(at)
	var center := (low+high)*.5
	var radius := Vector2(high.x-low.x,high.z-low.z).length()*.5+560
	var base_y := INF
	for height: float in world.terrain_grid.values(): base_y = minf(base_y,height)
	base_y -= 16
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dry: bool = world.track.id in ["sunstone_canyon","quarry_switchback"] or world.art.get("theme","") in ["desert","space"]
	var coast := world.track.id in ["palm_bay","marina_lights"]
	var tint := Color("AF8A81") if dry else Color("69898B")
	if world.art.get("expansion40",false): tint = Color.html(world.art.ground).darkened(.22)
	tint = tint.lerp(Color.html(world.art.horizon),.30)
	for index in range(44):
		# Leave the seaward side open; coastlines retain their broad ocean view.
		var angle := TAU*index/44
		if coast and cos(angle)>.15: continue
		var at := center+Vector3(cos(angle)*radius,0,sin(angle)*radius)
		at.y = base_y
		var seed := noise_at(index,0,11)
		var height := 100+seed*180+(90 if world.track.id=="pacific_summit" else 0)
		if world.art.get("theme","")=="polar": height += 110
		CourseDecor.stone(tool,at+Vector3(0,-height*.12,0),Vector3(220+seed*90,height,180+seed*80),tint,index)
	var node := MeshInstance3D.new()
	node.name = "LandscapeHorizon"
	node.mesh = tool.commit()
	var surface := StandardMaterial3D.new()
	surface.vertex_color_use_as_albedo = true
	surface.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	node.material_override = surface
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(node)

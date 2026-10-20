class_name CourseSpectacles
extends RefCounted
## Original cosmetic waterworks and basalt scenery, outside every road branch.

static func plan(world: TrackWorld) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if world.track.id not in ["spillway_sprint","caldera_crosscut"]: return result
	if world.track.id=="caldera_crosscut":
		assert(world.clear_of_road(Vector3.ZERO,300))
		world.scenery_clearings.append({"center":Vector3.ZERO,"radius":303.0})
	var spillway := world.track.id=="spillway_sprint"
	for s in range(100 if spillway else 120,int(world.track.length),280 if spillway else 220):
		var sides: Array = [-1.0 if (s/280)%2==0 else 1.0] if spillway else [-1.0,1.0]
		for side: float in sides:
			var pose := world.scenery_pose(s,side*(62 if spillway else 90))
			var radius := 26.0 if spillway else 43.0
			if not world.clear_of_road(pose.origin,radius) or RoadsidePosterArt.blocks_sightline(world.poster_sites,pose.origin): continue
			result.append({"s":s,"side":side,"pose":pose,"radius":radius,"height":world.track.pose(s).origin.y-pose.origin.y+(45 if spillway else 65)})
			world.scenery_clearings.append({"center":pose.origin,"radius":radius+3})
	return result


static func surface(lava: bool = false) -> ShaderMaterial:
	var result := ShaderMaterial.new()
	result.shader = load("res://assets/exported/shaders/landscape.gdshader")
	result.set_shader_parameter("lava",lava)
	return result


static func finish(world: TrackWorld, name: String, tool: SurfaceTool, material: Material, pose: Transform3D = Transform3D.IDENTITY, radius: float = 0.0, distance: float = 700.0) -> MeshInstance3D:
	var result := MeshInstance3D.new()
	result.name = name
	result.mesh = tool.commit()
	result.material_override = material
	result.transform = pose
	result.set_meta("spectacle",name.get_slice("_",0))
	result.set_meta("footprint_radius_m",radius)
	result.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if distance>0:
		result.add_to_group("scenery_distance")
		result.visibility_range_end = distance
	world.add_child(result)
	return result


static func build(world: TrackWorld) -> void:
	if world.track.id in ["spillway_sprint","caldera_crosscut"]:
		# One cheap distant floor remains after detailed terrain chunks cull.
		# It sits below the entire authored ground mesh and every road level.
		var floor_tool := SurfaceTool.new()
		floor_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		CourseDecor.colored_quad(floor_tool,Vector3(-4500,1,-4500),Vector3(4500,1,-4500),Vector3(4500,1,4500),Vector3(-4500,1,4500),Color.html(world.art.ground))
		finish(world,"DistantGround",floor_tool,surface(),Transform3D.IDENTITY,6400,0)
	if world.track.id=="spillway_sprint": spillway(world)
	elif world.track.id=="caldera_crosscut": caldera(world)


static func spillway(world: TrackWorld) -> void:
	var concrete := surface()
	backdrop(world,concrete,true)
	var painted := StandardMaterial3D.new()
	var pool := ShaderMaterial.new()
	for site: Dictionary in world.spectacle_sites:
		var s: int = site.s
		var pose: Transform3D = site.pose
		var height: float = site.height
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for x: float in [-18.0,18.0]:
			CourseSetPieces.cuboid(tool,Transform3D(Basis.IDENTITY,Vector3(x,height*.5,0)),Vector3(7,height,14),Color("C5C8AF"))
			CourseSetPieces.cuboid(tool,Transform3D(Basis.IDENTITY,Vector3(x,height+1,0)),Vector3(9,2,16),Color("F1D7A4"))
		for part in range(10):
			var a := PI*part/10
			var b := PI*(part+1)/10
			CourseSetPieces.beam(tool,Vector3(cos(a)*18,height-12+sin(a)*12,0),Vector3(cos(b)*18,height-12+sin(b)*12,0),3.5,Color("D9D7BD"))
		var dam := finish(world,"Spillway_"+str(s),tool,concrete,pose,26)
		var waterfall := Node3D.new()
		waterfall.name = "SpillwayCascade"
		waterfall.position.y = 0.1
		waterfall.scale = Vector3(.9,(height-13)/26,1)
		dam.add_child(waterfall)
		CourseDecor.waterfall(world,waterfall,painted,pool)
		# The existing painted falls stretch down the concrete opening. Their
		# pool remains on the reservoir floor; no gameplay water is introduced.


static func caldera(world: TrackWorld) -> void:
	var basalt := surface()
	backdrop(world,basalt,false)
	var cone := SurfaceTool.new()
	cone.begin(Mesh.PRIMITIVE_TRIANGLES)
	var profile := [Vector2(300,4),Vector2(235,90),Vector2(150,220),Vector2(100,345),Vector2(75,335),Vector2(62,300)]
	for level in range(profile.size()-1):
		for segment in range(48):
			var a := TAU*segment/48
			var b := TAU*(segment+1)/48
			var lower: Vector2 = profile[level]
			var upper: Vector2 = profile[level+1]
			var color := Color("57506B") if segment%3==0 else Color("655D70") if segment%3==1 else Color("7A6264")
			CourseDecor.colored_quad(cone,Vector3(cos(a)*lower.x,lower.y,sin(a)*lower.x),Vector3(cos(b)*lower.x,lower.y,sin(b)*lower.x),Vector3(cos(b)*upper.x,upper.y,sin(b)*upper.x),Vector3(cos(a)*upper.x,upper.y,sin(a)*upper.x),color)
	assert(world.clear_of_road(Vector3.ZERO,300),"the entire crater footprint stays outside every road branch")
	finish(world,"CalderaCrater",cone,basalt,Transform3D.IDENTITY,300,0)
	var lava := surface(true)
	var pool := SurfaceTool.new()
	pool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for segment in range(48):
		var a := TAU*segment/48
		var b := TAU*(segment+1)/48
		CourseDecor.colored_triangle(pool,Vector3(0,300.5,0),Vector3(cos(a)*62,300.5,sin(a)*62),Vector3(cos(b)*62,300.5,sin(b)*62),Color("FF873B"))
	finish(world,"CraterLava",pool,lava,Transform3D.IDENTITY,62,0)
	for site: Dictionary in world.spectacle_sites:
		var pose: Transform3D = site.pose
		var height: float = site.height
		var stone := SurfaceTool.new()
		stone.begin(Mesh.PRIMITIVE_TRIANGLES)
		for index in range(3):
			CourseDecor.stone(stone,Vector3((index-1)*18,-height*.1,index%2*4),Vector3(18,height*(.8+.1*index),16),Color("675D76"),index+int(site.s))
		finish(world,"BasaltSpire_"+str(site.s)+"_"+str(int(site.side)),stone,basalt,pose,43)


static func backdrop(world: TrackWorld, material: Material, waterworks: bool) -> void:
	# Low-poly distant silhouettes frame the whole layout at every driving height.
	# Their complete footprints stay beyond every branch, with no physics bodies.
	for index in range(16):
		var angle := TAU*index/16
		var radius := 1290.0 if waterworks else 1330.0
		var center := Vector3(cos(angle)*radius,2,sin(angle)*radius)
		assert(world.clear_of_road(center,180))
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var color := Color("849C8B") if waterworks else Color("695D7D")
		var height := 210+50*sin(index*1.7)
		CourseDecor.stone(tool,Vector3(0,-height*.12,0),Vector3(170,height,160),color,index)
		finish(world,"ReservoirCliff_"+str(index) if waterworks else "VolcanicRidge_"+str(index),tool,material,Transform3D(Basis.IDENTITY,center),180,0)

class_name CourseDecor
extends RefCounted
## Original, bounded roadside meshes. These never enter the driving collision.


static func plan(world: TrackWorld) -> Array[Dictionary]:
	if world.art.get("expansion40",false): return ExpansionRoadsideLife.plan(world)
	if world.art.get("composition_version",0)>=14: return authored_plan(world)
	var result: Array[Dictionary] = []
	for s in range(75,int(world.track.length),145):
		var edge := float(world.track.bake.samples[world.track.sample_index(s)][8])*.5
		var side := -1.0 if (s/145)%2==0 else 1.0
		var pose := world.scenery_pose(s,side*(edge+17))
		if world.art.get("elevated",false): continue
		if not world.clear_of_road(pose.origin,7) or RoadsidePosterArt.blocks_sightline(world.poster_sites,pose.origin): continue
		var logs: bool = world.track.id in ["citrus_pass","redwood_run","pacific_summit","quarry_switchback"] and (s/145)%3==1
		var variant := int(s/145)
		var kind := "Logs" if logs else "Rocks"
		if world.track.id=="palm_bay" and variant%2==1: kind = "SurfHut" if variant%4==1 else "BeachUmbrellas"
		elif world.track.id=="citrus_pass" and not logs and variant%4==0: kind = "PackingCrates"
		elif world.track.id=="marina_lights" and variant%2==1: kind = "HarborCargo"
		if kind in RoadsideLife.KINDS: pose.basis = pose.basis*Basis(Vector3.UP,-side*PI*.5)
		result.append({"kind":kind,"pose":pose,"s":s,"radius":7.0})
	if world.track.id in ["skyline_splice","quarry_switchback"]:
		for s in range(40,int(world.track.length),80 if world.track.id=="skyline_splice" else 320):
			for side: float in [-1.0,1.0]:
				var pose := world.scenery_pose(s,side*48)
				if not world.clear_of_road(pose.origin,15) or RoadsidePosterArt.blocks_sightline(world.poster_sites,pose.origin): continue
				var height := world.track.pose(s).origin.y-pose.origin.y+22+17*sin(s*.014+side)
				result.append({"kind":"Tower" if world.track.id=="skyline_splice" else "Bluff","pose":pose,"s":s,"radius":15.0,"height":height})
	if world.track.id in ["redwood_run","pacific_summit","quarry_switchback"]:
		for u: float in [.235,.735]:
			var s := CourseArt.original_s(world.track,u)
			for lateral: float in [-48.0,48.0,-64.0,64.0]:
				var pose := world.scenery_pose(s,lateral)
				if not world.clear_of_road(pose.origin,22) or RoadsidePosterArt.blocks_sightline(world.poster_sites,pose.origin): continue
				pose.basis = pose.basis*Basis(Vector3.UP,-signf(lateral)*deg_to_rad(50))
				result.append({"kind":"Waterfall","pose":pose,"s":s,"radius":22.0})
				break
	for site: Dictionary in result:
		world.scenery_clearings.append({"center":site.pose.origin,"radius":site.radius+3})
	return result


static func authored_plan(world: TrackWorld) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for scene: Dictionary in world.art.service_scenes:
		var s := CourseArt.original_s(world.track,float(scene.u))
		var side := float(scene.side)
		var pose := world.scenery_pose(s,side*float(scene.setback))
		var kind: String = scene.kinds[0]
		var radius := 22.0 if kind=="Waterfall" else 7.0
		if not world.clear_of_road(pose.origin,radius) or not world.decoration_allowed(pose.origin,radius) or RoadsidePosterArt.blocks_sightline(world.poster_sites,pose.origin): continue
		if kind in RoadsideLife.KINDS: pose.basis = pose.basis*Basis(Vector3.UP,-side*PI*.5)
		result.append({"kind":kind,"pose":pose,"s":s,"radius":radius})
		world.scenery_clearings.append({"center":pose.origin,"radius":radius+3})
	return result


static func stone(tool: SurfaceTool, center: Vector3, size: Vector3, color: Color, seed: int) -> void:
	# Uneven five-sided rings produce closed, faceted boulders without a sphere silhouette.
	var rings: Array[Vector3] = []
	for level in range(2):
		for corner in range(5):
			var angle := TAU*corner/5+seed*.47+level*.22
			var radius := (.8+.13*sin(seed+corner*2.7))*(1.0 if level==0 else .63)
			rings.append(center+Vector3(cos(angle)*size.x*radius,size.y*(.08 if level==0 else .72+.15*sin(corner*1.9+seed)),sin(angle)*size.z*radius))
	for corner in range(5):
		var next := (corner+1)%5
		colored_quad(tool,rings[corner],rings[next],rings[next+5],rings[corner+5],color)
		colored_triangle(tool,rings[corner+5],rings[next+5],center+Vector3(0,size.y,0),color.lightened(.08))
		colored_triangle(tool,rings[next],rings[corner],center,color.darkened(.15))


static func colored_triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	var normal := -(b-a).cross(c-a).normalized()
	for point: Vector3 in [a,b,c]:
		tool.set_normal(normal)
		tool.set_color(color*(.78+.22*maxf(0,normal.y)))
		tool.add_vertex(point)


static func colored_quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	colored_triangle(tool,a,b,c,color)
	colored_triangle(tool,a,c,d,color)


static func log_mesh(tool: SurfaceTool, center: Vector3, length: float, radius: float) -> void:
	for corner in range(8):
		var angle := TAU*corner/8
		var next := TAU*(corner+1)/8
		var a := Vector3(cos(angle)*radius,sin(angle)*radius,-length*.5)+center
		var b := Vector3(cos(next)*radius,sin(next)*radius,-length*.5)+center
		var c := b+Vector3.BACK*length
		var d := a+Vector3.BACK*length
		colored_quad(tool,a,d,c,b,Color("68452F") if corner%2==0 else Color("8B5B39"))
		colored_triangle(tool,center+Vector3.FORWARD*length*.5,a,b,Color("E4BC7F"))
		colored_triangle(tool,center+Vector3.BACK*length*.5,c,d,Color("C39A66"))


static func facade_box(tool: SurfaceTool, pose: Transform3D, size: Vector3, color: Color, height: float, windows: bool) -> void:
	# Keep the existing box geometry; metre UVs align glass with the floor bands.
	# Alpha marks window-bearing walls in an opaque shader, rather than blending.
	var box := BoxMesh.new()
	box.size = size
	var arrays := box.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for index: int in arrays[Mesh.ARRAY_INDEX]:
		var at := pose*vertices[index]
		var normal := pose.basis*normals[index]
		var ink := color*(.86+.14*maxf(0,normal.y))
		ink.a = 1.0 if windows else 0.0
		tool.set_normal(normal)
		tool.set_color(ink)
		tool.set_uv(Vector2(at.z if absf(normal.x)>.5 else at.x,at.y-height+3.6))
		tool.add_vertex(at)


static func build(world: TrackWorld) -> void:
	if world.art.get("expansion40",false):
		ExpansionRoadsideLife.build(world)
		return
	var surface := StandardMaterial3D.new()
	surface.vertex_color_use_as_albedo = true
	surface.roughness = .95
	var city_surface: ShaderMaterial
	for site: Dictionary in world.decor_sites:
		var node := MeshInstance3D.new()
		node.name = "Decor"+site.kind+"_"+str(site.s)
		node.transform = site.pose
		node.set_meta("clearance_radius_m",site.radius)
		node.set_meta("kind",site.kind)
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		if site.kind in RoadsideLife.KINDS:
			RoadsideLife.build(tool,site.kind,int(site.s/580))
		elif site.kind=="Logs":
			for index in range(5):
				log_mesh(tool,Vector3((index%3-1)*1.25,.65+(index/3)*1.1,0),7.0-index*.37,.65)
		elif site.kind=="Rocks":
			var color := Color("D59867") if world.track.id=="sunstone_canyon" else Color("85928A")
			for index in range(4):
				stone(tool,Vector3((index%2)*3-1.5,-.3,(index/2)*3-1.5),Vector3(2.1,2.3+index*.65,2.0),color,index+int(site.s))
		elif site.kind=="Tower":
			if city_surface==null:
				city_surface = ShaderMaterial.new()
				city_surface.shader = load("res://assets/exported/shaders/scenery.gdshader")
				city_surface.set_shader_parameter("city_facade",true)
				city_surface.set_shader_parameter("window_glow",float(world.art.get("emission",0)))
			var height: float = site.height
			var color := Color("597D98") if int(site.s/80)%3==0 else Color("A4AEA9") if int(site.s/80)%3==1 else Color("72748E")
			facade_box(tool,Transform3D(Basis.IDENTITY,Vector3(0,height*.5,0)),Vector3(18,height,17),color,height,true)
			for floor_index in range(10):
				var y := height-3-floor_index*3.7
				if y<4: break
				facade_box(tool,Transform3D(Basis.IDENTITY,Vector3(0,y,0)),Vector3(18.15,1.2,17.15),Color("C9DCD5") if floor_index%3 else Color("F0CB82"),height,false)
			facade_box(tool,Transform3D(Basis.IDENTITY,Vector3(0,height+1.5,0)),Vector3(8,3,9),color.darkened(.2),height,false)
		elif site.kind=="Bluff":
			for index in range(3):
				stone(tool,Vector3((index-1)*6,-1,index%2*2),Vector3(7,24+index*5,7),Color("7E8E89"),index+int(site.s))
		else:
			for index in range(3):
				stone(tool,Vector3((index-1)*8,-.3,0),Vector3(2.0,2.4,2.1),Color("6D817C"),index)
			waterfall(world,node)
		node.mesh = tool.commit()
		node.material_override = city_surface if site.kind=="Tower" else surface
		node.add_to_group("scenery_distance")
		var limit := 700.0 if site.kind in ["Waterfall","Tower","Bluff"] else 160.0
		node.set_meta("lod_limit",limit)
		node.visibility_range_end = limit
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		world.add_child(node)


static func waterfall(_world: TrackWorld, parent: Node3D, painted_override: StandardMaterial3D = null, pool_override: ShaderMaterial = null) -> void:
	var card := MeshInstance3D.new()
	card.name = "IllustratedWaterfall"
	var quad := QuadMesh.new()
	quad.size = Vector2(27,26)
	quad.center_offset = Vector3(0,13,0)
	card.mesh = quad
	card.custom_aabb = AABB(Vector3(-13.5,0,-13.5),Vector3(27,26,27))
	var painted := painted_override if painted_override!=null else StandardMaterial3D.new()
	painted.albedo_texture = load("res://assets/exported/decorations/waterfall-v1.png")
	painted.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	painted.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	painted.billboard_keep_scale = true
	painted.cull_mode = BaseMaterial3D.CULL_DISABLED
	painted.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	painted.alpha_scissor_threshold = .5
	painted.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	painted.texture_repeat = false
	card.material_override = painted
	card.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	card.add_to_group("scenery_distance")
	card.visibility_range_end = 700
	parent.add_child(card)
	var surface := pool_override if pool_override!=null else ShaderMaterial.new()
	surface.shader = load("res://assets/exported/shaders/water.gdshader")
	var pool := MeshInstance3D.new()
	pool.name = "WaterfallPool"
	var plane := PlaneMesh.new()
	plane.size = Vector2(15,14)
	pool.mesh = plane
	pool.position = Vector3(0,.08,4)
	pool.material_override = surface
	pool.add_to_group("scenery_distance")
	pool.add_to_group("scenery_motion")
	pool.visibility_range_end = 700
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(pool)

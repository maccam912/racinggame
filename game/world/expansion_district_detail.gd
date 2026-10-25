class_name ExpansionDistrictDetail
extends RefCounted
## Small, spatially batched neighborhoods with silhouettes specific to the course.

static func block(tool: SurfaceTool, at: Vector3, size: Vector3, color: Color) -> void:
	ExpansionSetPieces.box(tool,at,size,color)

static func fabric_triangle(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	CourseDecor.colored_triangle(tool,a,b,c,color)
	CourseDecor.colored_triangle(tool,c,b,a,color)

static func fabric_quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, color: Color) -> void:
	fabric_triangle(tool,a,b,c,color)
	fabric_triangle(tool,a,c,d,color)

static func festival_details(tool: SurfaceTool, color: Color, round_tent: bool) -> void:
	# All details stay inside the existing tent footprint. Lights use the opaque
	# compound emission mask; there are no lights, collisions or frame callbacks.
	var cream := Color("FFE3B1")
	var wire := Color("534E69")
	var glow := Color("FFE9A8")
	glow.a = .5
	var z := 7.0 if round_tent else 12.5
	for i in range(8):
		var x := -7.0+i*2
		var y := 6.5-1.3*(1.0-pow(x/8,2))
		var next_x := x+2
		var next_y := 6.5-1.3*(1.0-pow(next_x/8,2))
		ExpansionSetPieces.beam(tool,Vector3(x,y,z),Vector3(next_x,next_y,z),.055,wire)
		block(tool,Vector3(x,y-.25,z),Vector3(.32,.45,.32),glow)
		if i%2==0:
			var a := Vector3(x+.3,y-.1,z)
			var b := Vector3(x+1.6,next_y-.1,z)
			var c := Vector3(x+.95,minf(y,next_y)-1.2,z)
			CourseDecor.colored_triangle(tool,a,b,c,color if i%4 else cream)
			CourseDecor.colored_triangle(tool,c,b,a,color if i%4 else cream)
	# Simple people at the counter make the scale and purpose readable at speed.
	for i in range(3):
		var at := Vector3(-5+i*4.2,0,4 if round_tent else 11)
		var shirt: Color = [Color("56D1C1"),Color("F5BD58"),Color("ED7997")][i]
		var skin: Color = [Color("C98A62"),Color("86563E"),Color("EAB98A")][i]
		for side: float in [-1,1]: block(tool,at+Vector3(side*.22,.55,0),Vector3(.3,1.1,.36),wire)
		block(tool,at+Vector3(0,1.45,0),Vector3(.85,.8,.52),shirt)
		block(tool,at+Vector3(0,2.1,0),Vector3(.5,.5,.5),skin)
		ExpansionSetPieces.beam(tool,at+Vector3(-.55,1.65,0),at+Vector3(.7,1.65,-.25),.23,shirt)

static func roof(tool: SurfaceTool, color: Color, round_tent: bool) -> void:
	var cream := Color("FFE3B1")
	if round_tent:
		for i in range(16):
			var a := TAU*i/16
			var b := TAU*(i+1)/16
			var first := Vector3(cos(a)*12,7,sin(a)*12)
			var last := Vector3(cos(b)*12,7,sin(b)*12)
			fabric_triangle(tool,first,Vector3(0,16,0),last,color if i%2 else cream)
			ExpansionSetPieces.beam(tool,first,first-Vector3.UP*7,.28,cream)
			fabric_quad(tool,first,last,last-Vector3.UP*1.2,first-Vector3.UP*1.2,color if i%2 else cream)
		block(tool,Vector3(0,6,0),Vector3(.6,12,.6),cream)
	else:
		for strip in range(8):
			var z := -14.0+strip*3.5
			var ink := color if strip%2 else cream
			for side: float in [-1.0,1.0]:
				fabric_quad(tool,Vector3(side*12,7,z),Vector3(0,15,z),Vector3(0,15,z+3.5),Vector3(side*12,7,z+3.5),ink)
				fabric_quad(tool,Vector3(side*12,7,z),Vector3(side*12,7,z+3.5),Vector3(side*12,5.5,z+3.5),Vector3(side*12,5.5,z),ink)
		for z: float in [-14.0,14.0]:
			fabric_triangle(tool,Vector3(-12,7,z),Vector3(0,15,z),Vector3(12,7,z),color)
			for x: float in [-11.0,0.0,11.0]: block(tool,Vector3(x,3.5,z),Vector3(.35,7,.35),cream)
		# Open front, visible counter and a contrasting rear curtain.
		block(tool,Vector3(0,2,-12),Vector3(18,4,2),color.darkened(.25))
		block(tool,Vector3(0,2.5,9),Vector3(19,1,2),cream)
	block(tool,Vector3(0,16.5,0),Vector3(.3,4,.3),cream)
	fabric_triangle(tool,Vector3(.2,18.5,0),Vector3(.2,16.7,0),Vector3(4,17.6,0),color)
	festival_details(tool,color,round_tent)

static func dome(tool: SurfaceTool, at: Vector3, radius: float, color: Color, segments: int = 16, rings: int = 5) -> void:
	for ring in range(rings):
		var a := PI*.5*ring/rings
		var b := PI*.5*(ring+1)/rings
		for segment in range(segments):
			var u := TAU*segment/segments
			var v := TAU*(segment+1)/segments
			var first := at+Vector3(cos(u)*sin(a),cos(a)*1.15,sin(u)*sin(a))*radius
			var next := at+Vector3(cos(v)*sin(a),cos(a)*1.15,sin(v)*sin(a))*radius
			var last := at+Vector3(cos(v)*sin(b),cos(b)*1.15,sin(v)*sin(b))*radius
			var end := at+Vector3(cos(u)*sin(b),cos(b)*1.15,sin(u)*sin(b))*radius
			if ring==0: CourseDecor.colored_triangle(tool,first,last,end,color)
			else: CourseDecor.colored_quad(tool,first,next,last,end,color)

static func arch_window(tool: SurfaceTool, at: Vector3, width: float, height: float) -> void:
	var dark := Color("354B52")
	CourseDecor.colored_quad(tool,at+Vector3(-width*.5,0,0),at+Vector3(-width*.5,height*.60,0),at+Vector3(width*.5,height*.60,0),at+Vector3(width*.5,0,0),dark)
	var center := at+Vector3(0,height*.60,0)
	for i in range(8):
		var a := PI*i/8
		var b := PI*(i+1)/8
		CourseDecor.colored_triangle(tool,center,center+Vector3(cos(a)*width*.5,sin(a)*height*.4,0),center+Vector3(cos(b)*width*.5,sin(b)*height*.4,0),dark)

static func citadel(tool: SurfaceTool, seed: float, color: Color, detailed: bool = true) -> void:
	var height := 9.0+seed*10
	block(tool,Vector3(0,height*.5,0),Vector3(23,height,27),color)
	block(tool,Vector3(0,height,0),Vector3(24,1,28),color.lightened(.13))
	for side: float in ([-1.0,1.0] if detailed else []):
		for x in range(-10,11,5):
			block(tool,Vector3(x,height+1.7,side*13),Vector3(2.5,2.5,2.5),color.lightened(.08))
		for z in range(-8,9,5):
			block(tool,Vector3(side*11,height+1.7,z),Vector3(2.5,2.5,2.5),color.lightened(.08))
		for x: float in [-7.0,0.0,7.0]:
			arch_window(tool,Vector3(x,2,side*13.56),2.5,5)
	var teal := Color("398E92").lerp(Color("CEAC66"),seed)
	dome(tool,Vector3(0,height+.6,0),5+seed*2,teal,16 if detailed else 8,5 if detailed else 3)
	for side: float in [-1.0,1.0]:
		block(tool,Vector3(side*8,height+1,8),Vector3(4,4,4),color.lightened(.1))
		dome(tool,Vector3(side*8,height+3,8),2.6,teal,8,3)

static func blocks(world: TrackWorld, parent: Node3D, poses: Array[Transform3D], key: String) -> void:
	build_lod(world,parent,poses,key,0)
	if world.art.district=="citadel": build_lod(world,parent,poses,key,1)

static func build_lod(world: TrackWorld, parent: Node3D, poses: Array[Transform3D], key: String, lod: int) -> void:
	var district: String = world.art.district
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	var archetypes: Array[String] = []
	for pose: Transform3D in poses:
		var local := SurfaceTool.new()
		local.begin(Mesh.PRIMITIVE_TRIANGLES)
		var seed := CourseLandscape.noise_at(pose.origin.x,pose.origin.z,71)
		var kind := "domed_citadel"
		if district=="festival":
			var colors := [Color("D65571"),Color("378EA8"),Color("8568B4"),Color("E99141")]
			var round_tent := seed>.5
			kind = "round_pavilion" if round_tent else "striped_stall"
			roof(local,colors[int(seed*colors.size())%colors.size()],round_tent)
		else: citadel(local,seed,Color("D5A879").lerp(Color("EACFAB"),seed),lod==0)
		if kind not in archetypes: archetypes.append(kind)
		# Deep, individually grounded plinths cover uneven ground at every corner.
		var bottom := pose.origin.y-2
		for x: float in [-12.0,12.0]:
			for z: float in [-14.0,14.0]:
				bottom = minf(bottom,CourseArt.height_from_grid(world.terrain_grid,pose*Vector3(x,0,z),pose.origin.y)-2)
		var depth := pose.origin.y-bottom
		block(local,Vector3(0,-depth*.5,0),Vector3(24,depth,28),Color("AF886B") if district=="citadel" else Color("685F64"))
		var arrays := local.commit_to_arrays()
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		for i in range(vertices.size()):
			tool.set_normal(pose.basis*normals[i])
			tool.set_color(colors[i])
			tool.add_vertex(pose*vertices[i])
	var node := MeshInstance3D.new()
	node.name = "ThemedDistrict_"+district+"_"+key.replace(":","_")+"_LOD"+str(lod)
	node.mesh = tool.commit()
	var material_key := "district_"+district
	if not world.materials.has(material_key):
		var surface := StandardMaterial3D.new()
		surface.vertex_color_use_as_albedo = true
		surface.roughness = .9
		surface.cull_mode = BaseMaterial3D.CULL_DISABLED
		world.materials[material_key] = surface
	node.material_override = world.materials[material_key]
	node.set_meta("archetypes",archetypes)
	node.set_meta("building_count",poses.size())
	node.set_meta("detail_level",lod)
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_to_group("scenery_distance")
	node.visibility_range_begin = 210 if lod==1 else 0
	node.visibility_range_end = 210 if district=="citadel" and lod==0 else 700
	node.set_meta("lod_limit",node.visibility_range_end)
	parent.add_child(node)

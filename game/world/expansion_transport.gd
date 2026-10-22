class_name ExpansionTransport
extends RefCounted
## GPU-only course transport, with complete swept bounds and level cabin floors.

static func cable_position(distance: float, half: float, radius: float) -> Vector2:
	var at := fposmod(distance,4*half+TAU*radius)
	if at<2*half: return Vector2(-half+at,-radius)
	at -= 2*half
	if at<PI*radius:
		var angle := -PI*.5+at/radius
		return Vector2(half+cos(angle)*radius,sin(angle)*radius)
	at -= PI*radius
	if at<2*half: return Vector2(half-at,radius)
	at -= 2*half
	var angle := PI*.5+at/radius
	return Vector2(-half+cos(angle)*radius,sin(angle)*radius)

static func chairlift(solid: SurfaceTool, parent: Node3D, half: float, accent: Color) -> void:
	var radius := 6.0
	var length := 4*half+TAU*radius
	var metal := Color("7B908F")
	ExpansionSetPieces.supports(solid,half,40,metal,0,3)
	for side: float in [-1.0,1.0]:
		ExpansionSetPieces.box(solid,Vector3(side*half,40,0),Vector3(9,2,18),metal)
	for part in range(64):
		var first := cable_position(length*part/64,half,radius)
		var last := cable_position(length*(part+1)/64,half,radius)
		ExpansionSetPieces.beam(solid,Vector3(first.x,40,first.y),Vector3(last.x,40,last.y),.24,Color("4E646C"))
	for cabin in range(8):
		var phase := length*cabin/8
		var at := cable_position(phase,half,radius)
		var tool := ExpansionSetPieces.tool()
		ExpansionSetPieces.box(tool,Vector3(at.x,37,at.y),Vector3(.32,6,.32),metal)
		ExpansionSetPieces.box(tool,Vector3(at.x,32,at.y),Vector3(5,4,4),accent if cabin%2==0 else Color("D97055"))
		ExpansionSetPieces.box(tool,Vector3(at.x,33,at.y),Vector3(5.12,1.35,4.12),Color("A7D2D9"))
		ExpansionSetPieces.box(tool,Vector3(at.x,34.3,at.y),Vector3(5.7,.5,4.7),metal)
		var node := ExpansionSetPieces.finish(parent,"CableCabin_"+str(cabin),tool,.04,4,Vector3.ZERO,3.2)
		var material := node.material_override as ShaderMaterial
		material.set_shader_parameter("travel_extent",Vector2(half,radius))
		material.set_shader_parameter("travel_phase",phase)
		var swept := AABB(Vector3(-half-radius-4,29,-radius-3),Vector3((half+radius+4)*2,12,(radius+3)*2))
		node.custom_aabb = swept
		node.extra_cull_margin = 0
		node.set_meta("travel_bounds",swept)
		node.set_meta("cable_phase",phase)
		node.set_meta("travel_extent",Vector2(half,radius))

static func metro(solid: SurfaceTool, parent: Node3D, half: float) -> void:
	var metal := Color("526A76")
	for z: float in [-3.0,3.0]: ExpansionSetPieces.beam(solid,Vector3(-half-5,32,z),Vector3(half+5,32,z),.35,Color("C1CACC"))
	var train := ExpansionSetPieces.tool()
	for car in range(3):
		var x := (car-1)*14.0
		ExpansionSetPieces.box(train,Vector3(x,33,0),Vector3(12,1.5,6.5),metal)
		ExpansionSetPieces.box(train,Vector3(x,36,0),Vector3(13,5,7),Color("B7D3D4"))
		ExpansionSetPieces.box(train,Vector3(x,34.5,0),Vector3(13.15,1.2,7.15),Color("3B849C"))
		ExpansionSetPieces.box(train,Vector3(x,39,0),Vector3(12,1,6.5),metal)
		for window in range(4):
			for side: float in [-1.0,1.0]:
				ExpansionSetPieces.box(train,Vector3(x-4.5+window*3,37,side*3.56),Vector3(2.1,1.8,.18),Color("91D9DA"))
		for end: float in [-1.0,1.0]:
			ExpansionSetPieces.box(train,Vector3(x+end*4,32.5,0),Vector3(2,1,7.5),Color("314C5A"))
	for x: float in [-7.0,7.0]: ExpansionSetPieces.box(train,Vector3(x,33,0),Vector3(1.5,.7,1),metal)
	var amplitude := minf(18,half-24)
	var node := ExpansionSetPieces.finish(parent,"MetroShuttle",train,.08,5,Vector3.ZERO,.25)
	node.material_override.set_shader_parameter("travel_distance",amplitude)
	var swept := AABB(Vector3(-21-amplitude,31,-4),Vector3(42+amplitude*2,9,8))
	node.custom_aabb = swept
	node.extra_cull_margin = 0
	node.set_meta("travel_bounds",swept)
	node.set_meta("travel_distance",amplitude)

class_name ExpansionAmbientMotion
extends RefCounted
## Bounded GPU motion for regional landmarks; no per-frame scene callbacks.

static func sway(parent: Node3D, name: String, tool: SurfaceTool, pivot: Vector3, angle: float, phase: float, speed: float, glow: float = 0) -> MeshInstance3D:
	var node := ExpansionSetPieces.finish(parent,name,tool,glow,6,pivot,speed)
	var material := node.material_override as ShaderMaterial
	material.set_shader_parameter("sway_angle",angle)
	material.set_shader_parameter("sway_phase",phase)
	var first := true
	var swept := AABB()
	var vertices := node.mesh.get_faces()
	for step in range(65):
		var basis := Basis(Vector3.RIGHT,lerpf(-angle,angle,step/64.0))
		for vertex: Vector3 in vertices:
			var at := pivot+basis*(vertex-pivot)
			if first:
				swept = AABB(at,Vector3.ZERO)
				first = false
			else: swept = swept.expand(at)
	swept = swept.grow(.05)
	node.custom_aabb = swept
	node.extra_cull_margin = 0
	node.set_meta("travel_bounds",swept)
	node.set_meta("motion_kind","sway_x")
	node.set_meta("sway_pivot",pivot)
	node.set_meta("sway_angle",angle)
	node.set_meta("sway_phase",phase)
	return node

static func bell(parent: Node3D) -> void:
	var tool := ExpansionSetPieces.tool()
	ExpansionSetPieces.beam(tool,Vector3(0,35,0),Vector3(0,30,0),.7,Color("71808D"))
	ExpansionSetPieces.cylinder(tool,Vector3(0,29,0),6,3,7,Color("B9974F"))
	ExpansionSetPieces.cylinder(tool,Vector3(0,25,0),6.5,6.5,1.4,Color("DBB96D"))
	sway(parent,"TempleBellSwing",tool,Vector3(0,35,0),.13,0,1.1)

static func lanterns(parent: Node3D, half: float) -> void:
	for i in range(9):
		var x := lerpf(-half+3,half-3,i/8.0)
		var tool := ExpansionSetPieces.tool()
		ExpansionSetPieces.beam(tool,Vector3(x,35,0),Vector3(x,30,0),.15,Color("71808D"))
		ExpansionSetPieces.cylinder(tool,Vector3(x,29,0),1.4,1.4,2.7,Color("F3BC65") if i%2==0 else Color("E97877"),8)
		sway(parent,"LanternSwing_"+str(i),tool,Vector3(x,35,0),.08,i*.9,.9,.3)

static func conveyor(solid: SurfaceTool, parent: Node3D, half: float) -> void:
	var span := half-6
	var metal := Color("6D7D87")
	for side: float in [-1.0,1.0]:
		var x := side*(half-2)
		ExpansionSetPieces.box(solid,Vector3(x,37.5,0),Vector3(12,.8,12),Color("9F8059"))
		for z: float in [-5.5,5.5]: ExpansionSetPieces.box(solid,Vector3(x,34.6,z),Vector3(12,6.4,.7),metal)
	for i in range(8):
		var x := lerpf(-span,span,i/8.0)
		var tool := ExpansionSetPieces.tool()
		CourseDecor.stone(tool,Vector3(x,31.5,0),Vector3(2,3,2.2),Color("A66B43").lerp(Color("6E6F65"),i/8.0),i+13)
		var node := ExpansionSetPieces.finish(parent,"ConveyorOre_"+str(i),tool,0,7,Vector3.ZERO,2.5)
		node.material_override.set_shader_parameter("travel_distance",span)
		node.material_override.set_shader_parameter("travel_start",x)
		node.material_override.set_shader_parameter("travel_phase",x+span)
		var swept := AABB(Vector3(-span-2.3,31.4,-2.5),Vector3(2*span+4.6,3.3,5))
		node.custom_aabb = swept
		node.extra_cull_margin = 0
		node.set_meta("travel_bounds",swept)
		node.set_meta("motion_kind","belt_x")
		node.set_meta("belt_span",span)
		node.set_meta("belt_start",x)

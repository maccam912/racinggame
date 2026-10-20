class_name RoadsideLife
extends RefCounted
## Original small roadside scenes, merged into the existing decor mesh/material.

const KINDS := ["SurfHut","BeachUmbrellas","PackingCrates","HarborCargo"]
const COLORS := ["20BFC5","F16B50","F3CD48","79C697"]


static func box(tool: SurfaceTool, at: Vector3, size: Vector3, color: Color) -> void:
	CourseSetPieces.cuboid(tool,Transform3D(Basis.IDENTITY,at),size,color)


static func build(tool: SurfaceTool, kind: String, variant: int) -> void:
	if kind=="SurfHut": surf_hut(tool,variant)
	elif kind=="BeachUmbrellas": beach(tool,variant)
	elif kind=="PackingCrates": packing(tool,variant)
	elif kind=="HarborCargo": harbor(tool,variant)


static func surfboard(tool: SurfaceTool, at: Vector3, color: Color) -> void:
	var outline := [Vector2(0,3.2),Vector2(.3,2.8),Vector2(.4,1),Vector2(.28,.2),Vector2(0,0),Vector2(-.28,.2),Vector2(-.4,1),Vector2(-.3,2.8)]
	for index in range(outline.size()):
		var a: Vector2 = outline[index]
		var b: Vector2 = outline[(index+1)%outline.size()]
		var front_a := at+Vector3(a.x,a.y,.09)
		var front_b := at+Vector3(b.x,b.y,.09)
		var back_a := at+Vector3(a.x,a.y,-.09)
		var back_b := at+Vector3(b.x,b.y,-.09)
		CourseDecor.colored_triangle(tool,at+Vector3(0,1.5,.09),front_a,front_b,color)
		CourseDecor.colored_triangle(tool,at+Vector3(0,1.5,-.09),back_b,back_a,color.darkened(.15))
		CourseDecor.colored_quad(tool,front_a,back_a,back_b,front_b,Color("F5EBD3"))
	box(tool,at+Vector3(0,1.55,.10),Vector3(.12,2.0,.025),Color("F5EBD3"))


static func surf_hut(tool: SurfaceTool, variant: int) -> void:
	var paint := Color(COLORS[variant%COLORS.size()])
	var cream := Color("F5EBD3")
	var timber := Color("A8784C")
	# An embedded plinth carries the complete porch even on sloping verges.
	box(tool,Vector3(0,-.5,.25),Vector3(6.4,1.4,6),Color("887D69"))
	box(tool,Vector3(0,.3,.25),Vector3(6.6,.3,6.2),timber)
	box(tool,Vector3(0,2.5,-.7),Vector3(5.6,4.1,3.8),paint)
	for x: float in [-2.8,2.8]:
		box(tool,Vector3(x,2.5,2.9),Vector3(.2,4.4,.2),cream)
	box(tool,Vector3(0,4.65,2.9),Vector3(6,.24,.24),cream)
	box(tool,Vector3(-1.35,2.7,1.22),Vector3(1.8,1.65,.12),cream)
	box(tool,Vector3(-1.35,2.7,1.3),Vector3(1.5,1.35,.08),Color("234F67"))
	box(tool,Vector3(-1.35,2.7,1.36),Vector3(.09,1.4,.05),cream)
	box(tool,Vector3(1.15,1.85,1.22),Vector3(1.25,2.8,.13),Color("345666"))
	box(tool,Vector3(1.52,1.85,1.32),Vector3(.09,.12,.10),Color("F3CD48"))
	# Closed gables and broad roof planes read at driving distance.
	for z: float in [-3.0,3.5]:
		var a := Vector3(-3.5,4.9,z)
		var b := Vector3(0,6.2,z)
		var c := Vector3(3.5,4.9,z)
		if z>0: CourseDecor.colored_triangle(tool,a,b,c,cream)
		else: CourseDecor.colored_triangle(tool,c,b,a,cream)
	CourseDecor.colored_quad(tool,Vector3(-3.5,4.9,3.5),Vector3(-3.5,4.9,-3),Vector3(0,6.2,-3),Vector3(0,6.2,3.5),paint.darkened(.3))
	CourseDecor.colored_quad(tool,Vector3(0,6.2,3.5),Vector3(0,6.2,-3),Vector3(3.5,4.9,-3),Vector3(3.5,4.9,3.5),paint.darkened(.22))
	box(tool,Vector3(0,4.85,3.5),Vector3(7.1,.15,.18),cream)
	for x: float in [-1.9,-.9]:
		surfboard(tool,Vector3(x,.45,2.25),Color(COLORS[(variant+int(absf(x)*2))%COLORS.size()]))
	box(tool,Vector3(-1.4,.65,2.45),Vector3(2,.15,.35),timber)


static func umbrella(tool: SurfaceTool, at: Vector3, color: Color) -> void:
	box(tool,at+Vector3(0,1.45,0),Vector3(.13,2.9,.13),Color("F5EBD3"))
	box(tool,at+Vector3(0,-.25,0),Vector3(.8,.7,.8),Color("B7A17F"))
	for segment in range(12):
		var a := TAU*segment/12
		var b := TAU*(segment+1)/12
		var first := at+Vector3(cos(a)*2.05,2.45,sin(a)*2.05)
		var next := at+Vector3(cos(b)*2.05,2.45,sin(b)*2.05)
		var ink := color if segment%2==0 else Color("F5EBD3")
		CourseDecor.colored_triangle(tool,at+Vector3(0,3.1,0),first,next,ink)
		CourseDecor.colored_quad(tool,first,first-Vector3.UP*.25,next-Vector3.UP*.25,next,ink)


static func beach(tool: SurfaceTool, variant: int) -> void:
	for side: float in [-1.0,1.0]:
		var at := Vector3(side*2.6,0,side*.6)
		var paint := Color(COLORS[(variant+int(side+1))%COLORS.size()])
		umbrella(tool,at,paint)
		box(tool,at+Vector3(0,.6,.2),Vector3(1.0,.18,2.1),Color("F5EBD3"))
		CourseSetPieces.cuboid(tool,Transform3D(Basis(Vector3.RIGHT,-.45),at+Vector3(0,1.0,-.65)),Vector3(1.0,1.0,.16),paint)
		for z: float in [-.5,.8]:
			box(tool,at+Vector3(0,.2,z),Vector3(.9,.8,.14),Color("A8784C"))
	for x: float in [-.5,.5]: surfboard(tool,Vector3(x,0,-2.8),Color(COLORS[(variant+2)%COLORS.size()]))
	box(tool,Vector3(0,.5,-2.9),Vector3(1.8,.16,.35),Color("A8784C"))


static func orange(tool: SurfaceTool, at: Vector3, size: float) -> void:
	for side: float in [-1.0,1.0]:
		for corner in range(4):
			var a := TAU*corner/4
			var b := TAU*(corner+1)/4
			var first := at+Vector3(cos(a)*size,0,sin(a)*size)
			var next := at+Vector3(cos(b)*size,0,sin(b)*size)
			if side>0: CourseDecor.colored_triangle(tool,at+Vector3.UP*size,first,next,Color("F3A43B"))
			else: CourseDecor.colored_triangle(tool,at-Vector3.UP*size,next,first,Color("DF7936"))


static func packing(tool: SurfaceTool, variant: int) -> void:
	for x: float in [-2.4,-1.2,0.0,1.2,2.4]: box(tool,Vector3(x,.18,0),Vector3(.9,.35,3.8),Color("A8784C"))
	for index in range(4):
		var at := Vector3((index-1)*2.05,.4,0) if index<3 else Vector3(0,1.7,0)
		box(tool,at+Vector3(0,.65,0),Vector3(1.9,1.3,1.7),Color("A67542"))
		box(tool,at+Vector3(0,1.3,0),Vector3(1.65,.06,1.45),Color("6D503A"))
		for side: float in [-1.0,1.0]:
			for y: float in [.25,.75,1.15]:
				CourseDecor.colored_quad(tool,at+Vector3(-.95*side,y,side*.86),at+Vector3(-.95*side,y+.09,side*.86),at+Vector3(.95*side,y+.09,side*.86),at+Vector3(.95*side,y,side*.86),Color("DEB878"))
		CourseSetPieces.beam(tool,at+Vector3(-.85,.15,.89),at+Vector3(.85,1.25,.89),.1,Color("DEB878"))
		for fruit in range(5):
			if index==1: continue # The upper crate rests on this closed lower lid.
			orange(tool,at+Vector3((fruit%3-1)*.5,1.5,(fruit/3-.5)*.7),.24+.02*((variant+fruit)%2))


static func container_mesh(tool: SurfaceTool, at: Vector3, paint: Color) -> void:
	box(tool,at+Vector3(0,1.4,0),Vector3(6.2,2.7,2.7),paint)
	for side: float in [-1.0,1.0]:
		for rib in range(5): box(tool,at+Vector3((rib-2)*1.22,1.4,side*1.39),Vector3(.08,2.4,.08),paint.lightened(.18))
		box(tool,at+Vector3(3.13,1.4,side*.64),Vector3(.08,2.4,1.18),paint.darkened(.2))
		box(tool,at+Vector3(3.20,1.4,side*.64),Vector3(.08,2.2,.06),Color("D4D9CB"))
	for x: float in [-2.85,2.85]: box(tool,at+Vector3(x,.15,1.42),Vector3(.28,.25,.08),Color("F3CD48"))


static func harbor(tool: SurfaceTool, variant: int) -> void:
	for x: float in [-2.6,2.6]:
		for z: float in [-1.0,1.0]: box(tool,Vector3(x,-.25,z),Vector3(.6,.8,.6),Color("A3977E"))
	container_mesh(tool,Vector3.ZERO,Color(COLORS[variant%COLORS.size()]))
	container_mesh(tool,Vector3(-.35,2.7,.15),Color(COLORS[(variant+1)%COLORS.size()]))

class_name WaterworksDetail
extends RefCounted
## Original static machinery merged into each dam's existing material/mesh.

static func box(tool: SurfaceTool, at: Vector3, size: Vector3, color: Color, basis: Basis = Basis.IDENTITY) -> void:
	CourseSetPieces.cuboid(tool,Transform3D(basis,at),size,color)


static func add(tool: SurfaceTool, height: float, variant: int) -> void:
	var x := 18.0 if variant%2==0 else -18.0
	var floor_y := maxf(12,height-40)
	var paint: Color = [Color("64A5A1"),Color("DBA969"),Color("8BA5C7")][variant%3]
	var cream := Color("EEE0B4")
	var iron := Color("35555C")
	# The house projects in front of the existing pier, with a supported
	# platform and windows outside its concrete face. Its farthest roof
	# corner is 25.95 m from the centre, inside the reserved 26 m disk.
	box(tool,Vector3(x,floor_y-5,4.5),Vector3(11,2,13),iron)
	box(tool,Vector3(x,floor_y,4.5),Vector3(9,8,11),paint)
	box(tool,Vector3(x,floor_y+4.5,4.5),Vector3(11,1,13),cream)
	for pane in range(3):
		box(tool,Vector3(x+(pane-1)*2.55,floor_y+1,10.07),Vector3(2.1,3.5,.12),Color("244A62"))
		for side: float in [-1.0,1.0]:
			box(tool,Vector3(x+side*4.57,floor_y+1,5.5+(pane-1)*2.55),Vector3(.12,3.5,2.1),Color("244A62"))
	box(tool,Vector3(x,floor_y-1,10.2),Vector3(8,.25,.3),cream)
	box(tool,Vector3(x-3,floor_y-1,10.1),Vector3(1.8,5,.2),iron)
	box(tool,Vector3(x-2.6,floor_y-1,10.25),Vector3(.2,.3,.15),cream)
	var ladder_top := floor_y-4
	for side: float in [-1.0,1.0]:
		box(tool,Vector3(x+side*1.1,(ladder_top+2)*.5,11.2),Vector3(.25,ladder_top-2,.3),cream)
		pipe(tool,Vector3(x+side*3.8,0,7.7),2,floor_y-5,.6,iron)
		for y: float in [4.0,ladder_top*.5,ladder_top-2]:
			box(tool,Vector3(x+side*3.8,y,7.3),Vector3(1.7,.4,1.7),cream)
			box(tool,Vector3(x+side*1.1,y,9.05),Vector3(.3,.3,4.4),iron)
	var count := mini(64,maxi(8,int(ladder_top-2)))
	for rung in range(count):
		var y := lerpf(2,ladder_top,float(rung)/maxi(1,count-1))
		box(tool,Vector3(x,y,11.3),Vector3(2.3,.18,.35),iron)
	var wheel_at := Vector3(x+signf(x)*2.5,floor_y-9,11.8)
	box(tool,Vector3(wheel_at.x,wheel_at.y,9.35),Vector3(.5,.5,5),iron)
	wheel(tool,wheel_at,2.4)
	# A truss crane and its fixed hoist are deliberately static scenery.
	for z: float in [-4.0,4.0]:
		box(tool,Vector3(0,height+7,z),Vector3(42,1.1,1.1),cream)
		box(tool,Vector3(0,height+3,z),Vector3(38,.6,.6),iron)
		for side: float in [-1.0,1.0]:
			box(tool,Vector3(side*18,height+3,z),Vector3(.9,7,.9),iron)
		for bay in range(4):
			CourseSetPieces.beam(tool,Vector3(-18+bay*9,height+3,z),Vector3(-9+bay*9,height+7,z),.45,iron)
	var hoist_x := float(variant%3-1)*9
	box(tool,Vector3(hoist_x,height+5,6),Vector3(3.5,3,3),Color("C7714B"))
	box(tool,Vector3(hoist_x,height-5,6),Vector3(.18,17,.18),iron)
	box(tool,Vector3(hoist_x,height-13.8,6),Vector3(2.5,.65,1.3),cream)


static func pipe(tool: SurfaceTool, at: Vector3, low: float, high: float, radius: float, color: Color) -> void:
	for index in range(8):
		var a := TAU*index/8
		var b := TAU*(index+1)/8
		var first := at+Vector3(cos(a)*radius,low,sin(a)*radius)
		var last := at+Vector3(cos(b)*radius,low,sin(b)*radius)
		var up := Vector3.UP*(high-low)
		CourseDecor.colored_quad(tool,first,last,last+up,first+up,color)
		CourseDecor.colored_triangle(tool,at+Vector3.UP*high,first+up,last+up,color)
		CourseDecor.colored_triangle(tool,at+Vector3.UP*low,last,first,color)


static func wheel(tool: SurfaceTool, center: Vector3, radius: float) -> void:
	var rust := Color("C56B47")
	for index in range(12):
		var a := TAU*index/12
		var b := TAU*(index+1)/12
		var first := Vector3(cos(a),sin(a),0)
		var last := Vector3(cos(b),sin(b),0)
		var outer_a := center+first*radius
		var outer_b := center+last*radius
		var inner_a := center+first*(radius-.4)
		var inner_b := center+last*(radius-.4)
		var back := Vector3.FORWARD*.4
		CourseDecor.colored_quad(tool,outer_a,inner_a,inner_b,outer_b,rust)
		CourseDecor.colored_quad(tool,outer_b+back,inner_b+back,inner_a+back,outer_a+back,rust)
		CourseDecor.colored_quad(tool,outer_b,outer_b+back,outer_a+back,outer_a,rust)
		CourseDecor.colored_quad(tool,inner_a,inner_a+back,inner_b+back,inner_b,rust)
	for spoke in range(3):
		box(tool,center+Vector3.FORWARD*.2,Vector3(.35,radius*2,.4),rust,Basis(Vector3.BACK,PI*spoke/3))
	box(tool,center+Vector3.FORWARD*.15,Vector3(.8,.8,.7),Color("E8C68B"))

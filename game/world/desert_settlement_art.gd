class_name DesertSettlementArt
extends RefCounted
## Solid adobe houses, open market courts and ventilated towers for desert places.
const DARK := Color("4E6262")
const TRIM := Color("E5D0A1")
const WOOD := Color("816048")

static func box(t: SurfaceTool, at: Vector3, size: Vector3, color: Color) -> void:
	CourseCompoundArt.box(t,at,size,color)

static func arch(t: SurfaceTool, center: Vector3, half_width: float, height: float, color: Color) -> void:
	var spring := center+Vector3.UP*(height-half_width)
	CourseCompoundArt.window(t,center+Vector3.UP*(height-half_width)*.5,Vector3(half_width,0,0),Vector3(0,(height-half_width)*.5,0),center+Vector3.BACK,color)
	for i in range(8):
		var a := PI*i/8
		var b := PI*(i+1)/8
		ExpansionWatercraftArt.outward(t,spring,spring+Vector3(cos(a),sin(a),0)*half_width,spring+Vector3(cos(b),sin(b),0)*half_width,center+Vector3.BACK,color)

static func parapet(t: SurfaceTool, width: float, depth: float, y: float, color: Color, offset: Vector3 = Vector3.ZERO) -> void:
	for side: float in [-1,1]:
		box(t,offset+Vector3(side*(width*.5-.7),y,0),Vector3(1.4,2,depth),color)
		box(t,offset+Vector3(0,y,side*(depth*.5-.7)),Vector3(width,2,1.4),color)

static func emit(t: SurfaceTool, kind: String, variant: int) -> void:
	var wall: Color = [Color("C99A6A"),Color("D8BB85"),Color("B77E61"),Color("D1AD92")][posmod(variant,4)]
	var fabric: Color = [Color("4F9291"),Color("B7664E"),Color("8479A2"),Color("A69958")][posmod(variant,4)]
	match kind:
		"adobe_house":
			var height := 11.0+posmod(variant,3)*3
			box(t,Vector3(0,height*.5,0),Vector3(28,height,25),wall)
			box(t,Vector3(0,height+.2,0),Vector3(29,.7,26),TRIM)
			parapet(t,29,26,height+1.2,wall.lightened(.08))
			box(t,Vector3(6,height+3.5,5),Vector3(11,6,10),wall.lightened(.06))
			parapet(t,12,11,height+7,TRIM,Vector3(6,0,5))
			arch(t,Vector3(-5,0,-12.56),2.5,7,DARK)
			for x: float in [-10,3,10]:
				arch(t,Vector3(x,6,-12.57),1.5,3.5,DARK)
				box(t,Vector3(x,5.7,-13),Vector3(4,.45,1),TRIM)
			for side: float in [-1,1]:
				for z: float in [-6,5]: CourseCompoundArt.window(t,Vector3(side*14.06,7,z),Vector3(0,0,1.5),Vector3(0,2,0),Vector3(0,7,z),DARK)
			box(t,Vector3(-5,7.6,-15),Vector3(10,.5,6),fabric)
			for x: float in [-9, -1]: box(t,Vector3(x,3.7,-17),Vector3(.45,7.4,.45),WOOD)
			for x: float in [-10,-4,2,8]: box(t,Vector3(x,height-1,-13),Vector3(.5,.6,2),WOOD)
		"wind_tower":
			var height := 32.0+posmod(variant,3)*7
			box(t,Vector3(0,height*.5,0),Vector3(13,height,13),wall)
			box(t,Vector3(0,height+.5,0),Vector3(16,1,16),TRIM)
			for x: float in [-5,5]:
				for z: float in [-5,5]: box(t,Vector3(x,height+6,z),Vector3(2,11,2),wall)
			box(t,Vector3(0,height+6,0),Vector3(1,10,12),wall.darkened(.2))
			box(t,Vector3(0,height+6,0),Vector3(12,10,1),wall.darkened(.2))
			box(t,Vector3(0,height+12,0),Vector3(17,2,17),TRIM)
			parapet(t,17,17,height+14,wall)
			for y: float in [9,18,27]:
				if y>height-3: continue
				box(t,Vector3(0,y,0),Vector3(13.4,.8,13.4),wall.lightened(.13))
			arch(t,Vector3(0,0,-6.56),2,6,DARK)
		"market_court":
			# An open center and raised side arcades stay visible from the road.
			box(t,Vector3(0,.4,0),Vector3(58,.8,42),TRIM.darkened(.12))
			box(t,Vector3(0,7,17),Vector3(57,14,8),wall)
			for side: float in [-1,1]:
				box(t,Vector3(side*24,6,-1),Vector3(9,12,30),wall)
				box(t,Vector3(side*19,11,-2),Vector3(17,.8,35),fabric)
				for z: float in [-17,-5,10]: box(t,Vector3(side*11,5.5,z),Vector3(.6,11,.6),WOOD)
				for z: float in [-11,1,12]:
					box(t,Vector3(side*17,2,z),Vector3(7,3,5),WOOD)
					for x: float in [-2,0,2]: box(t,Vector3(side*17+x,3.8,z),Vector3(1.5,.6,3.5),fabric.lightened(.2))
			for x: float in [-18,-6,6,18]: arch(t,Vector3(x,1,-0.01+13),2.7,8,DARK)
			box(t,Vector3(0,15,17),Vector3(58,1.2,9),TRIM)
			box(t,Vector3(0,1.5,-10),Vector3(9,2,5),wall)
			box(t,Vector3(0,2.55,-10),Vector3(7,.15,3),Color("57928C"))
		"caravanserai":
			box(t,Vector3(0,.4,0),Vector3(76,.8,61),TRIM.darkened(.17))
			box(t,Vector3(0,9,23),Vector3(72,18,14),wall)
			for side: float in [-1,1]:
				box(t,Vector3(side*29,7,-3),Vector3(14,14,41),wall)
				box(t,Vector3(side*28,16,-23),Vector3(17,32,17),wall.lightened(.1))
				for x: float in [-5,0,5]: box(t,Vector3(side*28+x,33,-23),Vector3(2,3,17),TRIM)
				for y: float in [9,20]:
					arch(t,Vector3(side*28,y,-31.56),1.8,5,DARK)
					box(t,Vector3(side*28,y-.5,-31.8),Vector3(5,.7,.5),TRIM)
				for y: float in [7,17,27]: box(t,Vector3(side*28,y,-23),Vector3(17.4,.7,17.4),wall.lightened(.16))
				box(t,Vector3(side*18,11,-3),Vector3(10,1,36),fabric)
				for z: float in [-17,-5,7]: box(t,Vector3(side*14,5,z),Vector3(.8,10,.8),TRIM)
			box(t,Vector3(0,20,-24),Vector3(39,5,8),wall)
			for x: float in [-26,-13,0,13,26]: arch(t,Vector3(x,1,15.94),3.2,10,DARK)
			box(t,Vector3(0,1.2,3),Vector3(16,1.6,10),wall)
			box(t,Vector3(0,2.05,3),Vector3(13,.2,7),Color("57928C"))
		_:
			assert(false,"Unknown desert settlement module: "+kind)

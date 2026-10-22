class_name SpaceSettlementArt
extends RefCounted
## Bounded solid modules for a botanical station and a working freight base.
const WHITE := Color("DCE4DA")
const METAL := Color("536779")
const LEAF := Color("66A76F")
const GOLD := Color("E8B76A")

static func box(t: SurfaceTool, at: Vector3, size: Vector3, color: Color) -> void:
	CourseCompoundArt.box(t,at,size,color)

static func tree(t: SurfaceTool, at: Vector3, height: float, color: Color) -> void:
	box(t,at+Vector3.UP*height*.33,Vector3(.9,height*.66,.9),Color("94765A"))
	CourseCompoundArt.dome(t,at+Vector3.UP*height*.48,height*.30,height*.48,color)
	CourseCompoundArt.dome(t,at+Vector3.UP*height*.74,height*.20,height*.31,color.lightened(.13))

static func emit(t: SurfaceTool, kind: String, variant: int) -> void:
	match kind:
		"botanical_court":
			box(t,Vector3(0,.6,0),Vector3(46,1.2,38),METAL)
			box(t,Vector3(0,1.3,0),Vector3(43,.2,35),WHITE)
			# A clear cross-shaped walking court separates four planted beds.
			for x: float in [-13,13]:
				for z: float in [-10,10]:
					box(t,Vector3(x,2.1,z),Vector3(17,1.4,12),WHITE)
					box(t,Vector3(x,2.85,z),Vector3(15.5,.15,10.5),Color("5D7054"))
					tree(t,Vector3(x,2.9,z),23+posmod(int(x+z)+variant,4),LEAF if z>0 else Color("93B46E"))
					for offset: float in [-5,5]:
						box(t,Vector3(x+offset,3.3,z+3),Vector3(2.5,.8,2),Color("D18DAB") if x>0 else Color("E2C565"))
			for x: float in [-21,21]:
				for z: float in [-16,16]: box(t,Vector3(x,17,z),Vector3(.9,32,.9),WHITE)
			for z: float in [-16,16]:
				CourseSetPieces.beam(t,Vector3(-21,33,z),Vector3(0,40,z),.7,WHITE)
				CourseSetPieces.beam(t,Vector3(0,40,z),Vector3(21,33,z),.7,WHITE)
			CourseSetPieces.beam(t,Vector3(0,40,-16),Vector3(0,40,16),.7,GOLD)
			box(t,Vector3(0,3,0),Vector3(5,3,5),METAL)
			CourseCompoundArt.dome(t,Vector3(0,4.5,0),3,2,Color("70CFBD"))
		"freight_lander":
			box(t,Vector3(0,.5,0),Vector3(48,1,46),METAL)
			for side: float in [-1,1]:
				box(t,Vector3(side*22,1.1,0),Vector3(1,.2,40),GOLD)
				box(t,Vector3(0,1.1,side*21),Vector3(42,.2,1),GOLD)
				for z: float in [-9,9]:
					box(t,Vector3(side*11,1.7,z),Vector3(6,1.2,6),WHITE)
					CourseSetPieces.beam(t,Vector3(side*11,2,z),Vector3(side*5,7,z*.6),1.1,METAL)
				box(t,Vector3(side*8,8,1),Vector3(6,3,18),GOLD)
				box(t,Vector3(side*10,6,7),Vector3(4,4,5),METAL)
			box(t,Vector3(0,8,0),Vector3(13,8,23),WHITE)
			box(t,Vector3(0,13,-6),Vector3(10,5,10),WHITE)
			box(t,Vector3(0,13.4,-11.1),Vector3(8,2.7,.3),Color("365B70"))
			box(t,Vector3(0,7.5,11.6),Vector3(9,5,.4),METAL)
			for y: float in [6,8,10]: box(t,Vector3(0,y,11.9),Vector3(8,.3,.3),GOLD)
		"survey_rover":
			box(t,Vector3(0,3.5,0),Vector3(7,2,13),METAL)
			box(t,Vector3(0,5.5,-3),Vector3(6,4,7),WHITE)
			box(t,Vector3(0,6,-6.6),Vector3(4.8,2,.25),Color("365B70"))
			box(t,Vector3(0,5,4),Vector3(6,1,5),GOLD)
			for side: float in [-1,1]:
				for z: float in [-4.5,0,4.5]:
					box(t,Vector3(side*4,2,z),Vector3(2,4,3.4),METAL.darkened(.35))
					box(t,Vector3(side*5.05,2,z),Vector3(.2,2,1.7),WHITE)
			CourseSetPieces.beam(t,Vector3(2,6,4),Vector3(2,12,4),.25,WHITE)
			box(t,Vector3(2,12,4),Vector3(3,.7,1),GOLD)
		_:
			assert(false,"Unknown space settlement module: "+kind)

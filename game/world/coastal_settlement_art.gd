class_name CoastalSettlementArt
extends RefCounted
## Original pitched-roof coastal buildings, with readable verandas and open stilts.
const WOOD := Color("94704C")
const TRIM := Color("E7DAB4")
const DARK := Color("3F5961")

static func box(t: SurfaceTool, at: Vector3, size: Vector3, color: Color) -> void:
	CourseCompoundArt.box(t,at,size,color)

static func roof(t: SurfaceTool, floor_y: float, width: float, depth: float, rise: float, color: Color) -> void:
	var a := Vector3(-width*.5,floor_y,-depth*.5)
	var b := Vector3(width*.5,floor_y,-depth*.5)
	var c := Vector3(width*.5,floor_y,depth*.5)
	var d := Vector3(-width*.5,floor_y,depth*.5)
	var e := Vector3(0,floor_y+rise,-depth*.39)
	var f := Vector3(0,floor_y+rise,depth*.39)
	var inside := Vector3(0,floor_y+rise*.3,0)
	for triangle: Array in [[a,b,e],[b,c,f],[b,f,e],[c,d,f],[d,a,e],[d,e,f],[a,d,c],[a,c,b]]:
		ExpansionWatercraftArt.outward(t,triangle[0],triangle[1],triangle[2],inside,color)
	CourseSetPieces.beam(t,e,f,.5,TRIM)

static func rail(t: SurfaceTool, from: Vector3, to: Vector3) -> void:
	var count := maxi(1,ceili(from.distance_to(to)/4))
	for i in range(count+1):
		var at := from.lerp(to,i/float(count))
		box(t,at+Vector3.UP*1.1,Vector3(.4,2.2,.4),WOOD)
	CourseSetPieces.beam(t,from+Vector3.UP*2,to+Vector3.UP*2,.35,TRIM)

static func stairs(t: SurfaceTool, floor_y: float, start_z: float) -> void:
	for step in range(6):
		var height := floor_y*(6-step)/6.0
		box(t,Vector3(0,height*.5,start_z-step*.9),Vector3(4.5,height,1.05),WOOD)

static func emit(t: SurfaceTool, kind: String, variant: int) -> void:
	var wall: Color = [Color("D6A06A"),Color("77A8A4"),Color("D38C7D"),Color("A5AB73")][posmod(variant,4)]
	var tile: Color = [Color("C18654"),Color("987A53"),Color("BD7153"),Color("668C85")][posmod(variant,4)]
	match kind:
		"beach_bungalow","stilt_house":
			var floor_y := 6.0 if kind=="stilt_house" else 1.2
			var height := 9.0 if kind=="stilt_house" else 10.0
			var width := 21.0 if kind=="stilt_house" else 25.0
			var depth := 22.0
			if kind=="stilt_house":
				for x: float in [-9,9]:
					for z: float in [-9,0,9]: box(t,Vector3(x,2.6,z),Vector3(.9,7,.9),WOOD)
				for z: float in [-9,9]:
					CourseSetPieces.beam(t,Vector3(-9,0,z),Vector3(9,5.5,z),.6,WOOD)
					CourseSetPieces.beam(t,Vector3(9,0,z),Vector3(-9,5.5,z),.6,WOOD)
			box(t,Vector3(0,floor_y-.5,-2),Vector3(width+3,1,depth+9),WOOD)
			box(t,Vector3(0,floor_y+height*.5,1),Vector3(width,height,depth),wall)
			roof(t,floor_y+height,width+5,depth+7,6 if kind=="stilt_house" else 7,tile)
			# Veranda and shutters give a different silhouette to the city modules.
			for x: float in [-width*.5,width*.5]:
				box(t,Vector3(x,floor_y+3,-15),Vector3(.7,6,.7),TRIM)
			box(t,Vector3(0,floor_y+6,-13),Vector3(width+4,.6,8),tile)
			for x: float in [-6,6]:
				CourseCompoundArt.window(t,Vector3(x,floor_y+5,-10.06),Vector3(2,0,0),Vector3(0,2,0),Vector3(x,floor_y+5,0),DARK)
				for side: float in [-1,1]: box(t,Vector3(x+side*2.5,floor_y+5,-10.2),Vector3(.8,4.4,.3),TRIM)
			box(t,Vector3(0,floor_y+3,-10.2),Vector3(3.4,6,.3),DARK)
			rail(t,Vector3(-width*.5,floor_y,-16),Vector3(-3,floor_y,-16))
			rail(t,Vector3(3,floor_y,-16),Vector3(width*.5,floor_y,-16))
			stairs(t,floor_y,-17)
			if kind=="beach_bungalow":
				box(t,Vector3(width*.5+2,1,-5),Vector3(4,2,5),TRIM)
				CourseCompoundArt.dome(t,Vector3(width*.5+2,2,-5),3.2,3,Color("648E57"))
		"boat_shed":
			box(t,Vector3(0,.6,0),Vector3(31,1.2,38),WOOD)
			for x: float in [-13,13]:
				for z: float in [-16,0,16]: box(t,Vector3(x,7,z),Vector3(1,14,1),WOOD)
			box(t,Vector3(-13.5,7,0),Vector3(.8,13,34),wall)
			box(t,Vector3(0,7,17),Vector3(28,13,.8),wall)
			roof(t,14,32,40,7,tile)
			for z: float in [-16,0,16]:
				CourseSetPieces.beam(t,Vector3(-13,13,z),Vector3(0,20,z),.6,TRIM)
				CourseSetPieces.beam(t,Vector3(0,20,z),Vector3(13,13,z),.6,TRIM)
			ExpansionWatercraftArt.hull(t,20,5,Color("5C9EA9"),Vector3(-4,2,0),1.8,-.6,WOOD)
			for z: float in [-8,8]: box(t,Vector3(-4,1.4,z),Vector3(7,1.5,1.4),TRIM)
			for z: float in [-8,-3,2]: box(t,Vector3(8,2,z),Vector3(4,3,3),wall.lightened(.15))
		"fishing_pier":
			box(t,Vector3(0,3,0),Vector3(15,1,38),WOOD)
			for x: float in [-6,6]:
				for z: float in [-16,-5,6,17]: box(t,Vector3(x,1,z),Vector3(.9,7,.9),WOOD)
			rail(t,Vector3(-6,3.5,-16),Vector3(-6,3.5,17))
			rail(t,Vector3(6,3.5,-16),Vector3(6,3.5,17))
			for x: float in [-5,5]:
				for z: float in [5,16]: box(t,Vector3(x,7.5,z),Vector3(.7,8,.7),TRIM)
			var covered := ExpansionSetPieces.tool()
			roof(covered,11,15,17,4,tile)
			t.append_from(covered.commit(),0,Transform3D(Basis.IDENTITY,Vector3(0,0,10)))
			for x: float in [-4,4]: box(t,Vector3(x,4.7,12),Vector3(3,2,4),Color("B9A47B"))
			stairs(t,3.5,-19)
		_:
			assert(false,"Unknown coastal settlement module: "+kind)

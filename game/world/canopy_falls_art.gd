class_name CanopyFallsArt
extends RefCounted
## An asymmetric forest waterfall, two streams and a supported viewing balcony.
const ROCK := Color("657968")
const WOOD := Color("A58A61")
const LEAF := Color("6BA451")

static func crag(t: SurfaceTool, center: Vector3, width: float, depth: float, height: float, seed: int) -> Vector3:
	var rings: Array[PackedVector3Array] = []
	for level in range(3):
		var ring := PackedVector3Array()
		for side in range(9):
			var angle := TAU*side/9
			var radius := (1+.08*sin(side*2.8+seed))*(1.0 if level==0 else .96 if level==1 else .76)
			var crest := height*(.86+.10*sin(side*1.7+seed)+.04*cos(side*2.6))
			var y := -64.0 if level==0 else crest*.52 if level==1 else crest
			ring.append(center+Vector3(cos(angle)*width*radius,y,sin(angle)*depth*radius))
		rings.append(ring)
	var top := Vector3.ZERO
	for p: Vector3 in rings[2]: top += p/9
	for side in range(9):
		var next := (side+1)%9
		for level in range(2):
			var inside := center+Vector3.UP*(rings[level][side].y+rings[level+1][side].y)*.5
			var color := ROCK.lightened((side%3)*.045)
			ExpansionWatercraftArt.outward(t,rings[level][side],rings[level][next],rings[level+1][next],inside,color)
			ExpansionWatercraftArt.outward(t,rings[level][side],rings[level+1][next],rings[level+1][side],inside,color)
		ExpansionWatercraftArt.outward(t,rings[2][side],rings[2][next],top,center,LEAF.darkened(.15))
		ExpansionWatercraftArt.outward(t,rings[0][side],center+Vector3.DOWN*64,rings[0][next],center+Vector3.DOWN*63,ROCK)
	return top

static func fern(t: SurfaceTool, at: Vector3, spread: float, seed: float) -> void:
	ExpansionSetPieces.beam(t,at-Vector3.UP*2,at+Vector3.UP*6,.7,WOOD)
	for i in range(7):
		var angle := i*TAU/7+seed
		var direction := Vector3(cos(angle),0,sin(angle))
		var across := Vector3(-sin(angle),0,cos(angle))*1.6
		var a := at+Vector3.UP*5
		var b := at+direction*spread*.55+Vector3.UP*9
		var c := at+direction*spread+Vector3.UP*(4+sin(i+seed))
		for side: float in [-1,1]:
			ExpansionWatercraftArt.cloth(t,a,b+across*side,c,LEAF.lightened((i%3)*.08))

static func stream(t: SurfaceTool, path: Array[Vector3], width: float, color: Color) -> void:
	for strip in range(3):
		var left := lerpf(-width*.5,width*.5,strip/3.0)
		var right := lerpf(-width*.5,width*.5,(strip+1)/3.0)
		for row in range(path.size()-1):
			var a := path[row]+Vector3(left,0,.18*(strip%2))
			var b := path[row]+Vector3(right,0,.18*(strip%2))
			var c := path[row+1]+Vector3(right*1.15,0,.18*(strip%2))
			var d := path[row+1]+Vector3(left*1.15,0,.18*(strip%2))
			ExpansionWatercraftArt.outward(t,a,b,c,Vector3(0,20,-30),color.lightened(strip*.055))
			ExpansionWatercraftArt.outward(t,a,c,d,Vector3(0,20,-30),color.lightened(strip*.055))

static func build(solid: SurfaceTool, water: SurfaceTool) -> void:
	var crown := crag(solid,Vector3(-8,0,-8),36,29,68,2)
	var left := crag(solid,Vector3(-32,0,8),20,21,30,4)
	var right := crag(solid,Vector3(29,0,-6),16,24,48,7)
	fern(solid,crown,11,1.2)
	fern(solid,left,8,.5)
	fern(solid,right,9,2.4)
	stream(water,[Vector3(-10,52,9),Vector3(-8,37,22),Vector3(-4,22,27),Vector3(-6,2.6,33)],12,Color("7CC8CC"))
	stream(water,[Vector3(12,46,0),Vector3(13,31,22),Vector3(17,17,27),Vector3(16,2.6,32)],7,Color("94D3CF"))
	ExpansionSetPieces.cylinder(solid,Vector3(0,-8,31),28,27,20,ROCK,18)
	ExpansionSetPieces.cylinder(water,Vector3(0,2.3,31),25,25,.4,Color("68B6B5"),18)
	for x: float in [-21,-6,13,27]:
		CourseDecor.stone(solid,Vector3(x,-3,38),Vector3(6,7,7),ROCK,absi(int(x)))
	# A single cliffside lookout with handrails and a visible stair descent.
	ExpansionSetPieces.box(solid,Vector3(39,22,10),Vector3(14,1,16),WOOD)
	for x: float in [33,45]:
		for z: float in [3,17]: ExpansionSetPieces.beam(solid,Vector3(x,-8,z),Vector3(x,24,z),.8,WOOD.darkened(.2))
		ExpansionSetPieces.beam(solid,Vector3(x,24,3),Vector3(x,24,17),.4,WOOD)
	ExpansionSetPieces.beam(solid,Vector3(33,24,3),Vector3(45,24,3),.4,WOOD)
	for i in range(11):
		ExpansionSetPieces.box(solid,Vector3(39,21-i*2,19+i*1.2),Vector3(4,.7,1.4),WOOD)
	ExpansionSetPieces.beam(solid,Vector3(37,23,18),Vector3(37,1,32),.4,WOOD)
	ExpansionSetPieces.beam(solid,Vector3(41,23,18),Vector3(41,1,32),.4,WOOD)

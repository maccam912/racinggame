class_name ExpansionWatercraftArt
extends RefCounted
## Four original faceted coastal boats, local origin at the waterline.
static var meshes: Dictionary = {}
const CREAM := Color("EAE8D8")
const METAL := Color("637681")
const GLASS := Color("294E64")
const WOOD := Color("99734E")

static func box(tool: SurfaceTool, at: Vector3, size: Vector3, color: Color) -> void:
	CourseSetPieces.cuboid(tool,Transform3D(Basis.IDENTITY,at),size,color)

static func beam(tool: SurfaceTool, a: Vector3, b: Vector3, width: float, color: Color) -> void:
	CourseSetPieces.beam(tool,a,b,width,color)

static func outward(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, interior: Vector3, color: Color) -> void:
	var normal := -(b-a).cross(c-a).normalized()
	var points: Array[Vector3] = [a,b,c]
	if normal.dot((a+b+c)/3-interior)<0:
		normal = -normal
		points = [a,c,b]
	for p: Vector3 in points:
		tool.set_normal(normal)
		tool.set_color(color)
		tool.add_vertex(p)

static func hull(tool: SurfaceTool, length: float, width: float, color: Color, offset: Vector3 = Vector3.ZERO, top: float = 1.8, bottom: float = -.6, deck: Color = WOOD) -> void:
	var outline: Array[Vector2] = [Vector2(0,-length*.5),Vector2(width*.5,-length*.3),Vector2(width*.5,length*.3),Vector2(width*.38,length*.5),Vector2(-width*.38,length*.5),Vector2(-width*.5,length*.3),Vector2(-width*.5,-length*.3)]
	var inside := offset+Vector3.UP*((top+bottom)*.5)
	for i in range(outline.size()):
		var j := (i+1)%outline.size()
		var a := offset+Vector3(outline[i].x,top,outline[i].y)
		var b := offset+Vector3(outline[j].x,top,outline[j].y)
		var c := offset+Vector3(outline[j].x*.7,bottom,outline[j].y*.91)
		var d := offset+Vector3(outline[i].x*.7,bottom,outline[i].y*.91)
		outward(tool,a,b,c,inside,color)
		outward(tool,a,c,d,inside,color)
		outward(tool,offset+Vector3.UP*top,a,b,inside,deck.lightened(.15))
		outward(tool,offset+Vector3.UP*bottom,c,d,inside,color.darkened(.15))

static func cloth(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, color: Color) -> void:
	CourseDecor.colored_triangle(tool,a,b,c,color)
	CourseDecor.colored_triangle(tool,a,c,b,color)

static func mesh(kind: String, variant_index: int = 0) -> ArrayMesh:
	var key := kind+":"+str(variant_index)
	if meshes.has(key): return meshes[key]
	var t := ExpansionSetPieces.tool()
	match kind:
		"icebreaker":
			hull(t,56,14.5,Color("326C82"),Vector3.ZERO,2.4,-.6,Color("8197A2"))
			box(t,Vector3(0,4.2,7),Vector3(11.5,4.5,23),CREAM)
			box(t,Vector3(0,7.6,4),Vector3(9.3,3.2,11),CREAM)
			box(t,Vector3(0,8.0,4),Vector3(9.5,1.1,11.2),GLASS)
			box(t,Vector3(0,9.5,4),Vector3(11,.5,12.5),CREAM)
			box(t,Vector3(0,8,16),Vector3(3.4,5,4.6),Color("E99A4B"))
			box(t,Vector3(0,10.8,16),Vector3(3.8,.7,5),Color("324757"))
			beam(t,Vector3(0,9.7,4),Vector3(0,22,4),.38,METAL)
			beam(t,Vector3(-4,19,4),Vector3(4,19,4),.28,METAL)
			box(t,Vector3(2,21,4),Vector3(3,1.2,.18),Color("E99A4B"))
			box(t,Vector3(0,3,-18),Vector3(3.8,2.2,3.5),Color("E99A4B"))
			for side: float in [-1,1]:
				beam(t,Vector3(side*6.3,2.9,-13),Vector3(side*6.3,2.9,21),.18,CREAM)
				for z: float in [-10,-2,6,14,20]: beam(t,Vector3(side*6.3,1.9,z),Vector3(side*6.3,2.9,z),.14,CREAM)
		"river_barge":
			hull(t,40,13,Color("356E68"))
			var colors: Array[Color] = [Color("B36C49"),Color("C6A45D"),Color("637F98")]
			for row in range(3):
				for side: float in [-1,1]:
					var at := Vector3(side*3,3.2,-12+row*6)
					box(t,at,Vector3(4.7,2.7,4.6),colors[posmod(row+int(side)+variant_index,3)])
					box(t,at+Vector3.UP*1.4,Vector3(4.9,.25,4.8),WOOD)
			for x: float in [-5,5]:
				for z: float in [3,13]: beam(t,Vector3(x,2,z),Vector3(x,7,z),.25,WOOD)
			box(t,Vector3(0,7.1,8),Vector3(11,.35,12),Color("C5A770" if variant_index%2==0 else "7FA4A0"))
			box(t,Vector3(0,4.3,15),Vector3(7,4.3,6),WOOD)
			box(t,Vector3(0,7.0,15),Vector3(9,.4,8),Color("66816B"))
			box(t,Vector3(0,5.2,11.9),Vector3(5,1.2,.15),GLASS)
			beam(t,Vector3(0,7.2,15),Vector3(0,12,15),.28,METAL)
		"outrigger":
			hull(t,24,3.6,WOOD)
			for side: float in [-1,1]: hull(t,18,1.3,Color("4D8E95"),Vector3(side*7.5,0,1),.45,-.4)
			for z: float in [-5,5]: beam(t,Vector3(-8,.7,z),Vector3(8,.7,z),.25,WOOD.lightened(.12))
			beam(t,Vector3(0,1.8,0),Vector3(0,22,0),.3,WOOD)
			var a := Vector3(-3,4,3)
			var b := Vector3(0,21.5,0)
			var c := Vector3(6,4,-7)
			var middle := a.lerp(c,.43)
			cloth(t,a,b,middle,[Color("D99B75"),Color("6FA4AD"),Color("D0B765")][posmod(variant_index,3)])
			cloth(t,middle,b,c,CREAM)
			beam(t,a-Vector3.UP*.15,c-Vector3.UP*.15,.18,WOOD)
			beam(t,Vector3(0,21.5,0),Vector3(0,2,-10),.09,CREAM)
			box(t,Vector3(0,2.7,6),Vector3(1.8,1.2,2.5),Color("4D8E95"))
		"harbor_tug":
			hull(t,44,14,Color("344C60"),Vector3.ZERO,1.8,-.6,Color("73838A"))
			box(t,Vector3(0,5.1,-5),Vector3(9.5,6.5,12),Color("D3AC54"))
			box(t,Vector3(0,6.6,-5),Vector3(9.7,1.3,12.2),GLASS)
			box(t,Vector3(0,8.7,-5),Vector3(11,.5,13),CREAM)
			beam(t,Vector3(0,9,-5),Vector3(0,19,-5),.35,METAL)
			beam(t,Vector3(-3.8,16.5,-5),Vector3(3.8,16.5,-5),.25,METAL)
			box(t,Vector3(0,6.5,8),Vector3(3.5,7,4.5),Color("C47D50"))
			box(t,Vector3(0,10.3,8),Vector3(4,.7,5),Color("2B3944"))
			for side: float in [-1,1]:
				for z: float in [-12,-4,4,12]: box(t,Vector3(side*6.8,1.5,z),Vector3(1.3,1.6,3.2),Color("2B3944"))
				beam(t,Vector3(side*5,2,16),Vector3(side*2,9,11),.5,METAL)
			beam(t,Vector3(-2,9,11),Vector3(2,9,11),.5,METAL)
			box(t,Vector3(0,3.1,16),Vector3(4,2,3),Color("A88153"))
		_: assert(false,"Unknown watercraft: "+kind)
	meshes[key] = t.commit()
	return meshes[key]

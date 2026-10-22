class_name CourseCompoundArt
extends RefCounted
## Small, original building modules for deliberately placed settlements and yards.
static var cache: Dictionary = {}
const WALL := Color("DBD9C5")
const DARK := Color("3D5262")
const GLASS := Color("57B5C2")
const RUST := Color("B56E51")

static func box(t: SurfaceTool, at: Vector3, size: Vector3, color: Color, yaw: float = 0) -> void:
	CourseSetPieces.cuboid(t,Transform3D(Basis(Vector3.UP,yaw),at),size,color)

static func dome(t: SurfaceTool, at: Vector3, radius: float, height: float, color: Color) -> void:
	for ring in range(5):
		var a := PI*.5*ring/5
		var b := PI*.5*(ring+1)/5
		for side in range(12):
			var c := TAU*side/12
			var d := TAU*(side+1)/12
			var p := at+Vector3(cos(c)*cos(a)*radius,sin(a)*height,sin(c)*cos(a)*radius)
			var q := at+Vector3(cos(d)*cos(a)*radius,sin(a)*height,sin(d)*cos(a)*radius)
			var r := at+Vector3(cos(d)*cos(b)*radius,sin(b)*height,sin(d)*cos(b)*radius)
			var s := at+Vector3(cos(c)*cos(b)*radius,sin(b)*height,sin(c)*cos(b)*radius)
			ExpansionWatercraftArt.outward(t,p,q,r,at,color if ring!=1 else color.darkened(.16))
			if ring<4: ExpansionWatercraftArt.outward(t,p,r,s,at,color)

static func window(t: SurfaceTool, center: Vector3, right: Vector3, up: Vector3, interior: Vector3, color: Color) -> void:
	color.a = .5 # Opaque window emission mask; the surface never uses alpha blending.
	var a := center-right-up
	var b := center+right-up
	var c := center+right+up
	var d := center-right+up
	ExpansionWatercraftArt.outward(t,a,b,c,interior,color)
	ExpansionWatercraftArt.outward(t,a,c,d,interior,color)

static func windows(t: SurfaceTool, width: float, height: float, depth: float, color: Color) -> void:
	# Flat panes need two triangles each, not twelve-triangle boxes.
	for y in range(5,int(height)-2,6):
		for x in range(-int(width*.5)+3,int(width*.5)-1,6):
			for side: float in [-1,1]: window(t,Vector3(x,y,side*(depth*.5+.06)),Vector3(1.4,0,0),Vector3(0,.9,0),Vector3(0,y,0),color)
		for z in range(-int(depth*.5)+3,int(depth*.5)-1,6):
			for side: float in [-1,1]: window(t,Vector3(side*(width*.5+.06),y,z),Vector3(0,0,1.4),Vector3(0,.9,0),Vector3(0,y,0),color)

static func mesh(kind: String, variant: int = 0) -> ArrayMesh:
	var key := kind+str(variant)
	if cache.has(key): return cache[key]
	var t := ExpansionSetPieces.tool()
	var color: Color = [Color("D4976D"),Color("8DACA6"),Color("7B8CA6"),Color("B77F92")][posmod(variant,4)]
	match kind:
		"ice_wall","glacial_erratic":
			GlacierArt.emit(t,kind,variant)
		"botanical_court","freight_lander","survey_rover":
			SpaceSettlementArt.emit(t,kind,variant)
		"mesa_outcrop","terraced_field","basalt_crag","martian_butte","crater_outcrop":
			AuthoredLandformArt.emit(t,kind,variant)
		"festival_tent","festival_stall":
			ExpansionDistrictDetail.roof(t,color,kind=="festival_tent")
		"citadel":
			ExpansionDistrictDetail.citadel(t,variant/4.0,Color("D5A879").lerp(Color("EACFAB"),variant/4.0))
		"moon_rock":
			CourseDecor.stone(t,Vector3.ZERO,Vector3(17,13,12),Color("89949F"),3)
			CourseDecor.stone(t,Vector3(11,0,5),Vector3(7,6,8),Color("6F7D89"),5)
		"habitat":
			box(t,Vector3(0,2,0),Vector3(23,4,23),DARK)
			dome(t,Vector3(0,4,0),12,11,WALL)
			box(t,Vector3(0,4,-13),Vector3(8,8,8),WALL)
			box(t,Vector3(0,3.6,-17.1),Vector3(4.4,6,.2),GLASS)
			box(t,Vector3(0,8.2,-13),Vector3(8.2,.5,8.2),GLASS)
			for x: float in [-7,7]: box(t,Vector3(x,6,-9.5),Vector3(3.5,2,.4),GLASS)
		"conservatory":
			box(t,Vector3(0,1.5,0),Vector3(25,3,37),WALL)
			box(t,Vector3(0,7,0),Vector3(23,10,35),Color("477D70"))
			dome(t,Vector3(0,12,0),12,7,GLASS)
			for z: float in [-15,-7,1,9,17]:
				for side: float in [-1,1]: box(t,Vector3(side*12,7,z),Vector3(.7,11,.7),WALL)
				CourseSetPieces.beam(t,Vector3(-12,12,z),Vector3(0,19,z*.65),.6,WALL)
				CourseSetPieces.beam(t,Vector3(0,19,z*.65),Vector3(12,12,z),.6,WALL)
			box(t,Vector3(0,4,-18.6),Vector3(5,6,.3),DARK)
		"hangar","warehouse":
			var width := 32.0 if kind=="hangar" else 26.0
			box(t,Vector3(0,8,0),Vector3(width,16,38),WALL if kind=="hangar" else color)
			box(t,Vector3(0,16.5,0),Vector3(width+2,1.5,40),DARK)
			box(t,Vector3(0,5.6,-19.1),Vector3(width*.6,11,.2),DARK)
			for y: float in [2,4,6,8,10]: box(t,Vector3(0,y,-19.25),Vector3(width*.58,.2,.2),GLASS if kind=="hangar" else WALL)
			for x: float in [-10,10]: box(t,Vector3(x,13,-19.15),Vector3(4,2,.2),GLASS)
			box(t,Vector3(8,19,8),Vector3(6,5,8),DARK)
		"apartment":
			var height := 24.0+variant*6
			box(t,Vector3(0,height*.5,0),Vector3(52,height,28),color)
			windows(t,52,height,28,DARK.lightened(.15))
			box(t,Vector3(0,height+.8,0),Vector3(55,1.6,31),WALL)
			for x: float in [-18,0,18]:
				box(t,Vector3(x,4,-14.3),Vector3(7,8,.4),DARK)
				box(t,Vector3(x,8,-16),Vector3(9,.6,5),RUST)
			for y in range(11,int(height),6):
				box(t,Vector3(0,y,-15.6),Vector3(53,.45,3.6),WALL)
				box(t,Vector3(0,y+1,-17.3),Vector3(53,1.2,.3),GLASS.darkened(.3))
		"arcade":
			box(t,Vector3(0,7,0),Vector3(62,14,25),color)
			box(t,Vector3(0,14.7,0),Vector3(65,1.4,28),DARK)
			windows(t,62,14,25,DARK)
			for x: float in [-24,-12,0,12,24]:
				box(t,Vector3(x,3.5,-12.7),Vector3(9,6,.3),GLASS)
				box(t,Vector3(x,7.5,-15),Vector3(11,.8,6),Color("E0B553") if int(x)%24==0 else RUST)
				box(t,Vector3(x,10,-12.8),Vector3(8,2,.5),WALL)
		"parking":
			var height := 5.0*(3+variant%2)
			box(t,Vector3(0,height*.5,0),Vector3(48,height,40),DARK)
			for y in range(0,int(height)+1,5):
				box(t,Vector3(0,y+.6,0),Vector3(51,1.2,43),WALL)
			for x: float in [-22,-11,0,11,22]:
				for z: float in [-20.2,20.2]: box(t,Vector3(x,height*.5,z),Vector3(1.7,height,1.5),WALL)
			box(t,Vector3(20, height*.5,0),Vector3(7,height+2,43),color)
			box(t,Vector3(-14,4,-21),Vector3(12,6,.4),GLASS)
		"cinema":
			box(t,Vector3(0,10,0),Vector3(44,20,38),color.darkened(.22))
			box(t,Vector3(0,20.8,0),Vector3(47,1.6,41),DARK)
			box(t,Vector3(0,6,-20),Vector3(36,10,3),GLASS.darkened(.6))
			box(t,Vector3(0,12,-23),Vector3(40,3,10),Color("F0C966"))
			box(t,Vector3(0,14,-23),Vector3(41,.7,10.5),RUST)
			for x: float in [-13,-6.5,0,6.5,13]: box(t,Vector3(x,5,-21.6),Vector3(.7,10,.3),WALL)
			box(t,Vector3(0,26,0),Vector3(27,11,3),Color("C26CB1"))
			for x: float in [-9,-3,3,9]: box(t,Vector3(x,26,-1.7),Vector3(3.5,6,.3),WALL)
		"tower":
			var height := 36.0+variant*13
			box(t,Vector3(0,height*.5,0),Vector3(24,height,28),color)
			windows(t,24,height,28,Color("B9DAD4"))
			box(t,Vector3(0,height+1,0),Vector3(26,2,30),DARK)
			box(t,Vector3(-4,height+4,3),Vector3(9,6,11),WALL)
		"house","market":
			box(t,Vector3(0,7,0),Vector3(20,14,24),color)
			windows(t,20,15,24,DARK)
			box(t,Vector3(0,3,-12.1),Vector3(4,6,.2),DARK)
			for tier in range(2 if kind=="market" else 1): box(t,Vector3(0,14+tier*1.5,0),Vector3(25-tier*6,1.6,29-tier*6),RUST if kind=="house" else DARK)
			box(t,Vector3(0,7,-15),Vector3(24,.7,7),Color("E1B35E"))
			for side: float in [-1,1]: box(t,Vector3(side*10,3.5,-17),Vector3(.6,7,.6),DARK)
		"pavilion":
			for x: float in [-11,11]:
				for z: float in [-9,9]: box(t,Vector3(x,5,z),Vector3(.8,10,.8),WALL)
			box(t,Vector3(0,.6,0),Vector3(25,1.2,21),DARK)
			box(t,Vector3(0,10,0),Vector3(25,1,21),color)
			dome(t,Vector3(0,10,0),12,7,color.lightened(.2))
			box(t,Vector3(0,3,5),Vector3(18,4,6),WALL)
		"container_stack":
			for row in range(2):
				for stack in range(2+(variant%2)):
					var at := Vector3((row-.5)*7,1.6+stack*3.2,0)
					box(t,at,Vector3(6.4,3,16),[RUST,GLASS,Color("D3AD59")][(row+stack+variant)%3])
					for z in range(-7,8,2):
						for side: float in [-1,1]: box(t,at+Vector3(side*3.25,0,z),Vector3(.14,2.8,.18),DARK)
		"solar":
			for side: float in [-1,1]:
				box(t,Vector3(side*6,3,0),Vector3(.6,6,.6),WALL)
			var basis := Basis(Vector3.RIGHT,-.30)
			CourseSetPieces.cuboid(t,Transform3D(basis,Vector3(0,6,0)),Vector3(20,.5,12),DARK)
			for x: float in [-7.5,-2.5,2.5,7.5]:
				for z: float in [-3,3]: CourseSetPieces.cuboid(t,Transform3D(basis,Vector3(0,6,0)+basis*Vector3(x,.32,z)),Vector3(4.7,.1,5.6),Color("5575B8"))
		"tank":
			box(t,Vector3(0,5,0),Vector3(14,10,14),DARK)
			dome(t,Vector3(0,10,0),8,12,WALL)
			box(t,Vector3(0,12,-7.8),Vector3(5,8,.3),GLASS)
			CourseSetPieces.beam(t,Vector3(0,22,0),Vector3(0,29,0),.7,DARK)
		"antenna":
			box(t,Vector3(0,1.5,0),Vector3(12,3,12),DARK)
			CourseSetPieces.beam(t,Vector3(0,2,0),Vector3(0,32,0),.8,WALL)
			for y: float in [16,24,30]: CourseSetPieces.beam(t,Vector3(-8,y,0),Vector3(8,y,0),.4,GLASS)
			for side: float in [-1,1]: CourseSetPieces.beam(t,Vector3(side*5,2,0),Vector3(0,21,0),.3,WALL)
		_:
			assert(false,"Unknown compound module: "+kind)
	var result := t.commit()
	cache[key] = result
	return result

static func layout(kind: String) -> Array:
	# kind, local x/z, variant, yaw. Distinct footprints form a recognizable place.
	match kind:
		"landforms": return []
		"moon_base": return [["habitat",-27,-30,0,0],["habitat",28,-20,1,-.5],["hangar",18,35,0,PI],["tank",-32,30,0,0],["solar",-50,68,0,0],["solar",-24,68,0,0],["antenna",58,35,0,0]]
		"biosphere": return [["conservatory",-25,-20,0,0],["conservatory",25,24,1,PI*.5],["habitat",-30,36,0,PI],["tank",42,-29,0,0],["solar",8,-62,0,.4]]
		"lunar_survey": return [["habitat",-18,0,0,0],["antenna",25,15,0,0],["solar",12,-30,0,-.3]]
		"solar_farm": return [["solar",-28,-20,0,0],["solar",0,-20,0,0],["solar",28,-20,0,0],["solar",-14,12,0,0],["solar",14,12,0,0],["tank",46,25,0,0],["antenna",-45,32,0,0]]
		"reactor_yard": return [["tank",-24,-16,0,0],["tank",10,-14,0,0],["warehouse",-14,31,2,PI],["solar",35,36,0,0],["antenna",38,-26,0,0]]
		"city": return [["tower",-42,-40,3,0],["tower",3,-38,1,0],["tower",46,-28,2,.3],["house",-37,14,0,0],["tower",12,27,0,0],["market",56,27,1,PI]]
		"market": return [["market",-38,-25,0,0],["market",0,-31,1,.1],["market",41,-20,2,-.2],["pavilion",-27,29,3,0],["house",20,27,0,PI]]
		"citadel": return [["citadel",-33,-28,0,0],["citadel",26,-19,1,.2],["market",-29,28,0,0],["pavilion",20,33,1,0],["tower",65,19,0,0]]
		"festival": return [["festival_tent",-33,-21,0,0],["festival_stall",28,-16,1,.3],["festival_tent",0,37,3,0],["festival_stall",-44,45,2,0],["festival_stall",48,62,0,PI]]
		"resort": return [["house",-36,-20,1,0],["house",20,-24,0,.2],["pavilion",-10,26,1,0],["house",45,30,3,PI]]
		"river_village": return [["house",-33,-17,0,.25],["house",6,-30,1,-.15],["house",38,8,2,.4],["pavilion",-18,28,0,0]]
		"logistics": return [["container_stack",-31,-25,0,0],["container_stack",-11,-25,1,0],["container_stack",9,-25,2,0],["container_stack",-20,15,2,PI*.5],["warehouse",30,30,2,PI]]
		"harbor": return [["warehouse",-30,-22,1,0],["warehouse",26,-18,2,0],["container_stack",-26,29,0,PI*.5],["house",27,37,0,PI],["antenna",62,17,0,0]]
		"industry": return [["warehouse",-29,-18,2,0],["tank",20,-25,0,0],["tank",45,-25,0,0],["warehouse",26,28,0,PI],["container_stack",-27,35,1,0]]
		"quarry": return [["warehouse",-22,-18,0,0],["container_stack",27,-15,2,PI*.5],["tank",31,25,0,0],["house",-26,31,2,0]]
		"utility": return [["house",-17,-8,1,0],["tank",16,16,0,0],["antenna",24,-20,0,0]]
	assert(false,"Unknown compound: "+kind)
	return []

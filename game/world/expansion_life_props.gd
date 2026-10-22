class_name ExpansionLifeProps
extends RefCounted
## Original little course objects. Faceted meshes need no new texture atlases.
static var meshes: Dictionary = {}
const WOOD := Color("A47C55")
const METAL := Color("718796")
const CREAM := Color("E2D5AF")
const TEAL := Color("54A5AE")
const RED := Color("C96B5A")

static func box(t: SurfaceTool, at: Vector3, size: Vector3, color: Color) -> void: ExpansionSetPieces.box(t,at,size,color)
static func beam(t: SurfaceTool, a: Vector3, b: Vector3, width: float, color: Color) -> void: ExpansionSetPieces.beam(t,a,b,width,color)
static func cylinder(t: SurfaceTool, at: Vector3, radius: float, height: float, color: Color) -> void: ExpansionSetPieces.cylinder(t,at,radius,radius,height,color,8)
static func crate(t: SurfaceTool, at: Vector3, size: Vector3 = Vector3(1.3,1.2,1.1), color: Color = WOOD) -> void:
	box(t,at,size,color)
	for x: float in [-.4,.4]: box(t,at+Vector3(x*size.x,0,-size.z*.51),Vector3(.10,size.y,.10),CREAM)
	for y: float in [-.4,.4]: box(t,at+Vector3(0,y*size.y,-size.z*.52),Vector3(size.x,.10,.10),color.darkened(.25))
static func wheel(t: SurfaceTool, at: Vector3, radius: float, color: Color = METAL) -> void:
	ExpansionSetPieces.circle(t,at,radius,.12,color,2,8)
	for i in range(4):
		var angle := PI*i/4
		beam(t,at+Vector3(cos(angle)*radius,sin(angle)*radius,0),at-Vector3(cos(angle)*radius,sin(angle)*radius,0),.045,CREAM)
static func posts(t: SurfaceTool, height: float, width: float, depth: float, color: Color = WOOD) -> void:
	for x: float in [-width*.5,width*.5]:
		for z: float in [-depth*.5,depth*.5]: box(t,Vector3(x,height*.5-.2,z),Vector3(.18,height+.4,.18),color)
static func gable(t: SurfaceTool, height: float, width: float, depth: float, color: Color) -> void:
	for side: float in [-1.0,1.0]:
		var a := Vector3(side*width*.5,height,-depth*.5)
		var b := Vector3(0,height+width*.25,-depth*.5)
		var c := Vector3(0,height+width*.25,depth*.5)
		var d := Vector3(side*width*.5,height,depth*.5)
		if side<0: CourseDecor.colored_quad(t,a,b,c,d,color)
		else: CourseDecor.colored_quad(t,d,c,b,a,color)
static func mesh(kind: String) -> ArrayMesh:
	if meshes.has(kind): return meshes[kind]
	var t := ExpansionSetPieces.tool()
	match kind:
		"ski_rack":
			posts(t,1.8,3.6,1.4)
			for y: float in [.7,1.7]: box(t,Vector3(0,y,0),Vector3(4,.16,1.6),WOOD)
			for i in range(6):
				var x := -1.5+i*.6
				box(t,Vector3(x,1.45,.65),Vector3(.23,2.9,.13),RED if i%2 else TEAL)
				beam(t,Vector3(x+.15,0,-.6),Vector3(x+.4,2.8,-.6),.045,METAL)
		"weather_station":
			cylinder(t,Vector3(0,2.7,0),.13,5.8,METAL)
			box(t,Vector3(0,2,0),Vector3(1.2,1,.9),CREAM)
			for i in range(4): box(t,Vector3(0,1.7+i*.18,-.48),Vector3(1,.08,.12),METAL)
			beam(t,Vector3(-1.2,4.5,0),Vector3(1.2,4.5,0),.10,TEAL)
			for x: float in [-1.2,1.2]: cylinder(t,Vector3(x,4.6,0),.28,.35,CREAM)
			box(t,Vector3(.6,5.4,0),Vector3(1.2,.35,.10),RED)
		"rescue_sled":
			for x: float in [-.8,.8]:
				box(t,Vector3(x,.05,0),Vector3(.14,.18,3.8),METAL)
				beam(t,Vector3(x,.05,-1.9),Vector3(x,.5,-2.2),.14,METAL)
			box(t,Vector3(0,.55,0),Vector3(1.7,.5,3),RED)
			box(t,Vector3(0,.85,-.5),Vector3(1.5,.16,1.6),CREAM)
			beam(t,Vector3(-.8,.7,1.4),Vector3(-.8,1.5,1.8),.12,METAL)
			beam(t,Vector3(.8,.7,1.4),Vector3(.8,1.5,1.8),.12,METAL)
			box(t,Vector3(0,1.5,1.8),Vector3(1.7,.12,.12),METAL)
		"fuel_locker":
			box(t,Vector3(0,.1,0),Vector3(3.5,.5,2.5),METAL)
			for x: float in [-.9,.9]:
				box(t,Vector3(x,1.5,0),Vector3(1.5,2.5,1.8),CREAM)
				box(t,Vector3(x,1.5,-.93),Vector3(.06,2.2,.08),RED)
				box(t,Vector3(x+.45,1.5,-.96),Vector3(.12,.35,.1),METAL)
			cylinder(t,Vector3(2,1.1,0),.5,2,RED)
		"harbor_catch":
			posts(t,1.4,3.5,1.7,METAL)
			box(t,Vector3(0,1.3,0),Vector3(3.8,.2,2),WOOD)
			for x: float in [-1.2,0,1.2]:
				crate(t,Vector3(x,1.75,0),Vector3(.95,.7,1.4),TEAL)
				box(t,Vector3(x,2.15,0),Vector3(.6,.15,1),Color("C9D7CE"))
			cylinder(t,Vector3(2,.4,.7),.55,.8,CREAM)
		"fjord_buoy":
			box(t,Vector3(0,-.15,0),Vector3(2.6,.5,2.6),METAL)
			cylinder(t,Vector3(0,1.2,0),.7,2.2,RED)
			cylinder(t,Vector3(0,1.2,0),.72,.45,CREAM)
			beam(t,Vector3(0,2.2,0),Vector3(0,4.3,0),.12,METAL)
			cylinder(t,Vector3(0,4.1,0),.3,.5,TEAL)
			ExpansionSetPieces.circle(t,Vector3(1.5,1.3,0),.65,.17,CREAM,2,12)
		"trail_camp":
			posts(t,1.8,3.8,2.6)
			gable(t,1.8,4.4,3.2,Color("779C72"))
			box(t,Vector3(0,.35,0),Vector3(3.2,.55,1.8),WOOD)
			crate(t,Vector3(2.1,.5,.4),Vector3(.8,1,.8),RED)
			box(t,Vector3(-1,1,0),Vector3(1.1,.6,.8),CREAM)
		"river_gauge":
			box(t,Vector3(0,2.4,0),Vector3(.4,5.2,.4),CREAM)
			for i in range(10): box(t,Vector3(.02,.3+i*.45,-.24),Vector3(.55 if i%2==0 else .35,.08,.08),RED)
			box(t,Vector3(1.2,1.1,0),Vector3(1.5,2,1),TEAL)
			beam(t,Vector3(0,3.8,0),Vector3(2,3.8,0),.13,METAL)
			cylinder(t,Vector3(2,3.6,0),.25,.55,METAL)
		"surf_rack":
			posts(t,1.7,3.5,1.8)
			box(t,Vector3(0,1.4,0),Vector3(3.8,.2,1.9),WOOD)
			for i in range(4):
				var capsule := CapsuleMesh.new()
				capsule.radius = .35
				capsule.height = 3.3
				capsule.radial_segments = 8
				capsule.rings = 1
				ExpansionSetPieces.primitive(t,capsule,Vector3(-1.35+i*.9,1.65,-.6),[TEAL,RED,CREAM,Color("A882C2")][i])
		"fishing_rack":
			posts(t,2.8,3.4,1.2)
			box(t,Vector3(0,2.6,0),Vector3(3.8,.2,.2),WOOD)
			for i in range(7): beam(t,Vector3(-1.5+i*.5,.6,0),Vector3(-1.5+i*.5,2.6,0),.045,CREAM)
			for i in range(5): beam(t,Vector3(-1.5,.6+i*.45,0),Vector3(1.5,.6+i*.45,0),.045,CREAM)
			crate(t,Vector3(2,.6,0),Vector3(.9,1.2,1.2),TEAL)
			cylinder(t,Vector3(-2,.4,.5),.5,.8,CREAM)
		"coffee_crates":
			for i in range(5):
				var at := Vector3((i%3-1)*1.3,.55+(i/3)*1.2,0)
				crate(t,at,Vector3(1.2,1.1,1.5))
				box(t,at+Vector3(0,.60,0),Vector3(1,.15,1.3),Color("765345"))
			box(t,Vector3(0,-.05,0),Vector3(4.4,.25,2),METAL)
		"stone_idol":
			box(t,Vector3(0,.1,0),Vector3(3.1,.5,2.5),Color("78917B"))
			box(t,Vector3(0,1.6,0),Vector3(2.1,2.7,1.6),Color("8DA28A"))
			box(t,Vector3(0,3.4,0),Vector3(2.7,1.2,2),Color("A0AF8D"))
			for x: float in [-.65,.65]: box(t,Vector3(x,3.5,-1.03),Vector3(.4,.25,.12),Color("415D59"))
			box(t,Vector3(0,2.9,-1.08),Vector3(1.2,.22,.15),Color("415D59"))
		"cycle_rack":
			for x: float in [-1.2,0,1.2]: beam(t,Vector3(x,-.2,-1),Vector3(x,.7,1),.12,METAL)
			for z: float in [-.55,.55]:
				for x: float in [-1,1]: wheel(t,Vector3(x,.6,z),.6)
				beam(t,Vector3(-1,.6,z),Vector3(0,1.4,z),.09,RED)
				beam(t,Vector3(0,1.4,z),Vector3(.1,.65,z),.09,RED)
				beam(t,Vector3(.1,.65,z),Vector3(-1,.6,z),.09,RED)
				beam(t,Vector3(0,1.4,z),Vector3(.8,1.3,z),.09,RED)
				beam(t,Vector3(.8,1.3,z),Vector3(1,.6,z),.09,METAL)
				box(t,Vector3(0,1.5,z),Vector3(.5,.12,.3),Color("405762"))
		"bamboo_cart":
			box(t,Vector3(0,.9,0),Vector3(3.6,.3,1.7),WOOD)
			for x: float in [-1.2,1.2]:
				for z: float in [-.9,.9]: wheel(t,Vector3(x,.6,z),.55)
			for i in range(7):
				var at := Vector3(0,1.2+(i/4)*.3,(i%4-1.5)*.3)
				beam(t,at-Vector3.RIGHT*2.1,at+Vector3.RIGHT*2.1,.23,Color("8EAC6D"))
			beam(t,Vector3(1.6,1,-.8),Vector3(2.7,1.7,-.8),.15,WOOD)
		"market_cart", "snack_cart":
			box(t,Vector3(0,1.2,0),Vector3(3.2,1.5,1.8),RED if kind=="snack_cart" else TEAL)
			for x: float in [-1.2,1.2]:
				for z: float in [-1,1]: wheel(t,Vector3(x,.55,z),.5)
			posts(t,3.1,3.2,1.9,METAL)
			gable(t,3.1,3.8,2.5,CREAM if kind=="snack_cart" else RED)
			for x: float in [-1,0,1]: cylinder(t,Vector3(x,2.1,0),.3,.45,CREAM if kind=="snack_cart" else Color("BC9D59"))
		"tea_baskets":
			box(t,Vector3(0,.05,0),Vector3(4,.25,2.5),WOOD)
			for i in range(5):
				var at := Vector3((i%3-1)*1.2,.55+(i/3)*.9,(i%2)*.8-.4)
				cylinder(t,at,.52,1,Color("BCA16C"))
				cylinder(t,at+Vector3.UP*.55,.49,.15,Color("5A8B69"))
		"stone_lantern":
			box(t,Vector3(0,.1,0),Vector3(1.6,.5,1.6),METAL)
			cylinder(t,Vector3(0,1.1,0),.3,1.8,CREAM)
			box(t,Vector3(0,2.3,0),Vector3(1.25,1.2,1.25),Color("CABF9D"))
			for x: float in [-.65,.65]: box(t,Vector3(x,2.3,0),Vector3(.05,.7,.7),Color("F1C16B"))
			gable(t,2.9,2.1,2.1,METAL)
			cylinder(t,Vector3(0,3.6,0),.18,.5,CREAM)
		"wayside_shrine":
			box(t,Vector3(0,.1,0),Vector3(3.2,.5,2.3),METAL)
			posts(t,2.6,2.6,1.7,RED)
			box(t,Vector3(0,1.2,.5),Vector3(2.3,2,1),WOOD)
			gable(t,2.6,3.5,2.5,Color("514C63"))
			box(t,Vector3(0,.8,-.65),Vector3(1.8,.15,1),CREAM)
			cylinder(t,Vector3(0,1.1,-.65),.25,.5,TEAL)
		"timing_booth":
			box(t,Vector3(0,1.5,0),Vector3(2.6,3.4,2),CREAM)
			box(t,Vector3(0,2,-1.05),Vector3(2.3,.9,.12),TEAL)
			box(t,Vector3(0,3.3,0),Vector3(3.2,.3,2.5),RED)
			beam(t,Vector3(1.7,0,0),Vector3(1.7,4,0),.12,METAL)
			box(t,Vector3(1.7,3.5,0),Vector3(.9,.6,.1),Color("334A58"))
		"water_tank":
			posts(t,1.4,2.6,2.6,METAL)
			cylinder(t,Vector3(0,2.3,0),1.65,2,CREAM)
			cylinder(t,Vector3(0,2.3,0),1.68,.20,TEAL)
			cylinder(t,Vector3(0,3.5,0),.4,.4,METAL)
			beam(t,Vector3(1.3,1.5,0),Vector3(2.3,1.5,0),.16,TEAL)
			beam(t,Vector3(2.3,1.5,0),Vector3(2.3,.6,0),.16,TEAL)
		"shade_shelter":
			posts(t,2.8,4,2.8)
			gable(t,2.8,4.6,3.4,Color("BA9470"))
			for z: float in [-.9,.9]: box(t,Vector3(0,.65,z),Vector3(3.5,.3,.65),WOOD)
			cylinder(t,Vector3(0,.5,0),.55,1,TEAL)
		"core_samples":
			posts(t,1.3,3.5,2)
			box(t,Vector3(0,1.2,0),Vector3(3.8,.2,2.3),WOOD)
			for i in range(6):
				var x := -1.5+i*.6
				cylinder(t,Vector3(x,1.65,0),.22,.8,Color("B9866A") if i%2 else Color("D1B184"))
				box(t,Vector3(x,1.45,-.6),Vector3(.45,.1,.3),CREAM)
		"weather_probe", "survey_tripod":
			for i in range(3):
				var angle := TAU*i/3
				beam(t,Vector3(cos(angle)*1.4,-.3,sin(angle)*1.4),Vector3(0,2.3,0),.12,METAL)
			box(t,Vector3(0,2.7,0),Vector3(1.3,.9,1),TEAL)
			if kind=="survey_tripod":
				beam(t,Vector3(-1.1,2.7,0),Vector3(1.1,2.7,0),.4,CREAM)
				cylinder(t,Vector3(0,2.5,0),.3,.3,RED)
			else:
				beam(t,Vector3(0,2.5,0),Vector3(0,5,0),.10,METAL)
				beam(t,Vector3(-1.3,4.4,0),Vector3(1.3,4.4,0),.10,RED)
				for x: float in [-1.3,1.3]: cylinder(t,Vector3(x,4.5,0),.25,.35,CREAM)
		"steel_rack":
			posts(t,2.2,3.8,2,METAL)
			for y: float in [.5,1.4]:
				for z: float in [-.6,.6]:
					box(t,Vector3(0,y,z),Vector3(4.3,.12,.5),METAL)
					box(t,Vector3(0,y+.28,z),Vector3(4.3,.12,.5),METAL)
					box(t,Vector3(0,y+.14,z),Vector3(4.3,.3,.10),Color("9E8877"))
		"cargo_pallet":
			for z: float in [-.8,0,.8]: box(t,Vector3(0,.1,z),Vector3(3.8,.35,.5),WOOD)
			for i in range(5): crate(t,Vector3((i%3-1)*1.2,.8+(i/3)*1.2,0),Vector3(1.1,1.1,1.7),TEAL if i%2 else RED)
		"bus_shelter":
			posts(t,3.1,4.2,2.3,METAL)
			box(t,Vector3(0,3.1,0),Vector3(4.8,.25,2.9),TEAL)
			box(t,Vector3(0,1.6,1.05),Vector3(3.9,2.7,.12),Color("8FACB5"))
			box(t,Vector3(-2,1.6,0),Vector3(.12,2.7,2.2),Color("A4B9BA"))
			box(t,Vector3(0,.8,.5),Vector3(3.3,.2,.6),CREAM)
			for x: float in [-1.2,1.2]: box(t,Vector3(x,.3,.5),Vector3(.18,1,.4),METAL)
			box(t,Vector3(2.4,1.8,-.5),Vector3(.13,4.2,.13),METAL)
			box(t,Vector3(2.4,3.6,-.5),Vector3(.8,.8,.18),RED)
		"service_cabinet":
			box(t,Vector3(0,-.1,0),Vector3(3.3,.4,2),METAL)
			box(t,Vector3(0,1.4,0),Vector3(2.7,2.8,1.5),Color("A2B4AE"))
			for x: float in [-.7,.7]:
				box(t,Vector3(x,1.4,-.79),Vector3(1.1,2.5,.1),TEAL)
				for i in range(4): box(t,Vector3(x,.7+i*.25,-.86),Vector3(.8,.09,.08),METAL)
			box(t,Vector3(0,2.1,-.9),Vector3(.35,.4,.1),RED)
		"tire_stack":
			for x: float in [-.9,.9]:
				for i in range(3): ExpansionSetPieces.circle(t,Vector3(x,.2+i*.4,0),.63,.24,Color("36414D"),1,8)
			box(t,Vector3(0,-.1,0),Vector3(3.3,.35,1.9),WOOD)
		"cargo_pod":
			box(t,Vector3(0,.9,0),Vector3(3.2,2.1,2.2),CREAM)
			box(t,Vector3(0,1,-1.15),Vector3(2.3,1.5,.2),Color("63768F"))
			for x: float in [-1.45,1.45]: box(t,Vector3(x,.9,0),Vector3(.35,2.3,2.5),METAL)
			for x: float in [-.7,.7]: box(t,Vector3(x,1,-1.3),Vector3(.3,.4,.1),TEAL)
			box(t,Vector3(0,2.1,0),Vector3(2,.3,1.5),RED)
		"hydroponic_tray":
			posts(t,1,4,2.3,METAL)
			box(t,Vector3(0,.8,0),Vector3(4.3,.4,2.5),CREAM)
			box(t,Vector3(0,1.05,0),Vector3(3.9,.15,2.1),Color("46565F"))
			for i in range(8):
				var at := Vector3((i%4-1.5)*.9,1.25,(i/4-.5)*1.1)
				cylinder(t,at,.22,.4,Color("6E9D72"))
				for side: float in [-1,1]: beam(t,at,at+Vector3(side*.35,.3,.15),.18,Color("8EBB7C"))
			beam(t,Vector3(-2,1,-1.1),Vector3(-2,2.9,-1.1),.1,METAL)
			box(t,Vector3(0,2.9,-1.1),Vector3(4.3,.15,.5),TEAL)
		"survey_beacon":
			for i in range(3):
				var a := TAU*i/3
				beam(t,Vector3(cos(a)*1.3,-.3,sin(a)*1.3),Vector3(0,1.5,0),.18,METAL)
			cylinder(t,Vector3(0,2,0),.45,3,CREAM)
			for y: float in [2.1,2.8,3.5]: cylinder(t,Vector3(0,y,0),.65,.22,TEAL)
			box(t,Vector3(0,4,0),Vector3(1.5,.8,1.2),Color("A7BBE0"))
			box(t,Vector3(0,4,-.64),Vector3(.9,.3,.1),Color("A2E7D0"))
		"rover_battery":
			box(t,Vector3(0,.4,0),Vector3(3.8,1,2.2),METAL)
			for x: float in [-1.2,0,1.2]:
				box(t,Vector3(x,1.25,0),Vector3(.9,1.5,1.8),CREAM)
				box(t,Vector3(x,1.3,-.95),Vector3(.6,.6,.1),TEAL)
				box(t,Vector3(x,2.1,0),Vector3(.4,.3,.4),RED)
			box(t,Vector3(0,2.1,.5),Vector3(3.4,.13,.13),METAL)
		"coolant_station":
			box(t,Vector3(0,-.1,0),Vector3(4,.4,2.8),METAL)
			for x: float in [-1,1]:
				cylinder(t,Vector3(x,1.4,0),.65,2.8,TEAL)
				cylinder(t,Vector3(x,1.4,0),.68,.2,CREAM)
				box(t,Vector3(x,2.8,0),Vector3(1,.3,1),METAL)
				beam(t,Vector3(x,2.9,0),Vector3(x,3.4,0),.2,CREAM)
			beam(t,Vector3(-1,3.4,0),Vector3(1,3.4,0),.2,CREAM)
			box(t,Vector3(0,1.4,-1),Vector3(.8,.8,.4),RED)
		"antenna_dish":
			box(t,Vector3(0,-.1,0),Vector3(2.5,.4,2.5),METAL)
			beam(t,Vector3(0,0,0),Vector3(0,2.6,0),.3,CREAM)
			for i in range(12):
				var a := TAU*i/12
				var b := TAU*(i+1)/12
				CourseDecor.colored_triangle(t,Vector3(0,2.7,.6),Vector3(cos(a)*1.8,2.7+sin(a)*1.8,0),Vector3(cos(b)*1.8,2.7+sin(b)*1.8,0),Color("A9BBCC"))
			beam(t,Vector3(0,2.7,.6),Vector3(0,2.7,-1.1),.1,RED)
		_:
			assert(false,"Unimplemented roadside object: "+kind)
	meshes[kind] = t.commit()
	return meshes[kind]

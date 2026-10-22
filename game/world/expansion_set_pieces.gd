class_name ExpansionSetPieces
extends RefCounted
## Individually composed 3D course landmarks. Only the shared road has collision.

const SPECS := {
	"glacier_ridge":["glacial_gallery",.38,0], "aurora_harbor":["polar_crane",.58,-1],
	"alpine_meadow":["chairlift",.39,0], "frostbite_fjord":["frozen_falls",.59,-1],
	"tundra_pipeline":["pipeline",.38,0], "rainforest_ruins":["temple_portal",.38,0],
	"monsoon_delta":["sluice",.58,-1], "coral_causeway":["coral_hoops",.38,0],
	"mangrove_maze":["root_bridge",.59,0], "cloudforest_climb":["canopy_falls",.59,-1],
	"sakura_ring":["lantern_torii",.38,0], "bamboo_gorge":["suspension_walk",.59,0],
	"lantern_market":["market_canopy",.38,0], "terrace_touge":["tea_house",.59,-1],
	"temple_coast":["temple_bell",.38,0], "saltflat_velocity":["timing_gantry",.38,0],
	"dune_serpent":["fossil_ribs",.58,0], "oasis_citadel":["aqueduct",.38,0],
	"copper_mesa":["mine_conveyor",.59,0], "storm_chase":["storm_funnel",.59,-1],
	"steelworks_sprint":["blast_furnace",.38,-1], "container_corkscrew":["container_lift",.59,0],
	"neon_underpass":["metro_viaduct",.38,0], "windfarm_run":["wind_turbines",.59,-1],
	"festival_speedway":["festival_wheel",.38,-1], "lunar_freight":["rocket_pad",.59,-1],
	"orbital_gardens":["armillary",.38,0], "crystal_chasm":["crystal_arch",.59,0],
	"mars_badlands":["canyon_bridge",.38,0], "reactor_rift":["reactor_core",.59,-1]
}

static func plan(world: TrackWorld) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if not SPECS.has(world.track.id): return result
	var spec: Array = SPECS[world.track.id]
	var spanning := int(spec[2])==0
	var radius := 70.0 if not spanning else 9.0
	var intended := CourseArt.original_s(world.track,float(spec[1]))
	var best: Dictionary = {}
	var best_score := -INF
	var landmarks: Array[float] = []
	for landmark: Dictionary in world.art.landmarks: landmarks.append(CourseArt.original_s(world.track,float(landmark.u)))
	for shift: float in [0.0,80.0,-80.0,160.0,-160.0,240.0,-240.0,320.0,-320.0]:
		var s := fposmod(intended+shift,world.track.length)
		var near_landmark := false
		for anchor: float in landmarks:
			var distance := absf(s-anchor)
			if minf(distance,world.track.length-distance)<110: near_landmark = true
		if near_landmark: continue
		var edge := float(world.track.bake.samples[world.track.sample_index(s)][8])*.5
		var half := edge+28
		var directions: Array = [0.0] if spanning else [float(spec[2]),-float(spec[2])]
		for side: float in directions:
			var pose := world.ground_pose(s,0)
			var allowed := true
			var clearings: Array[Dictionary] = []
			if spanning:
				for pillar_side: float in [-1.0,1.0]:
					for z: float in [-32.0,0.0,32.0]:
						var at := pose*Vector3(pillar_side*half,0,z)
						if not world.clear_of_road(at,radius): allowed = false
					clearings.append({"center":pose*Vector3(pillar_side*(half+12),0,0),"radius":42.0})
			else:
				pose = world.scenery_pose(s,side*(edge+radius+30))
				pose.basis = pose.basis*Basis(Vector3.UP,-side*PI/2)
				if not world.clear_of_road(pose.origin,radius+5) or not world.decoration_allowed(pose.origin): allowed = false
				if world.art.water and pose.origin.y<float(CourseArt.terrain_info[world.track.id].sea_level)+2: allowed = false
				clearings.append({"center":pose.origin,"radius":radius+4})
			if not allowed: continue
			var approach := world.track.pose(s-(130 if spanning else 220))
			if not spanning:
				var facing := Vector3(approach.origin.x-pose.origin.x,0,approach.origin.z-pose.origin.z)
				pose.basis = Basis.looking_at(-facing.normalized(),Vector3.UP)
			var delta := Vector2(pose.origin.x-approach.origin.x,pose.origin.z-approach.origin.z).normalized()
			var forward := Vector2(-approach.basis.z.x,-approach.basis.z.z).normalized()
			var alignment := delta.dot(forward)
			var score := alignment*4-absf(shift)/800
			if score<=best_score: continue
			best_score = score
			best = {"kind":spec[0],"s":s,"pose":pose,"half":half,"spanning":spanning,"radius":radius,"clearings":clearings,"approach":approach.origin,"approach_alignment":alignment}
	if not best.is_empty():
		result.append(best)
		world.scenery_clearings.append_array(best.clearings)
	return result

static func blocks_sightline(sites: Array[Dictionary], at: Vector3) -> bool:
	for site: Dictionary in sites:
		var first := Vector2(site.approach.x,site.approach.z)
		var last := Vector2(site.pose.origin.x,site.pose.origin.z)
		var line := last-first
		var fraction := (Vector2(at.x,at.z)-first).dot(line)/line.length_squared()
		if fraction<.05 or fraction>1.08: continue
		var closest := first+line*clampf(fraction,0,1)
		# Include broad painted canopies in the view corridor, not just trunks.
		if Vector2(at.x,at.z).distance_to(closest)<24+28*clampf(fraction,0,1): return true
	return false

static func box(tool: SurfaceTool, at: Vector3, size: Vector3, color: Color, basis: Basis = Basis.IDENTITY) -> void:
	CourseSetPieces.cuboid(tool,Transform3D(basis,at),size,color)

static func beam(tool: SurfaceTool, a: Vector3, b: Vector3, width: float, color: Color) -> void:
	CourseSetPieces.beam(tool,a,b,width,color)

static func primitive(tool: SurfaceTool, mesh: PrimitiveMesh, at: Vector3, color: Color) -> void:
	var arrays: Array = mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	for index: int in arrays[Mesh.ARRAY_INDEX]:
		tool.set_normal(normals[index])
		tool.set_color(color)
		tool.add_vertex(at+vertices[index])

static func cylinder(tool: SurfaceTool, at: Vector3, bottom: float, top: float, height: float, color: Color, segments: int = 12) -> void:
	var mesh := CylinderMesh.new()
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	primitive(tool,mesh,at,color)

static func arch(tool: SurfaceTool, half: float, base: float, rise: float, z: float, width: float, color: Color, steps: int = 12, center: Vector3 = Vector3.ZERO) -> void:
	for i in range(steps):
		var a := PI*i/steps
		var b := PI*(i+1)/steps
		beam(tool,center+Vector3(cos(a)*half,base+sin(a)*rise,z),center+Vector3(cos(b)*half,base+sin(b)*rise,z),width,color)

static func circle(tool: SurfaceTool, center: Vector3, radius: float, width: float, color: Color, axis: int = 2, steps: int = 24) -> void:
	for i in range(steps):
		var a := TAU*i/steps
		var b := TAU*(i+1)/steps
		var first := Vector3(cos(a)*radius,sin(a)*radius,0)
		var last := Vector3(cos(b)*radius,sin(b)*radius,0)
		if axis==1:
			first = Vector3(first.x,0,first.y)
			last = Vector3(last.x,0,last.y)
		beam(tool,center+first,center+last,width,color)

static func supports(tool: SurfaceTool, half: float, height: float, color: Color, z: float = 0, width: float = 3) -> void:
	for side: float in [-1.0,1.0]:
		box(tool,Vector3(side*half,height*.5-8,z),Vector3(width,height+16,width+1),color)
		box(tool,Vector3(side*half,-3,z),Vector3(width+5,6,width+6),color.lightened(.10))

static func finish(parent: Node3D, name: String, tool: SurfaceTool, glow: float = 0, motion: int = 0, pivot: Vector3 = Vector3.ZERO, speed: float = 1) -> MeshInstance3D:
	var arrays := tool.commit_to_arrays()
	if arrays[Mesh.ARRAY_VERTEX]==null: return null
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = mesh
	var material := ShaderMaterial.new()
	material.shader = load("res://assets/exported/shaders/set_piece_motion.gdshader")
	material.set_shader_parameter("glow",glow)
	material.set_shader_parameter("motion",motion)
	material.set_shader_parameter("pivot",pivot)
	material.set_shader_parameter("motion_speed",speed)
	material.set_shader_parameter("animation_enabled",1.0)
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.visibility_range_end = 700
	node.add_to_group("scenery_distance")
	if motion>0:
		node.add_to_group("scenery_motion")
		node.set_meta("motion_radius",80.0)
		node.extra_cull_margin = 80
	parent.add_child(node)
	return node

static func tool() -> SurfaceTool:
	var result := SurfaceTool.new()
	result.begin(Mesh.PRIMITIVE_TRIANGLES)
	return result

static func build(world: TrackWorld, sites: Array[Dictionary]) -> void:
	for site: Dictionary in sites:
		var root := Node3D.new()
		root.name = "HeroSetPiece_"+str(site.kind)
		root.transform = site.pose
		root.set_meta("set_piece_kind",site.kind)
		root.set_meta("route_s",site.s)
		root.set_meta("spanning",site.spanning)
		root.set_meta("radius",site.radius)
		world.add_child(root)
		var solid := tool()
		var light := tool()
		var motion := tool()
		var half: float = site.half
		var accent := Color.html(world.art.accent)
		var stone := Color.html(world.art.ground).lightened(.18)
		var metal := Color("71808D")
		var cream := Color("E9DDC0")
		var pivot := Vector3.ZERO
		var motion_mode := 0
		var motion_speed := .35
		match str(site.kind):
			"glacial_gallery":
				ice_gallery(solid,half)
			"polar_crane":
				polar_crane(solid,accent)
			"container_lift":
				var span := half if site.spanning else 24.0
				supports(solid,span,48,Color("B66C48"),-12,4)
				supports(solid,span,48,Color("B66C48"),12,4)
				for z: float in [-12.0,12.0]:
					box(solid,Vector3(0,48,z),Vector3(span*2+12,5,4),accent)
					for x in range(-20,21,8): beam(solid,Vector3(x,44,z),Vector3(x+6,50,z),1.0,cream)
					beam(solid,Vector3(0,47,z),Vector3(0,34,z),.35,metal)
				box(solid,Vector3(0,36,0),Vector3(18,7,18),Color("C95C42"))
				for x in range(-8,9,2): box(solid,Vector3(x,36,-9.2),Vector3(.35,6.8,.3),cream)
				box(solid,Vector3(span-4,42,-12),Vector3(7,6,7),Color("82C2D5"))
			"chairlift":
				ExpansionTransport.chairlift(solid,root,half,accent)
			"pipeline":
				supports(solid,half,32,metal,0,4)
				for y: float in [33.0,38.0]:
					beam(solid,Vector3(-half-14,y,0),Vector3(half+14,y,0),3.6,Color("D5B96B"))
					for x in range(-20,21,8): box(solid,Vector3(x,y,0),Vector3(.6,4,4),Color("657D83"))
				box(solid,Vector3(half,18,0),Vector3(6,5,7),accent)
			"temple_portal":
				supports(solid,half,30,stone,0,7)
				arch(solid,half,29,14,0,5,stone)
				for tier in range(4): box(solid,Vector3(0,44+tier*2,0),Vector3(half*2+12-tier*6,2.2,13-tier),stone.darkened(tier*.035))
				for side: float in [-1.0,1.0]:
					for step in range(4): box(solid,Vector3(side*(half+5+step*4),1+step*2,0),Vector3(6,2,18),stone)
					CourseDecor.stone(solid,Vector3(side*(half+5),-4,0),Vector3(8,28,8),Color("778365"),int(side)+4)
			"aqueduct":
				supports(solid,half,52,stone,0,5)
				for height: float in [29.0,48.0]: arch(solid,half,height,10,0,4,stone)
				box(solid,Vector3(0,60,0),Vector3(half*2+12,3,12),stone)
				box(light,Vector3(0,61.6,0),Vector3(half*2+8,.4,6),Color("6DBCC1"))
				for side: float in [-1.0,1.0]:
					arch(solid,15,14,15,0,3,stone,8,Vector3(side*(half+19),0,0))
					box(solid,Vector3(side*(half+34),12,0),Vector3(5,40,8),stone)
			"coral_hoops":
				for rib in range(3):
					var z := -24+rib*24.0
					supports(solid,half,28,Color("D08D94"),z,2.8)
					arch(solid,half,28,17,z,3.4,Color("F0B2A7") if rib%2==0 else Color("C9A6CF"))
					for side: float in [-1.0,1.0]:
						beam(solid,Vector3(side*half,18,z),Vector3(side*(half+7),26,z+4),2.5,Color("D68B9F"))
			"root_bridge":
				for z: float in [-17.0,17.0]:
					supports(solid,half,28,Color("80754C"),z,5)
					arch(solid,half,28,10,z,4.5,Color("847B51"))
					for side: float in [-1.0,1.0]:
						for root_index in range(4): beam(solid,Vector3(side*half,20,z),Vector3(side*(half+8+root_index*3),-8,z+root_index*4-6),2.4,Color("6E7049"))
				for x in range(-20,21,3): box(solid,Vector3(x,36,0),Vector3(2.2,.8,34),Color("A18F5E"))
			"market_canopy":
				market_canopy(solid,light,half)
			"lantern_torii", "temple_bell":
				supports(solid,half,34,Color("BA4D45"),0,3.5)
				for height: float in [29.0,35.0]:
					beam(solid,Vector3(-half-7,height,0),Vector3(half+7,height,0),2.7,Color("B74D45"))
					for side: float in [-1.0,1.0]: beam(solid,Vector3(side*(half+7),height,0),Vector3(side*(half+12),height+3,0),2.6,Color("6C394B"))
				if site.kind=="temple_bell": ExpansionAmbientMotion.bell(root)
				else: ExpansionAmbientMotion.lanterns(root,half)
			"suspension_walk", "mine_conveyor", "metro_viaduct", "canyon_bridge":
				transport_span(solid,half,str(site.kind),stone)
				if site.kind=="metro_viaduct":
					ExpansionTransport.metro(solid,root,half)
				elif site.kind=="mine_conveyor":
					ExpansionAmbientMotion.conveyor(solid,root,half)
			"timing_gantry":
				supports(solid,half,30,Color("F1EAD1"),0,3)
				box(solid,Vector3(0,31,0),Vector3(half*2+9,5,5),Color("2B506F"))
				for i in range(12):
					var x := lerpf(-half,half,i/11.0)
					box(solid,Vector3(x,32,-2.6),Vector3(3,2,.2),cream if i%2==0 else Color("283749"))
				for side: float in [-1.0,1.0]:
					for i in range(5): cylinder(light,Vector3(side*half,6+i*4,0),1.3,1.3,1.5,Color("E3B843") if i<3 else Color("66C6B9"),8)
				var label := Label3D.new()
				label.text = I18n.t("track."+world.track.id).to_upper()
				label.font = load("res://assets/fonts/heading.tres")
				label.font_size = 160
				label.pixel_size = .026
				label.position = Vector3(0,31,2.8)
				label.modulate = cream
				root.add_child(label)
			"fossil_ribs":
				for rib in range(6):
					var z := -30+rib*12.0
					supports(solid,half,27,cream,z,3.5)
					arch(solid,half,27,18-rib*.7,z,3.5,cream,10)
				beam(solid,Vector3(0,45,-34),Vector3(0,42,34),4,cream)
			"armillary", "crystal_arch":
				supports(solid,half,28,Color("6D91A7"),0,3)
				if site.kind=="armillary":
					for z: float in [-14.0,14.0]: arch(light,half,28,18,z,2.5,accent)
					circle(light,Vector3(0,46,0),13,1.6,Color("A4E7D0"),1)
					for side: float in [-1.0,1.0]:
						box(solid,Vector3(side*(half+7),18,0),Vector3(8,30,10),metal)
				else:
					for index in range(5):
						var a := PI*index/4
						CourseDecor.stone(light,Vector3(cos(a)*half,27+sin(a)*14,0),Vector3(10,13,10),Color("B09FE8").lerp(Color("98D5EB"),index/5.0),index+9)
					for side: float in [-1.0,1.0]:
						for i in range(4): CourseDecor.stone(light,Vector3(side*(half+5+i*4),-5,i*6-8),Vector3(6,28+i*5,6),accent.lerp(Color("DF9EE8"),i/4.0),i)
			"frozen_falls", "canopy_falls", "sluice":
				waterworks(solid,light,str(site.kind),stone,accent)
			"tea_house":
				tea_house(solid,stone,accent)
			"storm_funnel":
				storm(solid,motion)
				motion_mode = 2
				motion_speed = .5
			"blast_furnace":
				furnace(solid,light)
			"wind_turbines":
				turbines(solid,root)
			"festival_wheel":
				wheel(solid,light,motion,root)
				motion_mode = 1
				pivot = Vector3(0,36,0)
				motion_speed = .12
			"rocket_pad":
				rocket(solid,light)
			"reactor_core":
				reactor(solid,light,motion)
				motion_mode = 2
				pivot = Vector3(0,30,0)
				motion_speed = .28
		finish(root,"Architecture",solid)
		var accents := finish(root,"Accents",light,.85 if site.kind=="crystal_arch" else .35)
		if accents!=null and site.kind in ["sluice","canopy_falls","aqueduct"]:
			accents.material_override.set_shader_parameter("water_flow",true)
			if site.kind=="aqueduct": accents.material_override.set_shader_parameter("flow_axis",0)
			accents.add_to_group("scenery_motion")
		finish(root,"MovingSilhouette",motion,.12,motion_mode,pivot,motion_speed)
		conform_bases(world,root)

static func conform_bases(world: TrackWorld, parent: Node3D) -> void:
	var grounded := 0
	for node: MeshInstance3D in parent.find_children("*","MeshInstance3D",true,false):
		var arrays := node.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var changed := false
		for index in range(vertices.size()):
			var at := vertices[index]
			if at.y>.1: continue
			var world_at := parent.transform*at
			var terrain_y := CourseArt.height_from_grid(world.terrain_grid,world_at,world_at.y)
			var bottom := minf(at.y,terrain_y-parent.position.y-1.5)
			if bottom!=at.y:
				vertices[index].y = bottom
				changed = true
			grounded += 1
		if not changed: continue
		arrays[Mesh.ARRAY_VERTEX] = vertices
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
		node.mesh = mesh
	parent.set_meta("grounded_base_vertices",grounded)

static func waterworks(solid: SurfaceTool, water: SurfaceTool, kind: String, stone: Color, accent: Color) -> void:
	var frozen := kind=="frozen_falls"
	var rock := Color("B7D7E1") if frozen else Color("6B8173")
	CourseDecor.stone(solid,Vector3(0,-10,-12),Vector3(43,82,24),rock,4)
	for side: float in [-1.0,1.0]:
		box(solid,Vector3(side*21,27,0),Vector3(11,66,16),stone if kind=="sluice" else rock)
		box(solid,Vector3(side*21,60,0),Vector3(14,3,18),accent)
	box(solid,Vector3(0,62,-3),Vector3(53,5,18),stone)
	for band in range(9):
		var x := -13.5+band*3.0
		var color := Color("B4E9F0") if frozen else Color("77C3C6")
		box(water,Vector3(x,31,9),Vector3(2.7,60-(band%3)*2,.5),color.lightened((band%3)*.06))
	cylinder(water,Vector3(0,1,9),27,27,1,Color("7DBFC5"),24)
	if kind=="canopy_falls":
		for level in range(3):
			box(solid,Vector3(30,20+level*13,0),Vector3(15,1.5,18),Color("AE9470"))
			for z: float in [-7.0,7.0]: beam(solid,Vector3(30,level*13,z),Vector3(30,24+level*13,z),1.2,Color("967A55"))
	elif kind=="sluice":
		for x: float in [-11.0,11.0]:
			beam(solid,Vector3(x,10,10),Vector3(x,64,10),1.4,Color("A7794E"))
			circle(solid,Vector3(x,68,10),4,.7,Color("B66E49"),2,12)

static func tea_house(solid: SurfaceTool, stone: Color, accent: Color) -> void:
	for level in range(5):
		box(solid,Vector3(0,level*5-3,0),Vector3(80-level*9,5,64-level*7),Color("729366").darkened(level*.025))
	box(solid,Vector3(0,27,0),Vector3(24,18,22),stone)
	for level in range(3):
		box(solid,Vector3(0,38+level*4,0),Vector3(34-level*8,3,32-level*8),Color("5F4850"))
	for x: float in [-11.0,11.0]:
		for z: float in [-10.0,10.0]: box(solid,Vector3(x,27,z),Vector3(2,18,2),accent)
	for x in range(-25,26,10):
		for z: float in [-22.0,22.0]: box(solid,Vector3(x,13,z),Vector3(7,2,5),Color("3F7951"))

static func storm(solid: SurfaceTool, moving: SurfaceTool) -> void:
	box(solid,Vector3(-32,8,5),Vector3(25,16,25),Color("A67E50"))
	box(solid,Vector3(-32,18,5),Vector3(31,5,29),Color("5F6A64"))
	for layer in range(10):
		var height := layer*10.0
		var radius := 6+pow(layer/9.0,1.3)*29
		cylinder(moving,Vector3(sin(layer*.7)*5,height+8,0),radius,radius+3,11,Color("948E7B").lightened(layer*.018),12)
		for i in range(3):
			var a := i*TAU/3+layer*.8
			box(moving,Vector3(cos(a)*(radius+4),height+7,sin(a)*(radius+4)),Vector3(4,1.4,6),Color("AD9C78"),Basis(Vector3.UP,a))

static func furnace(solid: SurfaceTool, light: SurfaceTool) -> void:
	cylinder(solid,Vector3(0,24,0),17,13,48,Color("806E63"),16)
	cylinder(solid,Vector3(0,51,0),13,8,8,Color("B7946B"),16)
	for side: float in [-1.0,1.0]:
		cylinder(solid,Vector3(side*27,35,-8),5,4,70,Color("9A6D59"))
		beam(solid,Vector3(side*27,12,-8),Vector3(side*13,12,0),5,Color("6F7D83"))
	for level in range(4):
		circle(solid,Vector3(0,10+level*11,0),17,1.5,Color("C0A277"),1,16)
	box(light,Vector3(0,8,17),Vector3(16,9,1),Color("F0A04E"))
	box(solid,Vector3(0,2,28),Vector3(22,4,22),Color("6D625B"))
	box(light,Vector3(0,4.2,28),Vector3(13,.35,18),Color("F5BE68"))

static func blades(tool_value: SurfaceTool, hub: Vector3, radius: float, color: Color) -> void:
	for i in range(3):
		var a := TAU*i/3+.18
		var direction := Vector3(sin(a),cos(a),0)
		box(tool_value,hub+direction*(radius*.54),Vector3(2.6,radius*.86,1),color,Basis(Vector3.BACK,-a))
		box(tool_value,hub+direction*(radius*.91),Vector3(2.7,radius*.14,1.1),Color("A6CCD3"),Basis(Vector3.BACK,-a))
	cylinder(tool_value,hub,2,2,3,Color("758B91"))

static func turbines(solid: SurfaceTool, parent: Node3D) -> void:
	for index in range(3):
		var at := Vector3((index-1)*35,0,abs(index-1)*16)
		var height := 49.0 if index==1 else 38.0
		cylinder(solid,at+Vector3.UP*(height*.5),2.8,1.2,height,Color("DDDCD0"))
		box(solid,at+Vector3(0,height,2),Vector3(5,4,8),Color("B1C5C6"))
		var moving := tool()
		var hub := at+Vector3(0,height,-3)
		blades(moving,hub,22 if index==1 else 15,Color("F0EBDC"))
		finish(parent,"TurbineRotor"+str(index),moving,0,1,hub,.6+index*.14)

static func wheel(solid: SurfaceTool, light: SurfaceTool, moving: SurfaceTool, parent: Node3D) -> void:
	var center := Vector3(0,36,0)
	for x: float in [-22.0,22.0]:
		for z: float in [-9.0,9.0]: beam(solid,Vector3(x,-4,z),center+Vector3(0,0,z*.5),3,Color("8B9CA5"))
	circle(light,center,27,1.3,Color("F0C56B"),2,32)
	circle(moving,center,25,.8,Color("70CFE0"),2,24)
	for i in range(12):
		var a := TAU*i/12
		beam(moving,center,center+Vector3(cos(a)*25,sin(a)*25,0),.6,Color("DA8497"))
		var at := center+Vector3(cos(a)*27,sin(a)*27,0)
		var cabin := tool()
		box(cabin,at-Vector3.UP*2,Vector3(4.4,5,5),Color("E0A062") if i%2==0 else Color("749AC5"))
		box(cabin,at-Vector3.UP,Vector3(4.6,1.4,5.2),Color("ABD3D8"))
		var node := finish(parent,"WheelCabin"+str(i),cabin,.08,3,center,.12)
		node.material_override.set_shader_parameter("orbit_center",at)
	box(solid,Vector3(34,5,0),Vector3(18,10,26),Color("794E83"))
	for x in range(28,43,4): beam(light,Vector3(x,13,-12),Vector3(x+2,23,-8),.6,Color("6ED9D4"))

static func rocket(solid: SurfaceTool, light: SurfaceTool) -> void:
	cylinder(solid,Vector3(0,2,0),28,28,4,Color("7B8591"),24)
	cylinder(solid,Vector3(0,29,0),7,7,46,Color("D8D8CE"),16)
	cylinder(solid,Vector3(0,58,0),7,0,16,Color("B7C8CF"),16)
	cylinder(solid,Vector3(0,10,0),10,5,9,Color("7E8E9A"),12)
	for side: float in [-1.0,1.0]:
		box(solid,Vector3(side*19,29,-7),Vector3(4,58,5),Color("987354"))
		for y in range(7,55,9): beam(solid,Vector3(side*19,y,-7),Vector3(side*19,y+7,7),1,Color("CEAD72"))
		beam(solid,Vector3(side*19,55,-7),Vector3(side*7,55,0),2,Color("9CAAAF"))
		box(solid,Vector3(side*9,14,0),Vector3(3,16,11),Color("C49459"))
	circle(light,Vector3(0,4.2,0),23,.8,Color("8CD3DC"),1,32)

static func reactor(solid: SurfaceTool, light: SurfaceTool, moving: SurfaceTool) -> void:
	for side: float in [-1.0,1.0]:
		box(solid,Vector3(side*26,22,0),Vector3(9,48,12),Color("687B83"))
		box(light,Vector3(side*26,24,7),Vector3(3,35,.5),Color("A4E4A1"))
	cylinder(solid,Vector3(0,5,0),25,22,10,Color("596770"),16)
	circle(light,Vector3(0,30,0),21,2.3,Color("8BDAB5"),2,24)
	circle(moving,Vector3(0,30,0),24,1.3,Color("A2D9F0"),1,24)
	for i in range(5):
		var a := TAU*i/5
		box(moving,Vector3(cos(a)*24,30,sin(a)*24),Vector3(4,6,4),Color("C8E796"),Basis(Vector3.UP,a))
	CourseDecor.stone(light,Vector3(0,18,0),Vector3(10,28,10),Color("A2DBBF"),3)

static func ice_gallery(solid: SurfaceTool, half: float) -> void:
	var xs := [-half-10,-half*.6,0.0,half*.65,half+10]
	var ys := [36.0,43.0,47.0,42.0,35.0]
	for row in range(3):
		var z := -42+row*28.0
		var next_z := z+28
		for strip in range(4):
			var x: float = xs[strip]
			var next_x: float = xs[strip+1]
			var y: float = ys[strip]+sin(row+strip)*2
			var next_y: float = ys[strip+1]+sin(row+strip+1)*2
			var color := Color("B1DBE8").lightened(strip*.025)
			CourseDecor.colored_quad(solid,Vector3(x,y,z),Vector3(x,y,next_z),Vector3(next_x,next_y,next_z),Vector3(next_x,next_y,z),color)
			CourseDecor.colored_quad(solid,Vector3(x,y+8,z),Vector3(next_x,next_y+8,z),Vector3(next_x,next_y+8,next_z),Vector3(x,y+8,next_z),color.lightened(.1))
			for end: float in [z,next_z]: CourseDecor.colored_quad(solid,Vector3(x,y,end),Vector3(x,y+8,end),Vector3(next_x,next_y+8,end),Vector3(next_x,next_y,end),color.darkened(.08))
		for side: float in [-1.0,1.0]:
			CourseDecor.stone(solid,Vector3(side*(half+8),-10,z+12),Vector3(12,60+row*3,20),Color("86B8D1"),row+int(side)+4)
		for icicle in range(4):
			var x := lerpf(-half*.65,half*.65,icicle/3.0)
			cylinder(solid,Vector3(x,35+icicle%2,z+8),0,1.6,9,Color("CAE9EF"),5)

static func polar_crane(solid: SurfaceTool, accent: Color) -> void:
	for x: float in [-7.0,7.0]:
		for z: float in [-7.0,7.0]:
			box(solid,Vector3(x,27,z),Vector3(2.2,62,2.2),Color("B88358"))
			for y in range(0,55,9): beam(solid,Vector3(x,y,z),Vector3(-x,y+8,z),1,Color("C7A272"))
	box(solid,Vector3(0,58,0),Vector3(20,6,20),accent)
	beam(solid,Vector3(-30,62,0),Vector3(40,66,0),3,Color("C5A171"))
	beam(solid,Vector3(0,76,0),Vector3(-29,62,0),.5,Color("657B87"))
	beam(solid,Vector3(0,76,0),Vector3(40,66,0),.5,Color("657B87"))
	beam(solid,Vector3(0,58,0),Vector3(0,77,0),2,Color("C5A171"))
	beam(solid,Vector3(37,66,0),Vector3(37,29,0),.35,Color("657B87"))
	box(solid,Vector3(37,27,0),Vector3(5,4,4),Color("B98955"))
	box(solid,Vector3(-7,60,0),Vector3(9,7,8),Color("96C6D3"))

static func transport_span(solid: SurfaceTool, half: float, kind: String, stone: Color) -> void:
	var metal := Color("7D8F98")
	if kind=="canyon_bridge":
		for side: float in [-1.0,1.0]:
			CourseDecor.stone(solid,Vector3(side*(half+10),-12,0),Vector3(17,66,25),Color("B97558"),int(side)+5)
		arch(solid,half,29,15,0,7,Color("CB916A"),8)
		box(solid,Vector3(0,47,0),Vector3(half*2+9,3,12),Color("9B7457"))
		for z: float in [-6.0,6.0]: beam(solid,Vector3(-half,50,z),Vector3(half,50,z),.8,Color("C9AB80"))
		return
	var depth := 5.0 if kind=="suspension_walk" else 7.0 if kind=="mine_conveyor" else 16.0
	for z: float in [-depth,depth]: supports(solid,half,40,stone if kind=="suspension_walk" else metal,z,2.5 if kind=="suspension_walk" else 3.5)
	if kind=="suspension_walk":
		for index in range(24):
			var x := lerpf(-half,half,index/23.0)
			var y := 29+2*pow(absf(x/half),2)
			box(solid,Vector3(x,y,0),Vector3(half*2/23*.86,.65,depth*2),Color("B49B6A"))
	else:
		box(solid,Vector3(0,30,0),Vector3(half*2+12,3,depth*2),metal)
	for z: float in [-depth,depth]:
		for index in range(12):
			var x := lerpf(-half,half,index/12.0)
			var next := lerpf(-half,half,(index+1)/12.0)
			var y := 35+6*pow(absf(x/half),2)
			var next_y := 35+6*pow(absf(next/half),2)
			beam(solid,Vector3(x,y,z),Vector3(next,next_y,z),.35 if kind=="suspension_walk" else .8,Color("D4CAA4"))
			beam(solid,Vector3(x,31,z),Vector3(x,y,z),.25 if kind=="suspension_walk" else .6,metal)
		if kind=="mine_conveyor":
			beam(solid,Vector3(-half,36,z),Vector3(half,36,z),2,Color("9F8059"))

static func market_canopy(solid: SurfaceTool, light: SurfaceTool, half: float) -> void:
	var red := Color("AC4F56")
	for z: float in [-28.0,0.0,28.0]:
		supports(solid,half,36,red,z,2.5)
		beam(solid,Vector3(-half,36,z),Vector3(half,36,z),.3,Color("B5A784"))
		for index in range(11):
			var x := lerpf(-half+4,half-4,index/10.0)
			var y := 34-2*sin(index*PI/10)
			beam(solid,Vector3(x,36,z),Vector3(x,y,z),.12,Color("A69376"))
			cylinder(light,Vector3(x,y-1,z),1.1,1.1,2.2,Color("EDBD75") if index%2==0 else Color("D9858E"),8)
	for side: float in [-1.0,1.0]:
		var x := side*(half+6)
		box(solid,Vector3(x,35,0),Vector3(15,2,64),Color("624859"))
		for z: float in [-25.0,0.0,25.0]:
			box(solid,Vector3(x,39,z),Vector3(19,2.5,22),red)
			box(solid,Vector3(x,41,z),Vector3(13,2,20),Color("77546B"))

class_name ExpansionHorizon
extends RefCounted
## Persistent regional silhouettes behind the actual cosmetic terrain.
const PROFILES := {
	"glacier_ridge":["ice",460.0,.4], "aurora_harbor":["harbor",95.0,1.7],
	"alpine_meadow":["alpine",225.0,2.9], "frostbite_fjord":["ice",500.0,4.1],
	"tundra_pipeline":["tundra",75.0,5.4], "rainforest_ruins":["karst",270.0,6.8],
	"monsoon_delta":["islands",65.0,8.0], "coral_causeway":["islands",90.0,9.3],
	"mangrove_maze":["canopy",72.0,10.7], "cloudforest_climb":["alpine",335.0,12.1],
	"sakura_ring":["hills",140.0,13.4], "bamboo_gorge":["karst",290.0,14.8],
	"lantern_market":["roofs",220.0,16.2], "terrace_touge":["terraces",235.0,17.6],
	"temple_coast":["hills",195.0,18.9], "saltflat_velocity":["salt",65.0,20.3],
	"dune_serpent":["dunes",240.0,21.6], "oasis_citadel":["dunes",95.0,23.0],
	"copper_mesa":["mesas",265.0,24.4], "storm_chase":["prairie",48.0,25.8],
	"steelworks_sprint":["works",135.0,27.1], "container_corkscrew":["harbor",100.0,28.5],
	"neon_underpass":["city",245.0,29.9], "windfarm_run":["hills",225.0,31.2],
	"festival_speedway":["pavilions",150.0,32.6], "lunar_freight":["craters",165.0,34.0],
	"orbital_gardens":["domes",300.0,35.4], "crystal_chasm":["crystal",460.0,36.7],
	"mars_badlands":["mesas",285.0,38.1], "reactor_rift":["basalt",210.0,39.5]
}
const SEGMENTS := 192

static func wave(angle: float, frequency: float, phase: float) -> float:
	return .5+.5*sin(angle*frequency+phase)

static func profile(kind: String, angle: float, phase: float) -> float:
	var broad := wave(angle,3,phase)
	var fine := wave(angle,13,phase*.71)
	match kind:
		"ice": return .12+pow(1-absf(sin(angle*9+phase)),1.1)*(.35+broad*.65)
		"alpine": return .12+pow(broad,.85)*(.50+fine*.50)
		"tundra": return .18+broad*.45+wave(angle,7,phase)*.12
		"karst": return .12+pow(smoothstep(.32,.82,fine),.65)*(.35+broad*.65)
		"islands": return .07+pow(smoothstep(.45,.90,broad),1.3)*(.4+fine*.6)
		"canopy": return .28+broad*.27+wave(angle,23,phase)*.16
		"hills": return .16+wave(angle,5,phase)*.56+fine*.13
		"terraces":
			var steps := broad*5
			return .12+(floorf(steps)+smoothstep(.82,1.0,fposmod(steps,1)))*.15
		"dunes": return .14+pow(wave(angle,6,phase),1.8)*.60+wave(angle,3,phase)*.15
		"salt": return .08+smoothstep(.46,.64,broad)*.55
		"mesas": return .12+smoothstep(.40,.58,broad)*.65+smoothstep(.72,.87,fine)*.13
		"prairie": return .20+broad*.36+fine*.10
		"craters": return .16+pow(absf(sin(angle*5+phase)),.7)*.60+fine*.12
		"crystal": return .10+pow(1-absf(sin(angle*15+phase)),2)*(.45+broad*.55)
		"basalt": return .12+floorf((.30+broad*.5+fine*.2)*6)/6
		"domes": return .12+sqrt(maxf(0,1-pow(fposmod(angle*6/TAU+phase,1)*2-1,2)))*(.35+broad*.4)
	return .12+broad*.24

static func quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, lower: Color, upper: Color) -> void:
	for triangle: Array in [[a,c,b],[a,d,c]]:
		var normal: Vector3 = -(triangle[1]-triangle[0]).cross(triangle[2]-triangle[0]).normalized()
		for at: Vector3 in triangle:
			tool.set_normal(normal)
			tool.set_color(upper if at==c or at==d else lower)
			tool.add_vertex(at)

static func dome(tool: SurfaceTool, at: Vector3, radius: float, height: float, color: Color) -> void:
	CourseSetPieces.cuboid(tool,Transform3D(Basis.IDENTITY,at+Vector3.UP*9),Vector3(radius*2+8,18,radius*2+8),color.darkened(.12))
	var center := at+Vector3.UP*18
	for band in range(3):
		var low := PI*.5*band/3
		var high := PI*.5*(band+1)/3
		for segment in range(8):
			var a := TAU*segment/8
			var b := TAU*(segment+1)/8
			var p := center+Vector3(cos(a)*cos(low)*radius,sin(low)*height,sin(a)*cos(low)*radius)
			var q := center+Vector3(cos(b)*cos(low)*radius,sin(low)*height,sin(b)*cos(low)*radius)
			var r := center+Vector3(cos(b)*cos(high)*radius,sin(high)*height,sin(b)*cos(high)*radius)
			var s := center+Vector3(cos(a)*cos(high)*radius,sin(high)*height,sin(a)*cos(high)*radius)
			if band==2:
				var peak := center+Vector3.UP*height
				var normal := -(q-p).cross(peak-p).normalized()
				# Clockwise Godot front, facing out and up.
				for point: Vector3 in [p,q,peak]:
					tool.set_normal(normal)
					tool.set_color(color.lightened(.04))
					tool.add_vertex(point)
			else: quad(tool,q,p,s,r,color,color.lightened(.04))

static func silhouette_box(tool: SurfaceTool, pose: Transform3D, at: Vector3, size: Vector3, color: Color, tilt: float = 0) -> void:
	CourseSetPieces.cuboid(tool,pose*Transform3D(Basis(Vector3.FORWARD,tilt),at),size,color)

static func farm_silos(tool: SurfaceTool, at: Vector3, height: float, color: Color) -> void:
	for silo in range(3):
		var center := at+Vector3((silo-1)*34,0,0)
		var h := height*(.82+silo*.09)
		for side in range(8):
			var a := TAU*side/8
			var b := TAU*(side+1)/8
			var p := center+Vector3(cos(a)*14,0,sin(a)*14)
			var q := center+Vector3(cos(b)*14,0,sin(b)*14)
			quad(tool,p,p+Vector3.UP*h,q+Vector3.UP*h,q,color,color)
			CourseDecor.colored_triangle(tool,p+Vector3.UP*h,q+Vector3.UP*h,center+Vector3.UP*(h+9),color.lightened(.05))

static func settlements(tool: SurfaceTool, world: TrackWorld, center: Vector3, radius: float, base_y: float, phase: float, haze: Color) -> int:
	if world.track.id not in ["tundra_pipeline","storm_chase","saltflat_velocity"]: return 0
	var metal := Color("53656F").lerp(haze,.30)
	var warm := Color("B28A64").lerp(haze,.30)
	for index in range(12):
		var angle := TAU*(index+.23)/12
		var seed := CourseLandscape.noise_at(index,phase,97)
		var at := center+Vector3(cos(angle)*(radius+260),base_y-center.y,sin(angle)*(radius+260))
		var pose := Transform3D(Basis(Vector3.UP,PI/2-angle),at)
		if world.track.id=="storm_chase":
			if index%2==0: farm_silos(tool,at,85+seed*45,metal)
			else:
				silhouette_box(tool,pose,Vector3(0,23,0),Vector3(82,46,65),warm)
				for side: float in [-1,1]: silhouette_box(tool,pose,Vector3(side*21,53,0),Vector3(49,5,72),metal,side*.40)
		else:
			var kind := index%3 if world.track.id=="tundra_pipeline" else 1 if index%2==0 else 2
			silhouette_box(tool,pose,Vector3(0,12,0),Vector3(64,24,48),warm)
			if kind==0:
				for side: float in [-1,1]:
					silhouette_box(tool,pose,Vector3(side*24,40,0),Vector3(18,80,22),metal)
				CourseSetPieces.beam(tool,pose*Vector3(-24,82,0),pose*Vector3(24,82,0),9,metal)
			elif kind==1:
				var height := 105+seed*50
				silhouette_box(tool,pose,Vector3(0,height*.5,0),Vector3(7,height,7),metal)
				for level in range(3): silhouette_box(tool,pose,Vector3(0,height-10-level*18,0),Vector3(48-level*8,5,5),metal)
				for side: float in [-1,1]: CourseSetPieces.beam(tool,pose*Vector3(side*26,0,0),pose*Vector3(0,height*.58,0),4,metal)
			else:
				for side: float in [-1,1]:
					silhouette_box(tool,pose,Vector3(side*21,43,0),Vector3(28,86,28),metal)
					silhouette_box(tool,pose,Vector3(side*21,87,0),Vector3(34,5,34),warm)
	return 12

static func coast_direction(world: TrackWorld) -> Vector2:
	var interval: Array = world.art.coast_interval
	if not world.art.water or interval.is_empty(): return Vector2.ZERO
	var s := CourseArt.original_s(world.track,lerpf(float(interval[0]),float(interval[1]),.55))
	var across := world.track.pose(s).basis.x
	return Vector2(across.x,across.z).normalized()

static func build(world: TrackWorld) -> void:
	if not PROFILES.has(world.track.id): return
	var spec: Array = PROFILES[world.track.id]
	var kind: String = spec[0]
	var amplitude: float = spec[1]
	var phase: float = spec[2]
	var low := Vector3(INF,INF,INF)
	var high := Vector3(-INF,-INF,-INF)
	for at: Vector3 in world.track.points:
		low = low.min(at)
		high = high.max(at)
	var center := (low+high)*.5
	var road_radius := Vector2(high.x-low.x,high.z-low.z).length()*.5
	var radius := road_radius+620
	var base_y := INF
	for height: float in world.terrain_grid.values(): base_y = minf(base_y,height)
	base_y -= 20
	var shore := coast_direction(world)
	var tint := Color.html(world.art.ground).darkened(.17)
	var haze := Color.html(world.art.horizon)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for layer in range(2):
		var inner := radius+layer*460
		var crest := inner+180
		var outer := inner+420
		var base := tint.lerp(haze,.28+layer*.28)
		var top := base.lightened(.08)
		if kind=="ice": top = Color("E8F2EF").lerp(haze,layer*.20)
		elif kind=="crystal": top = Color("B59CD5").lerp(haze,layer*.22)
		for index in range(SEGMENTS):
			var a := TAU*index/SEGMENTS
			var b := TAU*((index+1)%SEGMENTS)/SEGMENTS
			var direction_a := Vector2(cos(a),sin(a))
			var direction_b := Vector2(cos(b),sin(b))
			var coast_a := lerpf(1.0,.18,smoothstep(.1,.85,direction_a.dot(shore))) if shore!=Vector2.ZERO else 1.0
			var coast_b := lerpf(1.0,.18,smoothstep(.1,.85,direction_b.dot(shore))) if shore!=Vector2.ZERO else 1.0
			var ha := 12+profile(kind,a,phase+layer*.8)*amplitude*coast_a*(1+layer*.12)
			var hb := 12+profile(kind,b,phase+layer*.8)*amplitude*coast_b*(1+layer*.12)
			var p := center+Vector3(direction_a.x*inner,base_y-center.y,direction_a.y*inner)
			var q := center+Vector3(direction_b.x*inner,base_y-center.y,direction_b.y*inner)
			var r := center+Vector3(direction_b.x*crest,base_y+hb-center.y,direction_b.y*crest)
			var s := center+Vector3(direction_a.x*crest,base_y+ha-center.y,direction_a.y*crest)
			var shade := .96+.04*wave(a,7,phase)
			var mid_a := p.lerp(s,.77)
			var mid_b := q.lerp(r,.77)
			quad(tool,p,q,mid_b,mid_a,base*shade,base.lightened(.04)*shade)
			quad(tool,mid_a,mid_b,r,s,base.lightened(.04)*shade,top*shade)
			var u := center+Vector3(direction_a.x*outer,base_y-center.y,direction_a.y*outer)
			var v := center+Vector3(direction_b.x*outer,base_y-center.y,direction_b.y*outer)
			quad(tool,s,r,v,u,top*shade,base*shade)
	# Low ridges carry the skyline below distant built silhouettes.
	if kind in ["harbor","works","city","roofs","domes","pavilions"]:
		for index in range(36):
			var angle := TAU*index/36
			var seed := CourseLandscape.noise_at(index,phase,91)
			var outward := Vector2(cos(angle),sin(angle))
			if shore!=Vector2.ZERO and outward.dot(shore)>.55: continue
			var at := center+Vector3(outward.x*(radius+210),base_y-center.y,outward.y*(radius+210))
			var height := 30+amplitude*(.3+seed*.7)
			var width := 28+seed*42
			var color := tint.darkened(.12).lerp(haze,.23)
			if kind=="roofs": color = Color("71516A").lerp(haze,.35)
			var pose := Transform3D(Basis(Vector3.UP,-angle),at)
			if kind=="domes":
				if index%3==0: dome(tool,at,width*.9,height*.65,Color("8AB8B0").lerp(haze,.25))
				continue
			if kind=="pavilions":
				if index%2==0: dome(tool,at,width*1.1,height*.43,Color("D1B69C" if index%4==0 else "B69EB5").lerp(haze,.25))
				continue
			CourseSetPieces.cuboid(tool,pose*Transform3D(Basis.IDENTITY,Vector3(0,height*.5,0)),Vector3(width,height,36),color)
			if kind=="works": CourseSetPieces.cuboid(tool,pose*Transform3D(Basis.IDENTITY,Vector3(width*.2,height+14,0)),Vector3(9,28+seed*30,9),color)
			elif kind=="roofs":
				for tier in range(3): CourseSetPieces.cuboid(tool,pose*Transform3D(Basis.IDENTITY,Vector3(0,height+tier*3,0)),Vector3(width+10-tier*7,3,44-tier*7),color.lightened(.04))
			elif kind=="city" and index%3==0: CourseSetPieces.beam(tool,at+Vector3.UP*height,at+Vector3.UP*(height+28),1.8,color)
			if float(world.art.emission)>0:
				# Broad, static window bands remain legible at skyline scale.
				CourseSetPieces.cuboid(tool,pose*Transform3D(Basis.IDENTITY,Vector3(0,height*.72,0)),Vector3(width+.3,2.3,36.3),Color("D4BF85").lerp(haze,.5))
	var settlement_count := settlements(tool,world,center,radius,base_y,phase,haze)
	var node := MeshInstance3D.new()
	node.name = "LandscapeHorizon"
	node.mesh = tool.commit()
	var surface := StandardMaterial3D.new()
	surface.vertex_color_use_as_albedo = true
	surface.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	node.material_override = surface
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.set_meta("profile",kind)
	node.set_meta("far_settlements",settlement_count)
	node.set_meta("road_radius",road_radius)
	node.set_meta("inner_radius",radius)
	node.set_meta("center_xz",Vector2(center.x,center.z))
	world.add_child(node)

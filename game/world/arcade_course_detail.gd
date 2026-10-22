class_name ArcadeCourseDetail
extends RefCounted
## Course-specific scenery, batched into a few meshes outside driving collision.


static func finish(world: TrackWorld, tool: SurfaceTool, name: String, glow: float = 0.0) -> void:
	var node := MeshInstance3D.new()
	node.name = name
	node.mesh = tool.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = .85
	if glow>0:
		mat.emission_enabled = true
		mat.emission = Color("65CADA")
		mat.emission_energy_multiplier = glow
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(node)


static func build(world: TrackWorld) -> void:
	if world.track.id=="marina_lights" and world.art.get("composition_version",0)<14: city(world)
	if world.art.get("space",false) and not world.art.get("expansion40",false): orbital(world)
	if not world.track.definition.ramp_markers.is_empty(): launches(world)


static func city(world: TrackWorld) -> void:
	var blocks := SurfaceTool.new()
	blocks.begin(Mesh.PRIMITIVE_TRIANGLES)
	var windows := SurfaceTool.new()
	windows.begin(Mesh.PRIMITIVE_TRIANGLES)
	var placed := 0
	for s in range(70,int(world.track.length),125):
		for side: float in [-1.0,1.0]:
			var pose := world.scenery_pose(s,side*48)
			if not world.clear_of_road(pose.origin,22) or RoadsidePosterArt.blocks_sightline(world.poster_sites,pose.origin): continue
			placed += 1
			var height := 18.0+float((s/125+int(side)+3)%5)*9.0
			var color := Color("555E80") if s%3==0 else Color("3C566F") if s%3==1 else Color("746878")
			CourseSetPieces.cuboid(blocks,pose*Transform3D(Basis.IDENTITY,Vector3(0,height*.5,0)),Vector3(22,height,28),color)
			CourseSetPieces.cuboid(blocks,pose*Transform3D(Basis.IDENTITY,Vector3(0,1,0)),Vector3(27,2,32),Color("9BA6B5"))
			CourseSetPieces.cuboid(blocks,pose*Transform3D(Basis.IDENTITY,Vector3(0,height+.5,0)),Vector3(24,1,30),Color("C7A2BC"))
			for floor_index in range(2,int(height)-2,5):
				for z: float in [-9.0,-3.0,3.0,9.0]:
					var center := Vector3(-side*11.05,floor_index,z)
					CourseSetPieces.cuboid(windows,pose*Transform3D(Basis.IDENTITY,center),Vector3(.08,2.0,2.5),Color("FFE5B0") if (floor_index+s)%3 else Color("68D5EE"))
	assert(placed>10)
	finish(world,blocks,"DowntownBlocks")
	finish(world,windows,"DowntownWindows",.4)


static func launches(world: TrackWorld) -> void:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for marker: float in world.track.definition.ramp_markers:
		var s := CourseArt.original_s(world.track,marker)-18
		var pose := world.ground_pose(s,0)
		var half := float(world.track.bake.samples[world.track.sample_index(s)][8])*.5+4
		for side: float in [-1.0,1.0]:
			CourseSetPieces.cuboid(tool,pose*Transform3D(Basis.IDENTITY,Vector3(side*half,4,0)),Vector3(.7,8,1),Color("F3CD48"))
			CourseSetPieces.cuboid(tool,pose*Transform3D(Basis.IDENTITY,Vector3(side*half,6,0)),Vector3(1.8,.8,1.2),Color("ED7147"))
		CourseSetPieces.cuboid(tool,pose*Transform3D(Basis.IDENTITY,Vector3(0,8.5,0)),Vector3(half*2+1,1,.7),Color("F3CD48"))
		# Three upward arrows read as a jump even before a player can read a sign.
		for x: float in [-4.0,0.0,4.0]:
			for side: float in [-1.0,1.0]:
				CourseSetPieces.beam(tool,pose*Vector3(x+side*.9,8.3,-.45),pose*Vector3(x,9.1,-.45),.28,Color("3B414A"))
	finish(world,tool,"ArcadeJumpGates")


static func orbital(world: TrackWorld) -> void:
	var gates := SurfaceTool.new()
	gates.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s in range(180,int(world.track.length),540):
		var pose := world.ground_pose(s,0)
		var half := float(world.track.bake.samples[world.track.sample_index(s)][8])*.5+5
		for side: float in [-1.0,1.0]:
			CourseSetPieces.beam(gates,pose*Vector3(side*half,-1,0),pose*Vector3(side*half,8,0),1.2,Color("40E4E4"))
			CourseSetPieces.beam(gates,pose*Vector3(side*half,8,0),pose*Vector3(side*(half-4),13,0),1.2,Color("ED75DC"))
		CourseSetPieces.beam(gates,pose*Vector3(-half+4,13,0),pose*Vector3(half-4,13,0),1.2,Color("40E4E4"))
	finish(world,gates,"OrbitalSpeedGates",.65)
	var rocks := SurfaceTool.new()
	rocks.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s in range(50,int(world.track.length),190):
		var side := -1.0 if s%3 else 1.0
		var pose := world.scenery_pose(s,side*85)
		if not world.clear_of_road(pose.origin,18): continue
		for index in range(3):
			var lean := Basis(Vector3.FORWARD,side*(.1+index*.13))
			var offset := Vector3(index*5-5,5+index*2,0)
			CourseSetPieces.cuboid(rocks,pose*Transform3D(lean,offset),Vector3(3,12+index*4,3),Color("9381C4") if index%2 else Color("55B8B8"))
	finish(world,rocks,"MoonCrystals",.12)

extends TrackWorld
## Native comparison fixture: these two render methods are verbatim from
## commit 373c970 (content 11). Collision and shared world helpers are unchanged.
## No runtime game path loads this fixture.

func build_road() -> void:
	pending_geometry = RouteGeometry.meshes(track,true)
	var geometry := pending_geometry
	var sand := material(Color.html(art.ground))
	for key: String in geometry:
		if key in ["walls","shoulder"]: continue
		if key=="verges" and art.get("elevated",false): continue
		var instance := MeshInstance3D.new()
		instance.name = "Road_"+key
		instance.mesh = CourseRoadMesh.front_faces(geometry[key],track if key=="asphalt" else null)
		if key=="verges" and art.has("verge_extent"): instance.mesh = CourseRoadMesh.verges(track,float(art.verge_extent))
		if key=="asphalt":
			instance.material_override = paving_material()
		else:
			var mat: StandardMaterial3D = material(Color.html("F3E4C4")) if key == "markings" else sand
			mat.cull_mode = BaseMaterial3D.CULL_BACK
			if key=="markings" and art.get("space",false):
				mat.albedo_color = Color("65F6ED")
				mat.emission_enabled = true
				mat.emission = Color("36C6DF")
			instance.material_override = mat
		add_child(instance)
	var shoulders := CourseRoadMesh.shoulders(track)
	for surface: String in shoulders:
		var instance := MeshInstance3D.new()
		instance.name = "Shoulder_"+surface
		instance.mesh = shoulders[surface]
		var color := Color("646B75") if surface=="asphalt" else Color("D8BD83") if surface=="sand" and track.definition.surface!="sand" else Color(art.ground)
		instance.material_override = paving_material(true) if surface=="asphalt" else material(color)
		add_child(instance)
	var barrier := MeshInstance3D.new()
	barrier.name = "RoadsideBarriers"
	barrier.mesh = CourseRoadMesh.barriers(track,art)
	barrier.material_override = material(Color.html("F3E4C4"))
	add_child(barrier)
	if art.get("elevated",false):
		var deck := MeshInstance3D.new()
		deck.name = "ElevatedDeck"
		deck.mesh = CourseRoadMesh.elevated_deck(track)
		deck.material_override = material(Color("677C8A"))
		add_child(deck)


func build_scenery_batch(first: int, last: int) -> void:
	if art.get("space",false): return
	var batches: Dictionary = {}
	var species: String = art.vegetation
	var spacing := 10 if species=="orchard" else 16 if species=="palm" else 20
	for s in range(first,last,spacing):
		var edge := float(track.bake.samples[track.sample_index(s)][8])*.5
		var offsets: Array = [-edge-9,-edge-20,-edge-31,edge+9,edge+20] if species=="orchard" else [-edge-8,-edge-25,edge+9,edge+28] if species=="redwood" else [-edge-7,-edge-25,edge+7] if species=="palm" else [-edge-8,edge+10,edge+27]
		for lateral: float in offsets:
			if species=="palm" and lateral>0 and s%48!=0: continue
			var pose := scenery_pose(s,lateral)
			if RoadsidePosterArt.blocks_sightline(poster_sites,pose.origin): continue
			pose.basis = pose.basis.rotated(Vector3.UP,sin(s*.071+lateral)*PI)
			pose.basis = pose.basis.scaled(Vector3.ONE*(1+.12*sin(s*.11+lateral)))
			var variant := ArcadeSpriteVariety.tree(track.id,species,s,lateral,track.length)
			if not batches.has(variant): batches[variant] = [] as Array[Transform3D]
			batches[variant].append(pose)
	for s in range(first,last,16):
		for side: float in [-1.0,1.0]:
			var lateral := side*(float(track.bake.samples[track.sample_index(s)][8])/2+8)
			var pose := scenery_pose(s,lateral)
			pose.basis = pose.basis.rotated(Vector3.UP,s*.3)
			if not batches.has("grass"): batches.grass = [] as Array[Transform3D]
			batches.grass.append(pose)
	if track.id in ["palm_bay","marina_lights","skyline_splice"]:
		for s in range(first,last,40):
			var id := "streetlight" if track.id!="palm_bay" else "umbrella" if s%80==0 else "bench"
			if not batches.has(id): batches[id] = [] as Array[Transform3D]
			var edge := float(track.bake.samples[track.sample_index(s)][8])*.5
			batches[id].append(ground_pose(s,-edge-1.7) if art.get("elevated",false) else scenery_pose(s,-18))
	if track.id in ["marina_lights","skyline_splice"] or track.id=="palm_bay" and first%160==0:
		var id := ("marina_shops" if first%160==0 else "marina_hotel") if track.id!="palm_bay" else "coastal_home"
		var pose := scenery_pose(first+40,-48 if track.id!="palm_bay" else -65)
		pose.basis = pose.basis.rotated(Vector3.UP,PI/2)
		batches[id] = [pose] as Array[Transform3D]
	if first%160==0 and track.id in ["sunstone_canyon","pacific_summit"]:
		var id := "sandstone_rock" if track.id=="sunstone_canyon" else "summit_peak"
		var lateral := (-95 if first%320==0 else 100) if track.id=="sunstone_canyon" else -135
		var pose := scenery_pose(first+40,lateral)
		pose.basis = pose.basis.rotated(Vector3.UP,float((first/160)%7-3)*.17)
		if clear_of_road(pose.origin,25 if id=="sandstone_rock" else 52): batches[id] = [pose] as Array[Transform3D]
	if track.id=="pacific_summit":
		var pose := scenery_pose(first+20,-48)
		if not RoadsidePosterArt.blocks_sightline(poster_sites,pose.origin): batches.redwood = [pose] as Array[Transform3D]
	BillboardArt.load_catalog()
	ArcadeSpriteVariety.props(self,first,last,batches)
	for id: String in batches:
		var retained: Array[Transform3D] = []
		for pose: Transform3D in batches[id]:
			if decoration_allowed(pose.origin): retained.append(pose)
		CourseArt.batch(id,retained,self,float(art.get("emission",0)))

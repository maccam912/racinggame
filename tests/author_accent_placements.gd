extends SceneTree
## Offline placement search; emits explicit regions for review, never edits content.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	Catalog.load_all()
	var authored: Array[Dictionary] = []
	for track: TrackDefinition in Catalog.tracks:
		if track.id not in ["glacier_ridge","frostbite_fjord"]: continue
		var world := TrackWorld.new()
		world.build(track)
		root.add_child(world)
		var reserved: Array[Dictionary] = []
		reserved.assign(world.get_node("ExpansionLandscape").get_meta("sites"))
		reserved.append_array(world.get_node("CourseAccents").get_meta("sites"))
		var regions: Array[Dictionary] = []
		for index in range(50):
			if regions.size()>=6: break
			for side: float in [-1,1]:
				if regions.size()>=6: break
				for setback: float in [160,220,280]:
					var region := {"name":"Glacial ice face "+str(regions.size()+1),"kind":"landforms","u":.02+index*.019,"side":side,"setback":setback,"scale":"large","avoid_buildings":true,"modules":[["ice_wall",0,0,regions.size()%4,.3]]}
					var s := CourseArt.original_s(track,region.u)
					var pose := track.pose(s,side*setback)
					pose.basis = Basis(Vector3.UP,pose.basis.get_euler().y)
					var pending := Node3D.new()
					var sites: Array[Dictionary] = []
					AuthoredCourseScenery.compound(world,pending,region,pose,sites,reserved)
					pending.free()
					if sites.is_empty(): continue
					regions.append(region)
					reserved.append_array(sites)
					break
		assert(regions.size()==6,"six full footprint ice faces must fit: "+track.id)
		authored.append({"id":track.id,"regions":regions})
		print("AUTHORED_ICE_FACES ",track.id," ",regions.size())
		world.queue_free()
		await process_frame
	FileAccess.open("res://reports/layout15/ice-face-placements.json",FileAccess.WRITE).store_string(JSON.stringify(authored,"\t")+"\n")
	quit()

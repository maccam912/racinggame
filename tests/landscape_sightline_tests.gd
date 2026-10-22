extends SceneTree


func _initialize() -> void: call_deferred("run")


func run() -> void:
	Catalog.load_all()
	var records: Array[Dictionary] = []
	for track: TrackDefinition in Catalog.tracks.slice(0,10):
		var world := TrackWorld.new()
		world.build(track)
		root.add_child(world)
		var districts := world.get_node("LandscapeDistricts")
		var sites: Array = districts.get_meta("sites")
		print("LANDSCAPE_SITES ",track.id," ",sites.size())
		assert(sites.size()>20 and sites.size()<5000,"each course has bounded scenery across the landscape")
		var far_sites := 0
		for site: Dictionary in sites:
			var at: Vector3 = site.at
			assert(world.clear_of_road(at,site.radius),"every instance clears every road branch")
			assert(world.decoration_allowed(at) and not RoadsidePosterArt.blocks_sightline(world.poster_sites,at))
			assert(absf(at.y-(AuthoredCourseScenery.height(world,at,site) if world.art.get("composition_version",0)>=14 else CourseArt.height_from_grid(world.terrain_grid,at,INF)))<.001,"landscape roots meet actual terrain")
			if world.art.water and site.id!="islet": assert(at.y>float(CourseArt.terrain_info[track.id].sea_level)+1.49,"no groves or buildings in open water")
			if site.distance>220: far_sites += 1
		assert(far_sites>20,"decoration extends well beyond the roadside band")
		assert(districts.find_children("*","CollisionObject3D",true,false).is_empty())
		var batches := districts.find_children("*","GeometryInstance3D",true,false)
		assert(batches.size()<650,"spatial batches keep submissions bounded")
		for batch: GeometryInstance3D in batches:
			if batch.name=="LandscapeGroundSkirt": continue
			assert(batch.is_in_group("scenery_distance") and batch.visibility_range_end<=700)
		if world.has_node("LandscapeHorizon"):
			var horizon := world.get_node("LandscapeHorizon") as MeshInstance3D
			assert(not horizon.is_in_group("scenery_distance") and horizon.visibility_range_end==0,"coarse silhouettes survive detail culling")
			assert(horizon.mesh.get_faces().size()/3<1600)
			for at: Vector3 in horizon.mesh.get_faces():
				assert(at.is_finite() and world.clear_of_road(at,100),"the full horizon geometry stays outside the driving landscape")
		records.append({"track":track.id,"instances":sites.size(),"batches":batches.size(),"beyond_220m":far_sites})
		world.queue_free()
		await process_frame
	var file := FileAccess.open("res://reports/landscape-sightlines.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":true,"courses":records},"\t")+"\n")
	print("TEN_COURSE_LANDSCAPE_DEPTH_GROUNDING_CLEARANCE_AND_BATCH_BUDGET_PASS")
	quit()

extends SceneTree
## Actual revised roads and the additional large/medium scenery in every world.
func _initialize() -> void: call_deferred("run")

func run() -> void:
	Catalog.load_all()
	var cases: Array[Dictionary] = []
	var failures: Array[String] = []
	for track: TrackDefinition in Catalog.tracks:
		assert(track.definition.detail_offsets.size()>=16)
		assert(float(track.bake.validation.min_radius)>=28 and float(track.bake.validation.max_grade)<=.24)
		var previous := 0
		var reversals := 0
		for row: Array in track.bake.samples:
			var sign := 1 if float(row[6])>.002 else -1 if float(row[6])<-.002 else 0
			if sign!=0:
				if previous!=0 and sign!=previous: reversals += 1
				previous = sign
		if track.smooth_road():
			assert(reversals/track.length*1000<3,"smooth roads must avoid repeated steering corrections: "+track.id)
		else:
			assert(reversals>=16,"local-scale direction changes must survive the actual bake: "+track.id)
		var world := TrackWorld.new()
		world.build(track)
		root.add_child(world)
		var accents := world.get_node("CourseAccents")
		var regions: Array = accents.get_meta("regions")
		var sites: Array = accents.get_meta("sites")
		var occupied := 0
		for region: Dictionary in regions:
			if region.sites>0: occupied += 1
		if not (regions.size()>=4 and occupied>=2 and sites.size()>=3): failures.append(track.id)
		for site: Dictionary in sites:
			assert(world.clear_of_road(site.at,site.radius))
			assert(site.at.y>=site.foundation_min and site.at.y-site.foundation_min<=site.foundation_limit)
		assert(accents.find_children("*","CollisionObject3D",true,false).is_empty())
		cases.append({"track":track.id,"steering_reversals":reversals,"populated_accent_regions":occupied,"additional_models":sites.size(),"min_radius_m":track.bake.validation.min_radius})
		print("ROUTE_DETAIL ",track.id," reversals=",reversals," accent_models=",sites.size())
		world.queue_free()
		await process_frame
	FileAccess.open("res://reports/route-detail15.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":failures.is_empty(),"failures":failures,"content_hash":Compatibility.content_hash(),"cases":cases},"\t")+"\n")
	if failures.is_empty(): print("FORTY_THREE_SCALE_ROUTES_ADDED_LARGE_MEDIUM_SCENERY_CLEARANCE_PASS")
	print("ACCENT_PLACEMENT_FAILURES ",failures)
	quit(0 if failures.is_empty() else 1)

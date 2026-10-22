extends SceneTree
## Actual road clearance, compound bounds and named-area placement in content 14.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	Catalog.load_all()
	var rows: Array[Dictionary] = []
	var modules: Dictionary = {}
	for track: TrackDefinition in Catalog.tracks:
		if CourseArt.spec(track.id).get("composition_version",0)!=14: continue
		var world := TrackWorld.new()
		world.build(track)
		root.add_child(world)
		var landscape := world.get_node("ExpansionLandscape" if world.art.get("expansion40",false) else "LandscapeDistricts")
		var names: Dictionary = {}
		var places := 0
		for region: Dictionary in landscape.get_meta("regions"):
			assert(not names.has(region.name) and not str(region.name).is_empty())
			names[region.name] = true
			if region.sites>0: places += 1
		assert(places>=3 and landscape.find_children("*","CollisionObject3D",true,false).is_empty())
		var min_gap := INF
		for i in range(0,track.points.size(),5):
			var width := float(track.bake.samples[i][8])*.5
			for lateral: float in [-width,0,width]:
				var at := RouteGeometry.point(track,i,lateral)
				var gap := at.y-CourseArt.height_from_grid(world.terrain_grid,at,INF)
				assert(is_finite(gap) and gap>.05,"nearby hills cannot protrude through any sampled pavement edge")
				min_gap = minf(min_gap,gap)
		var physical_modules := 0
		for site: Dictionary in landscape.get_meta("sites"):
			assert(names.has(site.region) and site.at.is_finite() and site.radius>0)
			assert(world.clear_of_road(site.at,site.radius),"full scenery footprints clear all road branches")
			if site.has("module"):
				physical_modules += 1
				assert(site.at.y>=site.foundation_min and site.at.y-site.foundation_min<=16)
		for node: MeshInstance3D in landscape.find_children("*","MeshInstance3D",true,false):
			if not node.has_meta("module"): continue
			var key := node.mesh.get_instance_id()
			if modules.has(key): continue
			modules[key] = true
			var faces := node.mesh.get_faces()
			assert(faces.size()/3<1500)
			var arrays := node.mesh.surface_get_arrays(0)
			for vertex: Vector3 in faces: assert(vertex.is_finite())
			for normal: Vector3 in arrays[Mesh.ARRAY_NORMAL]: assert(normal.is_finite() and absf(normal.length()-1)<.01)
			assert(node.visibility_range_end==700 and node.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		rows.append({"track":track.id,"named_places":places,"actual_building_modules":physical_modules,"minimum_pavement_terrain_gap_m":min_gap})
		print("AUTHORED_COMPOSITION ",track.id," places=",places," modules=",physical_modules)
		world.queue_free()
		await process_frame
	assert(rows.size()==33 and modules.size()>20)
	FileAccess.open("res://reports/authored-compositions14.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":true,"content_hash":Compatibility.content_hash(),"cases":rows,"distinct_module_meshes":modules.size(),"boundary":"Actual world composition, full footprint road reservations, finite bounded model meshes and pavement-edge terrain samples. Native aesthetic review is separate."},"\t")+"\n")
	print("THIRTY_THREE_AUTHORED_PLACES_COMPOUNDS_AND_ROAD_TERRAIN_CLEARANCE_PASS")
	quit()

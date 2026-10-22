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
				assert(site.at.y>=site.foundation_min and site.at.y-site.foundation_min<=(60 if site.module in ["mesa_outcrop","terraced_field","basalt_crag","martian_butte","crater_outcrop","ice_wall","glacial_erratic"] else 16))
		for node: MeshInstance3D in landscape.find_children("*","MeshInstance3D",true,false):
			if not node.has_meta("module"): continue
			if node.get_meta("module") in ["mesa_outcrop","terraced_field","basalt_crag","martian_butte","crater_outcrop","ice_wall","glacial_erratic"]: check_natural_foundation(world,node)
			var key := node.mesh.get_instance_id()
			if modules.has(key): continue
			modules[key] = true
			var faces := node.mesh.get_faces()
			assert(faces.size()/3<1500)
			var arrays := node.mesh.surface_get_arrays(0)
			for vertex: Vector3 in faces: assert(vertex.is_finite())
			for normal: Vector3 in arrays[Mesh.ARRAY_NORMAL]: assert(normal.is_finite() and absf(normal.length()-1)<.01)
			assert(node.visibility_range_end==700 and node.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
		if track.id=="neon_underpass": check_city_blocks(world)
		if track.id in ["glacier_ridge","frostbite_fjord"]:
			var ice_walls := 0
			var erratics := 0
			for site: Dictionary in landscape.get_meta("sites"):
				if site.get("module","")=="ice_wall": ice_walls += 1
				elif site.get("module","")=="glacial_erratic": erratics += 1
			assert(ice_walls>=6 and erratics>=4,"broad ice faces and low glacial rocks must survive terrain and road clearance")
		if track.id in ["orbital_gardens","lunar_freight","mars_badlands"]:
			var present: Dictionary = {}
			for site: Dictionary in landscape.get_meta("sites"):
				if site.has("module"): present[site.module] = int(present.get(site.module,0))+1
			if track.id=="orbital_gardens": assert(int(present.get("botanical_court",0))>=3,"all three individually placed botanical courts must survive clearance checks")
			else:
				assert(int(present.get("survey_rover",0))>=1)
				if track.id=="lunar_freight": assert(int(present.get("freight_lander",0))==1)
		rows.append({"track":track.id,"named_places":places,"actual_building_modules":physical_modules,"minimum_pavement_terrain_gap_m":min_gap})
		print("AUTHORED_COMPOSITION ",track.id," places=",places," modules=",physical_modules)
		world.queue_free()
		await process_frame
	assert(rows.size()==33 and modules.size()>20)
	FileAccess.open("res://reports/authored-compositions14.json",FileAccess.WRITE).store_string(JSON.stringify({"passed":true,"content_hash":Compatibility.content_hash(),"cases":rows,"distinct_module_meshes":modules.size(),"boundary":"Actual world composition, full footprint road reservations, finite bounded model meshes and pavement-edge terrain samples. Native aesthetic review is separate."},"\t")+"\n")
	print("THIRTY_THREE_AUTHORED_PLACES_COMPOUNDS_AND_ROAD_TERRAIN_CLEARANCE_PASS")
	quit()

func check_city_blocks(world: TrackWorld) -> void:
	var nodes: Array[MeshInstance3D] = []
	var polygons: Array[PackedVector2Array] = []
	for node: MeshInstance3D in world.get_node("ExpansionLandscape").find_children("*","MeshInstance3D",true,false):
		if not node.has_meta("module"): continue
		nodes.append(node)
		var bounds := node.mesh.get_aabb()
		var polygon := PackedVector2Array()
		for point: Vector3 in [bounds.position,Vector3(bounds.end.x,0,bounds.position.z),bounds.end,Vector3(bounds.position.x,0,bounds.end.z)]:
			var at := node.global_transform*point
			polygon.append(Vector2(at.x,at.z))
		polygons.append(polygon)
	assert(nodes.size()>=100,"city districts must survive road and foundation culling")
	var kinds: Dictionary = {}
	for node: MeshInstance3D in nodes: kinds[node.get_meta("module")] = true
	for kind: String in ["cinema","arcade","apartment","parking"]: assert(kinds.has(kind))
	for a in range(nodes.size()):
		for b in range(a+1,nodes.size()):
			if nodes[a].position.distance_to(nodes[b].position)>120: continue
			for polygon: PackedVector2Array in Geometry2D.intersect_polygons(polygons[a],polygons[b]):
				var area := 0.0
				for i in range(polygon.size()): area += polygon[i].cross(polygon[(i+1)%polygon.size()])*.5
				assert(absf(area)<.01,"independently authored city blocks cannot intersect one another")

func check_natural_foundation(world: TrackWorld, node: MeshInstance3D) -> void:
	# Inspect the actual closed bottom triangles against the exported terrain,
	# independently of the placement helper's five support samples.
	var bounds := node.mesh.get_aabb()
	assert(is_equal_approx(bounds.position.y,-64))
	var faces := node.mesh.get_faces()
	for first in range(0,faces.size(),3):
		var a := faces[first]
		var b := faces[first+1]
		var c := faces[first+2]
		if is_equal_approx(a.y,b.y) and is_equal_approx(a.y,c.y):
			var facing := -(b-a).cross(c-a).normalized()
			assert(facing.y<-.999 if is_equal_approx(a.y,-64) else facing.y>.999,"exposed shelves face upward, including below the hill crest")
		if not (is_equal_approx(a.y,-64) and is_equal_approx(b.y,-64) and is_equal_approx(c.y,-64)): continue
		for i in range(5):
			for j in range(5-i):
				var at := node.global_transform*(a+(b-a)*(i/4.0)+(c-a)*(j/4.0))
				var floor_y := CourseArt.height_from_grid(world.terrain_grid,at,-INF)
				assert(is_finite(floor_y) and at.y<floor_y-.05,"closed natural bases must remain buried under the actual ground")

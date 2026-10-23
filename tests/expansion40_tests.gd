extends SceneTree
## Every new world, its illustrated assets, landmarks and road submission bounds.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	Catalog.load_all()
	BillboardArt.load_catalog()
	assert(Catalog.tracks.size()==40)
	var frozen: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/content14/tracks.json"))
	for index in range(40):
		assert(Catalog.tracks[index].definition!=frozen.tracks[index],"all forty routes receive approved local detail")
		assert(Catalog.tracks[index].definition.detail_offsets.size()>=16)
	var cases: Array[Dictionary] = []
	var polygons: Dictionary = {}
	var themes: Dictionary = {}
	var lengths: Array[float] = []
	var flowing := 0
	var speed_courses := 0
	for track: TrackDefinition in Catalog.tracks.slice(10):
		lengths.append(track.length)
		var straight_samples := 0
		for row: Array in track.bake.samples:
			if absf(float(row[6]))<.001: straight_samples += 1
		var straight_fraction: float = float(straight_samples)/track.bake.samples.size()
		if straight_fraction<.3: flowing += 1
		if straight_fraction>.22: speed_courses += 1
		var polygon := var_to_bytes(track.definition.ordered_control_points).hex_encode()
		assert(not polygons.has(polygon),"every addition has an individual authored polygon")
		polygons[polygon] = true
		assert(LobbyState.valid_rules({"track":Catalog.tracks.find(track),"laps":1,"bot_fill":true,"difficulty":1,"contact":true}))
		var postcard: Texture2D = load("res://assets/exported/thumbnails/"+track.id+".png")
		assert(postcard!=null and postcard.get_size()==Vector2(512,288))
		assert(UIIcons.entries().has("track_"+track.id))
		var world := TrackWorld.new()
		world.build(track)
		root.add_child(world)
		assert(TrackWorld.skies.size()<=6,"the expanded roster keeps a bounded reusable sky cache")
		var environment := world.find_children("*","WorldEnvironment",false,false)[0] as WorldEnvironment
		assert(environment.environment.background_mode==Environment.BG_SKY)
		assert(environment.environment.sky.sky_material is ShaderMaterial)
		var landscape := world.get_node("ExpansionLandscape")
		var sites: Array = landscape.get_meta("sites")
		var far_sites := 0
		var species := {}
		for site: Dictionary in sites:
			if not site.has("module"):
				assert(absf(site.at.y-AuthoredCourseScenery.height(world,site.at,site))<.001)
			else: assert(site.at.y>=site.foundation_min and site.at.y-site.foundation_min<=(60 if site.module in ["mesa_outcrop","terraced_field","basalt_crag","martian_butte","crater_outcrop","limestone_bluff","sandstone_fin","ice_wall","glacial_erratic"] else 16))
			assert(world.clear_of_road(site.at,site.radius) and world.decoration_allowed(site.at,site.radius))
			if site.distance>220: far_sites += 1
			species[site.id] = true
		assert(sites.size()>=12,"authored groves and compounds must contain actual scenery")
		var regions: Array = landscape.get_meta("regions")
		var occupied := 0
		for region: Dictionary in regions:
			if region.sites>0: occupied += 1
		assert(occupied>=3,"each course needs several actual places, not one cosmetic cluster")
		assert(species.size()>=3,"groves and districts mix distinct silhouettes")
		if world.art.space:
			assert(not world.has_node("OrbitalSpeedGates") and not world.has_node("MoonCrystals"),"authored space places must not inherit regular legacy decoration rows")
			var rail := world.get_node("RoadsideBarriers").material_override as StandardMaterial3D
			assert(not rail.emission_enabled)
			if world.has_node("Road_markings"):
				var paint := world.get_node("Road_markings").material_override as StandardMaterial3D
				assert(paint!=rail and paint.emission_enabled,"road paint cannot mutate the shared rail material")
				assert(rail.albedo_color!=paint.albedo_color)
			else: assert(track.road_surface()=="dirt")
		assert(world.has_node("LandscapeHorizon"),"persistent silhouettes mask the terrain cutoff, including space courses")
		if not world.art.light_sections.is_empty():
			assert(not world.find_children("streetlight_Batch_*","MultiMeshInstance3D",true,false).is_empty(),"urban districts use real streetlight models")
		themes[world.art.theme] = int(themes.get(world.art.theme,0))+1
		assert(AudioLibrary.entries().has("music_"+str(world.art.music_family)))
		var landmarks := 0
		for node: Node in world.get_children():
			if not node.has_meta("anchor_u"): continue
			landmarks += 1
			var id: String = node.get_meta("asset_id")
			assert(BillboardArt.rows.has(id))
			var radius: float = float(BillboardArt.rows[id].size_m[0])*.55
			assert(world.clear_of_road(node.position,radius+3))
			var terrain_y := CourseArt.height_from_grid(world.terrain_grid,node.position,INF)
			var verge_y := world.verge_height(float(node.get_meta("anchor_s")),float(node.get_meta("anchor_lateral")),node.position)
			assert(absf(node.position.y-maxf(terrain_y,verge_y))<.01,"illustrated landmarks meet the visible terrain/verge triangle")
		assert(landmarks==world.art.landmarks.size())
		var gates := world.find_children("ExpansionStructure_*","MeshInstance3D",false,false)
		assert(gates.size()==world.art.road_gates.size())
		for gate: MeshInstance3D in gates:
			assert(gate.mesh.get_faces().size()/3<400 and gate.get_meta("clearance_m")>=22)
			assert(gate.find_children("*","CollisionObject3D",true,false).is_empty())
			for lateral: float in [-12.0,0.0,12.0]:
				var faces := gate.mesh.get_faces()
				for first in range(0,faces.size(),3):
					assert(Geometry3D.segment_intersects_triangle(Vector3(lateral,0,0),Vector3(lateral,10,0),faces[first],faces[first+1],faces[first+2])==null,"3D gates keep the racing/landing corridor clear")
		var batches := world.find_children("*","MultiMeshInstance3D",true,false)
		assert(batches.size()<650,"spatial scenery remains bounded")
		cases.append({"track":track.id,"surface":track.road_surface(),"length_m":track.length,"straight_fraction":straight_fraction,"theme":world.art.theme,"landmarks":landmarks,"structures":gates.size(),"sprite_batches":batches.size(),"landscape_sites":sites.size(),"beyond_220m":far_sites,"landscape_species":species.keys()})
		print("EXPANSION_WORLD ",track.id," batches=",batches.size())
		world.queue_free()
		await process_frame
	assert(themes.size()==6)
	assert(lengths.max()/lengths.min()>3,"short and endurance tracks need meaningfully different lap lengths")
	assert(flowing>=16 and speed_courses>=8,"organic curves and long-straight courses have distinct driving demands")
	for count: int in themes.values(): assert(count==5)
	assert(not LobbyState.valid_rules({"track":40,"laps":1,"bot_fill":true,"difficulty":1,"contact":true}))
	var file := FileAccess.open("res://reports/expansion40-worlds.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":true,"cases":cases,"content_hash":Compatibility.content_hash(),"boundary":"All thirty real static worlds, forty revised definitions, thumbnails, icons, music routing, authored grounded/road-clear landmarks and selectively placed open gates and bounded sprite batches. AI/camera laps and native render captures are separate fixtures."},"\t")+"\n")
	file.close()
	print("FORTY_COURSES_THIRTY_NEW_GROUNDED_DISTINCT_WORLDS_ASSET_SERVER_GATE_CONTRACTS_PASS")
	quit()

extends SceneTree
## Every new world, its illustrated assets, landmarks and road submission bounds.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	Catalog.load_all()
	BillboardArt.load_catalog()
	assert(Catalog.tracks.size()==40)
	var frozen: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/content11/tracks.json"))
	for index in range(10): assert(Catalog.tracks[index].definition==frozen.tracks[index],"the established ten route definitions remain exact")
	var cases: Array[Dictionary] = []
	var polygons: Dictionary = {}
	var themes: Dictionary = {}
	for track: TrackDefinition in Catalog.tracks.slice(10):
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
		assert(landmarks==5)
		var gates := world.find_children("ExpansionStructure_*","MeshInstance3D",false,false)
		assert(gates.size()==3)
		for gate: MeshInstance3D in gates:
			assert(gate.mesh.get_faces().size()/3<400 and gate.get_meta("clearance_m")>=22)
			assert(gate.find_children("*","CollisionObject3D",true,false).is_empty())
			for lateral: float in [-12.0,0.0,12.0]:
				var faces := gate.mesh.get_faces()
				for first in range(0,faces.size(),3):
					assert(Geometry3D.segment_intersects_triangle(Vector3(lateral,0,0),Vector3(lateral,10,0),faces[first],faces[first+1],faces[first+2])==null,"3D gates keep the racing/landing corridor clear")
		var batches := world.find_children("*","MultiMeshInstance3D",true,false)
		assert(batches.size()<650,"spatial scenery remains bounded")
		cases.append({"track":track.id,"surface":track.road_surface(),"length_m":track.length,"theme":world.art.theme,"landmarks":landmarks,"structures":gates.size(),"sprite_batches":batches.size()})
		print("EXPANSION_WORLD ",track.id," batches=",batches.size())
		world.queue_free()
		await process_frame
	assert(themes.size()==6)
	for count: int in themes.values(): assert(count==5)
	assert(not LobbyState.valid_rules({"track":40,"laps":1,"bot_fill":true,"difficulty":1,"contact":true}))
	var file := FileAccess.open("res://reports/expansion40-worlds.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":true,"cases":cases,"content_hash":Compatibility.content_hash(),"boundary":"All thirty real static worlds, exact retained ten definitions, thumbnails, icons, music routing, five grounded/road-clear landmarks, three open 3D gates and bounded sprite batches. AI/camera laps and native render captures are separate fixtures."},"\t")+"\n")
	file.close()
	print("FORTY_COURSES_THIRTY_NEW_GROUNDED_DISTINCT_WORLDS_ASSET_SERVER_GATE_CONTRACTS_PASS")
	quit()

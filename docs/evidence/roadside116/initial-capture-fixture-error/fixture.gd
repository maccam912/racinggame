extends SceneTree

func _initialize() -> void: call_deferred("run")

func run() -> void:
	Catalog.load_all()
	root.size = Vector2i(1920,1080)
	root.msaa_3d = Viewport.MSAA_4X
	var folder := "/Users/maccam912/dev/racinggame/reports/roadside116-details"
	DirAccess.make_dir_recursive_absolute(folder)
	var records: Array[Dictionary] = []
	for track: TrackDefinition in Catalog.tracks.slice(0,3):
		var world := TrackWorld.new()
		world.build(track)
		root.add_child(world)
		var seen: Dictionary = {}
		var camera := Camera3D.new()
		camera.current = true
		camera.fov = 55
		camera.far = 3000
		world.add_child(camera)
		for site: Dictionary in world.decor_sites:
			if not site.kind in RoadsideLife.KINDS: continue
			var variant := int(site.s/580)
			if seen.get(site.kind,[]).size()>=2 or variant in seen.get(site.kind,[]): continue
			if not seen.has(site.kind): seen[site.kind] = []
			seen[site.kind].append(variant)
			camera.position = site.pose*Vector3(10,7,14)
			camera.look_at(site.pose*Vector3(0,2,0),Vector3.UP)
			for frame in range(8): await process_frame
			await RenderingServer.frame_post_draw
			var filename := str(site.kind)+"-"+str(variant)+".png"
			assert(root.get_texture().get_image().save_png(folder+"/"+filename)==OK)
			records.append({"track":track.id,"kind":site.kind,"variant":variant,"route_s":site.s,"camera":camera.position,"image":filename,"png_sha256":FileAccess.get_sha256(folder+"/"+filename)})
		world.queue_free()
		for frame in range(4): await process_frame
	var file := FileAccess.open(folder+"/summary.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":true,"boundary":"Native diagnostic closeups of the actual roadside nodes and terrain. No gameplay or frame-performance claim.","asset_hash":Compatibility.asset_hash(),"content_hash":Compatibility.content_hash(),"cases":records},"\t")+"\n")
	file.close()
	assert(records.size()==8)
	print("ROADSIDE_NATIVE_EIGHT_ACTUAL_WORLD_DETAILS_PASS")
	quit()

extends SceneTree
## Native neighborhoods and before/after pixels for the real ground light pools.
func _initialize() -> void: call_deferred("run")

func capture(path: String) -> Image:
	for frame in range(8): await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image()
	assert(result.save_png(path)==OK)
	return result

func changed(a: Image, b: Image) -> Dictionary:
	var count := 0
	var delta := 0.0
	for y in range(0,a.get_height(),2):
		for x in range(0,a.get_width(),2):
			var first := a.get_pixel(x,y)
			var last := b.get_pixel(x,y)
			var amount := (last.r+last.g+last.b-first.r-first.g-first.b)/3
			if amount>.012:
				count += 1
				delta += amount
	return {"brighter_samples":count,"mean_delta":delta/maxi(1,count)}

func run() -> void:
	assert(DisplayServer.get_name()!="headless")
	Catalog.load_all()
	root.size = Vector2i(1280,720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	DisplayServer.window_move_to_foreground()
	var folder := "res://reports/district-detail-native"
	DirAccess.make_dir_recursive_absolute(folder)
	var rows: Array[Dictionary] = []
	for id: String in ["oasis_citadel","festival_speedway","aurora_harbor","lantern_market","neon_underpass"]:
		var track: TrackDefinition = Catalog.tracks.filter(func(item: TrackDefinition) -> bool: return item.id==id)[0]
		var world := TrackWorld.new()
		world.build(track)
		root.add_child(world)
		# Freeze other animated scenery so light-pool deltas isolate the effect.
		var settings := SettingsCatalog.defaults(false)
		settings.reduce_motion = true
		settings.vsync = false
		settings.frame_cap = 60
		SettingsRuntime.apply(world,settings)
		var camera := Camera3D.new()
		camera.current = true
		camera.far = 3000
		world.add_child(camera)
		if id in ["oasis_citadel","festival_speedway"]:
			var sites: Array = world.find_child("ExpansionLandscape",false,false).get_meta("sites")
			var buildings: Array = sites.filter(func(item: Dictionary) -> bool: return item.id=="district" and float(item.distance)>80 and float(item.distance)<240)
			var site: Dictionary = buildings[0]
			var best_count := 0
			for candidate: Dictionary in buildings:
				var count := 0
				for other: Dictionary in buildings:
					if candidate.at.distance_to(other.at)<120: count += 1
				if count>best_count:
					best_count = count
					site = candidate
			camera.global_position = site.at+Vector3(45,32,55)
			camera.look_at(site.at+Vector3.UP*8,Vector3.UP)
			await capture(folder+"/"+id+"-neighborhood.png")
		var result := {"track":id}
		if not world.lamp_glow_sites.is_empty():
			# Choose a straight approach, avoiding a curve crest hiding the patch.
			var chosen: Dictionary = world.lamp_glow_sites[0]
			var best := INF
			for site: Dictionary in world.lamp_glow_sites:
				var curvature := absf(float(track.bake.samples[track.sample_index(site.s)][6]))
				if curvature<best and site.s>100:
					best = curvature
					chosen = site
			var pose := track.pose(chosen.s-27,chosen.side*2)
			camera.global_position = pose.origin+Vector3.UP*6
			camera.look_at(track.pose(chosen.s+30).origin+Vector3.UP*2,Vector3.UP)
			var pools := world.find_children("StreetlightPools_*","MeshInstance3D",false,false)
			for node: MeshInstance3D in pools: node.visible = false
			var before := await capture(folder+"/"+id+"-unlit.png")
			for node: MeshInstance3D in pools: node.visible = true
			var after := await capture(folder+"/"+id+"-lit.png")
			result.merge(changed(before,after))
			result["route_s"] = chosen.s
			assert(int(result.brighter_samples)>100,"visible rendered pools on actual road: "+id)
		rows.append(result)
		world.queue_free()
		for frame in range(4): await process_frame
	var file := FileAccess.open(folder+"/native.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":true,"renderer":RenderingServer.get_current_rendering_method(),"resolution":[1280,720],"cases":rows,"boundary":"Native macOS rendering of actual worlds and fixed road cameras. Every second pixel; >0.012 mean RGB brightness increase. Other moving scenery frozen with Reduce Motion. Not Android runtime or performance acceptance."},"\t")+"\n")
	file.close()
	print("NATIVE_DISTRICT_SILHOUETTES_AND_ACTUAL_ROAD_LIGHT_POOL_PIXELS_PASS")
	quit()

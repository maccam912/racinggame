extends SceneTree
## Native scene photographs from explicitly chosen route locations.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	Catalog.load_all()
	root.size = Vector2i(1280,720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.msaa_3d = Viewport.MSAA_4X
	root.anisotropic_filtering_level = Viewport.ANISOTROPY_4X
	var output := "res://docs/evidence/authored-courses14"
	DirAccess.make_dir_recursive_absolute(output)
	var records: Array[Dictionary] = []
	for track: TrackDefinition in Catalog.tracks:
		var art := CourseArt.spec(track.id)
		if art.get("composition_version",0)!=14: continue
		var world := TrackWorld.new()
		world.build(track)
		root.add_child(world)
		var settings := SettingsCatalog.defaults(false)
		settings.draw_distance = 700
		settings.vsync = false
		SettingsRuntime.apply(world,settings)
		await physics_frame
		await physics_frame
		var camera := ChaseCamera.new()
		camera.reduce_motion = true
		camera.dynamic_fov = false
		camera.base_fov = 65
		camera.current = true
		camera.far = 3000
		world.add_child(camera)
		var s := CourseArt.original_s(track,float(art.preview_u))
		var pose := track.pose(s)
		var state := VehicleState.new()
		state.position = RouteGeometry.point(track,track.sample_index(s),0)+Vector3.UP*.35
		state.yaw = atan2(-pose.basis.z.x,pose.basis.z.z)
		var query := WorldQuery.new(world.get_world_3d(),track,s)
		state.ground_normal = query.ground(state).normal
		camera.follow(state,.016)
		for frame in range(8): await process_frame
		await RenderingServer.frame_post_draw
		var image_path := output+"/"+track.id+".png"
		assert(root.get_texture().get_image().save_png(image_path)==OK)
		root.size = Vector2i(512,288)
		for frame in range(8): await process_frame
		await RenderingServer.frame_post_draw
		var thumbnail := "res://assets/exported/thumbnails/"+track.id+".png"
		assert(root.get_texture().get_image().save_png(thumbnail)==OK)
		var landscape := world.get_node("ExpansionLandscape" if art.get("expansion40",false) else "LandscapeDistricts")
		records.append({"track":track.id,"u":art.preview_u,"s":s,"image":image_path,"image_sha256":FileAccess.get_sha256(image_path),"thumbnail_sha256":FileAccess.get_sha256(thumbnail),"route_hash":track.content_hash,"regions":landscape.get_meta("regions"),"sites":landscape.get_meta("sites").size()})
		print("AUTHORED_NATIVE_PHOTO ",track.id)
		query = null
		world.queue_free()
		root.size = Vector2i(1280,720)
		for frame in range(4): await process_frame
	assert(records.size()==33)
	FileAccess.open(output+"/native.json",FileAccess.WRITE).store_string(JSON.stringify({"content_hash":Compatibility.content_hash(),"renderer":RenderingServer.get_current_rendering_method(),"cases":records,"boundary":"Native macOS Compatibility Far Chase photographs, 65 degree FOV, 700 metre scenery. Actual shipped 512x288 images plus 1280x720 evidence. Static rendered composition; not a human driving or Android performance claim."},"\t")+"\n")
	print("THIRTY_THREE_AUTHORED_NATIVE_PHOTOGRAPHS_COMPLETE")
	quit()

extends SceneTree


func _initialize() -> void: call_deferred("run")


func run() -> void:
	Catalog.load_all()
	root.size = Vector2i(1920,1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.msaa_3d = Viewport.MSAA_4X
	root.anisotropic_filtering_level = Viewport.ANISOTROPY_4X
	var output := "res://reports" if "--ci" in OS.get_cmdline_user_args() else "res://docs/evidence"
	DirAccess.make_dir_recursive_absolute(output)
	var records: Array[Dictionary] = []
	for track: TrackDefinition in Catalog.tracks:
		var world := TrackWorld.new()
		world.build(track)
		root.add_child(world)
		var camera := ChaseCamera.new()
		camera.reduce_motion = true
		camera.dynamic_fov = false
		camera.base_fov = 65
		camera.far = 3000
		camera.current = true
		world.add_child(camera)
		var visual := CarVisual.new()
		visual.build(Catalog.paints[0],"comet")
		world.add_child(visual)
		for light: DirectionalLight3D in world.find_children("*","DirectionalLight3D",true,false):
			light.shadow_enabled = true
			light.directional_shadow_max_distance = 80
		for u: float in [.10,.35,.60,.85]:
			var s := CourseArt.original_s(track,u)
			var pose := track.pose(s)
			var state := VehicleState.new()
			state.position = RouteGeometry.point(track,track.sample_index(s),0)+Vector3.UP*.35
			state.yaw = atan2(-pose.basis.z.x,pose.basis.z.z)
			visual.present(state,InputFrame.make(),.016)
			camera.initialized = false
			camera.follow(state,.016)
			for frame in range(8): await process_frame
			await RenderingServer.frame_post_draw
			var filename := "m4-course-%s-u%02d.png"%[track.id,roundi(u*100)]
			assert(root.get_texture().get_image().save_png(output+"/"+filename)==OK)
			records.append({"track":track.id,"u":u,"s":s,"image":filename,"sha256":FileAccess.get_sha256(output+"/"+filename),"route_hash":track.content_hash})
		if "--write-thumbnails" in OS.get_cmdline_user_args():
			var anchor: Dictionary = CourseArt.spec(track.id).landmarks[[1,3,1,1,1,1][Catalog.tracks.find(track)]]
			var s := CourseArt.original_s(track,float(anchor.u))-75
			var pose := track.pose(s)
			var state := VehicleState.new()
			state.position = RouteGeometry.point(track,track.sample_index(s),0)+Vector3.UP*.35
			state.yaw = atan2(-pose.basis.z.x,pose.basis.z.z)
			camera.initialized = false
			camera.follow(state,.016)
			visual.hide()
			root.size = Vector2i(512,288)
			for frame in range(8): await process_frame
			await RenderingServer.frame_post_draw
			DirAccess.make_dir_recursive_absolute("res://assets/exported/thumbnails")
			root.get_texture().get_image().save_png("res://assets/exported/thumbnails/"+track.id+".png")
			root.size = Vector2i(1920,1080)
		world.queue_free()
		for frame in range(8): await process_frame
	var file := FileAccess.open(output+"/m4-course-references.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"resolution":[1920,1080],"camera":"Near Chase","fov":65,"hud":false,"preset":"Medium: 100%, 4x MSAA, Low shadows 80 m, 700 m scenery, 4x anisotropic","exposure":"Authored fixed course lighting; brightness/exposure 1.0","content_hash":Compatibility.content_hash(),"asset_hash":JSON.parse_string(FileAccess.get_file_as_string("res://assets/checksums.json")).asset_hash,"renderer":RenderingServer.get_current_rendering_method(),"physical_device":false,"records":records},"\t")+"\n")
	file.close()
	print("SIX_COURSE_24_NATIVE_REFERENCE_VIEWS_PASS")
	quit()

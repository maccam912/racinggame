extends SceneTree
func _initialize() -> void: call_deferred("run")
func capture() -> Image:
	for frame in range(8): await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()
func changed(a: Image, b: Image) -> int:
	var count := 0
	for y in range(0,a.get_height(),2):
		for x in range(0,a.get_width(),2):
			var p := a.get_pixel(x,y)
			var q := b.get_pixel(x,y)
			if maxf(absf(p.r-q.r),maxf(absf(p.g-q.g),absf(p.b-q.b)))>.015: count += 1
	return count
func run() -> void:
	assert(DisplayServer.get_name()!="headless")
	Catalog.load_all()
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	DisplayServer.window_move_to_foreground()
	DirAccess.make_dir_recursive_absolute("res://reports/watercraft-native")
	var planner := ExpansionWatercraft
	var rows: Array[Dictionary] = []
	var all_visible := true
	for id: String in planner.SPECS:
		var track: TrackDefinition = Catalog.tracks.filter(func(t: TrackDefinition) -> bool: return t.id==id)[0]
		var world := TrackWorld.new()
		world.build(track)
		root.add_child(world)
		var settings := SettingsCatalog.defaults(false)
		settings.reduce_motion = true
		settings.vsync = false
		settings.frame_cap = 60
		SettingsRuntime.apply(world,settings)
		var sites: Array = world.watercraft_sites
		assert(sites.size()==planner.SPECS[id].sites.size())
		var boats := world.find_children("Watercraft_*","MeshInstance3D",false,false)
		var camera := ChaseCamera.new()
		camera.reduce_motion = true
		camera.dynamic_fov = false
		camera.base_fov = 65
		camera.far = 3000
		camera.current = true
		world.add_child(camera)
		var car := CarVisual.new()
		car.build(Catalog.paints[0],"comet")
		world.add_child(car)
		await physics_frame
		await physics_frame
		var query := WorldQuery.new(world.get_world_3d(),track)
		for index in range(sites.size()):
			var site: Dictionary = sites[index]
			var prefix := "res://reports/watercraft-native/"+id+"-"+str(index)
			var best := -1
			var selected := 0.0
			var first: Image
			var last: Image
			for distance: float in [float(site.approach_distance),float(site.approach_distance)+80,float(site.approach_distance)-60,160.0,120.0]:
				for boat: MeshInstance3D in boats: boat.hide()
				var s := float(site.s)-distance
				var pose := track.pose(s)
				var state := VehicleState.new()
				state.position = RouteGeometry.point(track,track.sample_index(s),0)+Vector3.UP*.35
				state.yaw = atan2(-pose.basis.z.x,pose.basis.z.z)
				state.ground_normal = query.ground(state).normal
				car.show()
				car.present(state,InputFrame.make(),.016)
				camera.initialized = false
				camera.follow(state,.016)
				var before := await capture()
				boats[index].show()
				var after := await capture()
				var count := changed(before,after)
				if count>best:
					best = count
					selected = distance
					first = before
					last = after
			if best<=30: all_visible = false
			assert(first.save_png(prefix+"-road-before.png")==OK and last.save_png(prefix+"-road-after.png")==OK)
			car.hide()
			camera.global_position = site.pose*Vector3(50,24,62)
			camera.look_at(site.pose*Vector3(0,7,0),Vector3.UP)
			var close := await capture()
			assert(close.save_png(prefix+"-close.png")==OK)
			# Freeze every other motion source; only this actual boat animates.
			boats[index].material_override.set_shader_parameter("animation_enabled",1.0)
			var moving_first := await capture()
			for frame in range(45): await process_frame
			var moving_second := await capture()
			for frame in range(37): await process_frame
			var moving_third := await capture()
			var moving := maxi(changed(moving_first,moving_second),changed(moving_first,moving_third))
			assert(moving>30,"the boat itself moves while ocean and other scenery stay frozen")
			assert(moving_first.save_png(prefix+"-moving-before.png")==OK and moving_second.save_png(prefix+"-moving-after.png")==OK)
			SettingsRuntime.apply(world,settings)
			var reduced_first := await capture()
			for frame in range(45): await process_frame
			var reduced_second := await capture()
			for frame in range(37): await process_frame
			var reduced_third := await capture()
			var reduced := maxi(changed(reduced_first,reduced_second),changed(reduced_first,reduced_third))
			assert(reduced==0,"Reduce Motion freezes all boat pixels")
			assert(reduced_first.save_png(prefix+"-reduced-before.png")==OK and reduced_second.save_png(prefix+"-reduced-after.png")==OK)
			rows.append({"track":id,"index":index,"kind":site.kind,"approach_distance_m":selected,"changed_samples":best,"moving_changed_samples":moving,"reduced_changed_samples":reduced})
			print("WATERCRAFT_NATIVE ",JSON.stringify(rows[-1]))
		world.queue_free()
		for frame in range(4): await process_frame
	var file := FileAccess.open("res://reports/watercraft-native/native.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":all_visible,"content_hash":Compatibility.content_hash(),"asset_hash":JSON.parse_string(FileAccess.get_file_as_string("res://assets/checksums.json")).asset_hash,"renderer":RenderingServer.get_current_rendering_method(),"cases":rows},"\t")+"\n")
	file.close()
	print("SEVEN_BOATS_REAL_FAR_CHASE_VIEWS_GPU_MOTION_REDUCE_MOTION_", "PASS" if all_visible else "FAIL")
	quit(0 if all_visible else 1)

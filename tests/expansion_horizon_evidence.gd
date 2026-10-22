extends SceneTree
## Paired native views isolate skyline changes from current terrain and scenery.
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

func frame_view(camera: Camera3D, track: TrackDefinition, fraction: float) -> Dictionary:
	var pose := track.pose(track.length*fraction)
	camera.global_position = pose.origin+pose.basis.z*14+Vector3.UP*18
	var target := pose.origin-pose.basis.z*180+Vector3.UP*12
	camera.look_at(target,Vector3.UP)
	return {"route_fraction":fraction,"position":[camera.global_position.x,camera.global_position.y,camera.global_position.z],"target":[target.x,target.y,target.z]}

func run() -> void:
	assert(DisplayServer.get_name()!="headless")
	Catalog.load_all()
	root.mode = Window.MODE_WINDOWED
	root.size = Vector2i(1280,720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	DisplayServer.window_move_to_foreground()
	var legacy := load("res://tests/fixtures/presentation13/legacy_horizon.gd")
	var output := "res://reports/horizon-native"
	DirAccess.make_dir_recursive_absolute(output)
	var rows: Array[Dictionary] = []
	var fractions: Array[float] = [.12,.37,.62,.87]
	for track: TrackDefinition in Catalog.tracks.slice(10):
		var world := TrackWorld.new()
		world.build(track)
		root.add_child(world)
		var settings := SettingsCatalog.defaults(false)
		settings.reduce_motion = true
		settings.vsync = false
		settings.frame_cap = 60
		settings.draw_distance = 700
		SettingsRuntime.apply(world,settings)
		var camera := Camera3D.new()
		camera.current = true
		camera.far = 3000
		camera.fov = 65
		world.add_child(camera)
		var new_horizon := world.get_node("LandscapeHorizon") as MeshInstance3D
		assert(new_horizon.has_meta("profile"))
		world.remove_child(new_horizon)
		legacy.build(world)
		var before: Array[Image] = []
		var views: Array[Dictionary] = []
		for fraction: float in fractions:
			views.append(frame_view(camera,track,fraction))
			before.append(await capture())
		var old_horizon := world.get_node("LandscapeHorizon")
		world.remove_child(old_horizon)
		old_horizon.free()
		world.add_child(new_horizon)
		var counts: Array[int] = []
		var best := -1
		var best_index := 0
		var after: Image
		for index in range(fractions.size()):
			frame_view(camera,track,fractions[index])
			var shot := await capture()
			var pixels := changed(before[index],shot)
			counts.append(pixels)
			if pixels>best:
				best = pixels
				best_index = index
				after = shot
		assert(best>100,"a regional skyline must change a visible regular road-approach view: "+track.id)
		var first_path := output+"/"+track.id+"-before.png"
		var last_path := output+"/"+track.id+"-after.png"
		assert(before[best_index].save_png(first_path)==OK and after.save_png(last_path)==OK)
		rows.append({"track":track.id,"profile":new_horizon.get_meta("profile"),"candidate_changed_samples":counts,"changed_samples":best,"selected_view":views[best_index],"before_sha256":FileAccess.get_sha256(first_path),"after_sha256":FileAccess.get_sha256(last_path)})
		print("NATIVE_REGIONAL_SKYLINE ",track.id," changed=",best," candidate=",best_index)
		world.queue_free()
		for frame in range(4): await process_frame
	var file := FileAccess.open(output+"/native.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":true,"renderer":RenderingServer.get_current_rendering_method(),"resolution":[1280,720],"content_hash":Compatibility.content_hash(),"source_sha256":FileAccess.get_sha256("res://game/world/expansion_horizon.gd"),"legacy_sha256":FileAccess.get_sha256("res://tests/fixtures/presentation13/legacy_horizon.gd"),"camera_far_m":3000,"cases":rows,"boundary":"Thirty paired native comparisons isolate only the horizon mesh, using the frozen legacy helper verified against actual pre-change meshes. Both halves share the current world and Reduce Motion freezes ambient/water. Choose the largest pixel change among four fixed regular road approaches at 12/37/62/87 percent distance, from a diagnostic camera 18 m above the road, FOV65 and the actual 3000 m race far plane. Candidate counts are retained. Ordinary Far Chase hero approaches are separate. Native macOS Compatibility, not Android runtime or frame-time acceptance."},"\t")+"\n")
	file.close()
	print("NATIVE_THIRTY_REGIONAL_SKYLINE_COMPARISONS_PASS")
	quit()

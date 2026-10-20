extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	Catalog.load_all()
	var hash := Compatibility.content_hash()
	var shaders: Dictionary = {}
	var maximum := 0
	for track: TrackDefinition in Catalog.tracks:
		var world := TrackWorld.new()
		world.build(track)
		var warm := ShaderWarmup.new()
		warm.prepare(world,SettingsCatalog.defaults(true))
		assert(world.get_parent()==null and not world.is_inside_tree(),"GPU preparation does not register or move the race's collision world")
		assert(warm.viewport.own_world_3d and not warm.viewport.audio_listener_enable_3d and warm.viewport.msaa_3d==Viewport.MSAA_2X)
		assert(warm.find_children("*","CollisionObject3D",true,false).is_empty(),"material submissions contain no physics bodies")
		assert(warm.submissions>20 and warm.submissions<256 and warm.rendered_frames==0)
		assert(warm.scene.find_children("*","MultiMeshInstance3D",true,false).size()>=3,"instanced effects compile their actual instance-color format")
		var models := 0
		for resource: Resource in warm.retained_resources:
			if resource is PackedScene: models += 1
		assert(models==4,"all car model resources remain owned through the race")
		for path: String in warm.shader_paths: shaders[path] = true
		maximum = maxi(maximum,warm.submissions)
		warm.cancel()
		warm.after_draw()
		assert(warm.cancelled and not warm.finished and warm.rendered_frames==0)
		warm.free()
		world.free()
	for file: String in DirAccess.get_files_at("res://assets/exported/shaders"):
		if file.get_extension()=="gdshader": assert(shaders.has("res://assets/exported/shaders/"+file),"required shipped shader has a warm submission: "+file)
	assert(hash==Compatibility.content_hash() and Engine.physics_ticks_per_second==60)
	var job := TrackLoader.new()
	job.begin(Catalog.tracks[0])
	while not job.done: job._process(0)
	assert(job.warm_evidence.gpu_warmed==false and job.world.warmed_resources.is_empty(),"headless loading never claims GPU work")
	job.cancel()
	job.free()
	await process_frame
	print("SHADER_WARM_ALL_EIGHT_TRACKS_ALL_SHIPPED_SHADERS_FOUR_CAR_RESOURCES_INSTANCING_NO_PHYSICS_CANCEL_HEADLESS_BOUNDARY_PASS shaders="+str(shaders.size())+" max_submissions="+str(maximum))
	quit()

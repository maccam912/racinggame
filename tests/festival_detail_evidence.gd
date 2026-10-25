extends SceneTree
## Actual fairground models and their road approach, without altering placement.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	assert(DisplayServer.get_name()!="headless")
	Catalog.load_all()
	root.size = Vector2i(1280,720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var track: TrackDefinition = Catalog.tracks.filter(func(t: TrackDefinition) -> bool: return t.id=="festival_speedway")[0]
	var world := TrackWorld.new()
	world.build(track)
	root.add_child(world)
	var settings := SettingsCatalog.defaults(false)
	settings.reduce_motion = true
	SettingsRuntime.apply(world,settings)
	var camera := Camera3D.new()
	camera.current = true
	camera.far = 1500
	world.add_child(camera)
	for kind: String in ["festival_tent","festival_stall"]:
		var candidates := world.find_children("*","MeshInstance3D",true,false).filter(func(n: MeshInstance3D) -> bool: return n.get_meta("module","")==kind)
		assert(not candidates.is_empty())
		var node: MeshInstance3D = candidates[0]
		camera.global_position = node.global_transform*Vector3(23,13,34)
		camera.look_at(node.global_transform*Vector3(0,6,0))
		for frame in range(8): await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("res://reports/"+kind+"-detail.png")==OK)
		var road := AuthoredCourseScenery.nearest(world,node.global_position)
		var pose := track.pose(float(road.s)-280)
		camera.global_position = pose.origin+Vector3.UP*4
		camera.look_at(track.pose(float(road.s)+80).origin+Vector3.UP*2)
		for frame in range(8): await process_frame
		await RenderingServer.frame_post_draw
		assert(root.get_texture().get_image().save_png("res://reports/"+kind+"-road.png")==OK)
	print("FESTIVAL_NATIVE_MODELS_AND_ACTUAL_ROAD_APPROACH_CAPTURED")
	quit()

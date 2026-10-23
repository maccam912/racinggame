extends SceneTree
## Preview clearance across every car and orbit, with an independent racing world.
var captures: Array[Dictionary] = []

func _initialize() -> void: call_deferred("run")

func census(world: Node3D, center: Vector3) -> Dictionary:
	var result := {"near":0,"visible":0,"batches":0,"palms_near":0,"footprints_near":0,"nearest_distance":INF,"nearest_name":"","nearest_point":Vector3.ZERO,"center":center}
	for batch: MultiMeshInstance3D in world.find_children("*","MultiMeshInstance3D",true,false):
		var count := batch.multimesh.visible_instance_count
		if count<0: count = batch.multimesh.instance_count
		result.visible += count
		result.batches += 1
		for index in range(count):
			var at := batch.global_transform*batch.multimesh.get_instance_transform(index).origin
			var distance := Vector2(at.x-center.x,at.z-center.z).length()
			if distance<float(result.nearest_distance):
				result.nearest_distance = distance
				result.nearest_name = str(batch.name)
				result.nearest_point = at
			if distance<14:
				result.near += 1
				if batch.name.begins_with("IllustratedBillboard_palm"): result.palms_near += 1
				if batch.name.begins_with("BillboardFootprint_"): result.footprints_near += 1
	return result

func run() -> void:
	Catalog.load_all()
	assert(DisplayServer.get_name()!="headless","Actual MultiMesh transforms require a native renderer, not the dummy headless backend")
	var render := "--render" in OS.get_cmdline_user_args()
	if render:
		assert(DisplayServer.get_name()!="headless")
		root.size = Vector2i(1920,1080)
		root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
		root.content_scale_size = Vector2i(1280,720)
	var original := TrackWorld.new()
	original.build(Catalog.tracks[0])
	var original_scope := SubViewport.new()
	original_scope.own_world_3d = true
	root.add_child(original_scope)
	original_scope.add_child(original)
	var center := Catalog.tracks[0].pose(45,27).origin
	var before := census(original,center)
	var stage := MenuStage.new()
	stage.reduce_motion = true
	root.add_child(stage)
	stage.set_process(false)
	original.visible = false
	await process_frame
	await RenderingServer.frame_post_draw
	before = census(original,center)
	var cleared := census(stage,center)
	var unchanged := census(original,center)==before
	var passed: bool = cleared.near==0 and cleared.visible>0 and unchanged
	if render:
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://reports/menu-stage"))
		for car_index in range(Catalog.cars.size()):
			stage.set_selection(car_index,(car_index*2)%Catalog.paints.size())
			for angle_index in range(8):
				stage.rotation_offset = angle_index*TAU/8
				stage._process(0)
				for frame in range(3): await process_frame
				await RenderingServer.frame_post_draw
				var path := "res://reports/menu-stage/%s-%d.png"%[Catalog.cars[car_index].id,angle_index]
				var pixels := root.get_texture().get_image()
				assert(pixels.save_png(path)==OK)
				captures.append({"car":Catalog.cars[car_index].id,"paint":(car_index*2)%Catalog.paints.size(),"angle_radians":stage.camera.rotation.y,"path":path,"width":pixels.get_width(),"height":pixels.get_height()})
	var file := FileAccess.open("res://reports/menu-stage.json",FileAccess.WRITE)
	assert(file!=null)
	file.store_string(JSON.stringify({"passed":passed,"racing_world_before":before,"preview_after":cleared,"independent_racing_world_unchanged":unchanged,"captures":captures,
		"boundary":"Real menu-stage world, instanced cutout foliage/footprints and optional native 360-degree views of all eight cars. Preview-only clearance; no driving geometry, car state or active track placement changes."},"\t")+"\n")
	file.close()
	stage.queue_free()
	original_scope.queue_free()
	await process_frame
	if passed: print("PREVIEW_TURNOUT_CLEAR_BILLBOARDS_FOOTPRINTS_ALL_CARS_RACING_WORLD_UNCHANGED_PASS")
	else: print("TEST FAIL: preview car/turnout contains nearby scenery: ",cleared)
	quit(0 if passed else 1)

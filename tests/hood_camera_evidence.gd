extends SceneTree
## Native raster checks of the actual model silhouette, plus normal course views.
func _initialize() -> void: call_deferred("run")

func run() -> void:
	Catalog.load_all()
	root.size = Vector2i(1280,720)
	root.msaa_3d = Viewport.MSAA_4X
	DirAccess.make_dir_recursive_absolute("res://reports/hood-cameras")
	var rows: Array[Dictionary] = []
	var captures: Array[Dictionary] = []
	var passed := true
	for car: CarDefinition in Catalog.cars:
		var scene := Node3D.new()
		root.add_child(scene)
		var environment := WorldEnvironment.new()
		environment.environment = Environment.new()
		environment.environment.background_mode = Environment.BG_COLOR
		environment.environment.background_color = Color.BLACK
		scene.add_child(environment)
		var visual := CarVisual.new()
		visual.build(Catalog.paints[car.default_paint],car.mesh_id)
		scene.add_child(visual)
		visual.shadow.hide()
		var white := StandardMaterial3D.new()
		white.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		white.albedo_color = Color.WHITE
		for mesh: MeshInstance3D in visual.body_meshes: mesh.material_override = white
		for label: Label3D in visual.number_labels: label.hide()
		var state := VehicleState.new()
		state.position = Vector3(0,.35,0)
		visual.present(state,InputFrame.make(),0)
		var camera := ChaseCamera.new()
		camera.mode = 2
		camera.dynamic_fov = false
		camera.current = true
		camera.hood_profiles = visual.hood_profiles
		scene.add_child(camera)
		for rear in [false,true]:
			for degrees: float in [55.0,65.0,75.0,85.0,95.0]:
				camera.base_fov = degrees
				camera.look_blend = 1.0 if rear else 0.0
				camera.initialized = false
				camera.follow(state,1.0/60,rear)
				for frame in range(4): await process_frame
				await RenderingServer.frame_post_draw
				var image := root.get_texture().get_image()
				var first := image.get_height()
				for x in range(634,646):
					for y in range(image.get_height()):
						if image.get_pixel(x,y).r>.8:
							first = mini(first,y)
							break
				var fraction := 1.0-float(first)/image.get_height()
				var valid := fraction>=.085 and fraction<=.115
				passed = passed and valid
				rows.append({"car":car.id,"look_back":rear,"fov":degrees,"hood_fraction":fraction,"eye_forward_m":absf(camera.position.z),"envelope_points":visual.hood_profiles[1 if rear else 0].size(),"passed":valid})
				if not valid:
					var failed_name := car.id+"-"+("rear" if rear else "front")+"-fov%d-failed.png"%roundi(degrees)
					assert(image.save_png("res://reports/hood-cameras/"+failed_name)==OK)
					rows[-1]["failure_png"] = failed_name
				if degrees==65:
					var name := car.id+("-rear-mask.png" if rear else "-front-mask.png")
					assert(image.save_png("res://reports/hood-cameras/"+name)==OK)
		scene.queue_free()
		await process_frame
	var world := TrackWorld.new()
	var track: TrackDefinition = Catalog.tracks[0]
	world.build(track)
	root.add_child(world)
	await physics_frame
	await physics_frame
	var query := WorldQuery.new(world.get_world_3d(),track)
	var s := CourseArt.original_s(track,.10)
	var pose := track.pose(s)
	var state := VehicleState.new()
	state.position = RouteGeometry.point(track,track.sample_index(s),0)+Vector3.UP*.35
	state.yaw = atan2(-pose.basis.z.x,pose.basis.z.z)
	state.ground_normal = query.ground(state).normal
	for car: CarDefinition in Catalog.cars:
		var visual := CarVisual.new()
		visual.build(Catalog.paints[car.default_paint],car.mesh_id)
		world.add_child(visual)
		visual.present(state,InputFrame.make(),0)
		var camera := ChaseCamera.new()
		camera.mode = 2
		camera.dynamic_fov = false
		camera.current = true
		camera.hood_profiles = visual.hood_profiles
		world.add_child(camera)
		for degrees: float in [65.0,83.0,95.0]:
			camera.base_fov = degrees
			camera.initialized = false
			camera.follow(state,1.0/60)
			for frame in range(6): await process_frame
			await RenderingServer.frame_post_draw
			var name := car.id+"-fov%d.png"%roundi(degrees)
			var path := "res://reports/hood-cameras/"+name
			assert(root.get_texture().get_image().save_png(path)==OK)
			captures.append({"car":car.id,"fov":degrees,"png":name,"sha256":FileAccess.get_sha256(path),"synthetic_pose":true,"track":track.id,"u":.10})
		camera.queue_free()
		visual.queue_free()
		await process_frame
	query = null
	world.queue_free()
	await process_frame
	var file := FileAccess.open("res://reports/hood-cameras/summary.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":passed,"cases":rows,"captures":captures,"boundary":"Actual native raster silhouette at the screen centre, four unmodified LOD0 car models, five FOVs and both settled view directions. Flat stationary geometry isolates hood framing. Course pictures use a labelled synthetic static Palm Bay pose, not ordinary driving telemetry or performance evidence."},"\t")+"\n")
	file.close()
	if passed: print("FOUR_REAL_MODELS_FIVE_FOVS_FRONT_REAR_TEN_PERCENT_HOOD_NATIVE_RASTER_PASS")
	else: print("TEST FAIL: native hood raster framing; inspect reports/hood-cameras/summary.json")
	quit(0 if passed else 1)

extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	Catalog.load_all()
	root.size = Vector2i(1280,960)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var canvas := Control.new()
	root.add_child(canvas)
	var first_world: Node3D
	var first_viewport: SubViewport
	for index in range(4):
		var viewport := SubViewport.new()
		viewport.size = Vector2i(640,480)
		viewport.own_world_3d = true
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		viewport.msaa_3d = Viewport.MSAA_4X
		canvas.add_child(viewport)
		var world := Node3D.new()
		viewport.add_child(world)
		if index==0:
			first_world = world
			first_viewport = viewport
		var environment := WorldEnvironment.new()
		environment.environment = Environment.new()
		environment.environment.background_mode = Environment.BG_COLOR
		environment.environment.background_color = Color("65B9EB")
		environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		environment.environment.ambient_light_color = Color("B9E6ED")
		environment.environment.ambient_light_energy = .7
		world.add_child(environment)
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-45,-30,0)
		sun.light_color = Color("FFF1D2")
		world.add_child(sun)
		var plane := MeshInstance3D.new()
		var geometry := PlaneMesh.new()
		geometry.size = Vector2(200,200)
		plane.mesh = geometry
		var material := StandardMaterial3D.new()
		material.albedo_color = Color("F3E4C4")
		material.roughness = .9
		plane.material_override = material
		world.add_child(plane)
		var visual := CarVisual.new()
		visual.build(Catalog.paints[Catalog.cars[index].default_paint],Catalog.cars[index].mesh_id,index)
		world.add_child(visual)
		var state := VehicleState.new()
		state.position.y = .35
		visual.present(state,InputFrame.make(),.016)
		var camera := Camera3D.new()
		world.add_child(camera)
		camera.position = Vector3(4,2.6,5.7)
		camera.look_at(Vector3(0,.85,0))
		camera.fov = 35
		camera.current = true
		var image := TextureRect.new()
		image.texture = viewport.get_texture()
		image.position = Vector2((index%2)*640,(index/2)*480)
		image.size = Vector2(640,480)
		canvas.add_child(image)
		var label := Label.new()
		label.text = I18n.t("car."+Catalog.cars[index].id)+" · original LOD0"
		label.position = image.position+Vector2(22,18)
		label.add_theme_font_override("font",load("res://assets/fonts/BarlowCondensed-Bold.ttf"))
		label.add_theme_font_size_override("font_size",28)
		label.add_theme_color_override("font_color",Color("172C40"))
		canvas.add_child(label)
	for index in range(12): await process_frame
	await RenderingServer.frame_post_draw
	var output := "res://reports/m4-original-cars.png" if "--ci" in OS.get_cmdline_user_args() else "res://docs/evidence/m4-original-cars.png"
	root.get_texture().get_image().save_png(output)
	var ghost := CarVisual.new()
	ghost.build(Catalog.paints[0],"comet")
	ghost.set_ghost(.35)
	first_world.add_child(ghost)
	var state := VehicleState.new()
	state.position = Vector3(-1.4,.35,-.8)
	ghost.present(state,InputFrame.make(),.016)
	for index in range(6): await process_frame
	await RenderingServer.frame_post_draw
	first_viewport.get_texture().get_image().save_png("res://reports/m4-car-ghost.png" if "--ci" in OS.get_cmdline_user_args() else "res://docs/evidence/m4-car-ghost.png")
	canvas.queue_free()
	for index in range(6): await process_frame
	if "--game-ui" in OS.get_cmdline_user_args():
		await capture_game_ui()
	print("FOUR_ORIGINAL_CARS_NATIVE_RENDER_PASS")
	quit()


func capture_game_ui() -> void:
	root.size = Vector2i(1920,1080)
	var app: Node = load("res://game/client_app.gd").new()
	app.capture_path = "user://unused-m4-cars.png"
	app.capture_frame = 1000000
	root.add_child(app)
	await process_frame
	var folder := "user://tests/m4-car-evidence-"+RaceSetup.uuid()
	app.data = AppData.new(folder,false)
	app.data.settings.reduce_motion = true
	app.menu.settings = app.data.settings
	for index in range(4):
		app.data.profile.selected_car = index
		app.data.profile.selected_paint = Catalog.cars[index].default_paint
		app.show_garage()
		assert(app.stage.car.model_id==Catalog.cars[index].mesh_id)
		for frame in range(8): await process_frame
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png("res://reports/m4-garage-"+Catalog.cars[index].id+".png")
	app.start_drive({"mode":"quick","track":0,"car":3,"paint":3,"opponents":7})
	app.drive.set_physics_process(false)
	assert(app.drive.visual.model_id=="sunset")
	for index in range(8):
		var state: VehicleState = app.drive.session.states[index]
		state.position = app.drive.track.pose(40+index*9, -3 if index%2==0 else 3).origin+Vector3.UP*.35
		state.yaw = app.drive.track.pose(40+index*9).basis.get_euler().y
	app.drive._process(.016)
	for frame in range(16): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/m4-cars-race.png")
	app.queue_free()
	for frame in range(8): await process_frame
	assert(AppData.remove_tree(ProjectSettings.globalize_path(folder))==OK)

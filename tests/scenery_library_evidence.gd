extends SceneTree


func _initialize() -> void: call_deferred("run")


func run() -> void:
	CourseArt.load_catalog()
	root.size = Vector2i(1920,1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	for category: String in ["landmarks","shared"]:
		var canvas := Control.new()
		root.add_child(canvas)
		var models: Array[Node3D] = []
		var index: int = 0
		var columns := 6 if category=="landmarks" else 5
		var pixels := Vector2i(320,216) if category=="landmarks" else Vector2i(384,270)
		for id: String in CourseArt.library:
			var row: Dictionary = CourseArt.library[id]
			if (row.category=="landmark")!=(category=="landmarks"): continue
			var viewport := SubViewport.new()
			viewport.size = pixels
			viewport.own_world_3d = true
			viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
			viewport.msaa_3d = Viewport.MSAA_2X
			canvas.add_child(viewport)
			var scene := Node3D.new()
			viewport.add_child(scene)
			var environment := WorldEnvironment.new()
			environment.environment = Environment.new()
			environment.environment.background_mode = Environment.BG_COLOR
			environment.environment.background_color = Color("B9E6ED")
			environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			environment.environment.ambient_light_color = Color.WHITE
			environment.environment.ambient_light_energy = .45
			scene.add_child(environment)
			var sun := DirectionalLight3D.new()
			sun.rotation_degrees = Vector3(-45,-30,0)
			sun.light_energy = .75
			scene.add_child(sun)
			var model := CourseArt.model(id,.15)
			scene.add_child(model)
			models.append(model)
			var bounds := AABB()
			var first := true
			for node: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
				if CourseArt.level_of(str(node.name))==0:
					bounds = node.get_aabb() if first else bounds.merge(node.get_aabb())
					first = false
			var target := bounds.get_center()
			var size := maxf(bounds.size.x,maxf(bounds.size.y,bounds.size.z))
			var camera := Camera3D.new()
			scene.add_child(camera)
			camera.position = target+Vector3(.75,.45,1.4)*size
			camera.look_at(target)
			camera.fov = 40
			camera.current = true
			var image := TextureRect.new()
			image.texture = viewport.get_texture()
			image.position = Vector2(index%columns*pixels.x,index/columns*pixels.y)
			image.size = pixels
			canvas.add_child(image)
			var label := Label.new()
			label.position = image.position+Vector2(8,4)
			label.text = id.replace("_"," ")
			label.add_theme_font_override("font",load("res://assets/fonts/BarlowCondensed-Bold.ttf"))
			label.add_theme_font_size_override("font_size",22)
			label.add_theme_color_override("font_color",Color("172C40"))
			canvas.add_child(label)
			index += 1
		for level in [0,1,2]:
			for model: Node3D in models:
				for node: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
					node.visible = CourseArt.level_of(str(node.name))==level
					node.visibility_range_begin = 0
					node.visibility_range_end = 0
			for frame in range(8): await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://reports/m4-"+category+"-library-lod"+str(level)+".png")
		canvas.queue_free()
		for frame in range(8): await process_frame
	print("SCENERY_ORIGINAL_LIBRARY_NATIVE_THREE_LODS_AND_SILHOUETTES_PASS")
	quit()

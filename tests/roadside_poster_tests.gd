extends SceneTree


func _initialize() -> void: call_deferred("run")


func run() -> void:
	Catalog.load_all()
	RoadsidePosterArt.load_catalog()
	assert(RoadsidePosterArt.rows.size()==Catalog.tracks.size())
	root.size = Vector2i(1280,720)
	root.msaa_3d = Viewport.MSAA_4X
	DirAccess.make_dir_recursive_absolute("res://reports/posters")
	var records: Array[Dictionary] = []
	var content_before := Compatibility.content_hash()
	for track: TrackDefinition in Catalog.tracks:
		var row: Dictionary = RoadsidePosterArt.rows[track.id]
		assert(FileAccess.get_sha256("res://"+str(row.source))==row.sha256)
		assert(FileAccess.get_sha256("res://"+str(row.path))==row.sha256)
		var texture: Texture2D = load("res://"+str(row.path))
		var pixels := texture.get_image()
		assert(pixels.get_size()==Vector2i(1536,1024) and pixels.has_mipmaps())
		for y in range(0,1024,32):
			for x in range(0,1536,32): assert(pixels.get_pixel(x,y).a>.999)
		var world := TrackWorld.new()
		world.build(track)
		root.add_child(world)
		var posters := world.find_children("RoadsidePoster_*","Node3D",false,false)
		assert(posters.size()==3,"three clear travel-sign sites must be available on every course")
		for poster: Node3D in posters:
			assert(world.clear_of_road(poster.position,7),"all sign geometry stays outside the drivable route")
			assert(poster.find_children("*","CollisionObject3D",true,false).is_empty())
			var front := poster.get_node("PaintedFront") as MeshInstance3D
			assert(front.mesh is QuadMesh and front.mesh.size==Vector2(12,8))
			assert(front.material_override.albedo_texture==texture)
			assert(front.material_override.billboard_mode==BaseMaterial3D.BILLBOARD_DISABLED,"painted sign faces stay fixed on their 3D frame")
			assert(front.material_override.cull_mode==BaseMaterial3D.CULL_BACK)
			assert(front.visibility_range_end==700 and front.is_in_group("scenery_distance"))
		var image_path := ""
		if DisplayServer.get_name()!="headless":
			await physics_frame
			await physics_frame
			var camera := ChaseCamera.new()
			camera.current = true
			camera.reduce_motion = true
			camera.dynamic_fov = false
			camera.base_fov = 65
			world.add_child(camera)
			var s := float(posters[0].get_meta("route_s"))-46
			var pose := track.pose(s)
			var state := VehicleState.new()
			state.position = pose.origin+Vector3.UP*.35
			state.yaw = atan2(-pose.basis.z.x,pose.basis.z.z)
			var query := WorldQuery.new(world.get_world_3d(),track,s)
			state.ground_normal = query.ground(state).normal
			camera.follow(state,1.0/60)
			for frame in range(4): await process_frame
			await RenderingServer.frame_post_draw
			image_path = "res://reports/posters/"+track.id+".png"
			assert(root.get_texture().get_image().save_png(image_path)==OK)
			query = null
		RoadsidePosterArt.release_cache()
		assert(RoadsidePosterArt.materials.is_empty() and RoadsidePosterArt.frame_material==null)
		for poster: Node3D in posters:
			assert(is_instance_valid(poster.get_node("PaintedFront").material_override.albedo_texture),"active signs retain their texture after a memory-pressure cache release")
		records.append({"track":track.id,"posters":posters.size(),"sha256":row.sha256,"image":image_path,"image_sha256":FileAccess.get_sha256(image_path) if not image_path.is_empty() else ""})
		world.queue_free()
		for frame in range(2): await process_frame
	assert(content_before==Compatibility.content_hash())
	var file := FileAccess.open("res://reports/posters/"+("headless" if DisplayServer.get_name()=="headless" else "native")+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":true,"content_hash":content_before,"asset_hash":JSON.parse_string(FileAccess.get_file_as_string("res://assets/checksums.json")).asset_hash,"backend":DisplayServer.get_name(),"boundary":"Static posed native views and asset/placement checks, not human readability or device performance","cases":records},"\t")+"\n")
	file.close()
	print("EIGHT_ORIGINAL_POSTERS_24_CLEAR_STATIC_FRAMES_MIPMAPS_HASHES_ACTIVE_TEXTURES_NO_COLLISION_PASS")
	quit()

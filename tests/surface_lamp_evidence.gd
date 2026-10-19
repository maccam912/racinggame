extends SceneTree

func _initialize() -> void: call_deferred("run")

func run() -> void:
	Catalog.load_all()
	root.size = Vector2i(1920,1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.msaa_3d = Viewport.MSAA_4X
	var world := TrackWorld.new()
	var track := Catalog.tracks[5]
	world.build(track)
	root.add_child(world)
	var camera := ChaseCamera.new()
	camera.reduce_motion = true
	camera.dynamic_fov = false
	camera.base_fov = 65
	camera.current = true
	world.add_child(camera)
	var visual := CarVisual.new()
	visual.build(Catalog.paints[0],"comet")
	world.add_child(visual)
	var records: Array[Dictionary] = []
	for row: Array in [["grass",.68,false],["sand",.71,false],["brake-on",.80,true],["brake-off",.80,false],["grass-after",.92,false]]:
		var s := CourseArt.original_s(track,row[1])
		var pose := track.pose(s)
		var state := VehicleState.new()
		state.position = RouteGeometry.point(track,track.sample_index(s),0)+Vector3.UP*.35
		state.yaw = atan2(-pose.basis.z.x,pose.basis.z.z)
		state.braking = row[2]
		# Round trip actual authority; the visual gets no input frame from a rival.
		var session := RaceSession.new()
		session.states = [state]
		var restored: VehicleState = NetCodec.decode_snapshot(NetCodec.encode_snapshot(session,100,Compatibility.content_hash().hex_decode()),1,Compatibility.content_hash().hex_decode()).states[0]
		visual.present(restored,InputFrame.make(),.016)
		camera.initialized = false
		camera.follow(restored,.016)
		for frame in range(8): await process_frame
		await RenderingServer.frame_post_draw
		var path := "res://reports/m4-summit-"+str(row[0])+".png"
		assert(root.get_texture().get_image().save_png(path)==OK)
		records.append({"u":row[1],"braking":restored.braking,"image":path,"shoulder_surface":track.shoulder_surface(s)})
	var file := FileAccess.open("res://reports/m4-surface-lamp-reference.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"content_hash":Compatibility.content_hash(),"protocol":NetCodec.PROTOCOL,"resolution":[1920,1080],"boundary":"Posed native Compatibility render of actual codec-round-tripped authority, no rival input frame. Not a human driving or physical Android test.","captures":records},"\t")+"\n")
	file.close()
	world.queue_free()
	for frame in range(3): await process_frame
	print("SUMMIT_VISIBLE_MIXED_SHOULDERS_REMOTE_AUTHORITY_BRAKE_LAMPS_RENDER_PASS")
	quit()

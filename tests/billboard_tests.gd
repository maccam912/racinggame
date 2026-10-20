extends SceneTree
## Actual alpha/instance bounds and rendered silhouettes from four approach directions.
func _initialize() -> void: call_deferred("run")

func run() -> void:
	Catalog.load_all()
	CourseArt.load_catalog()
	BillboardArt.load_catalog()
	assert(BillboardArt.rows.size()==17)
	var report := {"passed":false,"backend":DisplayServer.get_name(),"cases":[]}
	var folder := "res://reports/billboards"
	DirAccess.make_dir_recursive_absolute(folder)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(512,512)
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.msaa_3d = Viewport.MSAA_4X
	root.add_child(viewport)
	for id: String in BillboardArt.rows:
		var row: Dictionary = BillboardArt.rows[id]
		assert(FileAccess.get_sha256("res://"+str(row.path))==row.sha256)
		assert(FileAccess.get_sha256("res://"+str(row.source))==row.sha256)
		var texture: Texture2D = load("res://"+str(row.path))
		var image := texture.get_image()
		assert(image.has_mipmaps(),"racing vegetation requires committed mipmapped imports")
		assert(image.get_width()==row.pixels[0] and image.get_height()==row.pixels[1])
		var parent := Node3D.new()
		viewport.add_child(parent)
		var poses: Array[Transform3D] = [Transform3D(Basis(Vector3.UP,.73).scaled(Vector3.ONE*1.1),Vector3(3,2,-4))]
		CourseArt.batch(id,poses,parent,0)
		var plant := parent.get_child(0) as MultiMeshInstance3D
		assert(plant.name=="IllustratedBillboard_"+id and plant.multimesh.instance_count==1)
		assert(plant.multimesh.mesh is QuadMesh and plant.multimesh.mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX].size()==6)
		# Dummy rendering does not retain a GPU instance buffer. Read it back
		# only on the actual native/software-GL rendering path below.
		if DisplayServer.get_name()!="headless": assert(plant.multimesh.get_instance_transform(0).is_equal_approx(poses[0]))
		assert(plant.multimesh.custom_aabb.size.z>0 and plant.multimesh.custom_aabb.size.x>0)
		assert(parent.find_children("*","CollisionObject3D",true,false).is_empty())
		var material := plant.material_override as StandardMaterial3D
		assert(material.billboard_mode==BaseMaterial3D.BILLBOARD_FIXED_Y and material.billboard_keep_scale)
		assert(material.transparency==BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR and material.alpha_scissor_threshold==.5)
		var sizes: Array[int] = []
		if DisplayServer.get_name()!="headless":
			var camera := Camera3D.new()
			camera.projection = Camera3D.PROJECTION_ORTHOGONAL
			camera.size = maxf(plant.multimesh.mesh.size.x,plant.multimesh.mesh.size.y)*1.4
			camera.far = 200
			camera.current = true
			viewport.add_child(camera)
			var center: Vector3 = poses[0].origin+Vector3.UP*plant.multimesh.mesh.size.y*.55
			for direction in range(4):
				var angle := direction*PI*.5
				camera.position = center+Vector3(sin(angle),0,cos(angle))*80
				camera.look_at(center,Vector3.UP)
				for frame in range(3): await process_frame
				await RenderingServer.frame_post_draw
				var pixels := viewport.get_texture().get_image()
				var covered := 0
				for y in range(0,512,2):
					for x in range(0,512,2):
						if pixels.get_pixel(x,y).a>.5: covered+=1
				assert(covered>1000,"billboard disappeared from an approach direction")
				sizes.append(covered)
				if direction==0: assert(pixels.save_png(folder+"/"+id+".png")==OK)
			assert(float(sizes.max()-sizes.min())/float(sizes.max())<.025,"cylindrical card changed apparent silhouette with heading")
			camera.queue_free()
		report.cases.append({"id":id,"alpha_pixels":row.solid_pixels,"transparent_pixels":row.transparent_pixels,"visible_pixels_quarter_resolution":sizes,"instance_bounds":[plant.multimesh.custom_aabb.size.x,plant.multimesh.custom_aabb.size.y,plant.multimesh.custom_aabb.size.z]})
		parent.queue_free()
		await process_frame
	BillboardArt.release_cache()
	assert(BillboardArt.cards.is_empty() and BillboardArt.materials.is_empty() and BillboardArt.shadows.is_empty() and BillboardArt.shadow_material==null)
	viewport.queue_free()
	report.passed = true
	var file := FileAccess.open(folder+"/"+("headless" if DisplayServer.get_name()=="headless" else "native")+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")+"\n")
	file.close()
	print("BILLBOARD_ALPHA_HASH_MIPMAPS_INSTANCING_FOUR_APPROACH_DIRECTIONS_COLLISION_FREE_PASS")
	quit()

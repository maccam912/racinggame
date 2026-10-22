extends SceneTree
## Verify actual terrain and roadside share one cosmetic material across all 30.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	Catalog.load_all()
	var before := Compatibility.content_hash()
	var styles: Array[int] = []
	var rows: Array[Dictionary] = []
	for index in range(Catalog.tracks.size()):
		var track: TrackDefinition = Catalog.tracks[index]
		var world := TrackWorld.new()
		world.begin_build(track)
		world.build_environment()
		world.build_road()
		root.add_child(world)
		var terrain := world.get_node("CosmeticTerrain")
		var terrain_meshes := terrain.find_children("*","MeshInstance3D",true,false)
		assert(not terrain_meshes.is_empty())
		var ground: Material = terrain_meshes[0].material_override
		if index<10:
			assert(ground is StandardMaterial3D,"established ten keep their terrain path")
		else:
			assert(ground is ShaderMaterial)
			var surface := ground as ShaderMaterial
			assert(surface.shader.resource_path=="res://assets/exported/shaders/biome_ground.gdshader")
			assert(surface==ExpansionBiome.material(track.id),"one stable shared world-space ground material")
			assert(surface.get_shader_parameter("ground_color")==Color.html(world.art.ground))
			var style := int(surface.get_shader_parameter("biome"))
			if style not in styles: styles.append(style)
			for node: MeshInstance3D in terrain_meshes: assert(node.material_override==surface)
			var verge: MeshInstance3D = world.get_node("Road_verges")
			assert(verge.material_override==surface,"no material seam where roadside meets landscape")
			for node: MeshInstance3D in verge.find_children("*","MeshInstance3D",true,false): assert(node.material_override==surface)
			var environment := world.find_children("*","WorldEnvironment",false,false)[0] as WorldEnvironment
			var sky_material := environment.environment.sky.sky_material as ShaderMaterial
			if world.art.space:
				assert(int(sky_material.get_shader_parameter("space_view")) in [1,2,3,4,5])
			else: assert(int(sky_material.get_shader_parameter("space_view"))==0)
			rows.append({"track":track.id,"biome":style,"space_view":int(sky_material.get_shader_parameter("space_view")),"terrain_chunks":terrain_meshes.size()})
		world.queue_free()
		await process_frame
	assert(styles.size()==10 and rows.size()==30)
	assert(before==Compatibility.content_hash())
	var file := FileAccess.open("res://reports/biome-surfaces.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":true,"content_hash":before,"cases":rows},"\t")+"\n")
	file.close()
	print("THIRTY_COURSE_BIOMES_TEN_GROUND_TREATMENTS_FIVE_SPACE_SKIES_SHARED_VERGE_MATERIAL_PASS")
	quit()

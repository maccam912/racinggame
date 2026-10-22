extends SceneTree
## Actual scene budgets, geometry validity, local culling and cosmetic boundaries.
func _initialize() -> void: call_deferred("run")

func run() -> void:
	Catalog.load_all()
	var hash_before := Compatibility.content_hash()
	var rows: Array[Dictionary] = []
	for id: String in ["festival_speedway","oasis_citadel","aurora_harbor","lantern_market","neon_underpass","steelworks_sprint","marina_lights"]:
		var track: TrackDefinition = Catalog.tracks.filter(func(item: TrackDefinition) -> bool: return item.id==id)[0]
		var world := TrackWorld.new()
		world.build(track)
		root.add_child(world)
		var buildings := 0
		var triangles := 0
		var archetypes: Array[String] = []
		for node: MeshInstance3D in world.find_children("*","MeshInstance3D",true,false):
			if not node.has_meta("module"): continue
			buildings += 1
			triangles += node.mesh.get_faces().size()/3
			var kind := str(node.get_meta("module"))
			if kind not in archetypes: archetypes.append(kind)
			for point: Vector3 in node.mesh.get_faces(): assert(point.is_finite())
			for normal: Vector3 in node.mesh.surface_get_arrays(0)[Mesh.ARRAY_NORMAL]: assert(normal.is_finite() and absf(normal.length()-1)<.01)
			assert(node.find_children("*","CollisionObject3D",true,false).is_empty())
			assert(node.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and node.visibility_range_end==700)
		if id=="festival_speedway": assert(buildings>10 and archetypes.has("festival_tent") and archetypes.has("festival_stall"))
		elif id=="oasis_citadel": assert(buildings>=8 and archetypes.has("citadel"))
		elif id=="marina_lights": assert(buildings==0)
		else: assert(buildings>=8)
		assert(buildings==0 or float(triangles)/buildings<700,"bounded district geometry per building")
		var pools := world.find_children("StreetlightPools_*","MeshInstance3D",false,false)
		if id in ["festival_speedway","aurora_harbor","lantern_market","neon_underpass"]: assert(pools.size()>2 and world.lamp_glow_sites.size()>8)
		else: assert(pools.is_empty(),"daytime and original courses retain their existing lighting")
		var settings := SettingsCatalog.defaults(false)
		settings.draw_distance = 700
		settings.vsync = false
		SettingsRuntime.apply(world,settings)
		for node: MeshInstance3D in pools:
			assert(node.visibility_range_end==120,"draw-distance settings cannot extend additive pools across the world")
			assert(node.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
			assert(node.mesh.get_aabb().size.x<180 and node.mesh.get_aabb().size.z<180,"spatially local light batches")
			for point: Vector3 in node.mesh.get_faces(): assert(point.is_finite())
		assert(world.find_children("*","OmniLight3D",true,false).is_empty() and world.find_children("*","SpotLight3D",true,false).is_empty(),"no dynamic lights added by the glow pools")
		rows.append({"track":id,"buildings":buildings,"triangles":triangles,"archetypes":archetypes,"light_pool_batches":pools.size(),"lit_lamps":world.lamp_glow_sites.size()})
		world.queue_free()
		await process_frame
	assert(hash_before==Compatibility.content_hash())
	var file := FileAccess.open("res://reports/district-detail.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":true,"content_hash":hash_before,"cases":rows},"\t")+"\n")
	file.close()
	print("THEMED_FESTIVAL_CITADEL_DISTRICTS_BOUNDED_LOCAL_NIGHT_POOLS_CLASSIC_PRESERVED_PASS")
	quit()

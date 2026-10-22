extends SceneTree
## Whole wet footprints, road views and complete motion bounds for coastal boats.
func _initialize() -> void: call_deferred("run")
func flat(point: Vector3) -> Vector2: return Vector2(point.x,point.z)
func segment_distance(at: Vector3, first: Vector3, last: Vector3) -> float:
	return flat(at).distance_to(Geometry2D.get_closest_point_to_segment(flat(at),flat(first),flat(last)))
func run() -> void:
	Catalog.load_all()
	var before := Compatibility.content_hash()
	var geometry := load("res://tests/watercraft_geometry.gd")
	var rows: Array[Dictionary] = []
	var count := 0
	for track: TrackDefinition in Catalog.tracks:
		if not ExpansionWatercraft.SPECS.has(track.id):
			if not CourseArt.spec(track.id).get("expansion40",false):
				var classic := TrackWorld.new()
				classic.begin_build(track)
				classic.build_environment()
				assert(classic.watercraft_sites.is_empty())
				classic.free()
			continue
		var world := TrackWorld.new()
		world.build(track)
		root.add_child(world)
		var nodes := world.find_children("Watercraft_*","MeshInstance3D",false,false)
		assert(nodes.size()==ExpansionWatercraft.SPECS[track.id].sites.size())
		var index: Dictionary = geometry.verge_index(world)
		for node: MeshInstance3D in nodes:
			var site: Dictionary = node.get_meta("watercraft_site")
			var radius: float = site.radius
			var sea: float = site.sea_level
			assert(node.transform==site.pose and is_equal_approx(node.position.y,sea))
			assert(geometry.wet_disk(world,node.position,radius,sea),"every terrain triangle under the swept footprint is submerged")
			var road_margin := INF
			for i in range(track.points.size()):
				var j := (i+1)%track.points.size()
				var half := maxf(float(track.bake.samples[i][8]),float(track.bake.samples[j][8]))*.5
				var margin := segment_distance(node.position,track.points[i],track.points[j])-radius-half-float(world.art.get("verge_extent",65))-3
				road_margin = minf(road_margin,margin)
			assert(road_margin>0,"full footprints stay outside every branch of the road and its visible verge")
			var eye: Vector3 = geometry.approach_eye(track,float(site.s)-float(site.approach_distance))
			var target := node.position+Vector3.UP*(12 if site.kind=="outrigger" else 8 if site.kind=="harbor_tug" else 3)
			assert(geometry.terrain_view_clear(world,eye,target) and geometry.verge_view_clear(index,eye,target),"authored approaches clear actual terrain, shoulders, barriers and verges")
			for other: Dictionary in world.watercraft_sites:
				if other.variant==site.variant: continue
				assert(flat(node.position).distance_to(flat(other.pose.origin))>radius+float(other.radius)+40)
			for description: Dictionary in world.art.landmarks:
				var landmark := ExpansionCourseArt.landmark_site(world,description)
				assert(flat(node.position).distance_to(flat(landmark.pose.origin))>radius+float(landmark.radius)+10)
			for hero: Dictionary in world.hero_sites:
				assert(segment_distance(node.position,hero.approach,hero.pose.origin)>radius+52)
			for poster: Dictionary in world.poster_sites:
				assert(segment_distance(node.position,poster.approach,poster.pose.origin)>radius+15)
			var arrays := node.mesh.surface_get_arrays(0)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			assert(vertices.size()/3<400 and node.extra_cull_margin==0)
			assert(node.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
			assert(node.get_meta("lod_limit")==700.0 and node.is_in_group("scenery_distance") and node.is_in_group("scenery_motion"))
			assert(node.find_children("*","CollisionObject3D",true,false).is_empty())
			for first in range(0,vertices.size(),3):
				var normal := -(vertices[first+1]-vertices[first]).cross(vertices[first+2]-vertices[first]).normalized()
				assert(normal.is_finite() and normal.length()>.999)
				for corner in range(3): assert(normals[first+corner].dot(normal)>.999)
			for step in range(129):
				var roll := Basis(Vector3.BACK,lerpf(-.025,.025,step/128.0))
				for vertex: Vector3 in vertices:
					var at := roll*vertex
					assert(at.is_finite() and flat(at).length()<radius)
					for bob: float in [-.22,.22]:
						assert(node.custom_aabb.has_point(at+Vector3.UP*bob),"swept bounds enclose roll and independent vertical extremes")
						assert(at.y+bob> -1.30,"the deepest hull stays above the guaranteed wet clearance")
			assert(node.material_override.get_shader_parameter("motion")==8 and node.material_override.get_shader_parameter("animation_enabled")==1.0)
			rows.append({"track":track.id,"kind":site.kind,"variant":site.variant,"triangles":vertices.size()/3,"minimum_road_verge_margin_m":road_margin,"swept_roll_phases":129,"bob_extremes":2})
			count += 1
		var settings := SettingsCatalog.defaults(false)
		settings.reduce_motion = true
		settings.draw_distance = 1200
		settings.vsync = false
		SettingsRuntime.apply(world,settings)
		for node: MeshInstance3D in nodes: assert(node.material_override.get_shader_parameter("animation_enabled")==0.0 and node.visibility_range_end==700)
		world.queue_free()
		await process_frame
	assert(count==7 and before==Compatibility.content_hash())
	var file := FileAccess.open("res://reports/expansion-watercraft.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":true,"content_hash":before,"cases":rows},"\t")+"\n")
	file.close()
	print("SEVEN_COASTAL_BOATS_ACTUAL_WET_TRIANGLES_ROAD_VERGE_APPROACHES_SWEPT_BOUNDS_REDUCED_MOTION_CLASSIC_EXCLUSION_PASS")
	quit()

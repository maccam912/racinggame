extends SceneTree
## Actual persistent skyline geometry, first-ten retention and road separation.
func _initialize() -> void: call_deferred("run")

func fingerprint(node: MeshInstance3D) -> String:
	var arrays := node.mesh.surface_get_arrays(0)
	var context := HashingContext.new()
	context.start(HashingContext.HASH_SHA256)
	context.update(var_to_bytes([arrays[Mesh.ARRAY_VERTEX],arrays[Mesh.ARRAY_NORMAL],arrays[Mesh.ARRAY_COLOR]]))
	return context.finish().hex_encode()

func run() -> void:
	Catalog.load_all()
	var legacy := load("res://tests/fixtures/presentation13/legacy_horizon.gd")
	var content := Compatibility.content_hash()
	var rows: Array[Dictionary] = []
	var classics: Array[Dictionary] = []
	var families: Dictionary = {}
	var shapes: Dictionary = {}
	for index in range(Catalog.tracks.size()):
		var track: TrackDefinition = Catalog.tracks[index]
		var world := TrackWorld.new()
		world.build(track)
		root.add_child(world)
		var node := world.get_node_or_null("LandscapeHorizon") as MeshInstance3D
		if index<10:
			if node==null:
				assert(track.id in ["spillway_sprint","caldera_crosscut"])
				classics.append({"track":track.id,"horizon":false})
			else:
				assert(not node.has_meta("profile"))
				var before := fingerprint(node)
				world.remove_child(node)
				node.free()
				legacy.build(world)
				var old := world.get_node("LandscapeHorizon") as MeshInstance3D
				assert(before==fingerprint(old),"the established horizon keeps exact mesh positions, normals and colors")
				classics.append({"track":track.id,"horizon":true,"mesh_sha256":before,"triangles":old.mesh.get_faces().size()/3})
		else:
			assert(node!=null and node.has_meta("profile") and node.transform==Transform3D.IDENTITY)
			assert(not node.is_in_group("scenery_distance") and not node.is_in_group("scenery_motion"))
			assert(node.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF)
			assert(node.find_children("*","CollisionObject3D",true,false).is_empty())
			var material := node.material_override as StandardMaterial3D
			assert(material!=null and material.vertex_color_use_as_albedo and material.shading_mode==BaseMaterial3D.SHADING_MODE_UNSHADED)
			assert(material.transparency==BaseMaterial3D.TRANSPARENCY_DISABLED)
			var arrays := node.mesh.surface_get_arrays(0)
			var points: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
			assert(points.size()==normals.size() and points.size()==colors.size() and points.size()%3==0)
			var triangles := points.size()/3
			assert(triangles>=2304 and triangles<5000,"persistent background remains a small single mesh")
			var center: Vector2 = node.get_meta("center_xz")
			var road_radius: float = node.get_meta("road_radius")
			var minimum := INF
			for first in range(0,points.size(),3):
				var expected := -(points[first+1]-points[first]).cross(points[first+2]-points[first]).normalized()
				assert(expected.is_finite() and expected.length()>.999,"no collapsed or nonfinite skyline triangles")
				var projected := PackedVector2Array()
				for corner in range(3):
					var p := points[first+corner]
					assert(p.is_finite() and normals[first+corner].is_finite() and normals[first+corner].dot(expected)>.999)
					projected.append(Vector2(p.x,p.z))
				assert(not Geometry2D.is_point_in_polygon(center,projected))
				for corner in range(3):
					var nearest := Geometry2D.get_closest_point_to_segment(center,projected[corner],projected[(corner+1)%3])
					minimum = minf(minimum,nearest.distance_to(center)-road_radius)
			assert(minimum>550,"complete triangles stay outside the circle enclosing every road branch")
			for p: Vector3 in track.points: assert(Vector2(p.x,p.z).distance_to(center)<=road_radius+.01)
			var settlement_count := int(node.get_meta("far_settlements"))
			assert(settlement_count==(12 if track.id in ["tundra_pipeline","storm_chase","saltflat_velocity"] else 0))
			var kind: String = node.get_meta("profile")
			families[kind] = true
			var spec: Array = ExpansionHorizon.PROFILES[track.id]
			var signature: Array[float] = []
			for step in range(193):
				var height := ExpansionHorizon.profile(kind,TAU*step/192,float(spec[2]))*float(spec[1])
				assert(is_finite(height) and height>=0)
				signature.append(height)
			assert(absf(signature[0]-signature[-1])<.01,"periodic profiles close without a geometric crack")
			var key := str(signature)
			assert(not shapes.has(key),"each course has its own skyline profile and phase")
			shapes[key] = true
			var settings := SettingsCatalog.defaults(false)
			settings.reduce_motion = true
			for distance in [400,1000]:
				settings.draw_distance = distance
				SettingsRuntime.apply(world,settings)
				assert(node.visible and node.visibility_range_end==0,"background remains present when local scenery culls")
			rows.append({"track":track.id,"profile":kind,"triangles":triangles,"far_settlements":settlement_count,"minimum_outside_road_circle_m":minimum,"mesh_sha256":fingerprint(node)})
		world.queue_free()
		await process_frame
	assert(rows.size()==30 and classics.size()==10 and families.size()>=16)
	assert(content==Compatibility.content_hash())
	var file := FileAccess.open("res://reports/expansion-horizons.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":true,"content_hash":content,"families":families.size(),"cases":rows,"original_ten":classics,"boundary":"Actual forty worlds. Eight established generic horizons match the frozen helper exactly; two retain their spectacle skyline exclusion. All thirty new single-mesh skylines have finite clockwise unit normals, bounded triangles, distinct closed profiles, full-face separation from the circle enclosing all road branches, no collision/shadows and persistence at low/high draw settings. Native visual quality and camera-frustum coverage are separate."},"\t")+"\n")
	file.close()
	print("THIRTY_REGIONAL_PERSISTENT_SKYLINES_FIRST_TEN_EXACT_ROAD_CLEAR_MESHES_PASS families=",families.size())
	quit()

extends SceneTree
## Exact real-course triangle/UV preservation across render partitions.
func _initialize() -> void:
	Catalog.load_all()
	var track: TrackDefinition = Catalog.tracks[5]
	var geometry := RouteGeometry.meshes(track,true)
	for key: String in ["asphalt","verges","markings","barriers","deck"]:
		var node := MeshInstance3D.new()
		if key=="barriers": node.mesh = CourseRoadMesh.barriers(track,CourseArt.spec(track.id))
		elif key=="deck": node.mesh = CourseRoadMesh.elevated_deck(track)
		else: node.mesh = CourseRoadMesh.front_faces(geometry[key],track if key=="asphalt" else null)
		var original := triangles(node.mesh)
		CourseRoadMesh.partition(node)
		var actual := triangles(node.mesh)
		for chunk: MeshInstance3D in node.get_children():
			assert(chunk.get_aabb().size.x<900 and chunk.get_aabb().size.z<900)
			var parts := triangles(chunk.mesh)
			for signature: String in parts: actual[signature] = int(actual.get(signature,0))+int(parts[signature])
		assert(node.get_child_count()>2 and original==actual,"all real road triangles and UVs remain exact, once each")
		assert(node.visibility_range_end==0,"road coverage never depends on scenery distance")
		node.free()
	check_summit_instances(track)
	print("SUMMIT_RENDER_PARTITIONS_EXACT_TRIANGLES_UVS_FINITE_NORMALS_NO_DISTANCE_CLIP_PASS")
	quit()

func triangles(mesh: Mesh) -> Dictionary:
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV]!=null else PackedVector2Array()
	var result: Dictionary = {}
	for first in range(0,vertices.size(),3):
		var data: Array = []
		for index in range(first,first+3):
			data.append(vertices[index])
			assert(normals[index].is_finite() and absf(normals[index].length()-1)<.001)
			if not uvs.is_empty(): data.append(uvs[index])
		var signature := var_to_bytes(data).hex_encode()
		result[signature] = int(result.get(signature,0))+1
	return result

func check_summit_instances(track: TrackDefinition) -> void:
	var world := TrackWorld.new()
	world.begin_build(track)
	while world.scenery_cursor<int(track.length): assert(not world.advance_build())
	var expected: Dictionary = {}
	for bucket: Dictionary in world.scenery_batches.values():
		if not BillboardArt.supports(bucket.id): continue
		if not expected.has(bucket.id): expected[bucket.id] = []
		expected[bucket.id].append_array(bucket.poses)
	assert(expected.size()>2)
	while not world.advance_build(): pass
	assert(world.scenery_batches.is_empty())
	root.add_child(world)
	var actual: Dictionary = {}
	var counts: Dictionary = {}
	for child: Node in world.get_children():
		if not child is MultiMeshInstance3D or not child.has_meta("asset_id"): continue
		var id: String = child.get_meta("asset_id")
		assert(expected.has(id))
		counts[id] = int(counts.get(id,0))+child.multimesh.instance_count
		if DisplayServer.get_name()=="headless": continue
		if not actual.has(id): actual[id] = []
		for index in range(child.multimesh.instance_count): actual[id].append(child.multimesh.get_instance_transform(index))
	for id: String in expected:
		assert(counts[id]==expected[id].size(),"spatial regrouping retains every roadside instance")
		if DisplayServer.get_name()=="headless": continue
		var wanted: Dictionary = {}
		for pose: Transform3D in expected[id]:
			var signature := var_to_bytes(pose).hex_encode()
			wanted[signature] = int(wanted.get(signature,0))+1
		for pose: Transform3D in actual[id]:
			var signature := var_to_bytes(pose).hex_encode()
			assert(wanted.get(signature,0)>0,"native instance buffer preserves exact world poses")
			wanted[signature] -= 1
		for count: int in wanted.values(): assert(count==0)
	world.free()
	print("SUMMIT_SPATIAL_SCENERY_INSTANCE_COUNTS_AND_NATIVE_EXACT_POSES_PASS ",counts)

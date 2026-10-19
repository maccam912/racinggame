class_name CourseRoadMesh
extends RefCounted
## Render-only extrusion over the unchanged shared barrier planes.


static func quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var normal := -(b-a).cross(c-a).normalized()
	for point: Vector3 in [a,b,c,a,c,d]:
		tool.set_normal(normal)
		tool.add_vertex(point)


static func front_faces(source: ArrayMesh) -> ArrayMesh:
	var arrays := source.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX]!=null else PackedInt32Array()
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for first in range(0,indices.size() if not indices.is_empty() else vertices.size(),3):
		var order: Array = [indices[first],indices[first+1],indices[first+2]] if not indices.is_empty() else [first,first+1,first+2]
		# Godot's front faces use clockwise winding; normals point opposite the cross product.
		if (vertices[order[1]]-vertices[order[0]]).cross(vertices[order[2]]-vertices[order[0]]).dot(normals[order[0]])>0:
			order = [order[0],order[2],order[1]]
		for index: int in order:
			tool.set_normal(normals[index])
			tool.add_vertex(vertices[index])
	return tool.commit()


static func shoulders(track: TrackDefinition) -> Dictionary:
	var tools: Dictionary = {}
	for index in range(track.points.size()):
		var next := (index+1)%track.points.size()
		var start_s := track.distances[index]
		var end_s := track.distances[next] if next>0 else track.length
		var start_u := float(track.bake.samples[index][7])
		var end_u := float(track.bake.samples[next][7])
		if end_u<start_u: end_u += 1
		var cuts: Array[float] = [0.0,1.0]
		for interval: Dictionary in track.definition.get("surface_intervals",[]):
			for u: float in [float(interval.start),float(interval.end)]:
				if u<start_u: u += 1
				if u>start_u and u<end_u: cuts.append((u-start_u)/(end_u-start_u))
		cuts.sort()
		for part in range(cuts.size()-1):
			var lo := cuts[part]
			var hi := cuts[part+1]
			var surface := track.shoulder_surface(lerpf(start_s,end_s,(lo+hi)/2))
			if not tools.has(surface):
				var tool := SurfaceTool.new()
				tool.begin(Mesh.PRIMITIVE_TRIANGLES)
				tools[surface] = tool
			for side: float in [-1.0,1.0]:
				var wa := float(track.bake.samples[index][8])/2
				var wb := float(track.bake.samples[next][8])/2
				var inner_a := RouteGeometry.point(track,index,side*wa)
				var inner_b := RouteGeometry.point(track,next,side*wb)
				var outer_a := RouteGeometry.point(track,index,side*(wa+3))
				var outer_b := RouteGeometry.point(track,next,side*(wb+3))
				if side>0: quad(tools[surface],inner_a.lerp(inner_b,lo),inner_a.lerp(inner_b,hi),outer_a.lerp(outer_b,hi),outer_a.lerp(outer_b,lo))
				else: quad(tools[surface],outer_a.lerp(outer_b,lo),outer_a.lerp(outer_b,hi),inner_a.lerp(inner_b,hi),inner_a.lerp(inner_b,lo))
	var result: Dictionary = {}
	for surface: String in tools: result[surface] = tools[surface].commit()
	return result


static func barriers(track: TrackDefinition, spec: Dictionary) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(track.points.size()):
		var next := (index+1)%track.points.size()
		var row: Array = track.bake.samples[index]
		var coastal: bool = not spec.coast_interval.is_empty() and float(row[7])>=float(spec.coast_interval[0]) and float(row[7])<=float(spec.coast_interval[1])
		for side: float in [-1.0,1.0]:
			var profiles: Array = []
			if coastal and side>0 or track.id=="sunstone_canyon":
				profiles = [[Vector2(-.18,0),Vector2(-.18,.9),Vector2(.18,.9),Vector2(.18,0)]]
			else:
				profiles = [[Vector2(-.1,.38),Vector2(-.1,.54),Vector2(.1,.54),Vector2(.1,.38)], [Vector2(-.1,.72),Vector2(-.1,.88),Vector2(.1,.88),Vector2(.1,.72)]]
			for profile: Array in profiles:
				for vertex in range(3):
					var left: Vector2 = profile[vertex]
					var right: Vector2 = profile[vertex+1]
					var wa := float(row[8])/2+3
					var wb := float(track.bake.samples[next][8])/2+3
					quad(tool,RouteGeometry.point(track,index,side*(wa+left.x))+Vector3.UP*left.y,RouteGeometry.point(track,next,side*(wb+left.x))+Vector3.UP*left.y,RouteGeometry.point(track,next,side*(wb+right.x))+Vector3.UP*right.y,RouteGeometry.point(track,index,side*(wa+right.x))+Vector3.UP*right.y)
			if not coastal and track.id!="sunstone_canyon" and index%4==0:
				var pose := track.pose(track.distances[index],side*(float(row[8])/2+3))
				for face: Array in [[Vector3(-.07,0,-.07),Vector3(.07,0,-.07),Vector3(.07,.85,-.07),Vector3(-.07,.85,-.07)],[Vector3(.07,0,.07),Vector3(-.07,0,.07),Vector3(-.07,.85,.07),Vector3(.07,.85,.07)]]:
					quad(tool,pose*face[0],pose*face[1],pose*face[2],pose*face[3])
	return tool.commit()


static func cover(track: TrackDefinition, interval: Array, clearance: float) -> ArrayMesh:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in range(track.points.size()):
		var u := float(track.bake.samples[index][7])
		if u<float(interval[0]) or u>float(interval[1]): continue
		var next := (index+1)%track.points.size()
		var a := RouteGeometry.point(track,index,-14)
		var b := RouteGeometry.point(track,index,14)
		var c := RouteGeometry.point(track,next,14)
		var d := RouteGeometry.point(track,next,-14)
		quad(tool,a+Vector3.UP*clearance,b+Vector3.UP*clearance,c+Vector3.UP*clearance,d+Vector3.UP*clearance)
		quad(tool,a,a+Vector3.UP*clearance,d+Vector3.UP*clearance,d)
		quad(tool,b,c,c+Vector3.UP*clearance,b+Vector3.UP*clearance)
	return tool.commit()

class_name RouteGeometry
extends RefCounted
## Identical road/barrier triangles for client visuals, prediction and server sweeps.


static func point(track: TrackDefinition, i: int, lateral: float) -> Vector3:
	var row: Array = track.bake.samples[i]
	var result := track.points[i] + track.forwards[i].cross(Vector3.UP).normalized() * lateral
	result.y += float(row[10]) - lateral * tan(float(row[9]))
	return result


static func quad(tool: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	var normal := (b - a).cross(c - a).normalized()
	if normal.y < 0:
		normal = -normal
	for vertex: Vector3 in [a, b, c, a, c, d]:
		tool.set_normal(normal)
		tool.add_vertex(vertex)


static func meshes(track: TrackDefinition, visual: bool = false) -> Dictionary:
	var tools: Dictionary = {}
	for key in ["asphalt", "shoulder", "walls", "verges", "markings"] if visual else ["asphalt", "shoulder", "walls"]:
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		tools[key] = tool
	for i in range(track.points.size()):
		var j := (i + 1) % track.points.size()
		var wa: float = track.bake.samples[i][8] / 2
		var wb: float = track.bake.samples[j][8] / 2
		quad(tools.asphalt, point(track, i, -wa), point(track, i, wa), point(track, j, wb), point(track, j, -wb))
		for side: float in [-1.0, 1.0]:
			quad(tools.shoulder, point(track, i, side * wa), point(track, j, side * wb), point(track, j, side * (wb + 3)), point(track, i, side * (wa + 3)))
			var a := point(track, i, side * (wa + 3))
			var b := point(track, j, side * (wb + 3))
			quad(tools.walls, a, b, b + Vector3.UP * .9, a + Vector3.UP * .9)
			if visual:
				quad(tools.verges, a, b, point(track, j, side * (wb + 65)) - Vector3.UP * 2.5, point(track, i, side * (wa + 65)) - Vector3.UP * 2.5)
				quad(tools.markings, point(track, i, side * (wa - .35)) + Vector3.UP * .015, point(track, j, side * (wb - .35)) + Vector3.UP * .015, point(track, j, side * (wb - .60)) + Vector3.UP * .015, point(track, i, side * (wa - .60)) + Vector3.UP * .015)
		if visual and fposmod(track.distances[i], 12) < 4:
			quad(tools.markings, point(track, i, -.09) + Vector3.UP * .018, point(track, i, .09) + Vector3.UP * .018, point(track, j, .09) + Vector3.UP * .018, point(track, j, -.09) + Vector3.UP * .018)
	var result: Dictionary = {}
	for key: String in tools:
		result[key] = tools[key].commit()
	return result

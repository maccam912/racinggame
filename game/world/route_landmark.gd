class_name RouteLandmark
extends RefCounted
## Bend original bridge artwork over the actual banked, ramped road surface.
## Split long faces before deforming so a flat deck cannot cut through a hill.


static func conform(model: Node3D, track: TrackDefinition, anchor_s: float, anchor: Transform3D) -> void:
	for node: MeshInstance3D in model.find_children("*","MeshInstance3D",true,false):
		var relative := node.transform
		var ancestor := node.get_parent() as Node3D
		while ancestor!=null and ancestor!=model:
			relative = ancestor.transform*relative
			ancestor = ancestor.get_parent() as Node3D
		var arrays := node.mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV]
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		for first in range(0,indices.size(),3):
			var triangle: Array = []
			for index: int in [indices[first],indices[first+1],indices[first+2]]:
				triangle.append({"point":relative*vertices[index],"normal":(relative.basis*normals[index]).normalized(),"uv":uvs[index]})
			var lo: float = minf(triangle[0].point.z,minf(triangle[1].point.z,triangle[2].point.z))
			var hi: float = maxf(triangle[0].point.z,maxf(triangle[1].point.z,triangle[2].point.z))
			for slab in range(floori(lo/4),floori(hi/4)+1):
				var polygon := clip(clip(triangle,slab*4,true),(slab+1)*4,false)
				for corner in range(1,polygon.size()-1):
					for vertex: Dictionary in [polygon[0],polygon[corner],polygon[corner+1]]:
						var s: float = anchor_s-float(vertex.point.z)
						var pose := track.pose(s,float(vertex.point.x))
						var i := track.sample_index(s)
						var j := (i+1)%track.points.size()
						var end := track.distances[j] if j>0 else track.length
						var t := (fposmod(s,track.length)-track.distances[i])/(end-track.distances[i])
						pose.origin.y = lerpf(RouteGeometry.point(track,i,float(vertex.point.x)).y,RouteGeometry.point(track,j,float(vertex.point.x)).y,t)+float(vertex.point.y)
						tool.set_normal((relative.basis.inverse()*anchor.basis.inverse()*pose.basis*vertex.normal).normalized())
						tool.set_uv(vertex.uv)
						tool.add_vertex(relative.affine_inverse()*anchor.affine_inverse()*pose.origin)
		node.mesh = tool.commit()
	model.set_meta("route_conformed",true)


static func clip(polygon: Array, z: float, above: bool) -> Array:
	var output: Array = []
	if polygon.is_empty(): return output
	var previous: Dictionary = polygon[-1]
	var prior_inside: bool = previous.point.z>=z if above else previous.point.z<=z
	for current: Dictionary in polygon:
		var inside: bool = current.point.z>=z if above else current.point.z<=z
		if inside!=prior_inside:
			var t: float = (z-float(previous.point.z))/(float(current.point.z)-float(previous.point.z))
			output.append({"point":previous.point.lerp(current.point,t),"normal":previous.normal.lerp(current.normal,t).normalized(),"uv":previous.uv.lerp(current.uv,t)})
		if inside: output.append(current)
		previous = current
		prior_inside = inside
	return output

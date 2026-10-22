extends RefCounted
## Independent full terrain triangles and visible road surfaces for coastal art.
static func wet_disk(world: TrackWorld, center: Vector3, radius: float, sea: float) -> bool:
	if CourseArt.height_from_grid(world.terrain_grid,center,INF)>sea-1.30: return false
	for x in range(floori((center.x-radius)/32),ceili((center.x+radius)/32)):
		for z in range(floori((center.z-radius)/32),ceili((center.z+radius)/32)):
			var cell := Vector2i(x,z)
			for corners: Array in [[cell,cell+Vector2i(1,0),cell+Vector2i.ONE],[cell,cell+Vector2i.ONE,cell+Vector2i(0,1)]]:
				var polygon := PackedVector2Array()
				for key: Vector2i in corners: polygon.append(Vector2(key)*32)
				var flat := Vector2(center.x,center.z)
				var overlap := Geometry2D.is_point_in_polygon(flat,polygon)
				for edge in range(3):
					if Geometry2D.get_closest_point_to_segment(flat,polygon[edge],polygon[(edge+1)%3]).distance_to(flat)<=radius: overlap = true
				if not overlap: continue
				for key: Vector2i in corners:
					if not world.terrain_grid.has(key) or float(world.terrain_grid[key])>sea-1.30: return false
	return true

static var verge_indexes: Dictionary = {}
static func verge_index(world: TrackWorld) -> Dictionary:
	var extent: float = world.art.get("verge_extent",65)
	var key := world.track.id+":"+world.track.content_hash+":"+str(extent)
	if verge_indexes.has(key): return verge_indexes[key]
	var points := CourseRoadMesh.verges(world.track,extent).get_faces()
	points.append_array(CourseRoadMesh.barriers(world.track,world.art).get_faces())
	points.append_array(RouteGeometry.meshes(world.track).asphalt.get_faces())
	for shoulder: ArrayMesh in CourseRoadMesh.shoulders(world.track).values(): points.append_array(shoulder.get_faces())
	var cells: Dictionary = {}
	for first in range(0,points.size(),3):
		var low := Vector2(INF,INF)
		var high := Vector2(-INF,-INF)
		for corner in range(3):
			var p := Vector2(points[first+corner].x,points[first+corner].z)
			low = low.min(p)
			high = high.max(p)
		for x in range(floori(low.x/128),floori(high.x/128)+1):
			for z in range(floori(low.y/128),floori(high.y/128)+1):
				var cell := Vector2i(x,z)
				if not cells.has(cell): cells[cell] = []
				cells[cell].append(first)
	var result := {"points":points,"cells":cells}
	verge_indexes[key] = result
	return result

static func verge_view_clear(index: Dictionary, first: Vector3, last: Vector3) -> bool:
	var candidates: Dictionary = {}
	var low := Vector2(first.x,first.z).min(Vector2(last.x,last.z))
	var high := Vector2(first.x,first.z).max(Vector2(last.x,last.z))
	for x in range(floori(low.x/128),floori(high.x/128)+1):
		for z in range(floori(low.y/128),floori(high.y/128)+1):
			for offset: int in index.cells.get(Vector2i(x,z),[]): candidates[offset] = true
	var points: PackedVector3Array = index.points
	for offset: int in candidates:
		if Geometry3D.segment_intersects_triangle(first,last,points[offset],points[offset+1],points[offset+2])!=null: return false
	return true

static func approach_eye(track: TrackDefinition, s: float) -> Vector3:
	var i := track.sample_index(s)
	var center := RouteGeometry.point(track,i,0)
	var normal := (RouteGeometry.point(track,i,1)-center).cross(RouteGeometry.point(track,(i+1)%track.points.size(),0)-center).normalized()
	if normal.y<0: normal = -normal
	var pose := track.pose(s)
	var forward := Vector3(-pose.basis.z.x,0,-pose.basis.z.z).slide(normal).normalized()
	return center+Vector3.UP*.35-forward*8.2+normal*(3.4-.35)

static func terrain_view_clear(world: TrackWorld, first: Vector3, last: Vector3) -> bool:
	# Triangle boundaries are x=n*32, z=n*32 and x-z=n*32.
	var values: Array[float] = [0.0,1.0]
	for pair: Vector2 in [Vector2(first.x,last.x),Vector2(first.z,last.z),Vector2(first.x-first.z,last.x-last.z)]:
		var delta := pair.y-pair.x
		if absf(delta)<.001: continue
		for line in range(floori(minf(pair.x,pair.y)/32)+1,ceili(maxf(pair.x,pair.y)/32)):
			var t := (line*32.0-pair.x)/delta
			if t>0 and t<1: values.append(t)
	for t: float in values:
		var point := first.lerp(last,t)
		if CourseArt.height_from_grid(world.terrain_grid,point,INF)>point.y-1.0: return false
	return true

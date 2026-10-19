class_name RoutePreview
extends Control

var track: TrackDefinition


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)


func _draw() -> void:
	if track == null:
		return
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for p: Vector3 in track.points:
		lo = lo.min(Vector2(p.x, p.z))
		hi = hi.max(Vector2(p.x, p.z))
	var scale := minf((size.x - 24) / (hi.x - lo.x), (size.y - 24) / (hi.y - lo.y))
	var offset := (size - (hi - lo) * scale) / 2
	var route := PackedVector2Array()
	for p: Vector3 in track.points:
		route.append(offset + (Vector2(p.x, p.z) - lo) * scale)
	route.append(route[0])
	draw_polyline(route, Color("f3e4c4"), 3, true)
	draw_circle(offset + (Vector2(track.points[0].x, track.points[0].z) - lo) * scale, 4, Color("20bfc5"))

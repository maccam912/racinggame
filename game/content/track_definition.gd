class_name TrackDefinition
extends Resource

@export var id: String
@export var display_name_key: String
@export var length: float
@export var start_sample: int
@export var content_hash: String
var definition: Dictionary
var bake: Dictionary
var points := PackedVector3Array()
var forwards := PackedVector3Array()
var distances := PackedFloat64Array()


static func from_data(data: Dictionary) -> TrackDefinition:
	var track := TrackDefinition.new()
	track.id = data.id
	track.display_name_key = data.display_name_key
	track.definition = data
	track.bake = JSON.parse_string(FileAccess.get_file_as_string(data.baked_route_id))
	track.length = track.bake.length
	track.start_sample = track.bake.start_sample
	track.content_hash = track.bake.content_hash
	for row: Array in track.bake.samples:
		track.points.append(Vector3(row[0], row[1], row[2]))
		track.forwards.append(Vector3(row[3], row[4], row[5]))
	for value: float in track.bake.distances:
		track.distances.append(value)
	return track


func sample_index(s: float) -> int:
	var value := fposmod(s, length)
	var lo := 0
	var hi := distances.size() - 1
	while lo < hi:
		var mid := (lo + hi + 1) / 2
		if distances[mid] <= value:
			lo = mid
		else:
			hi = mid - 1
	return lo


func pose(s: float, lateral: float = 0.0) -> Transform3D:
	var i := sample_index(s)
	var next := (i + 1) % points.size()
	var segment_end := distances[next] if next > 0 else length
	var weight := (fposmod(s, length) - distances[i]) / (segment_end - distances[i])
	var forward := forwards[i].lerp(forwards[next], weight).normalized()
	var right := forward.cross(Vector3.UP).normalized()
	var position := points[i].lerp(points[next], weight) + right * lateral
	return Transform3D(Basis(right, right.cross(forward).normalized(), -forward), position)

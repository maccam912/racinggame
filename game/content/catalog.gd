class_name Catalog
extends RefCounted

static var cars: Array[CarDefinition] = []
static var tracks: Array[TrackDefinition] = []
static var paints: Array[Color] = []
static var rules: Dictionary


static func load_all() -> void:
	if not cars.is_empty():
		return
	var car_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/content/cars.json"))
	for data: Dictionary in car_data.cars:
		cars.append(CarDefinition.from_data(data))
	for color: String in car_data.paints:
		paints.append(Color.html(color))
	var track_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://game/content/tracks.json"))
	for data: Dictionary in track_data.tracks:
		tracks.append(TrackDefinition.from_data(data))
	rules = JSON.parse_string(FileAccess.get_file_as_string("res://game/content/rules.json"))

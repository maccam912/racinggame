class_name AudioLibrary
extends RefCounted
## Imported streams are shared; players and virtual RPM remain presentation only.
static var streams: Dictionary = {}
static var catalog: Dictionary = {}

static func entries() -> Dictionary:
	if catalog.is_empty():
		var value: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/exported/audio/catalog.json"))
		for row: Dictionary in value.assets: catalog[row.id] = row
	return catalog

static func stream(id: String) -> AudioStreamOggVorbis:
	if not streams.has(id):
		var row: Dictionary = entries()[id]
		streams[id] = load("res://"+str(row.path))
	return streams[id]

static func ui(viewport: Viewport, id: String) -> void:
	if is_instance_valid(viewport) and viewport.is_inside_tree(): viewport.get_tree().call_group("game_audio","effect","ui_"+id)

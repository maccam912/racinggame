class_name UIIcons
extends RefCounted
static var catalog: Dictionary = {}
static var textures: Dictionary = {}
static func entries() -> Dictionary:
	if catalog.is_empty():
		var value: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://assets/exported/icons/catalog.json"))
		for row: Dictionary in value.assets: catalog[row.id] = row
	return catalog
static func texture(id: String) -> Texture2D:
	assert(entries().has(id),"Installation incomplete: missing UI icon "+id)
	if not textures.has(id): textures[id] = load("res://"+str(entries()[id].path))
	return textures[id]
static func medal_id(rank: int) -> String:
	return "medal_"+(["gold","silver","bronze"][rank] if rank in range(3) else "none")

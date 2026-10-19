extends SceneTree
var count: int = 0
func check_folder(folder: String) -> void:
	var directory := DirAccess.open(folder)
	assert(directory!=null)
	for name: String in directory.get_directories(): check_folder(folder.path_join(name))
	for name: String in directory.get_files():
		if name.ends_with(".gd"):
			var script := load(folder.path_join(name)) as GDScript
			assert(script!=null and script.can_instantiate(),"Every shipped script, including optional diagnostic entrypoints, must compile")
			count += 1
func _initialize() -> void:
	check_folder("res://game")
	print("ALL_SHIPPED_OPTIONAL_AND_MAIN_GDSCRIPTS_COMPILE_PASS count="+str(count))
	quit()

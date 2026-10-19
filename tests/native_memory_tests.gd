extends SceneTree

func _initialize() -> void:
	assert(ClassDB.class_exists("PacificPlatform"))
	var platform: Object = ClassDB.instantiate("PacificPlatform")
	var before: int = platform.resident_memory_bytes()
	assert(before > 0 and before < 16 * 1024 * 1024 * 1024, "Current native process RSS must be available")
	var pages := PackedByteArray()
	pages.resize(32 * 1024 * 1024)
	pages.fill(123)
	var after: int = platform.resident_memory_bytes()
	assert(after >= before + 16 * 1024 * 1024, "Committed/touched pages must change current RSS")
	assert(pages[31 * 1024 * 1024] == 123)
	print("NATIVE_MEMORY_PASS before=%d after=%d delta=%d" % [before, after, after-before])
	platform = null
	quit()

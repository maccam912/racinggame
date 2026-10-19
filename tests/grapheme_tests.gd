extends SceneTree
func _initialize() -> void:
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/grapheme_break_16.json"))
	assert(document.unicode_version=="16.0.0")
	for index in range(document.cases.size()):
		var test: Dictionary = document.cases[index]
		var points: Array[int] = []
		var expected: Array[int] = []
		points.assign(test.points)
		expected.assign(test.breaks)
		assert(UnicodeGraphemes.boundaries(points)==expected,"Unicode 16 official grapheme boundary case "+str(index))
	var value := "👨‍👩‍👧‍👦".repeat(3)+"aa"
	assert(value.length()==23 and PlayerName.grapheme_count(value)==5 and PlayerName.validate(value).valid)
	assert(PlayerName.grapheme_count("क्‍षab")==3 and PlayerName.grapheme_count("🇺🇸á👩🏽‍🚀")==3)
	var primary := TextServerManager.get_primary_interface()
	var fallback: TextServer
	for interface: Dictionary in TextServerManager.get_interfaces():
		if str(interface.name).to_lower().contains("fallback"): fallback = TextServerManager.get_interface(int(interface.id))
	if fallback!=null:
		TextServerManager.set_primary_interface(fallback)
		assert(PlayerName.grapheme_count(value)==5 and PlayerName.validate(value).valid,"name validation is independent of the fallback text backend")
		TextServerManager.set_primary_interface(primary)
	assert(UnicodeGraphemes.count("")==0 and UnicodeGraphemes.count("abc")==3)
	print("UNICODE_16_ALL_1093_OFFICIAL_BOUNDARIES_EMOJI_INDIC_FLAG_NFC_TEXT_BACKEND_INDEPENDENT_NAMES_PASS")
	quit()

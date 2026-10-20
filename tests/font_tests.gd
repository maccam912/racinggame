extends SceneTree

func _initialize() -> void:
	var emoji: FontFile = load("res://assets/fonts/NotoColorEmoji.ttf")
	assert(emoji.data.size() == 10673480)
	var hash := HashingContext.new()
	hash.start(HashingContext.HASH_SHA256)
	hash.update(emoji.data)
	assert(hash.finish().hex_encode() == "72a635cb3d2f3524c51620cdde406b217204e8a6a06c6a096ff8ed4b5fd6e27b")
	for kind: String in ["body", "heading"]:
		var font: FontVariation = load("res://assets/fonts/"+kind+".tres")
		assert(font.fallbacks[0] == emoji)
		var base: Font = font.base_font
		# Explicit emoji fallback must not change this face's ASCII metrics.
		if kind=="heading":
			assert(base.get_font_name()=="Pacific Rush Display")
			assert(font.fallbacks.size()==2 and font.fallbacks[1].resource_path.ends_with("Rajdhani-SemiBold.ttf"))
			for codepoint in range(32,127): assert(base.has_char(codepoint),"Original display font covers printable ASCII")
		else:
			assert(font.fallbacks.size()==1)
		for size: int in [16, 24, 36, 64]:
			assert(font.get_string_size("Pacific Rush / 1:29.999", HORIZONTAL_ALIGNMENT_LEFT, -1, size) == base.get_string_size("Pacific Rush / 1:29.999", HORIZONTAL_ALIGNMENT_LEFT, -1, size))
		# Remove host fallbacks: these characters must come from shipped data.
		var isolated: FontVariation = font.duplicate(true)
		isolated.base_font.allow_system_fallback = false
		isolated.fallbacks[0].allow_system_fallback = false
		for codepoint: int in [0x1f468, 0x1f469, 0x1f467, 0x1f466, 0x1f3c1, 0x1f44d, 0x1f3fd]:
			assert(isolated.has_char(codepoint), "Bundled glyph absent")
		var line := TextLine.new()
		assert(line.add_string("👨‍👩‍👧‍👦👍🏽🏁", isolated, 36))
		assert(line.get_size().x > 60)
		var glyphs := TextServerManager.get_primary_interface().shaped_text_get_glyphs(line.get_rid())
		var drawn := glyphs.filter(func(glyph: Dictionary) -> bool: return float(glyph.advance) > 0)
		assert(drawn.size() == 3, "Family and skin-tone sequences must shape into full glyphs")
		for glyph: Dictionary in drawn:
			assert(glyph.font_rid.is_valid() and int(glyph.index) != 0)
			assert(isolated.fallbacks[0].get_rids().has(glyph.font_rid), "Glyph must use bundled emoji font")
	assert(ProjectSettings.get_setting("internationalization/locale/include_text_server_data"))
	print("ORIGINAL_ARCADE_ASCII_SHIPPED_EMOJI_NOTO_CBDT_SHA_ASCII_METRICS_NO_SYSTEM_GLYPHS_FULL_SEQUENCE_SHAPING_PASS")
	quit()

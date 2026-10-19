extends CanvasLayer
## Opt-in fixed-fixture rendering evidence. Never reads names or profile data.

func _ready() -> void:
	var canvas := Control.new()
	add_child(canvas)
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var background := ColorRect.new()
	background.color = Color("172c40")
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.add_child(background)
	var margin := MarginContainer.new()
	canvas.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_"+side, 32)
	var column := VBoxContainer.new()
	margin.add_child(column)
	var heading := Label.new()
	heading.text = "FIXED TEXT RENDERING PROBE"
	heading.add_theme_font_override("font", load("res://assets/fonts/BarlowCondensed-Bold.ttf"))
	heading.add_theme_font_size_override("font_size", 42)
	column.add_child(heading)
	var primary := TextServerManager.get_primary_interface()
	print("TEXT_PROBE_SERVER "+JSON.stringify({"primary":primary.get_name(),"features":primary.get_features(),"interfaces":TextServerManager.get_interfaces(),"break_data_setting":ProjectSettings.get_setting("internationalization/locale/include_text_server_data",false)}))
	var fonts: Array[Font] = []
	var original: FontFile = load("res://assets/fonts/Barlow-SemiBold.ttf")
	fonts.append(load("res://assets/fonts/body.tres"))
	var bitmaps: FontFile = original.duplicate()
	bitmaps.disable_embedded_bitmaps = false
	fonts.append(bitmaps)
	var explicit_font: FontFile = original.duplicate()
	var emoji := FontFile.new()
	var error := emoji.load_dynamic_font("/system/fonts/NotoColorEmoji.ttf") if FileAccess.file_exists("/system/fonts/NotoColorEmoji.ttf") else ERR_FILE_NOT_FOUND
	if error == OK:
		emoji.disable_embedded_bitmaps = false
		explicit_font.fallbacks = [emoji]
	fonts.append(explicit_font)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 12)
	column.add_child(grid)
	for title in ["Current", "Embedded bitmaps enabled", "Explicit OS emoji fallback"]:
		var label := Label.new()
		label.text = title
		label.add_theme_font_override("font", original)
		label.add_theme_font_size_override("font_size", 24)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(label)
	var samples := ["Driver / Élodie", "Алексей", "مريم", "漢字", "क्‍ष", "👨‍👩‍👧‍👦aa", "🇺🇸🏁", "👍🏽bb"]
	for index: int in range(samples.size()):
		for variant: int in range(fonts.size()):
			var label := Label.new()
			label.text = samples[index]
			label.add_theme_font_override("font", fonts[variant])
			label.add_theme_font_size_override("font_size", 36)
			label.add_theme_color_override("font_color", Color("f8f4e8"))
			grid.add_child(label)
			print("TEXT_PROBE_ROW "+JSON.stringify({"index":index,"variant":variant,"width":fonts[variant].get_string_size(samples[index],HORIZONTAL_ALIGNMENT_LEFT,-1,36).x,"native_graphemes":primary.string_get_character_breaks(samples[index]).size(),"portable_graphemes":PlayerName.grapheme_count(samples[index])}))
	var footer := Label.new()
	footer.text = "Fixed fixture only. " + primary.get_name() + " • explicit emoji: " + str(error == OK)
	footer.add_theme_font_override("font", original)
	footer.add_theme_font_size_override("font_size", 24)
	column.add_child(footer)
	var edit := UIFactory.text_edit()
	edit.text = "ab👨‍👩‍👧‍👦"
	edit.virtual_keyboard_enabled = false
	edit.add_theme_font_override("font", fonts[0])
	edit.add_theme_font_size_override("font_size", 32)
	column.add_child(edit)
	edit.text_changed.connect(func(value: String) -> void:
		print("TEXT_PROBE_EDIT "+JSON.stringify({"codepoints":value.length(),"equals_ab":value == "ab"})))
	edit.grab_focus()
	edit.caret_column = edit.text.length()
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--probe-frames="):
			await get_tree().create_timer(clampi(int(argument.trim_prefix("--probe-frames=")),1,600)/60.0).timeout
			get_tree().quit()

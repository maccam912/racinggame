extends SceneTree

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var control := Control.new()
	root.add_child(control)
	var edit := UIFactory.text_edit()
	edit.virtual_keyboard_enabled = false
	edit.add_theme_font_override("font", load("res://assets/fonts/body.tres"))
	control.add_child(edit)
	edit.grab_focus()
	await process_frame
	for suffix: String in ["👨‍👩‍👧‍👦", "👍🏽", "🇺🇸", "e\u0301"]:
		edit.text = "ab" + suffix
		edit.caret_column = edit.text.length()
		assert(not edit.caret_mid_grapheme)
		var event := InputEventKey.new()
		event.keycode = KEY_BACKSPACE
		event.pressed = true
		Input.parse_input_event(event)
		await process_frame
		assert(edit.text == "ab", "One backspace must remove the complete grapheme")
		event = event.duplicate()
		event.pressed = false
		Input.parse_input_event(event)
	control.queue_free()
	await process_frame
	print("TEXT_INPUT_FAMILY_SKIN_FLAG_COMBINING_ONE_BACKSPACE_COMPLETE_GRAPHEME_PASS")
	quit()

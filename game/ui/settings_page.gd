class_name SettingsPage
extends RefCounted

var app: Node
var back: Callable
var tab: String = "display"
var status: Label
var pending_display: Dictionary = {}
var revert_timer: Timer
var display_modal: ConfirmationDialog


func _init(owner_app: Node) -> void:
	app = owner_app


func show_tab(selected: String, return_to: Callable) -> void:
	back = return_to
	tab = selected
	app.page = "settings"
	app.back_action = back
	var shell: MenuShell = app.menu
	shell.settings = app.data.settings
	var body := shell.reset(I18n.t("settings.title"))
	var tabs := GridContainer.new()
	tabs.columns = 4 if app.data.mobile or int(app.data.settings.ui_scale) >= 125 else 7
	body.add_child(tabs)
	var names := ["display", "graphics", "audio", "controls", "accessibility", "gameplay", "data"]
	if app.data.mobile:
		names.insert(4, "touch")
	for key: String in names:
		var button := shell.ui.button(I18n.t("tab." + key), func() -> void: show_tab(key, back))
		button.modulate = UIFactory.TURQUOISE if key == tab else Color.WHITE
		tabs.add_child(button)
	var list := shell.scroll_column(body)
	for definition: Dictionary in SettingsCatalog.rows:
		if definition.tab != tab or (definition.get("platform", "") == "desktop" and app.data.mobile) or (definition.get("platform", "") == "mobile" and not app.data.mobile):
			continue
		setting_row(list, definition)
	if tab == "controls":
		list.add_child(shell.ui.paragraph(I18n.t("settings.controls_help")))
	if tab == "data":
		list.add_child(shell.ui.button(I18n.t("settings.name"), func() -> void: app.show_name(false)))
		list.add_child(shell.ui.button(I18n.t("settings.export"), export_diagnostics))
		list.add_child(shell.ui.button(I18n.t("settings.reset_records"), func() -> void: shell.confirm(I18n.t("settings.reset_records_confirm"), func() -> void: reset_data(false), true)))
		list.add_child(shell.ui.button(I18n.t("settings.reset_all"), func() -> void: shell.confirm(I18n.t("settings.reset_all_confirm"), func() -> void: reset_data(true), true)))
	status = shell.ui.paragraph("")
	list.add_child(status)
	if tab != "data":
		shell.footer.add_child(shell.ui.button(I18n.t("settings.restore_tab"), func() -> void:
			if app.data.restore_tab(tab) == OK:
				SettingsRuntime.apply(app, app.data.settings)
				if app.drive:
					app.drive.apply_settings()
				show_tab(tab, back)))
	shell.add_back(back)
	shell.first_focus()


func setting_row(parent: Node, definition: Dictionary) -> void:
	var row := HBoxContainer.new()
	var label: Label = app.menu.ui.label(I18n.t("settings." + definition.id))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var value: Variant = app.data.settings[definition.id]
	if definition.kind == "toggle":
		var toggle := CheckButton.new()
		toggle.button_pressed = bool(value)
		toggle.custom_minimum_size.y = app.menu.ui.row_height()
		toggle.toggled.connect(func(new_value: bool) -> void: changed(definition, new_value))
		row.add_child(toggle)
	elif definition.kind == "choice":
		var picker := OptionButton.new()
		picker.custom_minimum_size = Vector2(200 * app.menu.ui.unit, app.menu.ui.row_height())
		var choices: Array = definition.get("mobile_values", definition.values).duplicate() if app.data.mobile else definition.values.duplicate()
		if definition.id == "monitor":
			choices.clear()
			for index in range(DisplayServer.get_screen_count()):
				choices.append(index)
		for index in range(choices.size()):
			var choice: Variant = choices[index]
			var key := "choice." + str(choice)
			var caption := I18n.t(key)
			if caption == key:
				caption = str(choice)
			if (choice is int or choice is float) and float(choice) == 0 and definition.id in ["msaa", "frame_cap"]:
				caption = I18n.t("choice.off" if definition.id == "msaa" else "choice.unlimited")
			picker.add_item(caption)
			if str(choice) == str(value) or ((choice is int or choice is float) and (value is int or value is float) and float(choice) == float(value)):
				picker.selected = index
		picker.item_selected.connect(func(index: int) -> void: changed(definition, choices[index]))
		row.add_child(picker)
	else:
		var number := SpinBox.new()
		number.min_value = float(definition.minimum)
		number.max_value = float(definition.maximum)
		number.step = float(definition.step)
		number.value = float(value)
		number.custom_minimum_size = Vector2(180 * app.menu.ui.unit, app.menu.ui.row_height())
		number.value_changed.connect(func(new_value: float) -> void: changed(definition, new_value))
		row.add_child(number)
	parent.add_child(row)


func changed(definition: Dictionary, value: Variant) -> void:
	if definition.id in ["window_mode", "monitor", "resolution"]:
		begin_display(definition.id, value)
		return
	var error: Error = app.data.set_setting(definition.id, value)
	status.text = I18n.t("settings.saved" if error == OK else "data.save_failed")
	SettingsRuntime.apply(app, app.data.settings)
	if app.drive:
		app.drive.apply_settings()
	if app.stage:
		app.stage.reduce_motion = bool(app.data.settings.reduce_motion)
	if definition.id in ["ui_scale", "high_contrast", "preset"]:
		show_tab(tab, back)


func begin_display(key: String, value: Variant) -> void:
	pending_display = app.data.settings.duplicate(true)
	app.data.settings[key] = value
	SettingsRuntime.apply(app, app.data.settings, true)
	display_modal = ConfirmationDialog.new()
	display_modal.dialog_text = I18n.t("display.confirm")
	display_modal.ok_button_text = I18n.t("button.keep")
	display_modal.cancel_button_text = I18n.t("button.revert")
	display_modal.theme = app.menu.ui.theme
	app.menu.root.add_child(display_modal)
	revert_timer = Timer.new()
	revert_timer.wait_time = 15
	revert_timer.one_shot = true
	display_modal.add_child(revert_timer)
	display_modal.confirmed.connect(func() -> void:
		pending_display.clear()
		revert_timer.stop()
		app.data.save_settings())
	display_modal.canceled.connect(revert_display)
	display_modal.close_requested.connect(revert_display)
	revert_timer.timeout.connect(revert_display)
	display_modal.popup_centered(Vector2i(500, 180))
	revert_timer.start()


func revert_display() -> void:
	if pending_display.is_empty():
		return
	app.data.settings = pending_display.duplicate(true)
	pending_display.clear()
	SettingsRuntime.apply(app, app.data.settings, true)
	if is_instance_valid(display_modal):
		display_modal.queue_free()
	show_tab(tab, back)


func reset_data(all_data: bool) -> void:
	var error: Error = app.data.reset_local(all_data)
	if error != OK:
		status.text = I18n.t("data.save_failed")
		return
	if all_data:
		if app.drive:
			app.dispose_drive()
		app.show_name(true)
	else:
		show_tab("data", back)


func export_diagnostics() -> void:
	var folder: String = app.data.store.root_path.path_join("diagnostics")
	DirAccess.make_dir_recursive_absolute(folder)
	var filename := folder.path_join("diagnostics-" + str(Time.get_unix_time_from_system()) + ".json")
	var file := FileAccess.open(filename, FileAccess.WRITE)
	if file == null:
		status.text = I18n.t("data.save_failed")
		return
	file.store_string(JSON.stringify({"build":app.build_name(), "protocol":NetCodec.PROTOCOL, "content_hash":Compatibility.content_hash(), "os":OS.get_name(), "gpu":RenderingServer.get_video_adapter_name(), "settings":app.data.settings, "notices":app.data.store.notices}, "\t"))
	file.close()
	status.text = filename

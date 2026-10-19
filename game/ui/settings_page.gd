class_name SettingsPage
extends RefCounted

var app: Node
var back: Callable
var tab: String = "display"
var status: Label
var pending_display: Dictionary = {}
var pending_geometry: Dictionary = {}
var revert_timer: Timer
var display_modal: ConfirmationDialog
var display_generation: int = 0
var pending_focus: String = ""
var reset_pending: bool = false


func _init(owner_app: Node) -> void:
	app = owner_app


func show_tab(selected: String, return_to: Callable) -> void:
	if reset_pending or not is_instance_valid(app) or not app.is_inside_tree():
		return
	finish_display(false, display_generation, false)
	back = return_to
	tab = selected
	app.page = "settings"
	app.back_action = back
	var shell: MenuShell = app.menu
	shell.settings = app.data.settings
	var body := shell.reset(I18n.t("settings.title"))
	var names := ["display", "graphics", "audio", "controls", "accessibility", "gameplay", "data"]
	if app.data.mobile:
		names.insert(4, "touch")
	var selected_button: Button
	var geometry := TouchDriving.safe_geometry(app.get_viewport().get_visible_rect().size)
	if app.data.mobile and geometry.safe.size.y<600:
		var selector: Variant = shell.ui.choice_picker(I18n.t("settings.title"))
		selector.name = "settings_sections"
		selector.custom_minimum_size.y = shell.ui.row_height()
		for name_key: String in names:
			selector.add_item(I18n.t("tab."+name_key))
		selector.selected = maxi(0,names.find(tab))
		selector.item_selected.connect(func(index: int) -> void: show_tab(names[index],back))
		body.add_child(selector)
		selected_button = selector
	else:
		var tabs := GridContainer.new()
		tabs.columns = 4 if app.data.mobile or int(app.data.settings.ui_scale)>=125 else 7
		body.add_child(tabs)
		for key: String in names:
			var button := shell.ui.button(I18n.t("tab."+key),func() -> void: show_tab(key,back))
			button.modulate = UIFactory.TURQUOISE if key==tab else Color.WHITE
			tabs.add_child(button)
			if key==tab:
				selected_button = button
	var list := shell.scroll_column(body)
	if tab=="display" and not app.data.mobile:
		list.add_child(shell.ui.paragraph(I18n.t("display.resolution_help")))
	for definition: Dictionary in SettingsCatalog.rows:
		if definition.tab != tab or (definition.get("platform", "") == "desktop" and app.data.mobile) or (definition.get("platform", "") == "mobile" and not app.data.mobile):
			continue
		setting_row(list, definition)
	if tab == "controls":
		list.add_child(shell.ui.button(I18n.t("binding.title"),func() -> void: app.bindings_page.show_page(func() -> void: show_tab("controls",back))))
		list.add_child(shell.ui.paragraph(I18n.t("settings.controls_help")))
	if tab == "touch":
		var edit := shell.ui.button(I18n.t("touch.edit_layout"),app.show_touch_editor)
		var restore := shell.ui.button(I18n.t("touch.restore_layout"),restore_layout)
		edit.disabled = touch_layout_locked()
		restore.disabled = touch_layout_locked()
		list.add_child(edit)
		list.add_child(restore)
		if touch_layout_locked():
			list.add_child(shell.ui.paragraph(I18n.t("touch.change_lobby")))
	if tab == "data":
		list.add_child(shell.ui.button(I18n.t("settings.name"), func() -> void: app.show_name(false)))
		list.add_child(shell.ui.button(I18n.t("settings.export"), export_diagnostics))
		list.add_child(shell.ui.button(I18n.t("settings.reset_records"), func() -> void: shell.confirm(I18n.t("settings.reset_records_confirm"), func() -> void: reset_data(false), true)))
		list.add_child(shell.ui.button(I18n.t("settings.reset_all"), func() -> void: shell.confirm(I18n.t("settings.reset_all_confirm"), func() -> void: reset_data(true), true)))
	status = shell.ui.paragraph("")
	list.add_child(status)
	if tab != "data":
		var restore_tab := shell.ui.button(I18n.t("settings.restore_tab"), restore_this_tab)
		restore_tab.disabled = tab=="touch" and touch_layout_locked()
		shell.footer.add_child(restore_tab)
	shell.add_back(back)
	if selected_button:
		shell.focus_later(selected_button)
	else:
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
		var picker: Variant = app.menu.ui.choice_picker(I18n.t("settings."+definition.id))
		picker.custom_minimum_size = Vector2(200 * app.menu.ui.unit, app.menu.ui.row_height())
		var choices: Array = definition.get("mobile_values", definition.values).duplicate() if app.data.mobile else definition.values.duplicate()
		if definition.id == "monitor":
			choices.clear()
			for index in range(DisplayServer.get_screen_count()):
				choices.append(index)
		elif definition.id=="resolution":
			choices = DesktopDisplay.modes(int(app.data.settings.monitor))
		for index in range(choices.size()):
			var choice: Variant = choices[index]
			var key := "choice." + str(choice)
			var caption := str(int(choice)) if (choice is int or choice is float) and float(choice) == floorf(float(choice)) else I18n.t(key)
			if definition.id == "monitor":
				caption = I18n.t("display.monitor", [int(choice) + 1])
			if caption == key:
				caption = str(choice)
			if (choice is int or choice is float) and float(choice) == 0 and definition.id in ["msaa", "frame_cap"]:
				caption = I18n.t("choice.off" if definition.id == "msaa" else "choice.unlimited")
			picker.add_item(caption)
			if str(choice) == str(value) or ((choice is int or choice is float) and (value is int or value is float) and float(choice) == float(value)):
				picker.selected = index
		picker.item_selected.connect(func(index: int) -> void: changed(definition, choices[index]))
		picker.name = "setting_" + str(definition.id)
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
	if definition.id in ["touch_auto_accelerate","steering_style","button_size","left_handed"] and touch_layout_locked():
		var control := row.get_child(1)
		if control is BaseButton:
			control.disabled = true
		elif control is SpinBox:
			control.editable = false
	parent.add_child(row)


func changed(definition: Dictionary, value: Variant) -> void:
	if definition.id in ["touch_auto_accelerate","steering_style","button_size","left_handed"] and touch_layout_locked():
		return
	if definition.id in ["window_mode", "monitor", "resolution"]:
		begin_display(definition.id, value)
		return
	var error: Error = app.data.set_setting(definition.id, value)
	status.text = I18n.t("settings.saved" if error == OK else "data.save_failed")
	SettingsRuntime.apply(app, app.data.settings)
	if app.drive:
		app.drive.apply_settings()
		if definition.id=="trial_ghost": app.set_trial_ghost(bool(value))
	if app.stage:
		app.stage.reduce_motion = bool(app.data.settings.reduce_motion)
	if definition.id in ["ui_scale", "high_contrast", "preset"]:
		show_tab(tab, back)


func begin_display(key: String, value: Variant) -> void:
	preview_display({key:value}, key)


func preview_display(values: Dictionary, focus_key: String = "") -> void:
	finish_display(false, display_generation, false)
	display_generation += 1
	var generation := display_generation
	pending_focus = focus_key
	pending_geometry = DesktopDisplay.capture()
	if values.has("monitor") and not values.has("resolution"): values["resolution"] = "native"
	for key: String in values:
		pending_display[key] = app.data.settings[key]
		app.data.settings[key] = values[key]
	SettingsRuntime.apply(app, app.data.settings, true)
	display_modal = ConfirmationDialog.new()
	display_modal.dialog_autowrap = true
	display_modal.dialog_text = I18n.t("display.confirm_seconds", [15])
	display_modal.ok_button_text = I18n.t("button.keep")
	display_modal.cancel_button_text = I18n.t("button.revert")
	display_modal.theme = app.menu.ui.theme
	app.menu.root.add_child(display_modal)
	revert_timer = Timer.new()
	revert_timer.wait_time = 15
	revert_timer.one_shot = true
	display_modal.add_child(revert_timer)
	var ticker := Timer.new()
	ticker.wait_time = 1
	display_modal.add_child(ticker)
	ticker.timeout.connect(func() -> void:
		if generation == display_generation and is_instance_valid(display_modal) and is_instance_valid(revert_timer):
			display_modal.dialog_text = I18n.t("display.confirm_seconds", [maxi(1, ceili(revert_timer.time_left))]))
	ticker.start()
	display_modal.confirmed.connect(func() -> void: finish_display(true, generation))
	display_modal.canceled.connect(func() -> void: finish_display(false, generation))
	display_modal.close_requested.connect(func() -> void: finish_display(false, generation))
	display_modal.tree_exiting.connect(func() -> void: finish_display(false, generation, false))
	revert_timer.timeout.connect(func() -> void: finish_display(false, generation))
	display_modal.popup_centered(Vector2i(500, 180))
	revert_timer.start()


func revert_display() -> void:
	finish_display(false, display_generation)


func finish_display(keep: bool, generation: int, refresh: bool = true) -> void:
	if generation != display_generation or pending_display.is_empty():
		return
	var previous := pending_display.duplicate(true)
	var geometry := pending_geometry.duplicate(true)
	pending_display.clear()
	pending_geometry.clear()
	display_generation += 1
	if is_instance_valid(revert_timer):
		revert_timer.stop()
	var saved := false
	if is_instance_valid(app):
		if keep:
			saved = app.data.save_settings() == OK
		if not saved:
			for key: String in previous:
				app.data.settings[key] = previous[key]
		if app.is_inside_tree():
			SettingsRuntime.apply(app, app.data.settings, true)
			if not saved: DesktopDisplay.restore(geometry)
	if is_instance_valid(display_modal) and not display_modal.is_queued_for_deletion():
		display_modal.hide()
		display_modal.queue_free()
	if refresh and is_instance_valid(app) and app.is_inside_tree() and app.page == "settings":
		refresh_display.call_deferred(keep and not saved)


func refresh_display(save_failed: bool) -> void:
	if not is_instance_valid(app) or not app.is_inside_tree() or app.page != "settings":
		return
	show_tab(tab, back)
	if save_failed:
		status.text = I18n.t("data.save_failed")
	var control: Node = app.menu.root.find_child("setting_" + pending_focus, true, false)
	if control is Control:
		app.menu.focus_later(control)


func restore_this_tab() -> void:
	if tab=="touch" and touch_layout_locked():
		return
	if tab == "display" and not app.data.mobile:
		var defaults := SettingsCatalog.defaults(false)
		var changes: Dictionary = {}
		for row: Dictionary in SettingsCatalog.rows:
			if row.tab == "display":
				changes[row.id] = defaults[row.id]
		preview_display(changes)
		return
	if app.data.restore_tab(tab) == OK:
		SettingsRuntime.apply(app, app.data.settings)
		if tab == "controls":
			BindingBook.apply(app.data.settings.bindings)
		if app.drive:
			app.drive.apply_settings()
			if tab=="gameplay": app.set_trial_ghost(bool(app.data.settings.trial_ghost))
		show_tab(tab, back)


func reset_data(all_data: bool) -> void:
	if reset_pending:
		return
	if all_data:
		reset_pending = true
		app.online_page.cancel_work()
		app.dispose_drive()
		app.directory_client.forget_session()
		app.back_action = Callable()
		var controls: Array[Dictionary] = []
		for control: BaseButton in app.menu.root.find_children("*","BaseButton",true,false):
			controls.append({"control":control,"disabled":control.disabled})
			control.disabled = true
		status.text = I18n.t("data.resetting")
		var deadline := Time.get_ticks_msec()+10000
		while app.guest_service.busy() and Time.get_ticks_msec()<deadline:
			await app.get_tree().process_frame
		if app.guest_service.busy() or app.guest_service.begin("erase")!=OK:
			restore_reset_controls(controls,"online.storage_busy")
			return
		var erased: Dictionary = await app.guest_service.completed
		if not erased.ok:
			restore_reset_controls(controls,"online.identity_unavailable")
			return
	var error: Error = app.data.reset_local(all_data)
	if error!=OK:
		if all_data:
			reset_pending = false
			show_tab("data",app.show_menu)
		status.text = I18n.t("data.save_failed")
		return
	app.unsaved_results.clear()
	app.result_receipt = null
	reset_pending = false
	if all_data:
		BindingBook.apply(app.data.settings.bindings)
		app.menu.settings = app.data.settings
		SettingsRuntime.apply(app,app.data.settings)
		app.show_name(true)
	else:
		show_tab("data",back)

func restore_reset_controls(_controls: Array[Dictionary], key: String) -> void:
	reset_pending = false
	show_tab("data",app.show_menu)
	if is_instance_valid(status): status.text = I18n.t(key)


func export_diagnostics() -> void:
	var error: Error = app.diagnostics.begin_export()
	status.text = I18n.t("diagnostics.choose" if error==OK else "diagnostics.busy" if error==ERR_BUSY else "diagnostics.unavailable" if error==ERR_UNAVAILABLE else "diagnostics.failed")


func diagnostics_finished(state: String) -> void:
	if app.page=="settings" and tab=="data" and is_instance_valid(status):
		status.text = I18n.t("diagnostics."+state)


func touch_layout_locked() -> bool:
	return is_instance_valid(app.network) and is_instance_valid(app.drive) and app.drive.network!=null


func restore_layout() -> void:
	if touch_layout_locked():
		return
	var settings: Dictionary = app.data.settings
	var geometry := TouchDriving.safe_geometry(app.get_viewport().get_visible_rect().size)
	var key := TouchLayoutBook.profile_key(geometry.safe,bool(settings.touch_auto_accelerate),str(settings.steering_style),bool(settings.left_handed))
	var previous: Dictionary = settings.touch_layouts.duplicate(true)
	settings.touch_layouts.erase(key)
	if app.data.save_settings()!=OK:
		settings.touch_layouts = previous
		status.text = I18n.t("data.save_failed")
		return
	if is_instance_valid(app.drive):
		app.drive.apply_settings()
	status.text = I18n.t("settings.saved")

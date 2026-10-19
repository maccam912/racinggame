class_name BindingsPage
extends RefCounted

var app: Node
var back: Callable
var device_name: String = "keyboard"
var status: Label
var capture: BindingCapture
var conflict_dialog: ConfirmationDialog
var target_action: String = ""
var target_slot: int = 0
var pending: Variant

func _init(owner_app: Node) -> void:
	app=owner_app

func show_page(return_to: Callable) -> void:
	back=return_to
	app.page="bindings"
	app.back_action=back
	var shell: MenuShell=app.menu
	var body:=shell.reset(I18n.t("binding.title"))
	var devices:=HBoxContainer.new()
	var active_device_button: Button
	for key: String in ["keyboard","gamepad"]:
		var button:=shell.ui.button(I18n.t("binding."+key),func() -> void:
			device_name=key
			show_page(back))
		button.modulate=UIFactory.TURQUOISE if key==device_name else Color.WHITE
		devices.add_child(button)
		if key==device_name:
			active_device_button=button
	body.add_child(devices)
	var list:=shell.scroll_column(body)
	var bindings:=BindingBook.sanitize(app.data.settings.bindings)
	for group: Array in [BindingBook.DRIVING,BindingBook.MENU]:
		list.add_child(shell.ui.label(I18n.t("binding.driving" if group==BindingBook.DRIVING else "binding.menus"),true))
		for action: String in group:
			var row:=HBoxContainer.new()
			row.add_child(shell.ui.icon("action_"+action))
			var label:=shell.ui.label(I18n.t("action."+action))
			label.size_flags_horizontal=Control.SIZE_EXPAND_FILL
			row.add_child(label)
			for index in range(2):
				var button:=shell.ui.button(BindingBook.caption(bindings[device_name][action][index],str(app.data.settings.prompts)),func() -> void: begin_capture(action,index),180)
				button.name="binding_%s_%d" % [action,index]
				row.add_child(button)
			list.add_child(row)
	status=shell.ui.paragraph("")
	list.add_child(status)
	shell.footer.add_child(shell.ui.button(I18n.t("binding.defaults"),func() -> void: shell.confirm(I18n.t("binding.defaults_confirm"),restore_defaults)))
	shell.add_back(back)
	shell.focus_later(active_device_button)

func begin_capture(action: String,slot: int) -> void:
	target_action=action
	target_slot=slot
	capture=BindingCapture.new()
	capture.device_name=device_name
	capture.theme=app.menu.ui.theme
	capture.selected.connect(func(value: Dictionary) -> void:
		close_capture()
		choose.call_deferred(value))
	capture.canceled.connect(close_capture)
	capture.expired.connect(func() -> void:
		close_capture()
		if is_instance_valid(status):
			status.text=I18n.t("binding.timed_out"))
	# Removal remains explicit; Confirm/Back retain a keyboard path.
	var remove:=capture.add_button(I18n.t("binding.remove"),true,"remove")
	var cleared:=BindingBook.change(app.data.settings.bindings,device_name,action,slot,null)
	remove.disabled=cleared.status!="ok"
	app.menu.ui.help(remove,I18n.t("binding.essential"),true)
	capture.custom_action.connect(func(_action: String) -> void:
		close_capture()
		choose.call_deferred(null))
	app.menu.root.add_child(capture)
	app.menu.explain_window(capture)

func choose(value: Variant,decision: String = "") -> void:
	pending=value
	var result:=BindingBook.change(app.data.settings.bindings,device_name,target_action,target_slot,value,decision)
	match result.status:
		"conflict": show_conflict(str(result.action))
		"ok": save(result.bindings)
		"essential": status.text=I18n.t("binding.essential")
		"invalid": status.text=I18n.t("binding.invalid")

func show_conflict(other: String) -> void:
	conflict_dialog=ConfirmationDialog.new()
	conflict_dialog.theme=app.menu.ui.theme
	conflict_dialog.dialog_autowrap=true
	conflict_dialog.dialog_text=I18n.t("binding.conflict",[I18n.t("action."+other)])
	var can_swap: bool=BindingBook.change(app.data.settings.bindings,device_name,target_action,target_slot,pending,"swap").status=="ok"
	var can_replace: bool=BindingBook.change(app.data.settings.bindings,device_name,target_action,target_slot,pending,"replace").status=="ok"
	if not can_swap or not can_replace:
		conflict_dialog.dialog_text+="\n"+I18n.t("binding.essential")
	conflict_dialog.ok_button_text=I18n.t("binding.swap")
	conflict_dialog.cancel_button_text=I18n.t("button.cancel")
	var replace_button:=conflict_dialog.add_button(I18n.t("binding.replace"),true,"replace")
	conflict_dialog.confirmed.connect(func() -> void:
		app.get_viewport().set_input_as_handled()
		conflict_dialog.queue_free()
		choose(pending,"swap"))
	conflict_dialog.custom_action.connect(func(_action: String) -> void:
		app.get_viewport().set_input_as_handled()
		conflict_dialog.queue_free()
		choose(pending,"replace"))
	conflict_dialog.canceled.connect(func() -> void: conflict_dialog.queue_free())
	app.menu.root.add_child(conflict_dialog)
	conflict_dialog.popup_centered(Vector2i(600,200))
	conflict_dialog.get_ok_button().disabled=true
	replace_button.disabled=true
	app.menu.ui.help(conflict_dialog.get_ok_button(),I18n.t("binding.essential") if not can_swap else I18n.t("ui.wait"),true)
	app.menu.ui.help(replace_button,I18n.t("binding.essential") if not can_replace else I18n.t("ui.wait"),true)
	app.menu.explain_window(conflict_dialog)
	var gate:=Timer.new()
	gate.wait_time=.05
	conflict_dialog.add_child(gate)
	var opened:=Time.get_ticks_msec()
	gate.timeout.connect(func() -> void:
		if Time.get_ticks_msec()-opened>=200 and not Input.is_action_pressed("ui_accept"):
			conflict_dialog.get_ok_button().disabled=not can_swap
			replace_button.disabled=not can_replace
			gate.stop()
			(conflict_dialog.get_ok_button() if can_swap else conflict_dialog.get_cancel_button()).grab_focus())
	gate.start()

func save(bindings: Dictionary) -> void:
	app.get_viewport().set_input_as_handled()
	var previous: Dictionary=app.data.settings.bindings.duplicate(true)
	app.data.settings.bindings=bindings
	if app.data.save_settings()!=OK:
		app.data.settings.bindings=previous
		status.text=I18n.t("data.save_failed")
		return
	BindingBook.apply(bindings)
	show_page(back)
	var button: Node=app.menu.root.find_child("binding_%s_%d" % [target_action,target_slot],true,false)
	if button is Control:
		app.menu.focus_later(button)
	status.text=I18n.t("settings.saved")

func restore_defaults() -> void:
	var bindings:=BindingBook.sanitize(app.data.settings.bindings)
	bindings[device_name]=BindingBook.defaults()[device_name]
	save(bindings)


func close_capture() -> void:
	if is_instance_valid(capture):
		capture.done=true
		capture.exclusive=false
		capture.hide()
		capture.queue_free()

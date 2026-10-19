extends Node3D

var menu := MenuShell.new()
var drive: RaceDrive
var stage: MenuStage
var data: AppData
var events: EventMenu
var touch_demo: bool = false
var capture_path: String = ""
var rendered_frames: int = 0
var capture_frame: int = 150
var network: NetworkClient
var connection_label: Label
var page: String = "main"
var back_action: Callable
var pending_config: Dictionary = {}
var result_summary: Dictionary = {}
var result_receipt: ResultReceipt
var unsaved_results: Dictionary = {}
var settings_page: SettingsPage
var bindings_page: BindingsPage
var menu_repeat := MenuRepeat.new()
var foreground: bool = true
var touch_editor: TouchLayoutEditor
var touch_editor_return: Callable
var lobby_page: LobbyPage
var prepared_world: TrackWorld
var online_result_label: Label
var guest_service := GuestIdentityService.new()
var directory_client := DirectoryClient.new()
var regions := RegionBook.new()
var online_page: OnlinePage
var online_status: Label


func _ready() -> void:
	get_tree().auto_accept_quit = false
	Catalog.load_all()
	DrivingInput.register_defaults()
	var folder := "user://"
	touch_demo = "--touch" in OS.get_cmdline_user_args()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--profile="):
			var profile := arg.trim_prefix("--profile=")
			if GhostCodec.valid_id(profile):
				folder = "user://diagnostic_profiles/" + profile
		elif arg.begins_with("--capture="):
			capture_path = arg.trim_prefix("--capture=")
		elif arg.begins_with("--capture-frame="):
			capture_frame = maxi(1, int(arg.trim_prefix("--capture-frame=")))
	data = AppData.new(folder)
	BindingBook.apply(data.settings.bindings)
	SettingsRuntime.apply(self, data.settings, capture_path.is_empty())
	menu.settings = data.settings
	add_child(menu)
	events = EventMenu.new(self)
	settings_page = SettingsPage.new(self)
	bindings_page = BindingsPage.new(self)
	menu_repeat.allowed = func() -> bool: return foreground and page != "race" and (menu.visible or is_instance_valid(touch_editor) and not touch_editor.previewing) and (not is_instance_valid(bindings_page.capture) or not bindings_page.capture.visible)
	add_child(menu_repeat)
	menu.context_changed.connect(menu_repeat.clear_context)
	lobby_page = LobbyPage.new(self)
	guest_service.configure(data)
	add_child(guest_service)
	add_child(directory_client)
	add_child(regions)
	regions.configure(OS.get_cmdline_user_args())
	online_page = OnlinePage.new(self)
	add_child(online_page)
	directory_client.status_changed.connect(update_online_status)
	if "--drive" in OS.get_cmdline_user_args():
		start_drive()
	elif not data.profile.first_run_complete:
		show_name(true)
	else:
		show_menu()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--connect="):
			show_connection_form()
			connect_address(arg.trim_prefix("--connect="))
	print("PACIFIC_RUSH_CLIENT_READY")


func ensure_stage() -> void:
	if not is_instance_valid(stage):
		stage = MenuStage.new()
		add_child(stage)
	stage.reduce_motion = bool(data.settings.reduce_motion)
	stage.set_paint(int(data.profile.selected_paint))


func dispose_drive(keep_network: bool = false) -> void:
	if is_instance_valid(drive):
		remove_child(drive)
		drive.queue_free()
		drive = null
	if not keep_network and is_instance_valid(network):
		if is_instance_valid(online_page): online_page.depart_active_room()
		network.leave_room()
		network.queue_free()
		network = null
	if is_instance_valid(prepared_world):
		prepared_world.queue_free()
		prepared_world = null


func show_menu() -> void:
	if is_instance_valid(online_page): online_page.cancel_work()
	dispose_drive()
	ensure_stage()
	page = "main"
	back_action = Callable()
	menu.settings = data.settings
	var body := menu.reset(I18n.t("app.title"), I18n.t("app.tagline"), false)
	var list := menu.scroll_column(body)
	append_unsaved_results(list)
	list.get_parent().size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var choices := ["online", "quick", "trial", "cup", "school", "garage", "settings", "credits", "quit"]
	if data.mobile:
		choices.erase("quit")
	for choice: String in choices:
		var button := menu.ui.button(I18n.t("menu." + choice), func() -> void: main_choice(choice), 270)
		list.add_child(button)
		if choice == data.profile.last_menu:
			menu.focus_later(button)
	menu.footer.add_child(menu.ui.label(data.profile.display_name))
	menu.footer.add_child(menu.ui.button(I18n.t("menu.edit_name"), func() -> void: show_name(false)))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu.footer.add_child(spacer)
	online_status = menu.ui.label("")
	menu.footer.add_child(online_status)
	update_online_status("online" if directory_client.online() else "offline")
	show_notices()


func main_choice(choice: String) -> void:
	data.profile.last_menu = choice
	data.save_profile()
	match choice:
		"quick", "trial", "garage": show_garage(choice)
		"cup": show_cup()
		"online": show_online()
		"school": show_school()
		"settings": settings_page.show_tab("display", show_menu)
		"credits": show_credits()
		"quit": request_quit()


func show_name(first: bool) -> void:
	page = "name"
	back_action = Callable() if first else show_menu
	var body := menu.reset(I18n.t("first.title" if first else "menu.edit_name"))
	var list := menu.scroll_column(body)
	list.add_child(menu.ui.label(I18n.t("first.name")))
	var edit := LineEdit.new()
	edit.text = data.profile.display_name
	edit.max_length = 96
	edit.custom_minimum_size.y = menu.ui.row_height()
	list.add_child(edit)
	var error := menu.ui.paragraph("")
	error.modulate = UIFactory.CORAL
	list.add_child(error)
	if first:
		events.choice(list, "first.units", ["mph", "km/h"], 0 if data.settings.units == "mph" else 1, func(index: int) -> void: data.set_setting("units", ["mph", "km/h"][index]))
		var reduce := CheckButton.new()
		reduce.text = I18n.t("first.reduce_motion")
		reduce.button_pressed = data.settings.reduce_motion
		reduce.toggled.connect(func(value: bool) -> void: data.set_setting("reduce_motion", value))
		list.add_child(reduce)
	var save := func() -> void:
		var checked := PlayerName.validate(edit.text)
		if not checked.valid:
			error.text = I18n.t(checked.error)
			return
		data.profile.display_name = checked.value
		data.profile.first_run_complete = true
		if data.save_profile() != OK:
			error.text = I18n.t("data.save_failed")
			return
		show_school_offer() if first else show_menu()
	menu.footer.add_child(menu.ui.button(I18n.t("button.continue" if first else "button.save"), save))
	if not first:
		menu.add_back(show_menu)
	edit.text_submitted.connect(func(_text: String) -> void: save.call())
	if first and data.mobile:
		menu.first_focus()
	else:
		edit.call_deferred("grab_focus")


func show_school_offer() -> void:
	page = "school_offer"
	back_action = show_menu
	var body := menu.reset(I18n.t("first.school_title"), I18n.t("first.school_body"))
	body.add_child(menu.ui.button(I18n.t("first.start_school"), show_school))
	body.add_child(menu.ui.button(I18n.t("button.skip"), show_menu))
	menu.first_focus()


func show_garage(mode: String = "garage") -> void:
	page = "garage"
	back_action = lobby_page.show_lobby if mode == "online" else show_menu
	ensure_stage()
	var body := menu.reset(I18n.t("garage.title"), "", false)
	var list := menu.scroll_column(body)
	var cards := GridContainer.new()
	cards.columns = 2 if data.mobile or int(data.settings.ui_scale) >= 125 else 4
	list.add_child(cards)
	for index in range(4):
		var car: CarDefinition = Catalog.cars[index]
		var caption := I18n.t("car." + car.id)
		var button := menu.ui.button(caption, func() -> void:
			data.select_car(index, int(data.profile.selected_paint))
			show_garage(mode), 230)
		button.modulate = UIFactory.TURQUOISE if index == int(data.profile.selected_car) else Color.WHITE
		var card := VBoxContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_child(button)
		card.add_child(menu.ui.paragraph(I18n.t("role." + car.id)))
		card.add_child(menu.ui.paragraph("%s %.0f\n%s %.1f\n%s %.0f" % [I18n.t("garage.speed"), car.top_speed * (2.236936 if data.settings.units == "mph" else 3.6), I18n.t("garage.acceleration"), car.acceleration, I18n.t("garage.grip"), car.grip]))
		cards.add_child(menu.ui.panel(card))
	var space := Control.new()
	space.custom_minimum_size.y = 140 * menu.ui.unit
	list.add_child(space)
	var paints := GridContainer.new()
	paints.columns = 4 if data.mobile else 8
	list.add_child(paints)
	for index in range(8):
		var button := menu.ui.button(I18n.t("paint." + str(index)), func() -> void:
			data.select_car(int(data.profile.selected_car), index)
			show_garage(mode))
		button.add_theme_color_override("font_color", Catalog.paints[index].lightened(.25))
		if index == int(data.profile.selected_paint):
			button.text = "✓ " + button.text
		paints.add_child(button)
	list.add_child(menu.ui.paragraph(I18n.t("garage.rotate")))
	menu.add_back(lobby_page.show_lobby if mode == "online" else show_menu)
	menu.footer.add_child(menu.ui.button(I18n.t("button.confirm" if mode == "garage" else "button.continue"), func() -> void:
		if mode == "garage":
			show_menu()
		elif mode == "online":
			network.command("select_car", {"car":int(data.profile.selected_car), "paint":int(data.profile.selected_paint)})
			lobby_page.show_lobby()
		elif mode == "cup":
			if data.start_cup() == OK:
				start_cup_event()
		else:
			events.mode = mode
			page = "event"
			back_action = func() -> void: show_garage(mode)
			events.show_event()))
	menu.first_focus()


func start_drive(configuration: Dictionary = {}, reuse_world: bool = false) -> void:
	if not touch_layout_available():
		return
	configuration = configuration.duplicate(true)
	if configuration.get("mode","quick")=="quick" and not configuration.has("seed"):
		# Fresh event entropy stays outside deterministic simulation. Retry uses
		# pending_config, retaining this exact seed and roster order.
		configuration["seed"] = int(Crypto.new().generate_random_bytes(4).decode_u32(0))
	var retained_world: TrackWorld
	if reuse_world and is_instance_valid(drive) and not network and drive.session.mode in ["trial","quick"] and drive.track==Catalog.tracks[int(configuration.get("track",0))]:
		retained_world = drive.world
		drive.remove_child(retained_world)
	if is_instance_valid(stage):
		remove_child(stage)
		stage.queue_free()
		stage = null
	if is_instance_valid(drive):
		remove_child(drive)
		drive.queue_free()
	pending_config = configuration.duplicate(true)
	page = "race"
	menu.hide()
	drive = RaceDrive.new()
	drive.config = configuration
	drive.prepared_world = retained_world
	drive.retry_countdown = retained_world!=null and configuration.get("mode","")=="trial"
	drive.app_data = data
	drive.external_menus = true
	drive.show_touch = touch_demo
	drive.reduce_motion = bool(data.settings.reduce_motion)
	drive.leave_requested.connect(return_to_menu)
	drive.pause_requested.connect(show_pause)
	drive.results_ready.connect(show_results)
	drive.school_completed.connect(show_school_complete)
	drive.school_skipped.connect(skip_school)
	add_child(drive)


func retry_drive() -> void:
	start_drive(pending_config,true)


func return_to_menu() -> void:
	show_menu()


func show_pause() -> void:
	page = "pause"
	back_action = resume_drive
	var mode: String = drive.session.mode
	var body := menu.reset(I18n.t("pause.online" if network else "pause.title"))
	var list := menu.scroll_column(body)
	list.add_child(menu.ui.button(I18n.t("pause.resume"), resume_drive))
	if not network and mode != "cup":
		list.add_child(menu.ui.button(I18n.t("pause.restart_trial" if mode == "trial" else "pause.restart"), retry_drive))
	if mode == "trial":
		var ghost := CheckButton.new()
		ghost.text = I18n.t("event.ghost")
		ghost.button_pressed = drive.show_ghost
		ghost.toggled.connect(func(value: bool) -> void:
			drive.show_ghost = value)
		list.add_child(ghost)
	list.add_child(menu.ui.button(I18n.t("menu.settings"), func() -> void: settings_page.show_tab("display", show_pause)))
	list.add_child(menu.ui.button(I18n.t("pause.controls"), func() -> void: settings_page.show_tab("controls", show_pause)))
	var quit_key := "cup.save_quit" if mode == "cup" else "pause.leave" if network else "pause.quit"
	list.add_child(menu.ui.button(I18n.t(quit_key), func() -> void: menu.confirm(I18n.t("pause.leave_confirm" if network else "pause.offline_confirm"), return_to_menu)))
	menu.first_focus()


func resume_drive() -> void:
	menu.hide()
	page = "race"
	drive.apply_settings()
	drive.resume()


func show_results() -> void:
	page = "results"
	back_action = Callable()
	if result_receipt==null or result_receipt.session.race_uuid!=drive.session.race_uuid:
		result_receipt = ResultReceipt.capture(drive.session,drive.ghost_samples,network.result_event.get("results",[]) if network else [])
	retry_result_save()


func retry_result_save() -> void:
	result_summary = result_receipt.commit(data)
	var id: String = result_receipt.session.race_uuid
	if result_summary.saved:
		unsaved_results.erase(id)
	else:
		unsaved_results[id] = result_receipt
	render_results()


func continue_without_saving() -> void:
	result_receipt.dismissed = true
	unsaved_results.erase(result_receipt.session.race_uuid)
	if result_receipt.session.mode=="cup":
		# A Cup advances only when its event is committed. Leaving this result
		# resumes its last committed event checkpoint on the next Continue.
		return_to_menu()
	else:
		render_results()


func append_unsaved_results(parent: Node) -> void:
	if unsaved_results.is_empty():
		return
	parent.add_child(menu.ui.paragraph(I18n.t("data.pending_results",[unsaved_results.size()])))
	parent.add_child(menu.ui.button(I18n.t("data.retry_save"),retry_pending_saves))
	parent.add_child(menu.ui.button(I18n.t("data.dismiss_results"),func() -> void:
		menu.confirm(I18n.t("data.dismiss_results_confirm"),func() -> void:
			unsaved_results.clear()
			refresh_after_pending_saves())))


func retry_pending_saves() -> void:
	for id: String in unsaved_results.keys():
		var receipt: ResultReceipt = unsaved_results[id]
		if receipt.commit(data).saved:
			unsaved_results.erase(id)
	refresh_after_pending_saves()


func refresh_after_pending_saves() -> void:
	if page=="lobby" and network:
		lobby_page.show_lobby()
	else:
		show_menu()


func request_quit() -> void:
	if unsaved_results.is_empty():
		get_tree().quit()
	else:
		if is_instance_valid(touch_editor):
			close_touch_editor()
		if page=="race" and is_instance_valid(drive):
			drive.show_pause()
		menu.confirm(I18n.t("data.quit_unsaved"),func() -> void: get_tree().quit())


func render_results() -> void:
	var session := result_receipt.session
	var local_state := session.states[session.human_slot]
	var body := menu.reset(I18n.t("results.trial_title" if session.mode == "trial" else "results.title"))
	var list := menu.scroll_column(body)
	if not result_summary.saved:
		list.add_child(menu.ui.paragraph(I18n.t("data.save_failed")))
		list.add_child(menu.ui.paragraph(I18n.t("data.cup_unsaved" if session.mode=="cup" else "data.continue_unsaved_help")))
		list.add_child(menu.ui.button(I18n.t("data.retry_save"), retry_result_save))
	elif result_summary.new_best:
		list.add_child(menu.ui.label(I18n.t("results.new_best"), true))
	if session.mode == "trial":
		list.add_child(menu.ui.label(RaceHUD.format_time(local_state.finish_time) if local_state.finished else I18n.t("results.dnf"), true))
		if not local_state.trial_valid:
			list.add_child(menu.ui.paragraph(I18n.t("results.invalid")))
		var medal := Medals.award(session.track.length, local_state.finish_time, local_state.finished and local_state.trial_valid)
		list.add_child(menu.ui.label(I18n.t(["results.no_medal", "results.gold", "results.silver", "results.bronze"][medal + 1])))
		var previous := float(result_summary.get("previous", -1))
		list.add_child(menu.ui.label(I18n.t("results.previous") + ": " + (RaceHUD.format_time(previous) + "  (%+.3f)" % (local_state.finish_time - previous) if previous > 0 and local_state.finished else I18n.t("results.no_previous"))))
		var thresholds := Medals.thresholds(session.track.length)
		for index in range(3):
			list.add_child(menu.ui.label(I18n.t("results." + ["gold", "silver", "bronze"][index]) + "  " + RaceHUD.format_time(thresholds[index])))
	else:
		var order: Array[VehicleState] = []
		for slot: int in result_receipt.order:
			order.append(session.states[slot])
		for index in range(order.size()):
			var state: VehicleState = order[index]
			var record: Dictionary = session.roster[state.slot]
			var gap := "—" if index == 0 or not state.finished or not order[0].finished else "+%.3f" % (state.finish_time - order[0].finish_time)
			var row := menu.ui.paragraph("%d  %s  •  %s  •  %s  •  %s  •  %s" % [index + 1, record.name, I18n.t("car." + session.cars[state.slot].id), RaceHUD.format_time(state.finish_time) if state.finished else I18n.t("results.dnf") + " " + state.dnf_reason, RaceHUD.format_time(state.best_lap_time) if state.best_lap_time > 0 else "—", gap])
			list.add_child(menu.ui.panel(row) if state.slot == session.human_slot else row)
	if session.mode=="cup":
		append_cup_standings(list)
	if session.mode=="online":
		online_result_label = menu.ui.label("")
		list.add_child(online_result_label)
	if not result_summary.saved and not result_receipt.dismissed:
		menu.footer.add_child(menu.ui.button(I18n.t("data.continue_unsaved"),continue_without_saving))
		menu.first_focus()
		return
	if session.mode == "online":
		menu.footer.add_child(menu.ui.button(I18n.t("online.return_lobby"), func() -> void: network.command("return_lobby")))
		menu.footer.add_child(menu.ui.button(I18n.t("online.leave"), return_to_menu))
	elif session.mode == "cup":
		if int(data.cup.data.next_event) < 6:
			menu.footer.add_child(menu.ui.button(I18n.t("cup.next"), start_cup_event))
		menu.footer.add_child(menu.ui.button(I18n.t("cup.save_quit"), return_to_menu))
	else:
		menu.footer.add_child(menu.ui.button(I18n.t("results.retry"), retry_drive))
		menu.footer.add_child(menu.ui.button(I18n.t("results.change_track" if session.mode == "trial" else "results.change_event"), func() -> void:
			dispose_drive()
			ensure_stage()
			events.mode = session.mode
			events.show_event()))
		menu.footer.add_child(menu.ui.button(I18n.t("button.main_menu"), return_to_menu))
	menu.first_focus()


func show_cup() -> void:
	page = "cup"
	back_action = show_menu
	var body := menu.reset(I18n.t("cup.title"), I18n.t("cup.rules"))
	var list := menu.scroll_column(body)
	for index in range(6):
		list.add_child(menu.ui.label("%d  %s" % [index + 1, I18n.t("track." + Catalog.tracks[index].id)]))
	if not data.cup.data.is_empty():
		if data.cup.compatible(Compatibility.content_hash()):
			append_cup_standings(list)
			if int(data.cup.data.next_event) < 6:
				menu.footer.add_child(menu.ui.button(I18n.t("cup.continue"), start_cup_event))
		else:
			list.add_child(menu.ui.paragraph(I18n.t("cup.old_version")))
		menu.footer.add_child(menu.ui.button(I18n.t("cup.abandon"), func() -> void: menu.confirm(I18n.t("cup.abandon_confirm"), func() -> void:
			if data.abandon_cup() == OK:
				show_cup())))
	menu.footer.add_child(menu.ui.button(I18n.t("cup.start"), func() -> void:
		if not data.cup.data.is_empty() and int(data.cup.data.next_event) < 6:
			menu.confirm(I18n.t("cup.replace"), func() -> void: show_garage("cup"))
		else:
			show_garage("cup")))
	menu.add_back(show_menu)
	menu.first_focus()


func append_cup_standings(parent: Node) -> void:
	parent.add_child(menu.ui.label(I18n.t("cup.standings"), true))
	var rank := 0
	for row: Dictionary in data.cup.standings():
		rank += 1
		parent.add_child(menu.ui.label("%d  %s   %d %s" % [rank, row.name, row.points, I18n.t("cup.points")]))


func start_cup_event() -> void:
	var cup := data.cup
	if not cup.compatible(Compatibility.content_hash()) or int(cup.data.next_event) >= 6:
		show_cup()
		return
	var index := int(cup.data.next_event)
	var roster := cup.grid()
	var human: Dictionary = roster.filter(func(row: Dictionary) -> bool: return row.id == "local")[0]
	start_drive({"mode":"cup", "track":index, "car":int(human.car), "paint":int(human.paint), "laps":2, "roster":roster, "seed":int(cup.data.seeds[index]), "cup_event":index, "cup_id":str(cup.data.id), "contact":true, "difficulty":1})


func show_school() -> void:
	dispose_drive()
	ensure_stage()
	page = "school"
	back_action = show_menu
	var body := menu.reset(I18n.t("school.title"))
	var list := menu.scroll_column(body)
	for index in range(5):
		list.add_child(menu.ui.button(("✓ " if data.profile.school_steps[index] else "") + I18n.t("school." + str(index)), func() -> void: start_drive({"mode":"school", "lesson":index})))
	menu.add_back(show_menu)
	menu.first_focus()


func skip_school() -> void:
	var index := int(drive.config.get("lesson", 0))
	if index < 4:
		start_drive({"mode":"school", "lesson":index + 1})
	else:
		show_school_complete()


func show_school_complete() -> void:
	var index := int(drive.config.get("lesson", 0))
	if drive.lesson.done:
		data.profile.school_steps[index] = true
		data.save_profile()
	drive.paused = true
	drive.touch.clear()
	drive.touch.enabled = false
	page = "school_complete"
	back_action = show_school
	var body := menu.reset(I18n.t("school.finished" if index == 4 else "school.complete"))
	body.add_child(menu.ui.button(I18n.t("school.retry"), func() -> void: start_drive(pending_config)))
	if index < 4:
		body.add_child(menu.ui.button(I18n.t("school.next"), func() -> void: start_drive({"mode":"school", "lesson":index + 1})))
	else:
		body.add_child(menu.ui.paragraph(I18n.t("school.final_body")))
		body.add_child(menu.ui.button(I18n.t("menu.quick"), func() -> void:
			dispose_drive()
			show_garage("quick")))
	body.add_child(menu.ui.button(I18n.t("button.main_menu"), show_menu))
	menu.first_focus()


func show_online() -> void:
	online_page.show_hub()


func update_online_status(state: String) -> void:
	if is_instance_valid(online_status) and page=="main":
		online_status.text = build_name()+" • "+I18n.t("menu."+{"connecting":"connecting","online":"online_status"}.get(state,"offline"))


func show_connection_form() -> void:
	page = "connect"
	back_action = show_online
	var body := menu.reset(I18n.t("online.direct"), I18n.t("online.community"))
	var address := LineEdit.new()
	address.placeholder_text = I18n.t("online.address_help")
	address.text = "127.0.0.1:27020"
	address.custom_minimum_size.y = menu.ui.row_height()
	body.add_child(address)
	var code := LineEdit.new()
	code.placeholder_text = I18n.t("online.code_optional")
	code.custom_minimum_size.y = menu.ui.row_height()
	body.add_child(code)
	connection_label = menu.ui.paragraph(I18n.t("online.waiting"))
	body.add_child(connection_label)
	body.add_child(menu.ui.button(I18n.t("online.connect"), func() -> void: connect_address(address.text, code.text)))
	menu.add_back(func() -> void:
		if network:
			network.queue_free()
			network = null
		show_online())
	address.call_deferred("grab_focus")


func connect_address(value: String, code_value: String = "", admission_ticket: String = "") -> void:
	var address := PeerAddress.parse(value)
	if address.is_empty():
		connection_label.text = I18n.t("online.address_error")
		return
	var checked_code := PeerAddress.parse_code(code_value)
	if not checked_code.valid:
		connection_label.text = I18n.t("online.code_error")
		return
	if is_instance_valid(network):
		network.queue_free()
	network = NetworkClient.new()
	add_child(network)
	network.room_code = checked_code.value
	network.admission_ticket = admission_ticket
	network.initial_car = int(data.profile.selected_car)
	network.initial_paint = int(data.profile.selected_paint)
	network.loading_requested.connect(prepare_online)
	network.race_started.connect(start_online)
	network.results_received.connect(online_results)
	network.returned_to_lobby.connect(func() -> void:
		dispose_drive(true)
		ensure_stage()
		lobby_page.code_visible = false
		lobby_page.show_lobby())
	network.lobby_changed.connect(func(state: Dictionary) -> void:
		if int(state.phase) == LobbyState.Phase.LOBBY and page in ["connect", "lobby"]:
			if int(state.revision) != lobby_page.shown_revision or page != "lobby":
				lobby_page.show_lobby())
	network.disconnected_permanently.connect(show_connection_lost)
	network.status_changed.connect(func(message: String) -> void:
		if is_instance_valid(connection_label):
			connection_label.text = message
		print("NETWORK_STATUS " + message))
	network.connect_to(address.host, address.port, data.profile.display_name)


func prepare_online(configuration: Dictionary) -> void:
	if not touch_layout_available():
		return
	page = "loading"
	back_action = func() -> void:
		network.leave_room()
		show_menu()
	if is_instance_valid(stage):
		remove_child(stage)
		stage.queue_free()
		stage = null
	var body := menu.reset(I18n.t("online.loading"), I18n.t("track." + Catalog.tracks[int(configuration.track)].id))
	body.add_child(menu.ui.paragraph(I18n.t("settings.controls_help")))
	body.add_child(menu.ui.paragraph(I18n.t("online.waiting")))
	menu.add_back(back_action)
	await get_tree().process_frame
	if not network or page != "loading":
		return
	prepared_world = TrackWorld.new()
	prepared_world.build(Catalog.tracks[int(configuration.track)])
	add_child(prepared_world)
	await get_tree().physics_frame
	if network and page == "loading":
		network.mark_loaded(int(configuration.race))


func start_online(_configuration: Dictionary) -> void:
	menu.hide()
	page = "race"
	drive = RaceDrive.new()
	drive.network = network
	drive.app_data = data
	drive.show_touch = touch_demo
	drive.external_menus = true
	drive.prepared_world = prepared_world
	prepared_world = null
	drive.leave_requested.connect(return_to_menu)
	drive.pause_requested.connect(show_pause)
	add_child(drive)


func online_results(rows: Array) -> void:
	if not drive:
		return
	for row: Dictionary in rows:
		if int(row.slot) >= drive.session.states.size():
			return
		var state: VehicleState = drive.session.states[int(row.slot)]
		state.finished = row.dnf == "" and float(row.time) >= 0
		state.finish_time = float(row.time)
		state.dnf_reason = row.dnf
		state.best_lap_time = float(row.best_lap)
		state.distance_m = float(row.distance_m)
	drive.result_sent = true
	drive.session.phase = RaceSession.Phase.RESULTS
	drive.touch.clear()
	drive.touch.enabled = false
	show_results()


func show_connection_lost(message: String) -> void:
	if is_instance_valid(online_page) and online_page.pending=="connecting" and page=="connect":
		online_page.fail("room_unavailable")
		return
	dispose_drive()
	page = "connection_lost"
	back_action = show_online
	var body := menu.reset(I18n.t("online.title"), message)
	menu.add_back(show_online)
	body.add_child(menu.ui.paragraph(I18n.t("online.abandoned")))
	menu.first_focus()


func show_credits() -> void:
	page = "credits"
	back_action = show_menu
	var body := menu.reset(I18n.t("credits.title"))
	var list := menu.scroll_column(body)
	for key in ["creator", "software", "fonts", "inspiration", "licenses"]:
		list.add_child(menu.ui.paragraph(I18n.t("credits." + key)))
	list.add_child(menu.ui.label(build_name()))
	menu.add_back(show_menu)
	menu.first_focus()


func build_name() -> String:
	var filename := "res://game/build.json"
	if OS.has_feature("template") and FileAccess.file_exists(filename):
		var info: Variant = JSON.parse_string(FileAccess.get_file_as_string(filename))
		if info is Dictionary:
			return str(info.get("version", "Development"))
	return "Development • " + Compatibility.content_hash().left(8)


func show_notices() -> void:
	for notice: String in data.store.notices:
		menu.footer.add_child(menu.ui.paragraph(I18n.t(notice)))
	data.store.notices.clear()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and page != "race" and back_action.is_valid():
		back_action.call()
		get_viewport().set_input_as_handled()


func _process(_dt: float) -> void:
	if network and page == "results" and is_instance_valid(online_result_label):
		online_result_label.text = I18n.t("online.return_countdown", [maxi(0, ceili((float(network.result_event.get("return_tick", 0)) - network.server_tick) / 60))])
	if lobby_page and page == "lobby":
		lobby_page.update_countdown()
	if capture_path.is_empty():
		return
	rendered_frames += 1
	if rendered_frames == capture_frame:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(capture_path)
		print("PACIFIC_RUSH_CAPTURE_SAVED")
		get_tree().quit()


func _notification(what: int) -> void:
	if not is_inside_tree():
		return
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_inside_tree():
		if ChoicePicker.close_active(get_viewport()):
			return
		if page == "race" and is_instance_valid(drive):
			drive.show_pause()
		elif back_action.is_valid():
			back_action.call()
	elif what == NOTIFICATION_WM_CLOSE_REQUEST:
		request_quit()
	if capture_path != "":
		return
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_APPLICATION_PAUSED]:
		foreground = false
		menu_repeat.clear_context()
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED]:
		foreground = true
		menu_repeat.clear_context()


func _input(event: InputEvent) -> void:
	if page != "race":
		DrivingInput.remember_menu_device(event)


func touch_layout_available() -> bool:
	if not (touch_demo or OS.has_feature("mobile")):
		return true
	var geometry := TouchDriving.safe_geometry(get_viewport().get_visible_rect().size)
	var layout := TouchDriving.build_layout(geometry.safe, bool(data.settings.touch_auto_accelerate), str(data.settings.steering_style), float(data.settings.button_size) / 100, bool(data.settings.left_handed))
	if not layout.is_empty():
		return true
	dispose_drive()
	ensure_stage()
	page = "touch_unavailable"
	back_action = show_menu
	var body := menu.reset(I18n.t("tab.touch"))
	body.add_child(menu.ui.paragraph(I18n.t("touch.screen_small")))
	menu.add_back(show_menu)
	menu.first_focus()
	return false


func show_touch_editor() -> void:
	if settings_page.touch_layout_locked():
		return
	touch_editor_return = settings_page.back if settings_page.back.is_valid() else show_menu
	menu.hide()
	page = "touch_layout"
	touch_editor = TouchLayoutEditor.new()
	touch_editor.app = self
	touch_editor.closed.connect(close_touch_editor)
	back_action = func() -> void:
		if is_instance_valid(touch_editor):
			if touch_editor.previewing:
				touch_editor.finish_preview()
			else:
				touch_editor.cancel()
	add_child(touch_editor)
	menu_repeat.clear_context()


func close_touch_editor() -> void:
	if not is_instance_valid(touch_editor):
		return
	touch_editor.hide()
	remove_child(touch_editor)
	touch_editor.queue_free()
	touch_editor = null
	if is_instance_valid(drive):
		drive.apply_settings()
	settings_page.show_tab("touch",touch_editor_return)

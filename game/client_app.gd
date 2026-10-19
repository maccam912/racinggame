extends Node3D

var menu := MenuShell.new()
var drive: RaceDrive
var stage: MenuStage
var data: AppData
var events: EventMenu
var garage_mode: String = "garage"
var garage_car_buttons: Array[Button] = []
var garage_paint_buttons: Array[Button] = []
var touch_demo: bool = false
var capture_path: String = ""
var rendered_frames: int = 0
var capture_frame: int = 150
var capture_track: String = ""
var capture_race_tick: int = -1
var capture_pending: bool = false
var network: NetworkClient
var connection_label: Label
var connection_button: Button
var connection_back: Button
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
var presentation := WorldPresentation.new()
var mobile_runtime := MobileRuntime.new()
var audio_mix := AudioMix.new()
var game_audio := GameAudio.new()
var diagnostics := Diagnostics.new()
var track_loader: TrackLoader
var loading_bar: ProgressBar
var loading_status: Label
var loading_hint: Label
var loading_hint_started: int = 0
var checkpoint: RaceCheckpoint
var checkpoint_error: String = ""
var school_progress_saved: bool = false
const LOADING_HINTS: Array[String] = ["loading.hint_brake","loading.hint_slide","loading.hint_recover","loading.hint_look"]


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
		elif arg.begins_with("--capture-track="):
			capture_track = arg.trim_prefix("--capture-track=")
		elif arg.begins_with("--capture-race-tick="):
			capture_race_tick = clampi(int(arg.trim_prefix("--capture-race-tick=")),1,18000)
	data = AppData.new(folder)
	diagnostics.app = self
	add_child(diagnostics)
	presentation.app = self
	add_child(presentation)
	mobile_runtime.app = self
	add_child(mobile_runtime)
	add_child(audio_mix)
	game_audio.app = self
	add_child(game_audio)
	BindingBook.apply(data.settings.bindings)
	SettingsRuntime.apply(self, data.settings, capture_path.is_empty())
	menu.settings = data.settings
	add_child(menu)
	events = EventMenu.new(self)
	settings_page = SettingsPage.new(self)
	diagnostics.export_finished.connect(settings_page.diagnostics_finished)
	bindings_page = BindingsPage.new(self)
	menu_repeat.allowed = func() -> bool: return (foreground or mobile_runtime.audio_blocked and mobile_runtime.window_active) and page != "race" and (menu.visible or is_instance_valid(touch_editor) and not touch_editor.previewing) and (not is_instance_valid(bindings_page.capture) or not bindings_page.capture.visible)
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
	open_start_screen()

func missing_car_asset() -> String:
	if OS.has_feature("android") and not Engine.has_singleton("PacificMobile"): return I18n.t("installation.mobile_services")
	for car: CarDefinition in Catalog.cars:
		if not CarVisual.available(car.mesh_id): return I18n.t("car."+car.id)
	for path: String in ["res://assets/exported/textures/cars_atlas.png","res://assets/exported/shaders/car.gdshader","res://assets/exported/shaders/car_ghost.gdshader","res://assets/exported/shaders/blob_shadow.gdshader"]:
		if not ResourceLoader.exists(path): return I18n.t("installation.materials")
	if not FileAccess.file_exists("res://assets/exported/audio/catalog.json"): return I18n.t("installation.audio")
	for row: Dictionary in AudioLibrary.entries().values():
		if not ResourceLoader.exists("res://"+str(row.path)): return I18n.t("installation.audio")
	if not FileAccess.file_exists("res://assets/exported/icons/catalog.json"): return I18n.t("installation.icons")
	for row: Dictionary in UIIcons.entries().values():
		if not ResourceLoader.exists("res://"+str(row.path)): return I18n.t("installation.icons")
	return ""

func open_start_screen() -> void:
	var missing := missing_car_asset()
	if not missing.is_empty():
		show_installation_error(missing)
		return
	if not capture_track.is_empty():
		# Explicit diagnostic capture uses a disposable profile and a genuine
		# ordinary race. It cannot change a player's selected car/settings.
		var diagnostic_root := ProjectSettings.globalize_path("user://diagnostic_profiles/").replace("\\","/")
		if capture_path.is_empty() or not data.store.root_path.begins_with(diagnostic_root) or not "--autodrive" in OS.get_cmdline_user_args():
			push_error("Gameplay capture requires --capture, --profile and --autodrive")
			get_tree().quit(1)
			return
		var selected := -1
		for index in range(Catalog.tracks.size()):
			if Catalog.tracks[index].id==capture_track: selected = index
		if selected<0:
			push_error("Unknown gameplay capture track")
			get_tree().quit(1)
			return
		data.settings.camera = "near"
		data.settings.preset = "medium"
		data.apply_preset("medium")
		if capture_race_tick<0: capture_race_tick = 1200
		SettingsRuntime.apply(self,data.settings,false)
		request_drive({"mode":"quick","track":selected,"car":selected%4,"paint":selected%8,"opponents":7,"difficulty":1,"laps":2,"contact":true,"seed":0x505200+selected},show_menu)
		return
	local_checkpoint().reload()
	if "--drive" in OS.get_cmdline_user_args():
		start_drive()
	elif not local_checkpoint().payload.is_empty():
		show_saved_race()
	elif not data.profile.first_run_complete:
		show_name(true)
	else:
		show_menu()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--connect="):
			show_connection_form()
			connect_address(arg.trim_prefix("--connect="))
	print("PACIFIC_RUSH_CLIENT_READY")


func local_checkpoint() -> RaceCheckpoint:
	if checkpoint==null or checkpoint.data!=data: checkpoint = RaceCheckpoint.new(data)
	return checkpoint


func show_saved_race() -> void:
	dispose_drive()
	ensure_stage()
	page = "saved_race"
	back_action = request_quit
	var saved := local_checkpoint()
	var compatible := saved.can_resume()
	if compatible: stage.set_selection(int(saved.payload.config.car),int(saved.payload.config.paint))
	var trial: bool = compatible and saved.payload.session.mode=="trial"
	var body := menu.reset(I18n.t("resume.title"))
	var list := menu.scroll_column(body)
	if compatible:
		list.add_child(menu.ui.paragraph(I18n.t("resume.details",[I18n.t("menu."+str(saved.payload.session.mode)),I18n.t("track."+Catalog.tracks[int(saved.payload.config.track)].id)])))
		if trial: list.add_child(menu.ui.paragraph(I18n.t("resume.trial_body")))
	else: list.add_child(menu.ui.paragraph(I18n.t("resume.incompatible")))
	var resume_button := menu.ui.button(I18n.t("resume.restart_trial" if trial else "resume.continue"),resume_saved_race)
	resume_button.disabled = not compatible
	if not compatible: menu.ui.help(resume_button,I18n.t("resume.incompatible"),true)
	list.add_child(resume_button)
	list.add_child(menu.ui.button(I18n.t("resume.discard"),func() -> void:
		if local_checkpoint().discard(true)==OK:
			checkpoint_error = ""
			show_menu()
		else:
			checkpoint_error = data.store.last_error if not data.store.last_error.is_empty() else "data.save_failed"
			show_saved_race()))
	if not checkpoint_error.is_empty(): list.add_child(menu.ui.paragraph(I18n.t(checkpoint_error)))
	show_notices()
	menu.footer.get_parent().visible = menu.footer.get_child_count()>0
	menu.first_focus()


func resume_saved_race() -> void:
	var saved := local_checkpoint()
	if not saved.can_resume(): return
	var value := saved.payload.duplicate(true)
	request_drive(value.config,show_saved_race,{} if value.session.mode=="trial" else value)

func show_installation_error(missing: String) -> void:
	dispose_drive()
	if is_instance_valid(stage):
		stage.queue_free()
		stage = null
	page = "installation_error"
	back_action = Callable()
	var body := menu.reset(I18n.t("installation.title"),I18n.t("installation.body",[missing]))
	var status := menu.ui.paragraph("")
	body.add_child(menu.ui.button(I18n.t("button.retry"),open_start_screen))
	body.add_child(menu.ui.button(I18n.t("settings.export"),func() -> void:
		var error := diagnostics.begin_export()
		status.text = I18n.t("diagnostics.choose" if error==OK else "diagnostics.busy" if error==ERR_BUSY else "diagnostics.failed")
		if error==OK:
			diagnostics.export_finished.connect(func(state: String) -> void:
				if is_instance_valid(status): status.text = I18n.t("diagnostics."+state),CONNECT_ONE_SHOT)))
	body.add_child(status)
	if not data.mobile: body.add_child(menu.ui.button(I18n.t("menu.quit"),request_quit))
	menu.first_focus()


func ensure_stage() -> void:
	if not is_instance_valid(stage):
		stage = MenuStage.new()
		stage.car_index = int(data.profile.selected_car)
		stage.paint_index = int(data.profile.selected_paint)
		add_child(stage)
	stage.reduce_motion = bool(data.settings.reduce_motion)
	stage.set_selection(int(data.profile.selected_car),int(data.profile.selected_paint))
	SettingsRuntime.apply(self,data.settings)


func dispose_drive(keep_network: bool = false) -> void:
	cancel_loading()
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
	if is_instance_valid(drive) and drive.network==null: local_checkpoint().discard()
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
		menu.ui.help(button,I18n.t("help.menu."+choice))
		button.set_meta("help_side",true)
		menu.ui.set_icon(button,"menu_"+choice)
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
	var edit := UIFactory.text_edit()
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
			game_audio.effect("ui_error")
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
	garage_mode = mode
	garage_car_buttons.clear()
	garage_paint_buttons.clear()
	page = "garage"
	back_action = lobby_page.show_lobby if mode == "online" else show_menu
	ensure_stage()
	var body := menu.reset(I18n.t("garage.title"), "", false)
	var list := menu.scroll_column(body)
	var cards := GridContainer.new()
	cards.columns = 2 if data.mobile or int(data.settings.ui_scale) >= 125 else 4
	list.add_child(cards)
	var acceleration_max := 0.0
	var grip_max := 0.0
	for candidate: CarDefinition in Catalog.cars:
		acceleration_max = maxf(acceleration_max,candidate.acceleration)
		grip_max = maxf(grip_max,candidate.grip)
	for index in range(4):
		var car: CarDefinition = Catalog.cars[index]
		var selected := index==int(data.profile.selected_car)
		var caption := ("✓ " if selected else "")+I18n.t("car." + car.id)
		var button := menu.ui.button(caption, func() -> void:
			data.select_car(index, int(data.profile.selected_paint))
			show_garage(mode), 230)
		menu.ui.set_icon(button,"car_"+car.id)
		garage_car_buttons.append(button)
		menu.ui.selected(button,selected)
		var card := VBoxContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_child(button)
		card.add_child(menu.ui.paragraph(I18n.t("role." + car.id)))
		card.add_child(menu.ui.paragraph("%s %.0f %s" % [I18n.t("garage.speed"),car.top_speed*(2.236936 if data.settings.units=="mph" else 3.6),"mph" if data.settings.units=="mph" else "km/h"]))
		card.add_child(menu.ui.stat("%s %.1f m/s²"%[I18n.t("garage.acceleration"),car.acceleration],car.acceleration,acceleration_max))
		card.add_child(menu.ui.stat("%s %.0f m/s²"%[I18n.t("garage.grip"),car.grip],car.grip,grip_max))
		cards.add_child(menu.ui.panel(card))
	var space := Control.new()
	space.custom_minimum_size.y = 140 * menu.ui.unit
	space.mouse_default_cursor_shape = Control.CURSOR_DRAG
	space.gui_input.connect(stage.preview_input)
	list.add_child(space)
	var paints := GridContainer.new()
	paints.columns = (2 if int(data.settings.ui_scale)>=125 else 4) if data.mobile else (4 if int(data.settings.ui_scale)>=125 else 8)
	list.add_child(paints)
	for index in range(8):
		var button := menu.ui.button(I18n.t("paint." + str(index)), func() -> void:
			data.select_car(int(data.profile.selected_car), index)
			show_garage(mode)
			menu.focus_later(garage_paint_buttons[index]))
		if index == int(data.profile.selected_paint):
			button.text = "✓ " + button.text
		menu.ui.set_icon(button,"paint_"+str(index))
		paints.add_child(button)
		garage_paint_buttons.append(button)
	list.add_child(menu.ui.panel(menu.ui.paragraph(I18n.t("garage.rotate"))))
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
	menu.focus_later(garage_car_buttons[int(data.profile.selected_car)])


func cancel_loading() -> void:
	if is_instance_valid(track_loader):
		track_loader.cancel()
		track_loader.queue_free()
	track_loader = null


func show_loading(configuration: Dictionary, cancel: Callable) -> TrackLoader:
	cancel_loading()
	page = "loading"
	back_action = func() -> void:
		cancel_loading()
		cancel.call()
	var track: TrackDefinition = Catalog.tracks[int(configuration.get("track",0))]
	var body := menu.reset(I18n.t("online.loading"),I18n.t("track."+track.id))
	var list := menu.scroll_column(body)
	var postcard := TextureRect.new()
	postcard.texture = load("res://assets/exported/thumbnails/"+track.id+".png")
	postcard.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	postcard.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	postcard.custom_minimum_size = Vector2(320,180)*menu.ui.unit
	list.add_child(menu.ui.panel(postcard))
	list.add_child(menu.ui.paragraph(I18n.t("school.exercise",[int(configuration.get("lesson",0))+1]) if configuration.get("mode","")=="school" else I18n.t("loading.event",[I18n.t("menu."+str(configuration.get("mode","online"))),int(configuration.get("laps",2))])))
	var device := DrivingInput.last_device
	if device.is_empty(): device = "touch" if data.mobile else "keyboard"
	var hints := RaceDrive.control_captions(data.settings,device,bool(data.settings.touch_auto_accelerate))
	var prompts: Array[String] = []
	for action: String in ["accelerate","brake","handbrake","recover"]:
		prompts.append(I18n.t("action."+action)+": "+str(hints[action]))
	var input_row := HFlowContainer.new()
	for index in range(prompts.size()):
		var row := HBoxContainer.new()
		row.add_child(menu.ui.icon("action_"+["accelerate","brake","handbrake","recover"][index]))
		row.add_child(menu.ui.label(prompts[index]))
		input_row.add_child(row)
	list.add_child(input_row)
	loading_bar = ProgressBar.new()
	loading_bar.min_value = 0
	loading_bar.max_value = 1
	loading_bar.show_percentage = false
	loading_bar.custom_minimum_size.y = 16*menu.ui.unit
	menu.footer.add_child(loading_bar)
	loading_bar.custom_minimum_size.x = 220*menu.ui.unit
	loading_status = menu.ui.label(I18n.t("loading.local"))
	menu.footer.add_child(loading_status)
	loading_hint = menu.ui.paragraph(I18n.t(LOADING_HINTS[0]))
	list.add_child(loading_hint)
	loading_hint_started = Time.get_ticks_msec()
	menu.footer.add_child(menu.ui.button(I18n.t("button.cancel"),back_action))
	menu.first_focus()
	track_loader = TrackLoader.new()
	track_loader.settings = data.settings.duplicate(true)
	track_loader.active = func() -> bool: return foreground
	track_loader.begin(track)
	var expected := track_loader
	expected.progress.connect(func(value: float) -> void:
		if track_loader==expected and page=="loading" and is_instance_valid(loading_bar): loading_bar.value = value)
	expected.failed.connect(func() -> void:
		if track_loader!=expected or page!="loading": return
		loading_status.text = I18n.t("loading.graphics_failed")
		var retry := menu.ui.button(I18n.t("button.retry"),func() -> void: expected.retry_graphics())
		menu.footer.add_child(retry)
		retry.pressed.connect(func() -> void: retry.queue_free())
		retry.grab_focus())
	add_child(expected)
	return expected


func request_drive(configuration: Dictionary, return_to: Callable, resume_payload: Dictionary = {}) -> void:
	if not touch_layout_available(): return
	if is_instance_valid(drive):
		drive.paused = true
		drive.touch.clear()
		drive.touch.enabled = false
	var snapshot := configuration.duplicate(true)
	var resumed := resume_payload.duplicate(true)
	var job := show_loading(snapshot,return_to)
	job.completed.connect(func() -> void:
		if track_loader!=job or page!="loading": return
		var built := job.take_world()
		cancel_loading()
		start_drive(snapshot,false,built,resumed))


func start_drive(configuration: Dictionary = {}, reuse_world: bool = false, supplied_world: TrackWorld = null, resume_payload: Dictionary = {}) -> void:
	if not touch_layout_available():
		if is_instance_valid(supplied_world): supplied_world.queue_free()
		return
	cancel_loading()
	if resume_payload.is_empty(): local_checkpoint().discard()
	checkpoint_error = ""
	school_progress_saved = false
	result_receipt = null
	result_summary = {}
	configuration = configuration.duplicate(true)
	if configuration.get("mode","")=="trial" and not configuration.has("ghost"): configuration["ghost"] = bool(data.settings.trial_ghost)
	if configuration.get("mode","quick")=="quick" and not configuration.has("seed"):
		# Fresh event entropy stays outside deterministic simulation. Retry uses
		# pending_config, retaining this exact seed and roster order.
		configuration["seed"] = int(Crypto.new().generate_random_bytes(4).decode_u32(0))
	var retained_world: TrackWorld = supplied_world
	if retained_world==null and reuse_world and is_instance_valid(drive) and not network and drive.session.mode in ["trial","quick"] and drive.track==Catalog.tracks[int(configuration.get("track",0))]:
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
	drive.retry_countdown = reuse_world and retained_world!=null and configuration.get("mode","")=="trial"
	drive.app_data = data
	drive.external_menus = true
	drive.show_touch = touch_demo
	drive.reduce_motion = bool(data.settings.reduce_motion)
	drive.leave_requested.connect(return_to_menu)
	drive.pause_requested.connect(show_pause)
	drive.results_ready.connect(show_results)
	drive.school_completed.connect(show_school_complete)
	drive.school_skipped.connect(skip_school)
	drive.school_retry_requested.connect(func() -> void: request_drive(pending_config,show_school))
	add_child(drive)
	if not foreground: drive.driver.set_focus(false)
	if not resume_payload.is_empty():
		if not RaceArchive.restore(drive,resume_payload):
			checkpoint_error = "resume.incompatible"
			show_saved_race()
		elif drive.session.phase==RaceSession.Phase.RESULTS: show_results()
		elif foreground: drive.resume()
		else: drive.show_pause()
	elif not foreground: drive.show_pause()


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
	var resume_button := menu.ui.button(I18n.t("pause.resume"), resume_drive)
	resume_button.disabled = not foreground
	list.add_child(resume_button)
	if mobile_runtime.audio_blocked:
		list.add_child(menu.ui.paragraph(I18n.t("pause.audio_interrupted")))
		if mobile_runtime.focus_state in [0,-1]: list.add_child(menu.ui.button(I18n.t("pause.retry_audio"),mobile_runtime.retry_audio_focus))
	if not checkpoint_error.is_empty(): list.add_child(menu.ui.paragraph(I18n.t(checkpoint_error)))
	if not network and mode != "cup":
		list.add_child(menu.ui.button(I18n.t("pause.restart_trial" if mode == "trial" else "pause.restart"), retry_drive))
	if mode == "trial":
		var ghost := CheckButton.new()
		ghost.text = I18n.t("event.ghost")
		ghost.button_pressed = drive.show_ghost
		ghost.toggled.connect(func(value: bool) -> void:
			set_trial_ghost(value))
		list.add_child(ghost)
	list.add_child(menu.ui.button(I18n.t("menu.settings"), func() -> void: settings_page.show_tab("display", show_pause)))
	list.add_child(menu.ui.button(I18n.t("pause.controls"), func() -> void: settings_page.show_tab("controls", show_pause)))
	if network: list.add_child(NetworkStatusRow.new(menu.ui,network))
	var quit_key := "cup.save_quit" if mode == "cup" else "pause.leave" if network else "pause.quit"
	list.add_child(menu.ui.button(I18n.t(quit_key), func() -> void: menu.confirm(I18n.t("pause.leave_confirm" if network else "pause.offline_confirm"), return_to_menu)))
	menu.first_focus()

func set_trial_ghost(value: bool) -> void:
	data.set_setting("trial_ghost",value)
	if is_instance_valid(drive) and drive.session.mode=="trial":
		drive.show_ghost = value
		drive.config["ghost"] = value
		pending_config["ghost"] = value


func resume_drive() -> void:
	if not foreground: return
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
		if not network: local_checkpoint().discard()
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
		finish_quit()
	else:
		if is_instance_valid(touch_editor):
			close_touch_editor()
		if page=="race" and is_instance_valid(drive):
			drive.show_pause()
		menu.confirm(I18n.t("data.quit_unsaved"),finish_quit)

func finish_quit() -> void:
	process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().call_group("audio_transports","stop_audio")
	# The driver retires stopped playback references over several buffers.
	await get_tree().create_timer(.5).timeout
	get_tree().quit()


func render_results() -> void:
	if is_instance_valid(drive):
		drive.hud.hide()
		drive.help_label.hide()
	var session := result_receipt.session
	var local_state := session.states[session.human_slot]
	var body := menu.reset(I18n.t("results.trial_title" if session.mode == "trial" else "results.title"))
	var list := menu.scroll_column(body)
	var local_result: Control
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
		var award_row := HBoxContainer.new()
		award_row.add_child(menu.ui.icon(UIIcons.medal_id(medal),48))
		award_row.add_child(menu.ui.label(I18n.t(["results.no_medal", "results.gold", "results.silver", "results.bronze"][medal + 1])))
		list.add_child(award_row)
		var previous := float(result_summary.get("previous", -1))
		list.add_child(menu.ui.label(I18n.t("results.previous") + ": " + (RaceHUD.format_time(previous) + "  (%+.3f)" % (local_state.finish_time - previous) if previous > 0 and local_state.finished else I18n.t("results.no_previous"))))
		var thresholds := Medals.thresholds(session.track.length)
		for index in range(3):
			var row := HBoxContainer.new()
			row.add_child(menu.ui.icon(UIIcons.medal_id(index)))
			row.add_child(menu.ui.label(I18n.t("results." + ["gold", "silver", "bronze"][index]) + "  " + RaceHUD.format_time(thresholds[index])))
			list.add_child(row)
	else:
		var order: Array[VehicleState] = []
		for slot: int in result_receipt.order:
			order.append(session.states[slot])
		for index in range(order.size()):
			var state: VehicleState = order[index]
			var record: Dictionary = session.roster[state.slot]
			var gap := "—" if index == 0 or not state.finished or not order[0].finished else "+%.3f" % (state.finish_time - order[0].finish_time)
			var row := menu.ui.paragraph("%d  %s  •  %s  •  %s  •  %s  •  %s" % [index + 1, record.name, I18n.t("car." + session.cars[state.slot].id), RaceHUD.format_time(state.finish_time) if state.finished else I18n.t("results.dnf") + " " + state.dnf_reason, RaceHUD.format_time(state.best_lap_time) if state.best_lap_time > 0 else "—", gap])
			if state.slot==session.human_slot:
				var highlight := menu.ui.panel(row)
				highlight.add_theme_stylebox_override("panel",menu.ui.style(UIFactory.NAVY,UIFactory.YELLOW,2))
				list.add_child(highlight)
				local_result = highlight
			else:
				list.add_child(row)
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

	if result_summary.saved and is_instance_valid(local_result):
		menu.reveal_later(local_result)

func show_cup() -> void:
	page = "cup"
	back_action = show_menu
	var body := menu.reset(I18n.t("cup.title"), I18n.t("cup.rules"))
	var list := menu.scroll_column(body)
	for index in range(6):
		var row := HBoxContainer.new()
		row.add_child(menu.ui.icon("track_"+Catalog.tracks[index].id))
		row.add_child(menu.ui.label("%d  %s" % [index + 1, I18n.t("track." + Catalog.tracks[index].id)]))
		list.add_child(row)
	if not data.profile.trophies.is_empty():
		var history := HFlowContainer.new()
		for rank in range(3):
			var count: int = data.profile.trophies.filter(func(trophy: Dictionary) -> bool: return int(trophy.rank)==rank).size()
			if count==0: continue
			var row := HBoxContainer.new()
			row.add_child(menu.ui.icon("trophy_"+["gold","silver","bronze"][rank],32))
			row.add_child(menu.ui.label(I18n.t("cup.trophies",[rank+1,count])))
			history.add_child(row)
		list.add_child(history)
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
	request_drive({"mode":"cup", "track":index, "car":int(human.car), "paint":int(human.paint), "laps":2, "roster":roster, "seed":int(cup.data.seeds[index]), "cup_event":index, "cup_id":str(cup.data.id), "contact":true, "difficulty":1},show_cup)


func show_school() -> void:
	dispose_drive()
	ensure_stage()
	page = "school"
	back_action = show_menu
	var body := menu.reset(I18n.t("school.title"))
	var list := menu.scroll_column(body)
	for index in range(5):
		list.add_child(menu.ui.button(("✓ " if data.profile.school_steps[index] else "") + I18n.t("school." + str(index)), func() -> void: request_drive({"mode":"school", "lesson":index},show_school)))
	menu.add_back(show_menu)
	menu.first_focus()


func skip_school() -> void:
	var index := int(drive.config.get("lesson", 0))
	if index < 4:
		request_drive({"mode":"school", "lesson":index + 1},show_school)
	else:
		show_school_complete()


func show_school_complete() -> void:
	var index := int(drive.config.get("lesson", 0))
	var saved := true
	if drive.lesson.done:
		data.profile.school_steps[index] = true
		saved = data.save_profile()==OK
	school_progress_saved = saved
	if saved: local_checkpoint().discard()
	else: checkpoint_error = "data.save_failed"
	drive.paused = true
	drive.touch.clear()
	drive.touch.enabled = false
	drive.touch.hide()
	drive.school_overlay.hide()
	drive.school_actions.hide()
	page = "school_complete"
	back_action = show_school
	var body := menu.reset(I18n.t("school.finished" if index == 4 else "school.complete"))
	if not saved:
		body.add_child(menu.ui.paragraph(I18n.t("data.save_failed")))
		body.add_child(menu.ui.button(I18n.t("data.retry_save"),show_school_complete))
	body.add_child(menu.ui.button(I18n.t("school.retry"), func() -> void: request_drive(pending_config,show_school)))
	if index < 4:
		body.add_child(menu.ui.button(I18n.t("school.next"), func() -> void: request_drive({"mode":"school", "lesson":index + 1},show_school)))
	else:
		body.add_child(menu.ui.paragraph(I18n.t("school.final_body")))
		body.add_child(menu.ui.button(I18n.t("menu.quick"), func() -> void:
			dispose_drive()
			show_garage("quick")))
	body.add_child(menu.ui.button(I18n.t("button.main_menu"), show_menu))
	menu.first_focus()


func show_online() -> void:
	if not mobile_runtime.allow_online(show_online): return
	online_page.show_hub()


func update_online_status(state: String) -> void:
	if is_instance_valid(online_status) and page=="main":
		online_status.text = build_name()+" • "+I18n.t("menu."+{"connecting":"connecting","online":"online_status"}.get(state,"offline"))


func show_connection_form() -> void:
	page = "connect"
	back_action = cancel_connection
	var body := menu.reset(I18n.t("online.direct"), I18n.t("online.community"))
	var address := UIFactory.text_edit()
	address.name = "direct_address"
	address.placeholder_text = I18n.t("online.address_help")
	address.text = "127.0.0.1:27020"
	address.custom_minimum_size.y = menu.ui.row_height()
	body.add_child(address)
	var code := UIFactory.text_edit()
	code.name = "direct_code"
	code.placeholder_text = I18n.t("online.code_optional")
	code.custom_minimum_size.y = menu.ui.row_height()
	body.add_child(code)
	connection_label = menu.ui.paragraph(I18n.t("online.waiting"))
	body.add_child(connection_label)
	connection_button = menu.ui.button(I18n.t("online.connect"), func() -> void: connect_address(address.text, code.text))
	connection_button.name = "direct_connect"
	body.add_child(connection_button)
	address.text_submitted.connect(func(_value: String) -> void: connect_address(address.text,code.text))
	code.text_submitted.connect(func(_value: String) -> void: connect_address(address.text,code.text))
	connection_back = menu.add_back(cancel_connection)
	if data.mobile: menu.first_focus()
	else: address.call_deferred("grab_focus")

func cancel_connection() -> void:
	if is_instance_valid(network):
		network.leave_room()
		network.queue_free()
		network = null
	show_online()

func connection_pending() -> bool:
	return is_instance_valid(network) and not network.deliberate_leave and (network.initial_deadline_ms>0 or network.connected or not network.reconnect_token.is_empty())

func connect_address(value: String, code_value: String = "", admission_ticket: String = "") -> void:
	if connection_pending(): return
	var address := PeerAddress.parse(value)
	if address.is_empty():
		if is_instance_valid(connection_label): connection_label.text = I18n.t("online.address_error")
		return
	var checked_code := PeerAddress.parse_code(code_value)
	if not checked_code.valid:
		if is_instance_valid(connection_label): connection_label.text = I18n.t("online.code_error")
		return
	if not mobile_runtime.allow_online(connect_address.bind(value,code_value,admission_ticket)): return
	if is_instance_valid(network):
		network.leave_room()
		network.queue_free()
	network = NetworkClient.new()
	add_child(network)
	network.room_code = checked_code.value
	network.admission_ticket = admission_ticket
	network.initial_car = int(data.profile.selected_car)
	network.initial_paint = int(data.profile.selected_paint)
	var expected_network := network
	network.loading_requested.connect(func(configuration: Dictionary) -> void:
		if network==expected_network: prepare_online(configuration))
	network.race_started.connect(func(configuration: Dictionary) -> void:
		if network==expected_network: start_online(configuration))
	network.results_received.connect(func(results: Array) -> void:
		if network==expected_network: online_results(results))
	network.returned_to_lobby.connect(func() -> void:
		if network!=expected_network: return
		dispose_drive(true)
		ensure_stage()
		lobby_page.code_visible = false
		lobby_page.show_lobby())
	network.lobby_changed.connect(func(state: Dictionary) -> void:
		if network!=expected_network: return
		if int(state.phase) == LobbyState.Phase.LOBBY and page in ["connect", "lobby"]:
			if int(state.revision) != lobby_page.shown_revision or page != "lobby":
				lobby_page.show_lobby())
	network.disconnected_permanently.connect(func(message: String) -> void:
		if network==expected_network: show_connection_lost(message))
	network.status_changed.connect(func(message: String) -> void:
		if network!=expected_network: return
		if is_instance_valid(connection_label):
			connection_label.text = message
		if page=="connect" and is_instance_valid(connection_button) and not connection_pending():
			connection_button.disabled = false
			connection_button.grab_focus()
		print("NETWORK_STATUS " + message))
	network.connect_to(address.host, address.port, data.profile.display_name)
	if page=="connect" and is_instance_valid(connection_button):
		connection_button.disabled = connection_pending()
		if connection_button.disabled and is_instance_valid(connection_back): connection_back.grab_focus()
		if data.mobile and DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD): DisplayServer.virtual_keyboard_hide()


func prepare_online(configuration: Dictionary) -> void:
	if not touch_layout_available(): return
	var expected_network := network
	var snapshot := configuration.duplicate(true)
	snapshot["mode"] = "online"
	var job := show_loading(snapshot,func() -> void:
		data.store.notice("loading.left_room")
		show_menu())
	job.completed.connect(func() -> void:
		if track_loader!=job or page!="loading" or network!=expected_network: return
		var built := job.take_world()
		cancel_loading()
		if is_instance_valid(stage):
			remove_child(stage)
			stage.queue_free()
			stage = null
		prepared_world = built
		add_child(prepared_world)
		SettingsRuntime.apply(self,data.settings)
		await get_tree().physics_frame
		if network==expected_network and page=="loading" and prepared_world==built:
			network.mark_loaded(int(snapshot.race)))


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
	if not foreground:
		drive.driver.set_focus(false)
		drive.show_pause()
		network.set_suspended(true)


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
	if page=="garage" and event is InputEventJoypadButton and event.pressed and event.button_index in [JOY_BUTTON_LEFT_SHOULDER,JOY_BUTTON_RIGHT_SHOULDER]:
		var next := posmod(int(data.profile.selected_car)+(-1 if event.button_index==JOY_BUTTON_LEFT_SHOULDER else 1),Catalog.cars.size())
		data.select_car(next,int(data.profile.selected_paint))
		show_garage(garage_mode)
		game_audio.effect("ui_confirm")
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and page != "race" and back_action.is_valid():
		back_action.call()
		get_viewport().set_input_as_handled()


func _process(_dt: float) -> void:
	if page=="connect" and is_instance_valid(connection_button):
		connection_button.disabled = connection_pending()
		connection_button.text = I18n.t("button.retry" if is_instance_valid(network) and network.deliberate_leave else "online.connect")
	if is_instance_valid(stage): stage.interactive = page=="garage"
	var has_drive := is_instance_valid(drive)
	audio_mix.context(has_drive and drive.paused and drive.network==null,has_drive and drive.paused and drive.network!=null)
	if page=="loading":
		if is_instance_valid(loading_hint):
			loading_hint.text = I18n.t(LOADING_HINTS[((Time.get_ticks_msec()-loading_hint_started)/4000)%LOADING_HINTS.size()])
		if is_instance_valid(loading_status):
			if is_instance_valid(track_loader): loading_status.text = I18n.t("loading.graphics_failed" if track_loader.graphics_error else "loading.graphics" if track_loader.warming else "loading.local")
			elif network:
				var members: Array = network.lobby.get("members",[])
				var loaded := members.filter(func(row: Dictionary) -> bool: return bool(row.get("loaded",false))).size()
				loading_status.text = I18n.t("loading.waiting",[loaded,members.size()])
	if network and page == "results" and is_instance_valid(online_result_label):
		online_result_label.text = I18n.t("online.return_countdown", [maxi(0, ceili((float(network.result_event.get("return_tick", 0)) - network.server_tick) / 60))])
	if lobby_page and page == "lobby":
		lobby_page.update_countdown()
	if capture_path.is_empty() or capture_pending:
		return
	rendered_frames += 1
	var capture_due := rendered_frames == capture_frame
	if capture_race_tick>=0:
		capture_due = is_instance_valid(drive) and drive.race_ticks>=capture_race_tick and drive.session.phase==RaceSession.Phase.RACING
	if capture_due:
		capture_pending = true
		# Hold this genuine simulated instant while waiting for GPU readback;
		# an obscured window may otherwise advance before frame_post_draw.
		if is_instance_valid(drive): drive.set_physics_process(false)
		await RenderingServer.frame_post_draw
		var image := get_viewport().get_texture().get_image()
		if image.save_png(capture_path)!=OK:
			push_error("Gameplay capture output could not be saved")
			get_tree().quit(1)
			return
		if not capture_track.is_empty():
			var evidence := {
				"track":drive.track.id,"car":drive.car.id,"paint":pending_config.paint,
				"seed":pending_config.seed,"mode":drive.session.mode,"opponents":7,
				"phase":drive.session.phase,"race_ticks":drive.race_ticks,
				"route_s":drive.state.route_s,"speed_mps":drive.state.speed(),"speed_3d_mps":drive.state.velocity.length(),
				"content_hash":Compatibility.content_hash(),"asset_hash":JSON.parse_string(FileAccess.get_file_as_string("res://assets/checksums.json")).asset_hash,
				"camera":data.settings.camera,"settings":data.settings,
				"width":image.get_width(),"height":image.get_height(),"platform":OS.get_name(),
				"renderer":RenderingServer.get_current_rendering_method(),"autodrive":true,
				"synthetic_pose":false,"hud":true,"touch":drive.touch.visible,
				"world_width":presentation.viewport.size.x,"world_height":presentation.viewport.size.y,
				"png_sha256":FileAccess.get_sha256(capture_path)}
			evidence.execution = "exported_template" if OS.has_feature("template") else "editor_source"
			if OS.has_feature("template") and FileAccess.file_exists("res://game/build.json"): evidence.build = JSON.parse_string(FileAccess.get_file_as_string("res://game/build.json"))
			var output := FileAccess.open(capture_path+".json",FileAccess.WRITE)
			if output==null:
				push_error("Gameplay capture metadata could not be saved")
				get_tree().quit(1)
				return
			output.store_string(JSON.stringify(evidence,"\t")+"\n")
			output.close()
		print("PACIFIC_RUSH_CAPTURE_SAVED")
		finish_quit()


func _notification(what: int) -> void:
	if not is_inside_tree():
		return
	if what==MainLoop.NOTIFICATION_OS_MEMORY_WARNING:
		mobile_runtime.release_inactive_assets()
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_inside_tree():
		if is_instance_valid(menu.modal) and menu.modal.visible:
			menu.modal.get_cancel_button().pressed.emit()
			return
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
		mobile_runtime.window_changed(false)
		handle_background()
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN, NOTIFICATION_APPLICATION_RESUMED]:
		if not mobile_runtime.window_changed(true): handle_foreground()


func handle_foreground() -> void:
	if foreground: return
	foreground = true
	menu_repeat.clear_context()
	audio_mix.foreground = true
	audio_mix.apply_levels()
	if is_instance_valid(drive): drive.driver.set_focus(true)
	if data.mobile and is_instance_valid(network): network.set_suspended(false)
	mobile_runtime.refresh()


func handle_background() -> void:
	var was_foreground := foreground
	foreground = false
	menu_repeat.clear_context()
	mobile_runtime.refresh()
	if not was_foreground: return
	if data.mobile and is_instance_valid(network): network.set_suspended(true)
	if not is_instance_valid(drive): return
	drive.driver.set_focus(false)
	drive.show_pause()
	if data.mobile and not network:
		if drive.session.mode=="trial" and not drive.result_sent:
			drive.state.trial_valid = false
			drive.state.lap_valid = false
		if drive.result_sent and (drive.session.mode=="school" and school_progress_saved or drive.session.mode!="school" and result_summary.get("saved",false)):
			local_checkpoint().discard()
			return
		var error := local_checkpoint().save(drive)
		checkpoint_error = "" if error==OK else data.store.last_error if not data.store.last_error.is_empty() else "data.save_failed"
		if page=="pause": show_pause()


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

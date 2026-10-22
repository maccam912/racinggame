class_name EventMenu
extends RefCounted

var app: Node
var track_index: int = 0
var laps: int = 2
var opponents: int = 7
var difficulty: int = 1
var contact: bool = true
var ghost: bool = true
var mode: String = "quick"
var info: Label
var preview: RoutePreview
var buttons: Array[Button] = []
var medal_icons: Array[TextureRect] = []
var detail_title: Label
var detail_scroll: MenuScroll


func _init(owner_app: Node) -> void:
	app = owner_app


func show_event() -> void:
	ghost = bool(app.data.settings.trial_ghost)
	app.page = "event"
	app.back_action = func() -> void: app.show_garage(mode)
	var shell: MenuShell = app.menu
	var body := shell.reset(I18n.t("event.title"), I18n.t("menu." + mode))
	var workspace := HBoxContainer.new()
	workspace.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(workspace)
	var list := shell.scroll_column(workspace)
	var grid := GridContainer.new()
	grid.columns = (1 if int(app.data.settings.ui_scale)>=125 else 2) if app.data.mobile else 3
	list.add_child(grid)
	buttons.clear()
	medal_icons.clear()
	for index in range(Catalog.tracks.size()):
		var track: TrackDefinition = Catalog.tracks[index]
		var card := VBoxContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var postcard := TextureRect.new()
		postcard.texture = load("res://assets/exported/thumbnails/"+track.id+".png")
		postcard.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		postcard.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		postcard.custom_minimum_size = Vector2(160,90)*shell.ui.unit
		postcard.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(postcard)
		var name_value := I18n.t("track." + track.id)
		var distance: float = track.length / (1609.344 if app.data.settings.units == "mph" else 1000)
		var description := "%s • %.2f %s" % [I18n.t("difficulty."+str(track.definition.difficulty).to_lower()), distance, "mi" if app.data.settings.units == "mph" else "km"]
		var button := shell.ui.button(name_value + "\n" + description, func() -> void: select_track(index), 180 if app.data.mobile else 230)
		if app.data.mobile: button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.focus_entered.connect(func() -> void:
			select_track(index)
			list.get_parent().call_deferred("ensure_control_visible", card))
		card.add_child(button)
		var best: float = app.data.best("trial",track.id,Catalog.cars[int(app.data.profile.selected_car)].id)
		var medal := Medals.award(track.length,best,best>0)
		var award_row := HBoxContainer.new()
		var medal_icon := shell.ui.icon(UIIcons.medal_id(medal))
		medal_icons.append(medal_icon)
		award_row.add_child(medal_icon)
		award_row.add_child(shell.ui.label(I18n.t(["results.no_medal","results.gold","results.silver","results.bronze"][medal+1])))
		card.add_child(award_row)
		buttons.append(button)
		grid.add_child(shell.ui.panel(card))
	detail_scroll = MenuScroll.new()
	detail_scroll.unit = shell.ui.unit
	detail_scroll.custom_minimum_size.x = 208*shell.ui.unit
	detail_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	detail_scroll.focus_mode = Control.FOCUS_ALL
	detail_scroll.draw_focus_border = true
	detail_scroll.add_theme_stylebox_override("focus",shell.ui.style(Color(0,0,0,0),UIFactory.YELLOW,2))
	detail_scroll.gui_input.connect(func(event: InputEvent) -> void:
		var maximum := maxi(0,roundi(detail_scroll.get_v_scroll_bar().max_value-detail_scroll.get_v_scroll_bar().page))
		if event.is_action_pressed("ui_down") and detail_scroll.scroll_vertical<maximum:
			detail_scroll.scroll_vertical += roundi(32*shell.ui.unit*shell.ui.scale)
			detail_scroll.accept_event()
		elif event.is_action_pressed("ui_up") and detail_scroll.scroll_vertical>0:
			detail_scroll.scroll_vertical -= roundi(32*shell.ui.unit*shell.ui.scale)
			detail_scroll.accept_event()
		elif event.is_action_pressed("ui_left") or event.is_action_pressed("ui_accept"):
			buttons[track_index].grab_focus()
			detail_scroll.accept_event())
	workspace.add_child(detail_scroll)
	var details := VBoxContainer.new()
	detail_title = shell.ui.paragraph("")
	detail_title.add_theme_font_size_override("font_size",shell.ui.font_size(22))
	details.add_child(detail_title)
	preview = RoutePreview.new()
	preview.custom_minimum_size = Vector2(180,110)*shell.ui.unit
	details.add_child(preview)
	info = shell.ui.paragraph("")
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.add_child(info)
	var panel := shell.ui.panel(details)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail_scroll.add_child(panel)
	if mode == "quick":
		choice(list, "event.laps", ["1", "2", "3"], laps-1, func(index: int) -> void: laps = index+1)
		choice(list, "event.opponents", ["0", "1", "2", "3", "4", "5", "6", "7"], opponents, func(index: int) -> void: opponents = index)
		choice(list, "event.difficulty", [I18n.t("difficulty.easy"), I18n.t("difficulty.medium"), I18n.t("difficulty.hard")], difficulty, func(index: int) -> void: difficulty = index)
		var toggle := CheckButton.new()
		toggle.text = I18n.t("event.contact")
		toggle.button_pressed = contact
		toggle.toggled.connect(func(value: bool) -> void: contact = value)
		list.add_child(toggle)
	else:
		list.add_child(shell.ui.paragraph(I18n.t("event.standing_start")))
		var toggle := CheckButton.new()
		toggle.text = I18n.t("event.ghost")
		toggle.button_pressed = ghost
		toggle.toggled.connect(func(value: bool) -> void:
			ghost = value
			app.data.set_setting("trial_ghost",value))
		list.add_child(toggle)
	shell.add_back(func() -> void: app.show_garage(mode))
	var random_button := shell.ui.button(I18n.t("event.random_short" if app.data.mobile else "event.random_track"),select_random_track)
	random_button.name = "RandomTrack"
	shell.ui.help(random_button,I18n.t("event.random_help"))
	shell.footer.add_child(random_button)
	shell.footer.add_child(shell.ui.button(I18n.t("button.start" if app.data.mobile else "event.start_trial" if mode == "trial" else "event.start_race"), start))
	var fit := fit_columns.bind(grid,workspace,list.get_parent())
	workspace.resized.connect(fit)
	fit.call_deferred()
	select_track(track_index)
	shell.focus_later(buttons[track_index])


func fit_columns(grid: GridContainer, workspace: HBoxContainer, list_scroll: MenuScroll) -> void:
	if not is_instance_valid(grid) or not is_instance_valid(workspace) or not app.menu.root.is_ancestor_of(workspace): return
	var widest := 0.0
	for card: Control in grid.get_children(): widest = maxf(widest,card.get_combined_minimum_size().x)
	var gap := float(grid.get_theme_constant("h_separation"))
	var reserved := detail_scroll.get_combined_minimum_size().x+workspace.get_theme_constant("separation")+list_scroll.get_v_scroll_bar().get_combined_minimum_size().x
	var maximum := (1 if int(app.data.settings.ui_scale)>=125 else 2) if app.data.mobile else 3
	var count := maximum
	while count>1 and widest*count+gap*(count-1)+reserved>app.menu.safe_frame_width(): count -= 1
	if grid.columns!=count: grid.columns = count


func select_random_track() -> void:
	if Catalog.tracks.size()<2: return
	select_track((track_index+randi_range(1,Catalog.tracks.size()-1))%Catalog.tracks.size())
	buttons[track_index].grab_focus()


func select_track(index: int) -> void:
	track_index = index
	var track: TrackDefinition = Catalog.tracks[index]
	detail_title.text = I18n.t("track."+track.id)
	preview.track = track
	preview.queue_redraw()
	info.text = I18n.t("route.description." + track.id)
	if mode == "trial":
		var best: float = app.data.best("trial", track.id, Catalog.cars[int(app.data.profile.selected_car)].id)
		info.text += "\n" + I18n.t("event.best") + ": " + (RaceHUD.format_time(best) if best > 0 else I18n.t("event.no_record"))
	for i in range(buttons.size()):
		app.menu.ui.selected(buttons[i],i==index)


func choice(parent: Node, key: String, items: Array, selected: int, callback: Callable) -> void:
	var row := HBoxContainer.new()
	var label: Label = app.menu.ui.label(I18n.t(key))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var picker: Variant = app.menu.ui.choice_picker(I18n.t(key))
	picker.custom_minimum_size = Vector2(180, app.menu.ui.row_height())
	for item: String in items:
		picker.add_item(item)
	picker.selected = selected
	picker.item_selected.connect(callback)
	row.add_child(picker)
	parent.add_child(row)


func start() -> void:
	var configuration := {"mode":mode, "track":track_index, "car":int(app.data.profile.selected_car), "paint":int(app.data.profile.selected_paint), "laps":1 if mode == "trial" else laps, "opponents":0 if mode == "trial" else opponents, "difficulty":difficulty, "contact":contact, "ghost":ghost}
	app.request_drive(configuration,show_event)

class_name EventMenu
extends RefCounted

const FILTERS := ["all","new","classic","asphalt","dirt","space","night"]

var track_shuffle := TrackShuffle.new()
var filter_index: int = 0
var visible_tracks: Array[int] = []
var track_cards: Array[Control] = []
var filter_picker: Variant
var adjust_columns: Callable
var random_button: Button
var track_list: MenuScroll
var reveal_generation: int = 0
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
	track_list = list.get_parent()
	filter_picker = shell.ui.choice_picker(I18n.t("event.filter"))
	filter_picker.name = "TrackFilter"
	if app.data.mobile: filter_picker.add_theme_font_size_override("font_size",shell.ui.font_size(14))
	for key: String in FILTERS:
		var count := 0
		for index in range(Catalog.tracks.size()):
			if matches_filter(index,key): count += 1
		filter_picker.add_item(I18n.t("event.filter."+key)+" ("+str(count)+")")
	filter_picker.selected = filter_index
	filter_picker.item_selected.connect(func(index: int) -> void:
		filter_index = index
		apply_filter())
	shell.ui.help(filter_picker,I18n.t("event.filter_help"))
	var grid := GridContainer.new()
	grid.columns = (1 if int(app.data.settings.ui_scale)>=125 else 2) if app.data.mobile else 3
	list.add_child(grid)
	buttons.clear()
	medal_icons.clear()
	track_cards.clear()
	for index in range(Catalog.tracks.size()):
		var track: TrackDefinition = Catalog.tracks[index]
		var card: BoxContainer = HBoxContainer.new() if app.data.mobile else VBoxContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var postcard := TextureRect.new()
		postcard.texture = load("res://assets/exported/thumbnails/"+track.id+".png")
		postcard.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		postcard.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		postcard.custom_minimum_size = (Vector2(72,42) if app.data.mobile else Vector2(160,90))*shell.ui.unit
		postcard.size_flags_vertical = Control.SIZE_SHRINK_CENTER if app.data.mobile else Control.SIZE_FILL
		postcard.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(postcard)
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_child(words)
		var name_value := I18n.t("track." + track.id)
		var distance: float = track.length / (1609.344 if app.data.settings.units == "mph" else 1000)
		var description := "%s • %.2f %s" % [I18n.t("difficulty."+str(track.definition.difficulty).to_lower()), distance, "mi" if app.data.settings.units == "mph" else "km"]
		var entry := VBoxContainer.new()
		entry.add_theme_constant_override("separation",roundi(2*shell.ui.unit))
		words.add_child(entry)
		var button := shell.ui.button(name_value if app.data.mobile else name_value+"\n"+description, func() -> void: select_track(index), 160 if app.data.mobile else 230)
		if app.data.mobile:
			button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			button.add_theme_font_size_override("font_size",shell.ui.font_size(15))
		button.focus_entered.connect(func() -> void:
			select_track(index)
			list.get_parent().call_deferred("ensure_control_visible", entry))
		entry.add_child(button)
		if app.data.mobile:
			var facts := shell.ui.label(description)
			facts.add_theme_font_size_override("font_size",shell.ui.font_size(14))
			facts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			entry.add_child(facts)
		var best: float = app.data.best("trial",track.id,Catalog.cars[int(app.data.profile.selected_car)].id)
		var medal := Medals.award(track.length,best,best>0)
		var award_row := HBoxContainer.new()
		var medal_icon := shell.ui.icon(UIIcons.medal_id(medal))
		medal_icons.append(medal_icon)
		award_row.add_child(medal_icon)
		award_row.add_child(shell.ui.label(I18n.t(["results.no_medal","results.gold","results.silver","results.bronze"][medal+1])))
		words.add_child(award_row)
		buttons.append(button)
		var card_panel := shell.ui.panel(card)
		track_cards.append(card_panel)
		grid.add_child(card_panel)
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
	var options := VBoxContainer.new()
	details.add_child(options)
	if mode == "quick":
		options.add_child(shell.ui.paragraph(I18n.t("event.race_setup")))
		choice(options, "event.laps", ["1", "2", "3"], laps-1, func(index: int) -> void: laps = index+1)
		choice(options, "event.opponents", ["0", "1", "2", "3", "4", "5", "6", "7"], opponents, func(index: int) -> void: opponents = index)
		choice(options, "event.difficulty", [I18n.t("difficulty.easy"), I18n.t("difficulty.medium"), I18n.t("difficulty.hard")], difficulty, func(index: int) -> void: difficulty = index)
		var toggle := CheckButton.new()
		toggle.name = "CarContact"
		toggle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		toggle.text = I18n.t("event.contact")
		toggle.button_pressed = contact
		toggle.toggled.connect(func(value: bool) -> void: contact = value)
		options.add_child(toggle)
	else:
		options.add_child(shell.ui.paragraph(I18n.t("event.standing_start")))
		var toggle := CheckButton.new()
		toggle.name = "TrialGhost"
		toggle.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		toggle.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		toggle.text = I18n.t("event.ghost")
		toggle.button_pressed = ghost
		toggle.toggled.connect(func(value: bool) -> void:
			ghost = value
			app.data.set_setting("trial_ghost",value))
		options.add_child(toggle)
	shell.add_back(func() -> void: app.show_garage(mode))
	shell.footer.add_child(filter_picker)
	random_button = shell.ui.button(I18n.t("event.random_short" if app.data.mobile else "event.random_track"),select_random_track)
	random_button.name = "RandomTrack"
	shell.ui.help(random_button,I18n.t("event.random_help"))
	shell.footer.add_child(random_button)
	shell.footer.add_child(shell.ui.button(I18n.t("button.start" if app.data.mobile else "event.start_trial" if mode == "trial" else "event.start_race"), start))
	adjust_columns = fit_columns.bind(grid,workspace,list.get_parent())
	workspace.resized.connect(adjust_columns)
	adjust_columns.call_deferred()
	apply_filter()
	shell.focus_later(buttons[track_index])


func fit_columns(grid: GridContainer, workspace: HBoxContainer, list_scroll: MenuScroll) -> void:
	if not is_instance_valid(grid) or not is_instance_valid(workspace) or not app.menu.root.is_ancestor_of(workspace): return
	var widest := 0.0
	for card: Control in grid.get_children():
		if card.visible: widest = maxf(widest,card.get_combined_minimum_size().x)
	var gap := float(grid.get_theme_constant("h_separation"))
	var reserved := detail_scroll.get_combined_minimum_size().x+workspace.get_theme_constant("separation")+list_scroll.get_v_scroll_bar().get_combined_minimum_size().x
	var maximum := (1 if int(app.data.settings.ui_scale)>=125 else 2) if app.data.mobile else 3
	var count := maximum
	while count>1 and widest*count+gap*(count-1)+reserved>app.menu.safe_frame_width(): count -= 1
	if grid.columns!=count: grid.columns = count


func matches_filter(index: int, category: String = "") -> bool:
	var current := str(FILTERS[filter_index]) if category.is_empty() else category
	var track: TrackDefinition = Catalog.tracks[index]
	match current:
		"new": return index>=10
		"classic": return index<10
		"asphalt", "dirt": return track.road_surface()==current
		"space": return bool(CourseArt.spec(track.id).get("space",false))
		"night": return float(CourseArt.spec(track.id).get("emission",0))>0 or bool(CourseArt.spec(track.id).get("space",false))
	return true


func apply_filter() -> void:
	visible_tracks.clear()
	for index in range(Catalog.tracks.size()):
		var included := matches_filter(index)
		track_cards[index].visible = included
		if included: visible_tracks.append(index)
	if adjust_columns.is_valid(): adjust_columns.call_deferred()
	random_button.disabled = visible_tracks.size()<2
	if visible_tracks.is_empty(): return
	if not track_index in visible_tracks: track_index = visible_tracks[0]
	select_track(track_index)
	buttons[track_index].grab_focus()
	reveal_selection()


func select_random_track() -> void:
	var selected := track_shuffle.choose(visible_tracks,track_index)
	if selected<0: return
	select_track(selected)
	buttons[track_index].grab_focus()
	reveal_selection()


func reveal_selection() -> void:
	# Coalesce rapid rolls; old scroll requests use stale pre-layout positions.
	reveal_generation += 1
	var token := reveal_generation
	await app.get_tree().process_frame
	await app.get_tree().process_frame
	if token!=reveal_generation or app.page!="event" or not is_instance_valid(track_list): return
	var button := buttons[track_index]
	if is_instance_valid(button) and button.is_inside_tree(): track_list.ensure_control_visible(button)


func select_track(index: int) -> void:
	track_index = index
	track_shuffle.note_visit(visible_tracks,index)
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
	var row := VBoxContainer.new()
	var label: Label = app.menu.ui.label(I18n.t(key))
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var picker: Variant = app.menu.ui.choice_picker(I18n.t(key))
	picker.name = key.trim_prefix("event.").to_pascal_case()+"Picker"
	picker.custom_minimum_size = Vector2(160*app.menu.ui.unit, app.menu.ui.row_height())
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for item: String in items:
		picker.add_item(item)
	picker.selected = selected
	picker.item_selected.connect(callback)
	row.add_child(picker)
	parent.add_child(row)


func start() -> void:
	var configuration := {"mode":mode, "track":track_index, "car":int(app.data.profile.selected_car), "paint":int(app.data.profile.selected_paint), "laps":1 if mode == "trial" else laps, "opponents":0 if mode == "trial" else opponents, "difficulty":difficulty, "contact":contact, "ghost":ghost}
	app.request_drive(configuration,show_event)

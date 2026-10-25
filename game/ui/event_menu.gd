class_name EventMenu
extends RefCounted

const FILTERS := ["all","smooth","technical","new","classic","asphalt","dirt","space","night"]

var track_shuffle := TrackShuffle.new()
var filter_index: int = 0
var visible_tracks: Array[int] = []
var track_cards: Array[Control] = []
var filter_picker: Variant
var adjust_columns: Callable
var random_button: Button
var random_card: Button
var photograph: TextureRect
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
var relaxed_button: Button
var detail_scroll: MenuScroll


func _init(owner_app: Node) -> void:
	app = owner_app
	restore_setup()


func restore_setup() -> void:
	# Optional menu preferences must not invalidate an older profile or its progress.
	var saved: Variant = app.data.profile.get("quick_setup",{})
	if not saved is Dictionary: saved = {}
	laps = int(saved.laps) if NetEvents.integer(saved.get("laps"),1,3) else 2
	opponents = int(saved.opponents) if NetEvents.integer(saved.get("opponents"),0,7) else 7
	difficulty = int(saved.difficulty) if NetEvents.integer(saved.get("difficulty"),0,2) else 1
	contact = saved.contact if saved.get("contact") is bool else true
	filter_index = maxi(0,FILTERS.find(saved.get("filter","all")))
	track_index = 0
	for index in range(Catalog.tracks.size()):
		if Catalog.tracks[index].id==saved.get("track",""): track_index = index


func remember_setup() -> Error:
	if mode!="quick": return OK
	app.data.profile["quick_setup"] = {"laps":laps,"opponents":opponents,"difficulty":difficulty,"contact":contact,"track":Catalog.tracks[track_index].id,"filter":FILTERS[filter_index]}
	var error: Error = app.data.save_profile()
	if error!=OK: app.data.store.notice("data.save_failed")
	return error


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
		filter_picker.add_item(I18n.t("event.filter."+key+("_short" if app.data.mobile and key in ["smooth","technical"] else ""))+" ("+str(count)+")")
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
	var surprise := VBoxContainer.new()
	if not app.data.mobile:
		var symbol := shell.ui.label("?",true)
		symbol.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		symbol.custom_minimum_size.y = 90*shell.ui.unit
		symbol.add_theme_font_size_override("font_size",roundi(72*shell.ui.unit))
		symbol.add_theme_color_override("font_color",UIFactory.YELLOW)
		surprise.add_child(symbol)
	random_card = shell.ui.button(I18n.t("event.random_short"),select_random_track)
	random_card.name = "RandomTrackCard"
	surprise.add_child(random_card)
	var surprise_caption := shell.ui.paragraph(I18n.t("course.random_card"))
	surprise_caption.add_theme_font_size_override("font_size",shell.ui.font_size(14))
	surprise.add_child(surprise_caption)
	grid.add_child(shell.ui.panel(surprise))
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
		var description := "%s • %.2f %s" % [I18n.t("road.smooth") if track.smooth_road() else I18n.t("difficulty."+str(track.definition.difficulty).to_lower()), distance, "mi" if app.data.settings.units == "mph" else "km"]
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
		var medal := Medals.award(track.length,best,best>0,track)
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
	if mode == "quick":
		var relaxed := shell.ui.button(I18n.t("event.relaxed_setup"), relaxed_setup)
		relaxed_button = relaxed
		relaxed.name = "RelaxedSetup"
		relaxed.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		if app.data.mobile: relaxed.add_theme_font_size_override("font_size",shell.ui.font_size(14))
		shell.ui.help(relaxed,I18n.t("event.relaxed_help"))
		details.add_child(relaxed)
	photograph = TextureRect.new()
	photograph.name = "CoursePhotograph"
	photograph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photograph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	photograph.custom_minimum_size = Vector2(180,110)*shell.ui.unit
	photograph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	details.add_child(photograph)
	preview = RoutePreview.new()
	preview.unit = shell.ui.unit
	preview.custom_minimum_size = Vector2(180,200)*shell.ui.unit
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
		toggle.toggled.connect(func(value: bool) -> void:
			contact = value
			refresh_relaxed_state())
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
	fit_mobile_browser()
	reveal_selection()


func fit_mobile_browser() -> void:
	# Keep the scaled touch rows while reserving room for the course list/map.
	var ui: UIFactory = app.menu.ui
	if not ui.mobile: return
	for control: Node in app.menu.footer.get_children():
		if control is Button: control.add_theme_font_size_override("font_size",ui.font_size(14))
	var style := ui.theme.get_stylebox("normal","Button")
	for button: Button in buttons:
		var available := button.custom_minimum_size.x-style.get_content_margin(SIDE_LEFT)-style.get_content_margin(SIDE_RIGHT)-2*ui.unit
		var size := ui.font_size(15)
		var minimum := roundi(16*ui.unit)
		while size>minimum:
			var fits := true
			for word: String in button.text.split(" "):
				if ui.title_font.get_string_size(word,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>available: fits = false
			if fits: break
			size -= 1
		button.add_theme_font_size_override("font_size",size)
	var logical_height: float = app.get_viewport().get_visible_rect().size.y/(ui.unit*ui.scale)
	if logical_height>480 or app.menu.headers.size()!=2: return
	var heading := app.menu.headers[0] as Label
	var caption := app.menu.headers[1] as Label
	if heading==null or caption==null: return
	heading.autowrap_mode = TextServer.AUTOWRAP_OFF
	caption.autowrap_mode = TextServer.AUTOWRAP_OFF
	var strip := HBoxContainer.new()
	strip.name = "CompactEventHeader"
	strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strip.add_theme_constant_override("separation",roundi(12*ui.unit))
	var size := mini(heading.get_theme_font_size("font_size"),roundi(32*ui.unit))
	var available: float = app.menu.safe_frame_width()-caption.get_combined_minimum_size().x-12*ui.unit
	while size>roundi(20*ui.unit) and ui.title_font.get_string_size(heading.text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>available: size -= 1
	heading.add_theme_font_size_override("font_size",size)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	caption.size_flags_horizontal = Control.SIZE_SHRINK_END
	caption.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	app.menu.column.remove_child(heading)
	app.menu.column.remove_child(caption)
	strip.add_child(heading)
	strip.add_child(caption)
	app.menu.column.add_child(strip)
	app.menu.column.move_child(strip,0)
	app.menu.headers.assign([strip])


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
		"smooth": return track.smooth_road()
		"technical": return not track.smooth_road()
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
	random_card.disabled = random_button.disabled
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
	# Cancel old requests and allow the filtered grid/header layout to settle.
	reveal_generation += 1
	var token := reveal_generation
	var tree: SceneTree = app.get_tree()
	for frame in range(4):
		await tree.process_frame
		if token!=reveal_generation or not is_instance_valid(app) or app.page!="event": return
	for attempt in range(3):
		if token!=reveal_generation or not is_instance_valid(track_list) or not track_list.is_inside_tree(): return
		var button := buttons[track_index]
		if not is_instance_valid(button) or not button.is_inside_tree(): return
		track_list.ensure_control_visible(button)
		await tree.process_frame
		if token!=reveal_generation or not is_instance_valid(app) or app.page!="event" or not is_instance_valid(button): return
		var shown := button.get_global_rect().intersection(track_list.get_global_rect())
		var minimum_visible: float = minf(track_list.size.y,minf(button.size.y,app.menu.ui.row_height()))
		if shown.size.y>=minimum_visible-1: return


func select_track(index: int) -> void:
	track_index = index
	refresh_relaxed_state()
	track_shuffle.note_visit(visible_tracks,index)
	var track: TrackDefinition = Catalog.tracks[index]
	detail_title.text = I18n.t("track."+track.id)
	photograph.texture = load("res://assets/exported/thumbnails/"+track.id+".png")
	photograph.accessibility_name = I18n.t("course.photograph",[detail_title.text])
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
	picker.item_selected.connect(func(_index: int) -> void: refresh_relaxed_state())
	row.add_child(picker)
	parent.add_child(row)


func start() -> void:
	remember_setup()
	var configuration := {"mode":mode, "track":track_index, "car":int(app.data.profile.selected_car), "paint":int(app.data.profile.selected_paint), "laps":1 if mode == "trial" else laps, "opponents":0 if mode == "trial" else opponents, "difficulty":difficulty, "contact":contact, "ghost":ghost}
	app.request_drive(configuration,show_event)


func relaxed_active() -> bool:
	var settings: Dictionary = app.data.settings
	return mode=="quick" and laps==1 and opponents==3 and difficulty==0 and not contact and Catalog.tracks[track_index].smooth_road() and settings.steering_assist=="strong" and is_equal_approx(float(settings.sensitivity),.75) and settings.corner_braking and settings.turn_hints and settings.auto_accelerate and settings.touch_auto_accelerate


func refresh_relaxed_state() -> void:
	if mode!="quick" or not is_instance_valid(relaxed_button): return
	var active := relaxed_active()
	relaxed_button.text = ("✓ " if active else "")+I18n.t("event.relaxed_setup")
	app.menu.ui.selected(relaxed_button,active)


func relaxed_setup() -> void:
	laps = 1
	opponents = 3
	difficulty = 0
	contact = false
	filter_index = FILTERS.find("smooth")
	if not Catalog.tracks[track_index].smooth_road(): track_index = 0
	app.data.set_setting("steering_assist","strong")
	app.data.set_setting("sensitivity",.75)
	app.data.set_setting("corner_braking",true)
	app.data.set_setting("turn_hints",true)
	app.data.set_setting("auto_accelerate",true)
	app.data.set_setting("touch_auto_accelerate",true)
	remember_setup()
	show_event()

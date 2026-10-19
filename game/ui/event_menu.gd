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


func _init(owner_app: Node) -> void:
	app = owner_app


func show_event() -> void:
	var shell: MenuShell = app.menu
	var body := shell.reset(I18n.t("event.title"), I18n.t("menu." + mode))
	var list := shell.scroll_column(body)
	var grid := GridContainer.new()
	grid.columns = 2 if app.data.mobile else 3
	list.add_child(grid)
	buttons.clear()
	for index in range(6):
		var track: TrackDefinition = Catalog.tracks[index]
		var card := VBoxContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var map := RoutePreview.new()
		map.track = track
		map.custom_minimum_size = Vector2(160, 70) * shell.ui.unit
		map.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(map)
		var name_value := I18n.t("track." + track.id)
		var distance: float = track.length / (1609.344 if app.data.settings.units == "mph" else 1000)
		var description := "%s • %.2f %s" % [I18n.t("difficulty." + ["easy", "easy", "medium", "medium", "hard", "hard"][index]), distance, "mi" if app.data.settings.units == "mph" else "km"]
		var button := shell.ui.button(name_value + "\n" + description, func() -> void: select_track(index), 230)
		button.focus_entered.connect(func() -> void:
			select_track(index)
			list.get_parent().call_deferred("ensure_control_visible", card))
		card.add_child(button)
		buttons.append(button)
		grid.add_child(shell.ui.panel(card))
	info = shell.ui.paragraph("")
	list.add_child(info)
	if mode == "quick":
		choice(list, "event.laps", ["1", "2", "3", "5"], [1, 2, 3, 5].find(laps), func(index: int) -> void: laps = [1, 2, 3, 5][index])
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
		toggle.toggled.connect(func(value: bool) -> void: ghost = value)
		list.add_child(toggle)
	shell.add_back(func() -> void: app.show_garage(mode))
	shell.footer.add_child(shell.ui.button(I18n.t("event.start_trial" if mode == "trial" else "event.start_race"), start))
	select_track(track_index)
	shell.focus_later(buttons[track_index])


func select_track(index: int) -> void:
	track_index = index
	var track: TrackDefinition = Catalog.tracks[index]
	info.text = I18n.t("route.description." + track.id)
	if mode == "trial":
		var best: float = app.data.best("trial", track.id, Catalog.cars[int(app.data.profile.selected_car)].id)
		info.text += "\n" + I18n.t("event.best") + ": " + (RaceHUD.new().time(best) if best > 0 else I18n.t("event.no_record"))
	for i in range(buttons.size()):
		buttons[i].modulate = UIFactory.TURQUOISE if i == index else Color.WHITE


func choice(parent: Node, key: String, items: Array, selected: int, callback: Callable) -> void:
	var row := HBoxContainer.new()
	var label: Label = app.menu.ui.label(I18n.t(key))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var picker := OptionButton.new()
	app.menu.ui.configure_picker(picker)
	picker.custom_minimum_size = Vector2(180, app.menu.ui.row_height())
	for item: String in items:
		picker.add_item(item)
	picker.selected = selected
	picker.item_selected.connect(callback)
	row.add_child(picker)
	parent.add_child(row)


func start() -> void:
	app.start_drive({"mode":mode, "track":track_index, "car":int(app.data.profile.selected_car), "paint":int(app.data.profile.selected_paint), "laps":1 if mode == "trial" else laps, "opponents":0 if mode == "trial" else opponents, "difficulty":difficulty, "contact":contact, "ghost":ghost})

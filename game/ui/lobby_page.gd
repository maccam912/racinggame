class_name LobbyPage
extends RefCounted

var app: Node
var shown_revision: int = -1
var code_visible: bool = false
var countdown: Label
var iroh_code_caption: Label
var iroh_copy: Button
var track_shuffle := TrackShuffle.new()
var course_picker: CoursePicker


func _init(owner_app: Node) -> void:
	app = owner_app


func show_lobby() -> void:
	if not app.network or app.network.lobby.is_empty():
		return
	app.page = "lobby"
	app.back_action = leave
	var state: Dictionary = app.network.lobby
	shown_revision = int(state.revision)
	var shell: MenuShell = app.menu
	var region_name: String = state.region
	if app.network.official:
		for region: Dictionary in app.regions.regions:
			if region.id==state.region: region_name = I18n.t(region.name_key)
	var body := shell.reset(I18n.t("online.lobby"), state.name + " • " + region_name)
	var list := shell.scroll_column(body)
	iroh_code_caption = null
	iroh_copy = null
	app.append_unsaved_results(list)
	if is_instance_valid(app.iroh_rooms.authority):
		list.add_child(shell.ui.paragraph(I18n.t("online.iroh_host_help")))
		var room := HFlowContainer.new()
		var expired: bool = Time.get_unix_time_from_system()>=app.iroh_rooms.expires_at
		iroh_code_caption = shell.ui.label(I18n.t("online.iroh_code_expired") if expired else I18n.t("online.iroh_share",[app.iroh_rooms.code]))
		room.add_child(iroh_code_caption)
		var copy := shell.ui.button(I18n.t("online.copy"),func() -> void: DisplayServer.clipboard_set(app.iroh_rooms.code))
		iroh_copy = copy
		copy.disabled = expired
		room.add_child(copy)
		var renew := shell.ui.button(I18n.t("online.iroh_new_code"),app.iroh_page.regenerate)
		renew.name = "iroh_new_code"
		renew.disabled = app.iroh_rooms.busy
		room.add_child(renew)
		list.add_child(room)
	if app.network.official and is_instance_valid(app.guest_service.identity) and app.guest_service.identity.state=="session_only":
		list.add_child(shell.ui.paragraph(I18n.t("online.session_only")))
	var rules: Dictionary = state.rules

	var preview := CourseShowcase.new()
	preview.configure(shell.ui,app.data.settings,Catalog.tracks[int(rules.track)])
	list.add_child(preview)
	list.move_child(preview,0)
	list.add_child(shell.ui.paragraph(I18n.t("event.laps") + ": " + str(int(rules.laps)) + " • " + I18n.t("event.contact") + ": " + I18n.t("choice.on" if rules.contact else "choice.off")))
	compact_lobby_header(shell,preview,list)
	var own: Dictionary = {}
	for member: Dictionary in state.members:
		if member.id == app.network.guest_id:
			own = member
		var role := " • " + I18n.t("online.host") if member.id == state.host else ""
		var text := "%d  %s%s  •  %s  •  %s  •  %s  •  %d ms" % [int(member.slot) + 1, member.name, role, I18n.t("car." + Catalog.cars[int(member.car)].id), I18n.t("paint." + str(int(member.paint))), I18n.t("online.ready" if member.ready else "online.unready"), int(member.ping)]
		var row := HBoxContainer.new()
		row.add_child(shell.ui.icon("car_"+Catalog.cars[int(member.car)].id))
		row.add_child(shell.ui.paragraph(text))
		list.add_child(row)
	if rules.bot_fill:
		for index in range(8 - state.members.size()):
			var slot: int = state.members.size() + index
			list.add_child(shell.ui.label("%d  %s  •  %s  •  %s" % [slot + 1, RaceSetup.BOT_NAMES[index], I18n.t("online.bot"), I18n.t("difficulty." + ["easy", "medium", "hard", "expert"][int(rules.difficulty)])]))
	countdown = shell.ui.label("")
	list.add_child(countdown)
	update_countdown()
	if state.private:
		var row := HBoxContainer.new()
		row.add_child(shell.ui.label(state.code.left(4) + "-" + state.code.substr(4) if code_visible else "••••-••••"))
		row.add_child(shell.ui.button(I18n.t("online.hide" if code_visible else "online.show"), func() -> void:
			code_visible = not code_visible
			show_lobby()))
		row.add_child(shell.ui.button(I18n.t("online.copy"), func() -> void: DisplayServer.clipboard_set(state.code)))
		list.add_child(row)
	if own.is_empty():
		return
	var change_car := shell.ui.button(I18n.t("online.car_short" if shell.ui.mobile else "online.change_car"), func() -> void: app.show_garage("online"))
	shell.footer.add_child(change_car)
	shell.footer.add_child(shell.ui.button(I18n.t("online.unready" if own.ready else "online.ready"), func() -> void: app.network.command("ready", {"value":not own.ready})))
	if state.host == app.network.guest_id:
		shell.footer.add_child(shell.ui.button(I18n.t("online.settings_short" if shell.ui.mobile else "online.settings"), show_rules))
		var start := shell.ui.button(I18n.t("online.start"), func() -> void: app.network.command("start"))
		start.disabled = not state.members.all(func(row: Dictionary) -> bool: return row.ready and row.connected)
		shell.ui.help(start,I18n.t("online.ready_required"),true)
		if start.disabled:
			list.add_child(shell.ui.paragraph(I18n.t("online.ready_required")))
		shell.footer.add_child(start)
		list.add_child(shell.ui.button(I18n.t("online.kick"), show_kick))
		var assists := shell.ui.button(I18n.t("online.driving_assists"), show_driving_assists)
		assists.name = "driving_assists"
		list.add_child(assists)
	shell.footer.add_child(shell.ui.button(I18n.t("online.leave_short" if shell.ui.mobile else "online.leave"), leave))
	if shell.ui.mobile:
		for button: Button in shell.footer.get_children(): button.add_theme_font_size_override("font_size",shell.ui.font_size(14))
	change_car.call_deferred("grab_focus")


func compact_lobby_header(shell: MenuShell, preview: CourseShowcase, list: VBoxContainer) -> void:
	if not shell.ui.mobile: return
	var heading := shell.headers[0] as Label
	var room := shell.headers[1] as Label
	heading.add_theme_font_size_override("font_size",shell.ui.font_size(20))
	heading.autowrap_mode = TextServer.AUTOWRAP_OFF
	preview.title.add_theme_font_size_override("font_size",shell.ui.font_size(20))
	preview.title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var header := HBoxContainer.new()
	shell.column.remove_child(heading)
	shell.column.remove_child(room)
	preview.remove_child(preview.title)
	header.add_child(heading)
	header.add_child(preview.title)
	shell.column.add_child(header)
	shell.column.move_child(header,0)
	shell.headers.assign([header])
	preview.move_child(preview.facts,preview.get_child_count()-1)
	list.add_child(room)


func update_countdown() -> void:
	if is_instance_valid(iroh_code_caption):
		var expired: bool = Time.get_unix_time_from_system()>=app.iroh_rooms.expires_at
		iroh_code_caption.text = I18n.t("online.iroh_code_expired") if expired else I18n.t("online.iroh_share",[app.iroh_rooms.code])
		if is_instance_valid(iroh_copy): iroh_copy.disabled = expired
	if is_instance_valid(countdown) and app.network:
		var target := int(app.network.lobby.get("countdown_tick", -1))
		countdown.text = "" if target < 0 else I18n.t("online.start_countdown", [maxi(0, ceili((target - app.network.server_tick) / 60))])


func leave() -> void:
	app.network.leave_room()
	app.return_to_menu()


func show_rules() -> void:
	app.page = "room_settings"
	app.back_action = show_lobby
	var rules: Dictionary = app.network.lobby.rules.duplicate(true)
	var shell: MenuShell = app.menu
	var body := shell.reset(I18n.t("online.settings"))
	var list := shell.scroll_column(body)
	course_picker = CoursePicker.new()
	course_picker.configure(shell.ui,app.data.settings,int(rules.track),track_shuffle)
	course_picker.track_selected.connect(func(index: int) -> void: rules.track = index)
	list.add_child(course_picker)
	course_picker.compact_header(shell)
	app.events.choice(list, "event.laps", ["1", "2", "3"], int(rules.laps) - 1, func(index: int) -> void: rules.laps = index + 1)
	app.events.choice(list, "event.difficulty", [I18n.t("difficulty.easy"), I18n.t("difficulty.medium"), I18n.t("difficulty.hard"), I18n.t("difficulty.expert")], int(rules.difficulty), func(index: int) -> void: rules.difficulty = index)
	for key in ["bot_fill", "contact"]:
		var toggle := CheckButton.new()
		toggle.text = I18n.t("online.bot_fill" if key == "bot_fill" else "event.contact")
		toggle.button_pressed = bool(rules[key])
		toggle.toggled.connect(func(value: bool) -> void: rules[key] = value)
		list.add_child(toggle)
	shell.footer.add_child(shell.ui.button(I18n.t("button.confirm"), func() -> void:
		app.network.command("rules", {"rules":rules})
		show_lobby()))
	shell.add_back(show_lobby)
	shell.first_focus()


func show_driving_assists() -> void:
	if not app.network or app.network.lobby.get("host") != app.network.guest_id or int(app.network.lobby.get("phase", -1)) != LobbyState.Phase.LOBBY:
		show_lobby()
		return
	app.page = "driving_assists"
	app.back_action = show_lobby
	var state: Dictionary = app.network.lobby
	var draft: Dictionary = state.get("driving_assists", {}).duplicate()
	var shell: MenuShell = app.menu
	var body := shell.reset(I18n.t("online.driving_assists"))
	var list := shell.scroll_column(body)
	list.add_child(shell.ui.paragraph(I18n.t("online.driving_assists_help")))
	for member: Dictionary in state.members:
		var row := VBoxContainer.new()
		row.add_child(shell.ui.label(member.name))
		var choice := ChoicePicker.new()
		choice.name = "assist_" + str(member.slot)
		choice.ui = shell.ui
		choice.subject = member.name
		for key: String in ["choice.off", "online.assist_gentle", "online.assist_strong", "online.assist_relaxed"]: choice.add_item(I18n.t(key))
		choice.selected = int(draft.get(member.id, 0))
		choice.item_selected.connect(func(index: int) -> void: draft[member.id] = index)
		row.add_child(choice)
		list.add_child(row)
	shell.footer.add_child(shell.ui.button(I18n.t("button.confirm"), func() -> void:
		for id: String in draft:
			if int(draft[id]) != int(state.get("driving_assists", {}).get(id, 0)):
				app.network.command("driving_assist", {"id":id, "level":int(draft[id])})
		show_lobby()))
	shell.add_back(show_lobby)
	shell.first_focus()


func show_kick() -> void:
	app.page = "kick"
	app.back_action = show_lobby
	var shell: MenuShell = app.menu
	var body := shell.reset(I18n.t("online.kick"))
	for row: Dictionary in app.network.lobby.members:
		if row.id != app.network.guest_id:
			body.add_child(shell.ui.button(row.name, func() -> void: shell.confirm(I18n.t("online.kick_confirm"), func() -> void:
				app.network.command("kick", {"id":row.id})
				show_lobby())))
	shell.add_back(show_lobby)
	shell.first_focus()

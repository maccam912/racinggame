class_name LobbyPage
extends RefCounted

var app: Node
var shown_revision: int = -1
var code_visible: bool = false
var countdown: Label
var iroh_code_caption: Label
var iroh_copy: Button


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
	list.add_child(shell.ui.label(I18n.t("track." + Catalog.tracks[int(rules.track)].id) + " • " + I18n.t("event.laps") + ": " + str(int(rules.laps)) + " • " + I18n.t("event.contact") + ": " + I18n.t("choice.on" if rules.contact else "choice.off")))
	var preview := RoutePreview.new()
	preview.track = Catalog.tracks[int(rules.track)]
	preview.custom_minimum_size = Vector2(220, 80) * shell.ui.unit
	list.add_child(preview)
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
			list.add_child(shell.ui.label("%d  %s  •  %s  •  %s" % [slot + 1, RaceSetup.BOT_NAMES[index], I18n.t("online.bot"), I18n.t("difficulty." + ["easy", "medium", "hard"][int(rules.difficulty)])]))
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
	shell.footer.add_child(shell.ui.button(I18n.t("online.change_car"), func() -> void: app.show_garage("online")))
	shell.footer.add_child(shell.ui.button(I18n.t("online.unready" if own.ready else "online.ready"), func() -> void: app.network.command("ready", {"value":not own.ready})))
	if state.host == app.network.guest_id:
		shell.footer.add_child(shell.ui.button(I18n.t("online.settings"), show_rules))
		var start := shell.ui.button(I18n.t("online.start"), func() -> void: app.network.command("start"))
		start.disabled = not state.members.all(func(row: Dictionary) -> bool: return row.ready and row.connected)
		shell.ui.help(start,I18n.t("online.ready_required"),true)
		if start.disabled:
			list.add_child(shell.ui.paragraph(I18n.t("online.ready_required")))
		shell.footer.add_child(start)
		shell.footer.add_child(shell.ui.button(I18n.t("online.kick"), show_kick))
	shell.footer.add_child(shell.ui.button(I18n.t("online.leave"), leave))
	shell.first_focus()


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
	var tracks: Array[String] = []
	for track: TrackDefinition in Catalog.tracks:
		tracks.append(I18n.t("track." + track.id))
	app.events.choice(list, "event.title", tracks, int(rules.track), func(index: int) -> void: rules.track = index)
	app.events.choice(list, "event.laps", ["1", "2", "3"], int(rules.laps) - 1, func(index: int) -> void: rules.laps = index + 1)
	app.events.choice(list, "event.difficulty", [I18n.t("difficulty.easy"), I18n.t("difficulty.medium"), I18n.t("difficulty.hard")], int(rules.difficulty), func(index: int) -> void: rules.difficulty = index)
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

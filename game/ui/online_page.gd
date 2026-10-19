class_name OnlinePage
extends Node

var app: Node
var directory: DirectoryClient
var regions: RegionBook
var pending: String = ""
var last_action: String = ""
var last_payload: Dictionary = {}
var connect_deadline: int = 0
var next_refresh: int = 0
var active_room_id: String = ""
var quick_candidates: Array[Dictionary] = []
var quick_attempts: int = 0
var only_available: bool = true
var show_in_race: bool = false
var rooms: Array[Dictionary] = []
var room_list: VBoxContainer
var browser_status: Label
var refresh_button: Button
var status: Label
var identity_notice: Label
var hub_buttons: Array[Button] = []
var draft: Dictionary = {"name":"Driver's Race","private":false,"rules":{"track":0,"laps":2,"bot_fill":true,"difficulty":1,"contact":true}}

func _init(owner_app: Node) -> void:
	app = owner_app

func _ready() -> void:
	directory = app.directory_client
	regions = app.regions
	directory.completed.connect(receive)
	regions.updated.connect(regions_updated)

func cancel_work() -> void:
	if is_instance_valid(directory): directory.cancel()
	if is_instance_valid(regions): regions.cancel()
	pending = ""
	connect_deadline = 0

func exit_to_hub() -> void:
	cancel_work()
	depart_active_room()
	if is_instance_valid(app.network) and app.network.lobby.is_empty():
		app.network.queue_free()
		app.network = null
	show_hub(false)

func show_hub(refresh: bool = true) -> void:
	directory.cancel()
	pending = ""
	connect_deadline = 0
	app.page = "online"
	app.back_action = app.show_menu
	var body: VBoxContainer = app.menu.reset(I18n.t("online.title"))
	var list: VBoxContainer = app.menu.scroll_column(body)
	region_choice(list)
	status = app.menu.ui.paragraph(region_caption())
	list.add_child(status)
	hub_buttons.clear()
	for row: Array in [["online.quick_join",func() -> void: begin_action("quick")],["online.browse",browse],["online.create",show_create],["online.join_code",show_code]]:
		var button: Button = app.menu.ui.button(I18n.t(row[0]),row[1])
		button.disabled = regions.probing or regions.selected().is_empty()
		app.menu.ui.help(button,func() -> String: return region_caption(),true)
		list.add_child(button)
		hub_buttons.append(button)
	list.add_child(app.menu.ui.button(I18n.t("online.direct"),func() -> void:
		cancel_work()
		app.show_connection_form()))
	app.menu.footer.add_child(app.menu.ui.button(I18n.t("online.check_regions"),probe_regions))
	app.menu.add_back(app.show_menu)
	app.menu.first_focus()
	var configured := regions.regions.any(func(row: Dictionary) -> bool: return not str(row.url).is_empty())
	if refresh and configured and Time.get_ticks_msec()-regions.last_probe_ms>=30000:
		probe_regions()

func region_choice(parent: Node, changed: Callable = Callable()) -> Variant:
	var shell: MenuShell = app.menu
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label: Label = shell.ui.label(I18n.t("online.region"))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var picker: Variant = shell.ui.choice_picker(I18n.t("online.region"))
	picker.custom_minimum_size = Vector2(190*shell.ui.unit,shell.ui.row_height())
	picker.add_item(I18n.t("online.auto"))
	for index in range(regions.regions.size()):
		var region: Dictionary = regions.regions[index]
		var caption := I18n.t(region.name_key)
		if not region.available:
			caption += " • "+I18n.t("online.region_unavailable")
		picker.add_item(caption)
		picker.set_item_disabled(index+1,not region.available)
		if regions.selected_id==region.id:
			picker.selected = index+1
	picker.item_selected.connect(func(index: int) -> void:
		regions.selected_id = "auto" if index==0 else str(regions.regions[index-1].id)
		if changed.is_valid(): changed.call()
		elif app.page=="online": show_hub(false))
	row.add_child(picker)
	return picker

func region_caption() -> String:
	if regions.probing:
		return I18n.t("online.checking_regions")
	var selected := regions.selected()
	if selected.is_empty():
		return I18n.t("online.unavailable")
	return I18n.t(selected.name_key)+" • ~%d ms" % roundi(float(selected.ping_ms))

func probe_regions() -> void:
	for button: Button in hub_buttons:
		if is_instance_valid(button): button.disabled = true
	if is_instance_valid(status): status.text = I18n.t("online.checking_regions")
	regions.probe()

func regions_updated() -> void:
	if app.page=="online": show_hub(false)

func configure_directory() -> bool:
	var region := regions.selected()
	if region.is_empty(): return false
	if directory.base==region.url and directory.data==app.data:
		return true
	return directory.configure(app.data,app.guest_service,str(region.url),regions.certificate)==OK

func browse() -> void:
	if not configure_directory():
		show_hub(false)
		return
	app.page = "online_rooms"
	app.back_action = exit_to_hub
	var body: VBoxContainer = app.menu.reset(I18n.t("online.browse"),region_caption())
	var filters := HFlowContainer.new()
	body.add_child(filters)
	var available := check(I18n.t("online.available_rooms"),only_available)
	filters.add_child(available)
	var in_race := check(I18n.t("online.show_in_race"),show_in_race)
	filters.add_child(in_race)
	available.toggled.connect(func(value: bool) -> void:
		only_available = value
		if value:
			show_in_race = false
			in_race.set_pressed_no_signal(false)
		request_rooms())
	in_race.toggled.connect(func(value: bool) -> void:
		show_in_race = value
		if value:
			only_available = false
			available.set_pressed_no_signal(false)
		request_rooms())
	browser_status = app.menu.ui.paragraph("")
	body.add_child(browser_status)
	room_list = app.menu.scroll_column(body)
	refresh_button = app.menu.ui.button(I18n.t("online.refresh"),request_rooms)
	app.menu.ui.help(refresh_button,I18n.t("online.refreshing"),true)
	app.menu.footer.add_child(refresh_button)
	app.menu.footer.add_child(app.menu.ui.button(I18n.t("online.create"),show_create))
	app.menu.add_back(exit_to_hub)
	app.menu.first_focus()
	request_rooms()

func check(text: String, pressed: bool) -> CheckButton:
	var control := CheckButton.new()
	control.text = text
	control.button_pressed = pressed
	control.custom_minimum_size.y = app.menu.ui.row_height()
	return control

func request_rooms() -> void:
	if app.page!="online_rooms": return
	directory.cancel()
	pending = "browse"
	next_refresh = Time.get_ticks_msec()+10000
	if is_instance_valid(browser_status): browser_status.text = I18n.t("online.refreshing")
	if is_instance_valid(refresh_button): refresh_button.disabled = true
	if directory.begin("rooms",{"show_in_race":not only_available or show_in_race})!=OK:
		pending = ""
		browser_status.text = I18n.t("online.unavailable")
		refresh_button.disabled = false

static func quick_order(a: Dictionary, b: Dictionary) -> bool:
	if int(a.humans)!=int(b.humans): return int(a.humans)>int(b.humans)
	if int(a.created_at)!=int(b.created_at): return int(a.created_at)<int(b.created_at)
	return str(a.id)<str(b.id)

func render_rooms() -> void:
	if app.page!="online_rooms" or not is_instance_valid(room_list): return
	var viewport: Viewport = app.get_viewport()
	var focused: Control = viewport.gui_get_focus_owner()
	var focus_id: String = focused.get_meta("room_id","") if is_instance_valid(focused) else ""
	var old_scroll: int = room_list.get_parent().scroll_vertical
	for child: Node in room_list.get_children():
		room_list.remove_child(child)
		child.queue_free()
	var displayed: Array[Dictionary] = []
	for room: Dictionary in rooms:
		if room.region!=regions.selected().get("id",""): continue
		if only_available and (room.state!="Lobby" or int(room.humans)>=8): continue
		if not show_in_race and room.state!="Lobby": continue
		displayed.append(room)
	displayed.sort_custom(func(a: Dictionary,b: Dictionary) -> bool:
		if int(a.humans)!=int(b.humans): return int(a.humans)>int(b.humans)
		return str(a.id)<str(b.id))
	if displayed.is_empty():
		room_list.add_child(app.menu.ui.paragraph(I18n.t("online.empty")))
	var grid := GridContainer.new()
	grid.columns = 7
	var table: bool = viewport.get_visible_rect().size.x/(app.menu.ui.unit*app.menu.ui.scale)>=1100
	if table and not displayed.is_empty():
		room_list.add_child(grid)
		for key: String in ["name","track","humans","ping","state","contact","join"]:
			grid.add_child(app.menu.ui.label(I18n.t("online.column_"+key)))
	var restore_focus: Button
	for room: Dictionary in displayed:
		var join: Button = app.menu.ui.button(I18n.t("online.join"),func() -> void: begin_action("join",{"room_id":room.id}))
		join.disabled = room.state!="Lobby" or int(room.humans)>=8
		app.menu.ui.help(join,I18n.t("online.room_not_joinable"),true)
		join.set_meta("room_id",room.id)
		join.name = "join_"+str(room.id).replace("-","_")
		var values: Array[String] = [room.name,I18n.t("track."+Catalog.tracks[int(room.rules.track)].id),"%d/8" % int(room.humans),"~%d ms" % roundi(float(regions.selected().get("ping_ms",0))),I18n.t("online.state_"+str(room.state)),I18n.t("choice.on" if room.rules.contact else "choice.off")]
		if table:
			for value: String in values:
				var label: Label = app.menu.ui.paragraph(value)
				label.custom_minimum_size.x = 75*app.menu.ui.unit
				grid.add_child(label)
			grid.add_child(join)
		else:
			var column := VBoxContainer.new()
			column.add_child(app.menu.ui.paragraph(values[0]+" • "+values[1]))
			column.add_child(app.menu.ui.paragraph("%s • %s • %s • %s: %s" % [values[2],values[3],values[4],I18n.t("event.contact"),values[5]]))
			column.add_child(join)
			room_list.add_child(app.menu.ui.panel(column))
		if room.id==focus_id and not join.disabled: restore_focus = join
	if grid.get_parent()==null: grid.free()
	if is_instance_valid(restore_focus) and DrivingInput.last_device!="touch":
		app.menu.focus_later(restore_focus)
	else:
		restore_scroll.call_deferred(room_list.get_parent(),old_scroll)

func restore_scroll(scroll: ScrollContainer, value: int) -> void:
	await get_tree().process_frame
	if is_instance_valid(scroll) and app.page=="online_rooms": scroll.scroll_vertical = value

func show_create() -> void:
	directory.cancel()
	pending = ""
	app.page = "online_create"
	app.back_action = exit_to_hub
	var body: VBoxContainer = app.menu.reset(I18n.t("online.create"))
	var list: VBoxContainer = app.menu.scroll_column(body)
	var action: Button = app.menu.ui.button(I18n.t("online.create"),create_room)
	app.menu.ui.help(action,func() -> String: return region_caption(),true)
	action.name = "create_room_start"
	region_choice(list,func() -> void: action.disabled = regions.selected().is_empty())
	list.add_child(app.menu.ui.label(I18n.t("online.room_name")))
	var name_edit := LineEdit.new()
	name_edit.name = "room_name"
	name_edit.text = draft.name
	name_edit.max_length = 96
	name_edit.custom_minimum_size.y = app.menu.ui.row_height()
	name_edit.text_changed.connect(func(value: String) -> void: draft.name = value)
	list.add_child(name_edit)
	app.events.choice(list,"online.visibility",[I18n.t("online.public"),I18n.t("online.private")],1 if draft.private else 0,func(index: int) -> void: draft.private = index==1)
	app.events.choice(list,"online.column_track",Catalog.tracks.map(func(track: TrackDefinition) -> String: return I18n.t("track."+str(track.id))),int(draft.rules.track),func(index: int) -> void: draft.rules.track = index)
	app.events.choice(list,"event.laps",["1","2","3"],int(draft.rules.laps)-1,func(index: int) -> void: draft.rules.laps = index+1)
	var fill := check(I18n.t("online.bot_fill"),bool(draft.rules.bot_fill))
	fill.toggled.connect(func(value: bool) -> void: draft.rules.bot_fill = value)
	list.add_child(fill)
	app.events.choice(list,"event.difficulty",[I18n.t("difficulty.easy"),I18n.t("difficulty.medium"),I18n.t("difficulty.hard")],int(draft.rules.difficulty),func(index: int) -> void: draft.rules.difficulty = index)
	var contact := check(I18n.t("event.contact"),bool(draft.rules.contact))
	contact.toggled.connect(func(value: bool) -> void: draft.rules.contact = value)
	list.add_child(contact)
	status = app.menu.ui.paragraph("")
	list.add_child(status)
	action.disabled = regions.selected().is_empty()
	app.menu.footer.add_child(action)
	app.menu.add_back(exit_to_hub)
	app.menu.first_focus()

func create_room() -> void:
	var checked := PlayerName.validate(str(draft.name),24)
	if not checked.valid:
		status.text = I18n.t("online.room_name_error")
		return
	draft.name = checked.value
	var body := DirectoryClient.compatibility()
	body.merge({"name":draft.name,"private":draft.private,"region":regions.selected().get("id",""),"rules":draft.rules.duplicate(true)})
	begin_action("create",body)

func show_code() -> void:
	directory.cancel()
	pending = ""
	connect_deadline = 0
	app.page = "online_code"
	app.back_action = exit_to_hub
	var body: VBoxContainer = app.menu.reset(I18n.t("online.join_code"),region_caption())
	var list: VBoxContainer = app.menu.scroll_column(body)
	var edit := LineEdit.new()
	edit.name = "room_code"
	edit.placeholder_text = "XXXX-XXXX"
	edit.max_length = 9
	edit.custom_minimum_size.y = app.menu.ui.row_height()
	list.add_child(edit)
	status = app.menu.ui.paragraph("")
	list.add_child(status)
	var submit := func() -> void:
		var checked := PeerAddress.parse_code(edit.text)
		if not checked.valid or checked.value.is_empty():
			status.text = I18n.t("online.code_error")
			return
		begin_action("code",{"code":checked.value})
	var join: Button = app.menu.ui.button(I18n.t("online.join"),submit)
	join.name = "join_code_start"
	join.disabled = regions.selected().is_empty()
	app.menu.ui.help(join,func() -> String: return region_caption(),true)
	app.menu.footer.add_child(join)
	app.menu.add_back(exit_to_hub)
	edit.text_submitted.connect(func(_text: String) -> void: submit.call())
	if app.data.mobile: app.menu.first_focus()
	else: edit.call_deferred("grab_focus")

func begin_action(kind: String, payload: Dictionary = {}) -> void:
	if not configure_directory():
		show_hub(false)
		return
	directory.cancel()
	last_action = kind
	last_payload = payload.duplicate(true)
	pending = kind
	connect_deadline = Time.get_ticks_msec()+10000
	app.page = "online_wait"
	app.back_action = exit_to_hub
	var body: VBoxContainer = app.menu.reset(I18n.t("online.connecting"),region_caption())
	status = app.menu.ui.paragraph(I18n.t("online.waiting_service"))
	body.add_child(status)
	identity_notice = app.menu.ui.paragraph("")
	body.add_child(identity_notice)
	app.menu.add_back(exit_to_hub)
	app.menu.first_focus()
	var error: Error = directory.begin("rooms" if kind=="quick" else kind,payload)
	if error!=OK: fail("storage_busy" if error==ERR_BUSY else "invalid_response")

func receive(result: Dictionary) -> void:
	if pending=="browse" and app.page=="online_rooms":
		pending = ""
		refresh_button.disabled = false
		if result.ok:
			rooms.assign(result.payload.rooms)
			browser_status.text = ""
		else:
			rooms.clear()
			browser_status.text = message(result.state)
		render_rooms()
		return
	if app.page!="online_wait" or pending.is_empty(): return
	if not result.ok:
		if pending=="quick_join" and result.state in ["room_unavailable","room_full"]:
			next_quick_candidate()
		else:
			fail(result.state)
		return
	if pending=="quick" and result.kind=="rooms":
		quick_candidates.clear()
		quick_attempts = 0
		for row: Dictionary in result.payload.rooms:
			if row.state=="Lobby" and int(row.humans)<8 and not directory.departures.has(str(row.id)):
				quick_candidates.append(row)
		quick_candidates.sort_custom(quick_order)
		next_quick_candidate()
		return
	active_room_id = result.payload.room_id
	pending = "connecting"
	app.page = "connect"
	app.connection_label = status
	app.connect_address(("["+str(result.payload.host)+"]" if ":" in str(result.payload.host) else str(result.payload.host))+":"+str(int(result.payload.port)),"",str(result.payload.ticket))

func next_quick_candidate() -> void:
	var error: Error
	if quick_candidates.is_empty() or quick_attempts>=3:
		pending = "quick_create"
		var body := DirectoryClient.compatibility()
		body.merge({"name":"Driver's Race","private":false,"region":regions.selected().id,"rules":{"track":0,"laps":2,"bot_fill":true,"difficulty":1,"contact":true}})
		error = directory.begin("create",body)
	else:
		quick_attempts += 1
		pending = "quick_join"
		var row: Dictionary = quick_candidates.pop_front()
		error = directory.begin("join",{"room_id":row.id})
	if error!=OK: fail("storage_busy")

func depart_active_room() -> void:
	if not active_room_id.is_empty():
		directory.depart(active_room_id)
		active_room_id = ""

func fail(state: String) -> void:
	directory.cancel()
	depart_active_room()
	pending = ""
	connect_deadline = 0
	if is_instance_valid(app.network) and app.network.lobby.is_empty():
		app.network.queue_free()
		app.network = null
	app.page = "online_error"
	app.back_action = exit_to_hub
	var body: VBoxContainer = app.menu.reset(I18n.t("online.title"),message(state))
	body.add_child(app.menu.ui.button(I18n.t("button.retry"),func() -> void: begin_action(last_action,last_payload)))
	app.menu.add_back(exit_to_hub)
	app.menu.first_focus()

static func message(state: String) -> String:
	if state=="timeout": return I18n.t("online.timeout")
	if state=="rate_limited": return I18n.t("online.rate_limited")
	if state in ["capacity","no_capacity"]: return I18n.t("online.capacity")
	if state=="room_unavailable" or state=="room_full": return I18n.t("online.unavailable_room")
	if state.begins_with("identity_"): return I18n.t("online.identity_unavailable")
	if state=="storage_busy": return I18n.t("online.storage_busy")
	return I18n.t("online.unavailable")

func _process(_delta: float) -> void:
	if app.page=="online_rooms" and pending.is_empty() and Time.get_ticks_msec()>=next_refresh:
		request_rooms()
	if pending=="connecting" and app.page=="lobby":
		pending = ""
		connect_deadline = 0
	if not pending.is_empty() and pending!="browse" and app.page in ["online_wait","connect"] and Time.get_ticks_msec()>=connect_deadline:
		fail("timeout")
	if is_instance_valid(identity_notice) and is_instance_valid(app.guest_service.identity):
		identity_notice.text = I18n.t("online.session_only") if app.guest_service.identity.state=="session_only" else ""

func _exit_tree() -> void:
	cancel_work()

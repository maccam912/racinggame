class_name IrohPage
extends Node

var app: Node
var serial: int = 0
var status: Label
var pending: bool = false


func _init(owner_app: Node) -> void:
	app = owner_app


func cancel() -> void:
	serial += 1
	pending = false
	app.cancel_connection()


func show_join() -> void:
	serial += 1
	app.page = "connect"
	app.back_action = cancel
	var body: VBoxContainer = app.menu.reset(I18n.t("online.iroh_join"))
	var edit := UIFactory.text_edit()
	edit.name = "iroh_join_code"
	edit.placeholder_text = I18n.t("online.iroh_code_help")
	edit.max_length = 8
	edit.custom_minimum_size.y = app.menu.ui.row_height()
	body.add_child(edit)
	status = app.menu.ui.paragraph(I18n.t("online.iroh_code_help"))
	body.add_child(status)
	app.connection_label = status
	app.connection_button = app.menu.ui.button(I18n.t("online.connect"),func() -> void: join(edit.text))
	app.connection_button.name = "iroh_join"
	body.add_child(app.connection_button)
	edit.text_submitted.connect(func(_text: String) -> void: join(edit.text))
	app.connection_back = app.menu.add_back(cancel)
	app.menu.first_focus()
	edit.call_deferred("grab_focus")


func join(value: String) -> void:
	if app.connection_pending() or pending: return
	if not IrohRendezvous.valid_code(value):
		status.text = I18n.t("online.iroh_code_error")
		return
	if not app.mobile_runtime.allow_online(join.bind(value)): return
	app.connection_button.disabled = true
	pending = true
	status.text = I18n.t("online.iroh_resolving")
	var expected := serial
	var reply: Dictionary = await app.iroh_rooms.rendezvous.resolve(value)
	if serial!=expected or app.page!="connect": return
	pending = false
	if not reply.ok:
		status.text = reply.message
		app.connection_button.disabled = false
		return
	app.connect_address("127.0.0.1:27020","","",str(reply.payload.endpoint_id))


func show_host() -> void:
	serial += 1
	app.page = "connect"
	app.back_action = cancel
	var body: VBoxContainer = app.menu.reset(I18n.t("online.iroh_host"))
	body.add_child(app.menu.ui.paragraph(I18n.t("online.iroh_host_help")))
	status = app.menu.ui.paragraph(I18n.t("online.iroh_creating"))
	body.add_child(status)
	app.connection_label = status
	app.connection_button = app.menu.ui.button(I18n.t("button.retry"),host)
	app.connection_button.disabled = true
	body.add_child(app.connection_button)
	app.connection_back = app.menu.add_back(cancel)
	app.menu.first_focus()
	host()


func host() -> void:
	if pending or app.connection_pending(): return
	if not app.mobile_runtime.allow_online(host): return
	app.connection_button.disabled = true
	status.text = I18n.t("online.iroh_creating")
	pending = true
	var expected := serial
	var reply: Dictionary = await app.iroh_rooms.host()
	if expected!=serial or app.page!="connect": return
	pending = false
	if not reply.ok:
		status.text = reply.message
		app.connection_button.disabled = false
		return
	app.connect_address("127.0.0.1:27020","","",str(reply.endpoint))


func regenerate() -> void:
	if app.iroh_rooms.busy: return
	var button: Button = app.menu.root.find_child("iroh_new_code",true,false)
	if is_instance_valid(button): button.disabled = true
	var reply: Dictionary = await app.iroh_rooms.regenerate()
	if app.page!="lobby": return
	if is_instance_valid(button): button.disabled = false
	if reply.ok: app.lobby_page.show_lobby()
	else: app.menu.confirm(reply.message,func() -> void: pass)

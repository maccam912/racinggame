extends SceneTree

class CapturedClient extends NetworkClient:
	var sent: Array[Dictionary] = []
	func command(type: String, values: Dictionary = {}) -> void: sent.append({"type":type,"values":values.duplicate(true)})

func _initialize() -> void: call_deferred("run")

func expert_picker(app: Node) -> Variant:
	var picker: Variant = app.menu.root.find_child("DifficultyPicker", true, false)
	assert(picker != null and picker.item_count == 4)
	if picker is ChoicePicker: assert(picker.labels == ["Easy", "Medium", "Hard", "Expert"])
	else: assert(picker.get_item_text(3) == "Expert")
	picker.selected = 3
	picker.item_selected.emit(3)
	assert(picker.text == "Expert")
	return picker

func run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var app: Node = load("res://game/client_app.gd").new()
	root.add_child(app)
	await process_frame
	var folder := "user://tests/expert-ui-" + RaceSetup.uuid()
	app.data = AppData.new(folder, false)
	app.menu.settings = app.data.settings
	var client := CapturedClient.new()
	client.process_mode = Node.PROCESS_MODE_DISABLED
	client.guest_id = "host"
	app.add_child(client)
	app.network = client
	var lobby := LobbyState.new()
	lobby.join("host", "Driver", 0)
	for mobile: bool in [false, true]:
		root.size = Vector2i(884,398) if mobile else Vector2i(1280,720)
		app.data.mobile = mobile
		app.menu.mobile_override = mobile
		app.menu.logical_unit_override = 1.0
		app.data.settings.ui_scale = 150
		app.events.mode = "quick"
		app.events.show_event()
		await process_frame
		var picker: Variant = expert_picker(app)
		assert(app.events.difficulty == 3)
		assert(app.events.remember_setup() == OK)
		app.events.restore_setup()
		assert(app.events.difficulty == 3)
		assert(picker.get_global_rect().end.x <= root.size.x)
		app.online_page.show_create()
		expert_picker(app)
		assert(app.online_page.draft.rules.difficulty == 3)
		client.lobby = lobby.public_state(0, "host")
		app.lobby_page.show_rules()
		expert_picker(app)
		for button: Button in app.menu.footer.find_children("*", "Button", true, false):
			if button.text == I18n.t("button.confirm"): button.pressed.emit()
		assert(client.sent[-1].type == "rules" and client.sent[-1].values.rules.difficulty == 3)
		lobby.rules.difficulty = 3
		client.lobby = lobby.public_state(0, "host")
		app.lobby_page.show_lobby() # Expert bot labels must index the fourth name.
	app.queue_free()
	await create_timer(.5).timeout
	assert(AppData.remove_tree(ProjectSettings.globalize_path(folder)) == OK)
	print("EXPERT_QUICK_CREATE_HOST_RULES_BOT_LABELS_DESKTOP_PHONE_150_PASS")
	quit()

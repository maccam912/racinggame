extends SceneTree

class CapturedClient extends NetworkClient:
	var sent: Array[Dictionary] = []
	func command(type: String, values: Dictionary = {}) -> void: sent.append({"type":type,"values":values.duplicate()})

func _initialize() -> void: call_deferred("run")

func run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var app: Node = load("res://game/client_app.gd").new()
	root.add_child(app)
	await process_frame
	var folder := "user://tests/assist-ui-"+RaceSetup.uuid()
	app.data = AppData.new(folder,false)
	app.menu.settings = app.data.settings
	var client := CapturedClient.new()
	client.process_mode = Node.PROCESS_MODE_DISABLED
	client.guest_id = "parent"
	app.add_child(client)
	app.network = client
	var lobby := LobbyState.new()
	lobby.join("parent","Parent",0)
	lobby.join("child","Child",1)
	lobby.join("friend","Friend",2)
	for mobile: bool in [false,true]:
		root.size = Vector2i(884,398) if mobile else Vector2i(1280,720)
		app.data.mobile = mobile
		app.menu.mobile_override = mobile
		app.menu.logical_unit_override = 1.0
		app.data.settings.ui_scale = 150
		client.lobby = lobby.public_state(0,"parent")
		app.lobby_page.show_driving_assists()
		for i in range(5): await process_frame
		var choice := app.menu.root.find_child("assist_1",true,false) as ChoicePicker
		assert(choice != null and choice.labels == [I18n.t("choice.off"),"Gentle","Strong"])
		assert(choice.get_global_rect().end.x <= root.size.x)
		choice.item_selected.emit(2)
		if "--capture" in OS.get_cmdline_user_args():
			choice.selected = 2
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://reports/driving-assists-"+("phone" if mobile else "desktop")+".png")
		for button: Button in app.menu.footer.find_children("*","Button",true,false):
			if button.text == I18n.t("button.confirm"): button.pressed.emit()
		assert(client.sent[-1] == {"type":"driving_assist","values":{"id":"child","level":2}})
	client.guest_id = "child"
	client.lobby = lobby.public_state(0,"child")
	app.lobby_page.show_lobby()
	assert(app.menu.root.find_child("driving_assists",true,false) == null)
	app.lobby_page.show_driving_assists()
	assert(app.page == "lobby", "nonhost cannot open assist controls")
	app.queue_free()
	await create_timer(.5).timeout
	assert(AppData.remove_tree(ProjectSettings.globalize_path(folder)) == OK)
	print("HOST_ONLY_ASSIST_SCREEN_DESKTOP_PHONE_CHOICES_CONFIRM_PRIVACY_PASS")
	quit()

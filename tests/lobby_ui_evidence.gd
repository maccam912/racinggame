extends SceneTree

var app: Node
var port: int = 27055
var index: int = 0
var captured_lobby: bool = false
var captured_race: bool = false
var started: int = 0


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--port="): port = int(arg.trim_prefix("--port="))
		elif arg.begins_with("--index="): index = int(arg.trim_prefix("--index="))
	app = load("res://game/client_app.gd").new()
	root.add_child(app)
	await process_frame
	app.data.select_car(2 + index, 2 + index)
	app.data.settings.ui_scale = 150
	app.menu.settings = app.data.settings
	app.show_connection_form()
	app.connect_address("127.0.0.1:" + str(port))
	app.network.lobby_changed.connect(on_lobby)
	started = Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < 22000:
		await process_frame
		if app.page == "race" and not captured_race:
			await create_timer(4).timeout
			await capture("race")
			captured_race = true
			assert(app.drive.track.id == "redwood_run" and app.drive.car.id == ["switch", "sunset"][index])
			print("NATIVE_LOBBY_RACE car=", app.drive.car.id, " track=", app.drive.track.id, " racers=", app.drive.session.states.size())
	app.show_menu()
	app.queue_free()
	await process_frame
	print("NATIVE_LOBBY_UI_EVIDENCE_COMPLETE")
	quit(0 if captured_lobby and captured_race else 1)


func capture(label: String) -> void:
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/lobby-native-%d-%s.png" % [index, label])


func on_lobby(state: Dictionary) -> void:
	if int(state.phase) != LobbyState.Phase.LOBBY or state.members.size() < 2:
		return
	var rules := {"track":3, "laps":1, "bot_fill":true, "difficulty":1, "contact":true}
	if state.host == app.network.guest_id and state.rules != rules:
		app.network.command("rules", {"rules":rules})
		return
	if state.rules != rules:
		return
	if not captured_lobby:
		captured_lobby = true
		await capture("lobby")
	app.network.command("ready", {"value":true})

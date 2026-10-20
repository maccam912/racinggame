extends SceneTree

var app: Node


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	app = load("res://game/client_app.gd").new()
	root.add_child(app)
	await process_frame
	for method in ["show_menu", "show_garage", "show_cup", "show_school", "show_online", "show_connection_form", "show_credits"]:
		app.call(method)
		await process_frame
		assert(app.menu.visible and app.menu.body.get_child_count() > 0, method)
	for mode in ["quick", "trial"]:
		app.events.mode = mode
		app.events.show_event()
		await process_frame
		assert(app.events.buttons.size() == Catalog.tracks.size())
	for tab in ["display", "graphics", "audio", "controls", "accessibility", "gameplay", "data"]:
		app.settings_page.show_tab(tab, app.show_menu)
		await process_frame
	app.start_drive({"mode":"quick", "track":3, "car":2, "paint":4, "opponents":7})
	await physics_frame
	assert(app.drive.session.states.size() == 8)
	assert(app.drive.state.slot == 4)
	assert(app.drive.car.id == "switch" and app.drive.track.id == "redwood_run")
	assert(app.drive.session.bots.size() == 7)
	app.drive.show_pause()
	await process_frame
	assert(app.menu.visible and app.drive.paused)
	app.resume_drive()
	assert(not app.menu.visible and not app.drive.paused)
	app.drive.state.finished = true
	app.drive.next_racer()
	assert(app.drive.spectator_slot != app.drive.state.slot)
	for press in range(7):
		app.drive.next_racer()
	assert(app.drive.spectator_slot == app.drive.state.slot)
	app.show_menu()
	await process_frame
	app.queue_free()
	await process_frame
	print("Menu flow: all pages, eight routes, eight-car race, settings tabs, pause and resume pass")
	await create_timer(.5).timeout # Retire stopped audio on the mixer thread.
	quit()

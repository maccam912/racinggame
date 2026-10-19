extends SceneTree
var app: Node
var folder: String
var ready_resume_ticks: int = -1
func _initialize() -> void: call_deferred("run")
func settle(frames: int = 3) -> void:
	for index in range(frames): await process_frame
func click(text: String) -> void:
	for button: Button in app.menu.root.find_children("*","Button",true,false):
		if button.text==text:
			button.pressed.emit()
			return
	assert(false,"expected real menu action "+text)
func load_complete() -> void:
	while app.page=="loading": await process_frame
	assert(app.page=="race")
	app.drive.set_physics_process(false)
func run() -> void:
	Catalog.load_all()
	folder = "user://tests/checkpoint-ui-"+RaceSetup.uuid()
	app = load("res://game/client_app.gd").new()
	root.add_child(app)
	await settle()
	app.data = AppData.new(folder,true)
	app.data.profile.first_run_complete = true
	app.touch_demo = true
	assert(app.data.save_profile()==OK)
	app.start_drive({"mode":"quick","track":0,"car":2,"paint":3,"opponents":2,"laps":2,"seed":908172,"contact":false})
	app.drive.set_physics_process(false)
	await physics_frame
	await physics_frame
	for tick in range(420): app.drive._physics_process(1.0/60)
	var time: int = app.drive.session.elapsed_ticks
	var position: Vector3 = app.drive.state.position
	var id: String = app.drive.session.race_uuid
	app.drive.touch.pointer_down(99,app.drive.touch.controls.brake.get_center())
	assert(app.drive.touch.captures.has(99))
	app.handle_background()
	assert(app.page=="pause" and app.drive.paused and app.drive.touch.captures.is_empty())
	assert(app.local_checkpoint().payload.session.race_uuid==id and app.local_checkpoint().can_resume())
	for tick in range(30): app.drive._physics_process(1.0/60)
	assert(app.drive.session.elapsed_ticks==time and app.drive.state.position==position)
	var checkpoint_bytes := FileAccess.get_file_as_bytes(app.data.store.path("suspended_race"))
	app.handle_background()
	assert(FileAccess.get_file_as_bytes(app.data.store.path("suspended_race"))==checkpoint_bytes and not FileAccess.file_exists(app.data.store.path("suspended_race")+".bak"),"duplicate focus/pause notifications do not rewrite the checkpoint")
	app.foreground = true
	app.drive.driver.set_focus(true)
	app.open_start_screen()
	assert(app.page=="saved_race" and app.drive==null)
	click(I18n.t("resume.continue"))
	app.track_loader.completed.connect(func() -> void: ready_resume_ticks = app.drive.resume_ticks)
	await load_complete()
	assert(app.drive.session.race_uuid==id and app.drive.session.elapsed_ticks==time and app.drive.state.position==position)
	assert(ready_resume_ticks==180 and app.drive.resume_ticks>0 and app.drive.frame.throttle==0)
	for tick in range(app.drive.resume_ticks): app.drive._physics_process(1.0/60)
	assert(app.drive.session.elapsed_ticks==time and app.drive.state.position==position)
	app.drive._physics_process(1.0/60)
	assert(app.drive.session.elapsed_ticks==time+1)
	assert(app.data.profile.races_completed==0)
	app.show_menu()
	assert(app.local_checkpoint().payload.is_empty())
	app.start_drive({"mode":"trial","track":0,"car":1,"paint":5,"opponents":0,"laps":1})
	app.drive.set_physics_process(false)
	for tick in range(330): app.drive._physics_process(1.0/60)
	id = app.drive.session.race_uuid
	app.handle_background()
	assert(not app.drive.state.trial_valid and not app.drive.state.lap_valid)
	assert(app.local_checkpoint().payload.session.mode=="trial")
	app.foreground = true
	app.open_start_screen()
	assert(app.page=="saved_race")
	click(I18n.t("resume.restart_trial"))
	await load_complete()
	assert(app.drive.session.race_uuid!=id and app.drive.session.elapsed_ticks==0 and app.drive.session.phase==RaceSession.Phase.GRID and app.drive.state.trial_valid and app.drive.ghost_samples.is_empty())
	app.handle_background()
	app.foreground = true
	app.open_start_screen()
	var before: Dictionary = app.data.profile.duplicate(true)
	click(I18n.t("resume.discard"))
	assert(app.page=="main" and app.local_checkpoint().payload.is_empty() and app.data.profile==before)
	var future := {"format":2,"unknown_future_payload":true}
	assert(app.data.store.save_component("suspended_race",future)==OK)
	var preserved := FileAccess.get_file_as_bytes(app.data.store.path("suspended_race"))
	app.open_start_screen()
	assert(app.page=="saved_race" and not app.local_checkpoint().can_resume())
	assert(FileAccess.get_file_as_bytes(app.data.store.path("suspended_race"))==preserved)
	click(I18n.t("resume.discard"))
	assert(app.page=="main" and app.data.profile.races_completed==0 and app.data.records.times.is_empty())
	app.queue_free()
	await create_timer(.5).timeout
	assert(AppData.remove_tree(ProjectSettings.globalize_path(folder))==OK)
	print("BACKGROUND_ATOMIC_PAUSE_TOUCH_CANCEL_DEDUP_COLD_REAL_MENU_RESUME_180_TICKS_EXACT_ID_TRIAL_RESTART_EXPLICIT_DISCARD_NO_STATS_PASS")
	quit()

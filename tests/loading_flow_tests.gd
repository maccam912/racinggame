extends SceneTree
func _initialize() -> void: call_deferred("run")
func settle() -> void:
	await process_frame
	await process_frame
	await process_frame
func run() -> void:
	var app: Node = load("res://game/client_app.gd").new()
	root.add_child(app)
	await process_frame
	app.data = AppData.new("user://tests/loading-"+str(Time.get_ticks_usec()),false)
	app.events.mode = "trial"
	app.events.track_index = 3
	app.events.show_event()
	assert(app.page=="event" and app.back_action.is_valid())
	app.events.start()
	assert(app.page=="loading" and app.menu.visible and app.track_loader!=null)
	var job: TrackLoader = app.track_loader
	assert(job.world.build_stage==0 and app.loading_bar.value==0,"local construction begins only after a presentation frame")
	await settle()
	app.back_action.call()
	await settle()
	assert(app.page=="event" and app.track_loader==null and not is_instance_valid(job),"Cancel frees its partially built world and returns to track selection")
	assert(app.events.track_index==3 and app.drive==null)
	app.events.start()
	job = app.track_loader
	var progress: Array[float] = []
	job.progress.connect(func(value: float) -> void: progress.append(value))
	while app.page=="loading": await process_frame
	assert(app.page=="race" and not app.menu.visible)
	assert(app.drive.track==Catalog.tracks[3] and app.drive.session.phase==RaceSession.Phase.GRID,"initial loads retain the full Grid phase")
	assert(progress.size()==app.drive.world.build_steps() and progress[-1]==1.0)
	for index in range(1,progress.size()): assert(progress[index]>progress[index-1] and progress[index]<=1.0)
	assert(app.drive.world.pending_geometry.is_empty())
	app.drive.set_physics_process(false)
	# Cancelling at every construction boundary cannot publish a late race.
	for stage in range(0,6):
		app.request_drive({"mode":"quick","track":1,"opponents":0},app.show_menu)
		job = app.track_loader
		job.set_process(false)
		for step in range(stage+1): job._process(0)
		assert(not job.done)
		app.back_action.call()
		await settle()
		assert(app.page=="main" and app.drive==null and app.track_loader==null)
	# A newer load owns completion even if the previous job has done work.
	app.request_drive({"mode":"quick","track":0,"opponents":0},app.show_menu)
	job = app.track_loader
	app.request_drive({"mode":"trial","track":2,"car":1,"laps":1,"opponents":0},app.show_menu)
	while app.page=="loading": await process_frame
	assert(not is_instance_valid(job) and app.drive.track==Catalog.tracks[2] and app.drive.session.mode=="trial")
	app.queue_free()
	await settle()
	print("LOADING_PROGRESS_CANCEL_EVERY_STAGE_REPLACEMENT_TRACK_SELECTION_PASS")
	quit()

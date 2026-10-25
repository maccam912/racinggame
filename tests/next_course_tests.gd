extends SceneTree
## Filter tours preserve the actual race setup, including after cancel and reload.
func _initialize() -> void: call_deferred("run")
func settle() -> void:
	for i in range(8): await process_frame
func run() -> void:
	var app: Node = load("res://game/client_app.gd").new()
	app.capture_path = "user://unused-next-course.png"
	app.capture_frame = 1000000000
	root.add_child(app)
	await settle()
	var folder := "user://tests/next-course-"+RaceSetup.uuid()
	app.data = AppData.new(folder,false)
	app.checkpoint = RaceCheckpoint.new(app.data)
	app.menu.settings = app.data.settings
	app.events.mode = "quick"
	app.events.filter_index = EventMenu.FILTERS.find("smooth")
	app.events.track_shuffle = TrackShuffle.new(42)
	var configuration := {"mode":"quick","track":0,"car":4,"paint":6,"laps":1,"opponents":3,"difficulty":0,"contact":false,"seed":12345}
	var visited: Array[int] = [0]
	for step in range(5):
		var next: Dictionary = app.events.next_quick_configuration(configuration)
		assert(not next.has("seed") and next.car==4 and next.paint==6 and next.laps==1 and next.opponents==3 and next.difficulty==0 and not next.contact)
		assert(Catalog.tracks[int(next.track)].smooth_road() and not int(next.track) in visited)
		visited.append(int(next.track))
		configuration = next
	assert(visited.size()==6)
	assert(app.events.next_quick_configuration({"mode":"trial","track":0}).is_empty())
	var reloaded := AppData.new(folder,false)
	assert(reloaded.profile.quick_setup.track==Catalog.tracks[int(configuration.track)].id and reloaded.profile.quick_setup.filter=="smooth")
	reloaded = null
	app.data.set_setting("steering_assist","strong")
	app.data.set_setting("corner_braking",true)
	app.start_drive(configuration)
	app.drive.set_physics_process(false)
	for state: VehicleState in app.drive.session.states:
		state.finished = true
		state.finish_time = 100+state.slot
		state.best_lap_time = state.finish_time
	app.show_results()
	await settle()
	assert(app.menu.root.find_child("NextCourse",true,false)!=null)
	var original: Dictionary = app.pending_config.duplicate(true)
	app.result_summary.saved = false
	app.next_quick_course()
	assert(app.page=="results" and app.pending_config==original,"unsaved result needs explicit handling before another course")
	app.result_summary.saved = true
	app.menu.root.find_child("NextCourse",true,false).pressed.emit()
	assert(app.page=="loading")
	app.back_action.call()
	await settle()
	assert(app.page=="results" and app.pending_config==original and app.result_receipt!=null,"cancel returns to the same results")
	app.data.profile.selected_car = 0
	app.data.profile.selected_paint = 0
	app.menu.root.find_child("NextCourse",true,false).pressed.emit()
	for i in range(1200):
		if app.page=="race": break
		await process_frame
	assert(app.page=="race")
	app.drive.set_physics_process(false)
	assert(app.pending_config.track!=original.track and Catalog.tracks[int(app.pending_config.track)].smooth_road())
	assert(app.pending_config.car==4 and app.pending_config.paint==6 and app.pending_config.opponents==3 and app.pending_config.laps==1 and not app.pending_config.contact)
	assert(app.drive.session.states.size()==4 and app.drive.session.driving_assists=={app.drive.local_slot:2} and app.drive.session.corner_braking=={app.drive.local_slot:true})
	app.queue_free()
	await create_timer(.5).timeout
	assert(AppData.remove_tree(ProjectSettings.globalize_path(folder))==OK)
	print("NEXT_COURSE_FILTER_TOUR_SETUP_PERSISTENCE_CANCEL_SAVE_GUARD_AND_ACTUAL_RACE_PASS")
	quit()

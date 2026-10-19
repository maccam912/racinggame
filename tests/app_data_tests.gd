extends SceneTree

var failures: int = 0


func check(condition: bool, message: String) -> void:
	if not condition:
		push_error("TEST FAIL: " + message)
		failures += 1


func _initialize() -> void:
	Catalog.load_all()
	var folder := "user://test-app-data-" + RaceSetup.uuid()
	var app := AppData.new(folder, false)
	check(app.settings.render_scale == 100 and app.settings.msaa == 4, "desktop defaults")
	check(app.set_setting("master", 25) == OK, "confirmed setting persisted")
	app.set_setting("preset", "low")
	check(app.settings.render_scale == 70 and app.settings.shadows == "off", "Low preset mapping")
	app.restore_tab("graphics")
	check(app.settings.render_scale == 100 and app.settings.master == 25, "restore tab preserves other tabs")
	app.save_profile()
	var phone := AppData.new(folder, true)
	check(phone.settings.render_scale == 80 and phone.settings.touch_auto_accelerate and phone.settings.frame_cap == 60, "independent mobile defaults")
	phone.set_setting("touch_auto_accelerate", false)
	check(AppData.new(folder, false).settings.master == 25, "mobile settings preserve desktop settings")
	var race := RaceSession.new()
	race.track = Catalog.tracks[0]
	race.mode = "trial"
	race.race_uuid = RaceSetup.uuid()
	race.human_slot = 0
	race.cars = [Catalog.cars[0]]
	var state := VehicleState.new()
	state.finished = true
	state.trial_valid = true
	state.finish_time = .123456
	state.distance_m = 15.0
	race.states = [state]
	var samples: Array[Dictionary] = [
		{"time":0.0, "position":Vector3(0, 4.35, 0), "yaw":0.0},
		{"time":.05, "position":Vector3(0, 4.35, -3), "yaw":0.0},
		{"time":.1, "position":Vector3(0, 4.35, -6), "yaw":0.0},
		{"time":.123456, "position":Vector3(0, 4.35, -7), "yaw":0.0}]
	var outcome := app.commit_result(race, samples)
	check(outcome.saved and outcome.new_best, "valid faster trial saves record and ghost")
	check(app.load_ghost("palm_bay", "comet").time == .123456, "record/ghost pair validated")
	app.commit_result(race, samples)
	check(app.profile.races_completed == 1 and app.profile.distance_m == 15, "idempotent result stats")
	race.race_uuid = RaceSetup.uuid()
	state.finish_time = .15
	check(not app.commit_result(race, samples).new_best and app.best("trial", "palm_bay", "comet") == .123456, "slower trial preserves best/ghost")
	race.race_uuid = RaceSetup.uuid()
	state.finish_time = .1
	state.trial_valid = false
	check(not app.commit_result(race, samples).new_best, "invalid faster trial cannot record")
	var restored := AppData.new(folder, false)
	print("Reload stats=%s best=%s notices=%s" % [str(restored.profile.races_completed), str(restored.best("trial", "palm_bay", "comet")), str(restored.store.notices)])
	check(restored.profile.races_completed == 3 and restored.best("trial", "palm_bay", "comet") == .123456, "cold reload preserves stats and record")
	check(app.set_setting("frame_cap", 30) == OK, "numeric choice accepts JSON number/int equivalence")
	race.race_uuid = RaceSetup.uuid()
	state.trial_valid = true
	state.finish_time = .16
	app.store.fail_component = "profile"
	app.store.fail_stage = "before_replace"
	check(not app.commit_result(race, samples).saved, "statistics write failure is exposed")
	var after_failure := AppData.new(folder, false)
	check(after_failure.profile.races_completed == 4 and after_failure.records.pending.is_empty(), "cold reload completes pending statistics journal")
	check(AppData.new(folder, false).profile.races_completed == 4, "recovered journal cannot count twice")
	app.store.fail_stage = ""
	app.store.fail_component = ""
	check(app.start_cup()==OK,"create trophy reset fixture")
	var order: Array[Dictionary] = []
	for id: String in ["local"]+app.cup.data.roster.filter(func(row: Dictionary) -> bool: return row.bot).map(func(row: Dictionary) -> String: return row.id):
		order.append({"id":id,"dnf":"","time":60.0+order.size(),"best_lap":30.0,"distance_m":100.0})
	for event in range(6): check(app.cup.commit(event,RaceSetup.uuid(),order),"complete trophy fixture event")
	check(app.store.save_component("cup",app.cup.data)==OK and app.reconcile_cup_profile()==OK,"persist completed Cup trophy")
	check(app.profile.trophies.size()==1,"completed Cup earns trophy")
	check(app.reset_local(false)==OK,"record reset persists trophy suppression for a completed Cup")
	check(AppData.new(folder,false).profile.trophies.is_empty(),"cold reload cannot resurrect a reset Cup trophy")
	remove_tree(ProjectSettings.globalize_path(folder))
	print("App data fixtures: platform settings, tab restore, records/ghosts and idempotent stats; failures %d" % failures)
	quit(1 if failures else 0)


func remove_tree(path: String) -> void:
	var directory := DirAccess.open(path)
	for child: String in directory.get_directories():
		remove_tree(path.path_join(child))
	for file: String in directory.get_files():
		directory.remove(file)
	DirAccess.remove_absolute(path)

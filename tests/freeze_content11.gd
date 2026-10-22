extends SceneTree
## One-time authoring tool. Never rerun after the content-11 boundary.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	Catalog.load_all()
	assert(Catalog.rules.content_version==11)
	var target := "res://tests/fixtures/content11/"
	assert(not FileAccess.file_exists(target+"manifest.json"),"frozen fixtures cannot be overwritten")
	DirAccess.make_dir_recursive_absolute(target)
	var folder := "user://tests/freeze-content11-"+RaceSetup.uuid()
	var data := AppData.new(folder,false)
	data.profile.display_name = "Archive Eleven"
	data.profile.first_run_complete = true
	assert(data.save_profile()==OK)
	var race := RaceSession.new()
	race.track = Catalog.tracks[0]
	race.mode = "trial"
	race.race_uuid = RaceSetup.uuid()
	race.human_slot = 0
	race.cars = [Catalog.cars[0]]
	var state := VehicleState.new()
	state.finished = true
	state.trial_valid = true
	state.finish_time = .1
	race.states = [state]
	var samples: Array[Dictionary] = [{"time":0.0,"position":Vector3.ZERO,"yaw":0.0},{"time":.05,"position":Vector3.FORWARD,"yaw":0.0},{"time":.1,"position":Vector3.FORWARD*2,"yaw":0.0}]
	assert(data.commit_result(race,samples).saved)
	assert(data.start_cup()==OK)
	var app: Node = load("res://game/client_app.gd").new()
	root.add_child(app)
	await process_frame
	app.data = data
	app.start_drive({"mode":"quick","track":0,"car":0,"paint":0,"opponents":7,"laps":2,"difficulty":1,"contact":true,"seed":1112})
	app.drive.set_physics_process(false)
	await physics_frame
	await physics_frame
	for tick in range(600): app.drive.session.step({app.drive.local_slot:app.drive.demo_driver.sample(app.drive.state,app.drive.car,app.drive.track,app.drive.query)})
	var archive := RaceArchive.capture(app.drive)
	assert(RaceArchive.valid(archive))
	assert(data.store.save_component("suspended_race",archive)==OK)
	var files := {}
	for component: String in ["profile","records","cup","suspended_race"]:
		copy(data.store.path(component),target+component+".json")
		files[component+".json"] = FileAccess.get_sha256(target+component+".json")
	copy(data.ghost_path("palm_bay","comet"),target+"ghost.bin")
	files["ghost.bin"] = FileAccess.get_sha256(target+"ghost.bin")
	for name: String in ["cars","tracks","rules","compatibility"]: copy("res://game/content/"+name+".json",target+name+".json")
	var manifest := {"content_hash":Compatibility.content_hash(),"content_version":11,"files":files,"purpose":"Frozen content-11: synthetic 0.1-second record/ghost, fresh Cup and actual 600-tick eight-car race before the forty-course expansion. No earned result claim."}
	var file := FileAccess.open(target+"manifest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(manifest,"\t")+"\n")
	file.close()
	app.queue_free()
	await create_timer(.5).timeout
	assert(AppData.remove_tree(ProjectSettings.globalize_path(folder))==OK)
	print("CONTENT11_FROZEN ",FileAccess.get_sha256(target+"manifest.json"))
	quit()

func copy(source: String, target: String) -> void:
	var file := FileAccess.open(target,FileAccess.WRITE)
	assert(file!=null)
	file.store_buffer(FileAccess.get_file_as_bytes(source))
	file.close()

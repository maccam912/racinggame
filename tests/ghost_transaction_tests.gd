extends SceneTree

func samples(total: float) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for index in range(ceili(total*20)):
		result.append({"time":index/20.0,"position":Vector3(0,4.35,-index*3),"yaw":0.0})
	result.append({"time":total,"position":Vector3(0,4.35,-total*60),"yaw":0.0})
	return result

func write_bytes(path: String, bytes: PackedByteArray) -> void:
	var file := FileAccess.open(path,FileAccess.WRITE)
	assert(file!=null)
	file.store_buffer(bytes)
	file.close()

func _initialize() -> void:
	Catalog.load_all()
	var folder := "user://tests/ghost-transaction-"+RaceSetup.uuid()
	var data := AppData.new(folder,false)
	var race := RaceSession.new()
	race.track = Catalog.tracks[0]
	race.cars = [Catalog.cars[0]]
	race.mode = "trial"
	race.human_slot = 0
	race.race_uuid = RaceSetup.uuid()
	var state := VehicleState.new()
	state.finished = true
	state.trial_valid = true
	state.finish_time = .2
	race.states = [state]
	assert(data.commit_result(race,samples(.2)).saved)
	var path := data.ghost_path("palm_bay","comet")
	var valid := FileAccess.get_file_as_bytes(path)
	write_bytes(path+".bak",valid)
	write_bytes(path,"broken".to_ascii_buffer())
	assert(data.load_ghost("palm_bay","comet").time==.2)
	data.store.fail_component = "records"
	data.store.fail_stage = "before_replace"
	race.race_uuid = RaceSetup.uuid()
	state.finish_time = .1
	assert(not data.commit_result(race,samples(.1)).saved)
	var restored := AppData.new(folder,false)
	var ghost := restored.load_ghost("palm_bay","comet")
	if ghost.is_empty() or ghost.time!=.2:
		print("TEST FAIL: failed faster result overwrote the only verified ghost backup")
		quit(1)
		return
	assert(restored.best("trial","palm_bay","comet")==.2)
	# A previous process may have replaced its ghost just before the records
	# write. That valid, uncommitted primary must not replace the matching backup.
	write_bytes(path,GhostCodec.encode("palm_bay","comet",Compatibility.content_hash(),.15,samples(.15)))
	assert(restored.load_ghost("palm_bay","comet").time==.2)
	restored.store.fail_component = "records"
	restored.store.fail_stage = "before_replace"
	race.race_uuid = RaceSetup.uuid()
	assert(not restored.commit_result(race,samples(.1)).saved)
	assert(AppData.new(folder,false).load_ghost("palm_bay","comet").time==.2)
	restored.store.fail_stage = ""
	assert(restored.commit_result(race,samples(.1)).saved)
	var final := AppData.new(folder,false)
	assert(final.best("trial","palm_bay","comet")==.1 and final.load_ghost("palm_bay","comet").time==.1)
	assert(not GhostCodec.decode(FileAccess.get_file_as_bytes(path+".bak"),"palm_bay","comet",Compatibility.content_hash()).is_empty())
	print("Ghost transactions: corrupt primary, verified backup, interrupted record commit and retry preserve matched pairs")
	quit()

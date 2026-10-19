extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func make_race(data: AppData,mode: String) -> RaceSession:
	var race := RaceSession.new()
	race.track = Catalog.tracks[0]
	race.mode = mode
	race.race_uuid = RaceSetup.uuid()
	race.cup_event = 0 if mode=="cup" else -1
	race.event_uuid = str(data.cup.data.id) if mode=="cup" else ""
	race.roster = data.cup.grid() if mode=="cup" else RaceSetup.roster(0,0,0,"Local")
	for index: int in range(race.roster.size()):
		var record: Dictionary = race.roster[index]
		if record.id=="local":
			race.human_slot = index
		race.cars.append(Catalog.cars[int(record.car)])
		var state := VehicleState.new()
		state.slot = index
		state.finished = true
		state.finish_time = 70.125+index
		state.best_lap_time = 35.0625+index
		state.distance_m = 3000.0
		race.states.append(state)
	return race

func has_button(app: Node,label: String) -> bool:
	for button: Node in app.menu.root.find_children("*","Button",true,false):
		if button.text==label:
			return true
	return false

func run() -> void:
	var app: Node = load("res://game/client_app.gd").new()
	root.add_child(app)
	await process_frame
	var folder := "user://tests/results-"+str(Time.get_ticks_usec())
	app.data = AppData.new(folder,false)
	var data: AppData = app.data
	data.start_cup()
	var race := make_race(data,"cup")
	var original_seed: int = data.cup.data.seeds[0]
	data.store.fail_component = "cup"
	data.store.fail_stage = "before_replace"
	var previous_cup := data.cup.data.duplicate(true)
	assert(data.start_cup()!=OK and data.cup.data==previous_cup,"failed replacement preserves the unfinished championship")
	app.page = "results"
	app.result_receipt = ResultReceipt.capture(race,[])
	app.retry_result_save()
	await process_frame
	assert(not app.result_summary.saved and data.cup.data.next_event==0)
	assert(has_button(app,I18n.t("data.retry_save")) and has_button(app,I18n.t("data.continue_unsaved")))
	assert(not has_button(app,I18n.t("cup.next")) and not has_button(app,I18n.t("cup.save_quit")),"Cup progression blocked until save")
	app.continue_without_saving()
	await process_frame
	assert(app.page=="main" and app.unsaved_results.is_empty())
	assert(data.cup.data.next_event==0 and data.cup.data.seeds[0]==original_seed,"dismissal preserves original unstarted Cup event")
	# Retry freezes rows before the original scene can change or be disposed.
	app.result_receipt = ResultReceipt.capture(race,[])
	app.page = "results"
	app.retry_result_save()
	race.states[race.human_slot].finish_time = 999
	race.states[race.human_slot].distance_m = 1
	race.roster[race.human_slot].name = "Changed"
	data.store.fail_stage = ""
	app.retry_result_save()
	await process_frame
	assert(app.result_summary.saved and data.cup.data.next_event==1)
	assert(has_button(app,I18n.t("cup.next")))
	var local_row: Dictionary = data.cup.data.results[0].order.filter(func(row: Dictionary) -> bool: return row.id=="local")[0]
	assert(local_row.time==74.125 and local_row.distance_m==3000)
	assert(data.profile.races_completed==1 and data.profile.distance_m==3000)
	app.retry_result_save()
	assert(data.cup.data.results.size()==1 and data.profile.races_completed==1,"repeated retries are idempotent")
	var cup_receipt: ResultReceipt = app.result_receipt
	# Online deadline/lobby transitions may dispose the scene before disk space
	# returns. The pending receipt remains independently retryable afterward.
	var online := make_race(data,"online")
	app.result_receipt = ResultReceipt.capture(online,[],[{"slot":0}])
	app.page = "results"
	data.store.fail_component = "records"
	data.store.fail_stage = "before_replace"
	app.retry_result_save()
	await process_frame
	assert(not app.result_summary.saved and app.unsaved_results.size()==1)
	app.show_menu()
	await process_frame
	assert(has_button(app,I18n.t("data.retry_save")))
	online.states[0].finish_time = 999
	online.states[0].distance_m = 0
	app.result_receipt = null
	data.store.fail_stage = ""
	app.retry_pending_saves()
	await process_frame
	assert(app.unsaved_results.is_empty())
	assert(data.profile.races_completed==2 and data.profile.distance_m==6000,"pending result survives scene/result replacement")
	assert(data.best("race_lap","palm_bay","comet")==35.0625)
	app.retry_pending_saves()
	assert(data.profile.races_completed==2)
	var trial := make_race(data,"trial")
	trial.states[0].trial_valid = false
	data.store.fail_stage = "before_replace"
	app.result_receipt = ResultReceipt.capture(trial,[])
	app.page = "results"
	app.retry_result_save()
	assert(not has_button(app,I18n.t("results.retry")),"ordinary progression needs explicit dismissal")
	app.continue_without_saving()
	assert(has_button(app,I18n.t("results.retry")) and app.unsaved_results.is_empty())
	data.start_cup()
	assert(not cup_receipt.commit(data).saved and data.cup.data.next_event==0,"stale Cup receipt cannot enter a replacement championship")
	app.queue_free()
	await process_frame
	await process_frame
	print("Result receipts: failed Cup gates, explicit dismissal, frozen rows, exact retry, online scene disposal and idempotent journals pass")
	quit()

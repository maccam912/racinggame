extends SceneTree

func _initialize() -> void: call_deferred("run")

func run() -> void:
	Catalog.load_all()
	assert(Catalog.cars.size() == 8)
	var query := FlatQuery.new()
	var press := InputFrame.make(0,1)
	press.boost = true
	var release := InputFrame.make(0,1)
	for index in range(Catalog.cars.size()):
		var car := Catalog.cars[index]
		var state := VehicleState.new()
		state.position.y = .35
		state.boost_charges = car.boost_charges
		var normal := state.copy()
		for tick in range(120):
			VehicleSim.step(state,press,car,query)
			VehicleSim.step(normal,release,car,query)
		if car.boost_charges == 0:
			assert(state.boost_ticks == 0 and state.boost_charges == 0 and state.position == normal.position)
			continue
		assert(state.boost_charges == 2 and state.boost_ticks == 0 and state.speed() > normal.speed()+15,"two second burst must produce meaningful acceleration")
		for tick in range(240): VehicleSim.step(state,press,car,query)
		assert(state.boost_charges == 2,"holding the button never chains charges")
		VehicleSim.step(state,release,car,query)
		VehicleSim.step(state,press,car,query)
		assert(state.boost_charges == 1 and state.boost_ticks == 119)
		VehicleSim.step(state,release,car,query)
		VehicleSim.step(state,press,car,query)
		assert(state.boost_charges == 1,"pressing during a burst cannot queue another charge")
		state.recovery_ticks = 30
		for tick in range(30): VehicleSim.step(state,release,car,query)
		assert(state.boost_charges == 1 and state.boost_ticks == 0,"recovery cancels without a refund")
		state.laps = 1
		VehicleSim.step(state,press,car,query)
		assert(state.boost_charges == 0)
		for tick in range(300): VehicleSim.step(state,release if tick%2 else press,car,query)
		assert(state.boost_charges == 0 and state.boost_ticks == 0,"laps and further presses never refill")
		assert(state.speed() <= car.top_speed*VehicleSim.BOOST_SPEED_FACTOR+.001)
	# All device bindings and redundant input packets carry exactly the same bit.
	assert(BindingBook.defaults().keyboard.boost[0] == BindingBook.key(KEY_SHIFT))
	assert(BindingBook.defaults().gamepad.boost[0] == BindingBook.button(JOY_BUTTON_X))
	assert(NetCodec.quantize(press).boost)
	assert(not NetCodec.quantize(release).boost)
	var lobby := LobbyState.new()
	assert(not lobby.join("boost-driver","Boost Driver",0,7,7).is_empty())
	assert(lobby.select_car("boost-driver",6,6))
	assert(not lobby.select_car("boost-driver",8,0))
	assert(NetEvents.roster_valid(RaceSetup.roster(7,7,7,"Boost Driver")))
	for reason: String in ["airborne","braking","reverse","finished"]:
		var unavailable := VehicleState.new()
		unavailable.position.y = 10 if reason == "airborne" else .35
		unavailable.grounded = reason != "airborne"
		unavailable.reversing = reason == "reverse"
		unavailable.finished = reason == "finished"
		unavailable.boost_charges = 3
		var blocked := InputFrame.make(0,1,1 if reason == "braking" else 0)
		blocked.boost = true
		VehicleSim.step(unavailable,blocked,Catalog.cars[7],query)
		assert(unavailable.boost_charges == 3 and unavailable.boost_ticks == 0,reason)
	var buffer := InputBuffer.new()
	press.sequence = 1
	press.tick = 0
	buffer.push(press,0)
	assert(buffer.sample(3).boost)
	for tick in range(4,20): buffer.sample(tick)
	var missing := buffer.sample(20)
	assert(missing.boost and missing.throttle == 0 and missing.steer == 0,"packet loss retains the boost edge latch while neutralizing driving")
	var bad := NetCodec.encode_inputs(1,[press])
	bad[21] = 8
	assert(NetCodec.decode_inputs(bad,1).is_empty())
	await race_cases(press)
	print("EIGHT_CARS_THREE_FINITE_BOOSTS_NO_REFILL_HOLD_RECOVERY_SAVE_NETWORK_PREDICTION_TOUCH_PASS")
	await create_timer(.5).timeout
	quit()

func race_cases(press: InputFrame) -> void:
	var folder := "user://tests/boost-"+RaceSetup.uuid()
	var app: Node = load("res://game/client_app.gd").new()
	root.add_child(app)
	await process_frame
	app.data = AppData.new(folder,true)
	assert(app.data.select_car(7,7) == OK)
	assert(AppData.new(folder,true).profile.selected_car == 7)
	app.start_drive({"mode":"quick","track":0,"car":7,"paint":7,"opponents":0,"laps":2,"difficulty":1,"contact":false})
	var drive: RaceDrive = app.drive
	drive.set_physics_process(false)
	await physics_frame
	await physics_frame
	for tick in range(300): drive.session.step({drive.local_slot:press})
	assert(drive.state.boost_charges == 3,"countdown cannot spend a charge")
	drive.session.step({drive.local_slot:press})
	assert(drive.state.boost_charges == 2 and drive.state.boost_ticks == 119)
	assert(drive.hud.boost_available and drive.touch.boost_available)
	var archive := RaceArchive.capture(drive)
	assert(RaceArchive.valid(archive))
	assert(app.data.store.save_component("suspended_race",archive) == OK)
	var cold := SaveStore.new(folder).load_component("suspended_race",{},RaceArchive.valid)
	app.start_drive(cold.config)
	drive = app.drive
	drive.set_physics_process(false)
	assert(RaceArchive.restore(drive,cold))
	assert(drive.state.boost_charges == 2 and drive.state.boost_ticks == 119 and drive.state.boost_latched == 1)
	var packet := NetCodec.encode_snapshot(drive.session,1,Compatibility.content_hash().hex_decode())
	var decoded := NetCodec.decode_snapshot(packet,drive.session.race_id,Compatibility.content_hash().hex_decode())
	assert(decoded.states[0].boost_charges == 2 and decoded.states[0].boost_ticks == 119 and decoded.states[0].boost_latched == 1)
	# Replay a held press from authority: no second spend after reconciliation.
	var prediction := PredictionBuffer.new()
	prediction.state = drive.state.copy()
	prediction.track = drive.track
	prediction.car = drive.car
	prediction.query = drive.query
	press.sequence = 1
	press.tick = 1
	prediction.advance(press)
	prediction.reconcile(decoded.states[0],0,1)
	assert(prediction.state.boost_charges == 2)
	var touch := drive.touch
	touch.enabled = true
	touch.pointer_down(10,touch.controls.boost.get_center())
	assert(touch.held("boost"))
	touch.pointer_up(10)
	assert(not touch.held("boost"))
	app.start_drive({"mode":"quick","track":0,"car":7,"paint":7,"opponents":0})
	app.drive.set_physics_process(false)
	assert(app.drive.state.boost_charges == 3,"only a new race replenishes charges")
	app.start_drive({"mode":"quick","track":0,"car":0,"paint":0,"opponents":0})
	app.drive.set_physics_process(false)
	assert(not app.drive.hud.boost_available and not app.drive.touch.boost_available)
	app.queue_free()
	await process_frame
	assert(AppData.remove_tree(ProjectSettings.globalize_path(folder)) == OK)

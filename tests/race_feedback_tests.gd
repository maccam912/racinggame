extends SceneTree
class Motors extends DrivingHaptics:
	var starts: Array[Dictionary] = []
	var stops: Array[int] = []
	func connected(id: int) -> bool: return id==7
	func send_start(id: int, weak: float, heavy: float, duration: float) -> void: starts.append({"id":id,"weak":weak,"heavy":heavy,"duration":duration})
	func send_stop(id: int) -> void: stops.append(id)
func _initialize() -> void: call_deferred("run")
func count(fx: RaceFeedback, kind: String, slot: int) -> int:
	return fx.particles.filter(func(puff: RaceFeedback.Puff) -> bool: return puff.kind==kind and puff.slot==slot).size()
func run() -> void:
	Catalog.load_all()
	var app: Node = load("res://game/client_app.gd").new()
	root.add_child(app)
	await process_frame
	app.start_drive({"mode":"quick","track":0,"opponents":7})
	await process_frame
	var drive: RaceDrive = app.drive
	drive.set_physics_process(false)
	drive.audio.set_physics_process(false)
	var fx: RaceFeedback = drive.feedback
	fx.set_physics_process(false)
	fx.set_process(false)
	fx.set_mode("full")
	var own := drive.state
	var rival: VehicleState = drive.session.states[(drive.local_slot+1)%8]
	var before := own.copy()
	for kind: String in ["smoke","dust","spark","landing"]:
		fx.spawn(kind,own,100)
		fx.spawn(kind,rival,100)
		assert(count(fx,kind,own.slot)<=fx.cap(kind,own.slot) and count(fx,kind,rival.slot)<=fx.cap(kind,rival.slot))
	assert(fx.particles.size()>0 and own.position==before.position and own.velocity==before.velocity)
	fx.advance(.61,Basis.IDENTITY)
	assert(count(fx,"smoke",own.slot)==0 and count(fx,"spark",own.slot)==0)
	fx.set_mode("reduced")
	assert(count(fx,"dust",own.slot)<=15 and count(fx,"dust",rival.slot)<=5)
	fx.set_mode("full")
	for index in range(500):
		own.position = Vector3(index*.5,.35,0)
		fx.add_skid(own)
	assert(fx.meters[own.slot]<=200 and fx.meters[own.slot]>199 and fx.marks[own.slot].size()<=640)
	fx.advance(15.01,Basis.IDENTITY)
	assert(fx.particles.is_empty() and fx.marks[own.slot].is_empty() and is_zero_approx(fx.meters[own.slot]))
	own.events.assign(["wall"])
	fx.elapsed = 1
	for index in range(20):
		fx.elapsed += .04
		fx.consume(own)
	assert(fx.spark_times.size()<=8 and count(fx,"spark",own.slot)<=12)
	fx.set_mode("off")
	assert(fx.particles.is_empty() and fx.skid_batch.multimesh.visible_instance_count==0)
	for batch: MultiMeshInstance3D in fx.batches.values(): assert(batch.multimesh.visible_instance_count==0)
	var motors := Motors.new()
	drive.driver.owner_device = "gamepad"
	drive.driver.joy_device = 7
	drive.driver.focused = true
	own.velocity = Vector3.FORWARD*20
	own.drift_phase = 1
	own.events.clear()
	var values := SettingsCatalog.defaults(false)
	values.vibration = 100
	motors.update(drive,values,.016,false)
	assert(motors.starts.size()==1 and motors.starts[0].weak==.15 and motors.starts[0].heavy==0)
	for tick in range(60): motors.update(drive,values,.016,false)
	assert(motors.starts.size()==1,"sustained slip does not send vibration commands per frame")
	own.events.assign(["wall"])
	motors.update(drive,values,.016,false)
	assert(motors.starts[-1].heavy==.4 and motors.starts[-1].duration<=.12)
	own.events.clear()
	motors.update(drive,values,.13,false)
	assert(motors.starts[-1].heavy==0 and motors.starts[-1].weak==.15)
	values.vibration = 0
	motors.update(drive,values,.016,false)
	assert(motors.last_strength==Vector2.ZERO)
	values.vibration = 100
	motors.update(drive,values,.016,false)
	drive.driver.focused = false
	motors.update(drive,values,.016,false)
	assert(motors.device<0 and motors.last_strength==Vector2.ZERO and not motors.stops.is_empty())
	motors.stop()
	app.queue_free()
	await process_frame
	await create_timer(.5).timeout
	print("BOUNDED_PARTICLES_SKID_DISTANCE_LIFETIME_OFF_REDUCED_MOTOR_CAPS_FOCUS_CANCELLATION_PASS")
	quit()

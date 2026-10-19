extends SceneTree

var failures: int = 0


func check(condition: bool, message: String) -> void:
	if not condition:
		push_error("TEST FAIL: " + message)
		failures += 1


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	Catalog.load_all()
	DrivingInput.register_defaults()
	var drive := RaceDrive.new()
	root.add_child(drive)
	await physics_frame
	drive.phase = "Racing"
	drive.session.phase = RaceSession.Phase.RACING
	var initial := drive.state.position
	Input.action_press("accelerate")
	for tick in range(120):
		await physics_frame
	Input.action_release("accelerate")
	check(drive.state.speed() > 20, "scene input accelerates the real chassis")
	check(drive.state.position.distance_to(initial) > 20, "scene moves on baked road")
	check(drive.state.grounded, "baked mesh ground probes support moving chassis")
	drive.show_pause()
	var frozen := drive.state.position
	var timer := drive.race_ticks
	for tick in range(30):
		await physics_frame
	check(drive.state.position == frozen and drive.race_ticks == timer, "offline pause freezes physics/timer")
	drive.resume()
	for tick in range(179):
		await physics_frame
	check(drive.state.position == frozen and drive.race_ticks == timer, "resume countdown freezes the world")
	for tick in range(3):
		await physics_frame
	check(drive.race_ticks > timer, "resume countdown returns to racing")
	ProgressTracker.recover(drive.state, drive.track)
	check(drive.state.recovery_ticks == 60 and drive.state.velocity == Vector3.ZERO, "scene recovery transition")
	drive.queue_free()
	await process_frame
	print("Driving scene smoke: failures %d" % failures)
	quit(1 if failures else 0)

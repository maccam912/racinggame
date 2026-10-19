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
	var folder := "user://tests/modes-" + str(Time.get_ticks_usec())
	var data := AppData.new(folder, false)
	var drive := RaceDrive.new()
	drive.config = {"mode":"trial", "laps":1, "opponents":0}
	drive.app_data = data
	drive.external_menus = true
	root.add_child(drive)
	drive.set_physics_process(false)
	await physics_frame
	var bot := BotDriver.new()
	for tick in range(10000):
		var frame := bot.sample(drive.state, drive.car, drive.track, drive.query)
		Input.action_press("steer_left", maxf(0, -frame.steer))
		Input.action_press("steer_right", maxf(0, frame.steer))
		Input.action_press("accelerate", frame.throttle)
		Input.action_press("brake", frame.brake)
		drive._physics_process(1.0 / 60)
		if drive.session.phase == RaceSession.Phase.RESULTS:
			break
	for action in ["steer_left", "steer_right", "accelerate", "brake"]:
		Input.action_release(action)
	check(drive.state.finished and drive.state.trial_valid, "standing trial completes valid with shared input/controller")
	check(drive.ghost_samples.size() > 1000, "trial records at 20 Hz")
	var result := data.commit_result(drive.session, drive.ghost_samples)
	check(result.saved and result.new_best, "real trial saves a new best and matching ghost")
	var loaded := data.load_ghost(drive.track.id, drive.car.id)
	check(not loaded.is_empty() and absf(float(loaded.time) - drive.state.finish_time) < .00000001, "ghost preserves exact sub-tick finish")
	print("Trial real finish %.9f, samples %d, medal %d" % [drive.state.finish_time, drive.ghost_samples.size(), Medals.award(drive.track.length, drive.state.finish_time, true)])
	drive.queue_free()
	await process_frame
	var track: TrackDefinition = Catalog.tracks[0]
	for index in range(5):
		var lesson := SchoolLesson.new()
		lesson.configure(index, track)
		var state := VehicleState.new()
		var frame := InputFrame.make()
		match index:
			0:
				state.velocity.z = -13
				lesson.update(state, frame, track)
				state.velocity = Vector3.ZERO
				frame.brake = 1
			1:
				for point: Vector3 in lesson.markers:
					state.position = point + Vector3.UP * .35
					lesson.update(state, frame, track)
			2:
				state.velocity.z = -12
				state.route_s = lesson.turn_s - 20
				lesson.update(state, frame, track)
				frame.brake = 1
				lesson.update(state, frame, track)
				state.route_s = lesson.turn_s + 12
				state.position = track.pose(state.route_s).origin
			3:
				state.drift_phase = 1
				frame.handbrake = true
				for tick in range(12):
					lesson.update(state, frame, track)
				state.drift_phase = 0
				frame.handbrake = false
			4: state.events.append("recovery")
		lesson.update(state, frame, track)
		check(lesson.done, "school objective " + str(index))
	# Hard deadline is inclusive and doesn't silently add the settling delay.
	var session := RaceSession.new()
	session.setup(track, [0], root.world_3d)
	session.phase = RaceSession.Phase.RACING
	session.elapsed_ticks = 35999
	session.step({})
	check(session.elapsed_ticks == 36000 and session.phase == RaceSession.Phase.RESULTS, "hard cap settles at exactly 600 seconds")
	AppData.remove_tree(ProjectSettings.globalize_path(folder))
	print("Mode fixtures: standing-start trial/ghost commit, five school objectives, exact cap; failures %d" % failures)
	quit(1 if failures else 0)

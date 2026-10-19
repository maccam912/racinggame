extends SceneTree

var failures: int = 0


func check(condition: bool, message: String) -> void:
	if not condition:
		push_error("TEST FAIL: " + message)
		failures += 1


func _initialize() -> void:
	Catalog.load_all()
	var track: TrackDefinition = Catalog.tracks[0]
	var state := VehicleState.new()
	# Crossing an out-of-order gate cannot project progress onto another section.
	var gate: Dictionary = track.bake.gates[3]
	var point := ProgressTracker.vector(gate.position)
	var forward := ProgressTracker.vector(gate.forward)
	state.position = point + forward * 2
	ProgressTracker.advance(state, point - forward * 2, track, 10, 1)
	check(state.last_gate == -1 and state.laps == 0, "skip gate rejected")
	var tick := 100
	for index in range(track.bake.gates.size() + 1):
		gate = track.bake.gates[index % track.bake.gates.size()]
		point = ProgressTracker.vector(gate.position)
		forward = ProgressTracker.vector(gate.forward)
		state.position = point - forward
		ProgressTracker.advance(state, point + forward, track, tick, 1)
		check(state.last_gate == index - 1 or index == track.bake.gates.size(), "reverse crossing cannot count")
		state.position = point + forward
		ProgressTracker.advance(state, point - forward, track, tick, 1)
		tick += 60
	check(state.finished and state.laps == 1, "ordered lap finish")
	check(absf(state.finish_time - (tick - 61 + .5) / 60.0) < .0001, "sub-tick crossing time")
	state.finished = false
	state.last_gate = 8
	ProgressTracker.recover(state, track)
	check(state.last_gate == 8 and state.laps == 1, "recovery retains lap and gate")
	check(state.velocity == Vector3.ZERO and not state.trial_valid and state.ghost_ticks == 180, "recovery zeroes speed, invalidates trial, starts ghost")
	var touch := TouchDriving.new()
	touch.unit = 1
	touch.controls = {"steer": Rect2(0, 0, 180, 100), "brake": Rect2(200, 0, 88, 88), "handbrake": Rect2(300, 0, 72, 72), "recover": Rect2(400, 0, 56, 56), "look_back": Rect2(500, 0, 48, 48)}
	touch.pointer_down(1, Vector2(160, 50))
	touch.pointer_down(2, Vector2(220, 40))
	touch.pointer_down(3, Vector2(320, 40))
	touch.pointer_down(4, Vector2(420, 40))
	touch.pointer_down(5, Vector2(520, 40))
	check(touch.captures.size() == 5 and touch.steer == 1 and touch.held("brake") and touch.held("handbrake"), "five independent pointers")
	touch.pointer_move(1, Vector2(-200, 200))
	check(touch.steer == -1, "steering ownership retained outside artwork")
	touch.pointer_move(2, Vector2(800, 300))
	check(not touch.held("brake"), "pedal outside release margin releases")
	touch.pointer_move(2, Vector2(220, 40))
	check(touch.held("brake"), "same captured pointer can reenter")
	touch.pointer_up(1)
	check(touch.steer == 0 and touch.held("handbrake"), "one pointer release preserves other input")
	touch.clear()
	check(touch.captures.is_empty() and touch.steer == 0, "cancel releases all inputs")
	touch.free()
	print("Progress/touch fixtures: failures %d" % failures)
	quit(1 if failures else 0)

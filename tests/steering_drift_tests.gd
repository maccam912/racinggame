extends SceneTree
## Full-lock slides must stay catchable with ordinary steering on every car.

var failures: int = 0


func check(condition: bool, message: String) -> void:
	if not condition:
		push_error("TEST FAIL: " + message)
		failures += 1


func moving(speed: float) -> VehicleState:
	var state := VehicleState.new()
	state.position.y = .35
	state.velocity = Vector3.FORWARD * speed
	return state


func slip(state: VehicleState) -> float:
	return rad_to_deg(state.forward().angle_to(state.velocity.normalized()))


func _initialize() -> void:
	Catalog.load_all()
	var evidence: Array[Dictionary] = []
	for car: CarDefinition in Catalog.cars:
		for direction: float in [-1.0, 1.0]:
			for surface: String in ["asphalt", "sand", "grass", "dirt"]:
				var query := FlatQuery.new()
				query.surface = surface
				for speed: float in [20.0, 40.0, car.top_speed]:
					var state := moving(speed)
					var max_slip := 0.0
					var label := "%s %s %.0f m/s steer %.0f" % [car.id, surface, speed, direction]
					for tick in range(600):
						VehicleSim.step(state, InputFrame.make(direction, 1), car, query)
						max_slip = maxf(max_slip, slip(state))
						if tick == 7:
							check(state.drift_phase == 0, label + ": brief steering tap keeps grip")
						if tick >= 29:
							check(state.drift_phase == 1, label + ": sustained lock holds drift without handbrake")
					check(max_slip > 20 and max_slip < 50, label + ": visible slide stays below spin angle: %.2f degrees" % max_slip)
					check(state.velocity.dot(state.forward()) > 15, label + ": slide keeps forward momentum")
					check(not state.braking, label + ": steering slide does not light brake lamps")
					evidence.append({"car":car.id, "surface":surface, "start_speed_mps":speed, "steer":direction, "max_slip_degrees":max_slip, "final_speed_mps":state.speed()})
					if surface != "asphalt": continue
					var caught := state.copy()
					var initial_slip := slip(caught)
					VehicleSim.step(caught, InputFrame.make(-direction * .5, 1), car, query)
					check(caught.drift_phase == 2, label + ": countersteer immediately starts recovery")
					for tick in range(44):
						VehicleSim.step(caught, InputFrame.make(-direction * .5, 1), car, query)
					check(slip(caught) < initial_slip * .5, label + ": countersteer catches the rear")
					var eased := state.copy()
					VehicleSim.step(eased, InputFrame.make(direction * .7, 1), car, query)
					check(eased.drift_phase == 2, label + ": easing steering starts recovery")
					for tick in range(24):
						VehicleSim.step(state, InputFrame.make(0, 1), car, query)
					check(state.drift_phase == 0, label + ": releasing lock restores grip in .40 seconds")
					for tick in range(156):
						VehicleSim.step(state, InputFrame.make(0, 1), car, query)
					check(slip(state) < 1, label + ": released steering settles back to straight travel")
		var query := FlatQuery.new()
		for speed: float in [0.0, 10.0, -8.0]:
			var state := moving(speed)
			for tick in range(60):
				VehicleSim.step(state, InputFrame.make(1), car, query)
				check(state.drift_phase == 0, car.id + ": parking and reverse keep normal grip")
		var partial := moving(40)
		for tick in range(120):
			VehicleSim.step(partial, InputFrame.make(.8, 1), car, query)
			check(partial.drift_phase == 0, car.id + ": partial lock does not trigger steering drift")
		var hysteresis := moving(40)
		for tick in range(30):
			VehicleSim.step(hysteresis, InputFrame.make(1, 1), car, query)
		for tick in range(30):
			VehicleSim.step(hysteresis, InputFrame.make(.8, 1), car, query)
			check(hysteresis.drift_phase == 1, car.id + ": small input fluctuations hold an existing slide")
		var airborne := moving(40)
		airborne.position.y = 100
		airborne.grounded = false
		for tick in range(30):
			VehicleSim.step(airborne, InputFrame.make(1, 1), car, query)
			check(airborne.drift_phase == 0, car.id + ": airborne steering cannot initiate drift")
		var session := RaceSession.new()
		session.states.append(hysteresis.copy())
		var prefix := "0123456789abcdef".hex_decode()
		var decoded := NetCodec.decode_snapshot(NetCodec.encode_snapshot(session, 100, prefix), 1, prefix)
		check(not decoded.is_empty(), car.id + ": active slide survives the existing snapshot format")
		if not decoded.is_empty():
			var restored: VehicleState = decoded.states[0]
			for tick in range(60):
				var frame := InputFrame.make(1, 1) if tick < 30 else InputFrame.make(0, 1)
				VehicleSim.step(hysteresis, frame, car, query)
				VehicleSim.step(restored, frame, car, query)
			check(hysteresis.position.distance_to(restored.position) < .05, car.id + ": snapshot replay through drift and recovery agrees within 5 cm")
	var output := FileAccess.open("res://reports/steering-drift.json", FileAccess.WRITE)
	output.store_string(JSON.stringify({"passed":failures == 0, "cases":evidence, "boundary":"Shared 60 Hz controller on deterministic flat asphalt/sand/grass/dirt; all four cars, both directions, three approach speeds and ten seconds sustained lock. Recovery, countersteering and snapshot replay are numeric checks, separate from human feel and physical-device testing."}, "\t") + "\n")
	output.close()
	print("STEERING_DRIFT_ALL_CARS_SURFACES_DIRECTIONS_CONTROL_RECOVERY_SNAPSHOT cases=%d failures=%d" % [evidence.size(), failures])
	quit(1 if failures else 0)

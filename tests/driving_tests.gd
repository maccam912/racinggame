extends SceneTree

var failures: int = 0


func check(condition: bool, message: String) -> void:
	if not condition:
		push_error("TEST FAIL: " + message)
		failures += 1


func _initialize() -> void:
	Catalog.load_all()
	var car: CarDefinition = Catalog.cars[0]
	var query := FlatQuery.new()
	var state := VehicleState.new()
	state.position.y = 0.35
	var launch_ticks := 0
	for tick in range(1200):
		VehicleSim.step(state, InputFrame.make(0, 1), car, query)
		if launch_ticks == 0 and state.speed() >= 100.0 / 3.6:
			launch_ticks = tick + 1
		check(state.speed() <= car.top_speed + 0.001, "flat powered speed cap")
	check(launch_ticks >= 120 and launch_ticks <= 180, "0–100 km/h: %f s" % (launch_ticks / 60.0))
	check(absf(state.position.x) < 0.0001, "zero-steer launch has no lateral drift")
	state.velocity = Vector3(0, 0, -100.0 / 3.6)
	state.position = Vector3(0, 0.35, 0)
	var stop_distance := 0.0
	for tick in range(300):
		VehicleSim.step(state, InputFrame.make(0, 0, 1), car, query)
		if state.speed() < 0.001:
			stop_distance = -state.position.z
			break
	check(stop_distance >= 18 and stop_distance <= 26, "100–0 stop distance: %f m" % stop_distance)
	for tick in range(19):
		VehicleSim.step(state, InputFrame.make(0, 0, 1), car, query)
	check(state.velocity.z <= 0.001, "reverse delayed at rest")
	for tick in range(80):
		VehicleSim.step(state, InputFrame.make(0, 0, 1), car, query)
	check(state.velocity.z > 0 and state.speed() <= 8, "brake-hold reverse cap")
	state = VehicleState.new()
	state.position.y = 0.35
	state.velocity = Vector3(0, 0, -40)
	for tick in range(30):
		VehicleSim.step(state, InputFrame.make(.8, 0, 0, true), car, query)
	check(state.drift_phase == 1, "deliberate handbrake enters Drift")
	check(state.velocity.dot(state.forward().cross(Vector3.UP)) < -3, "visible bounded-grip slip")
	for tick in range(24):
		VehicleSim.step(state, InputFrame.make(), car, query)
	check(state.drift_phase == 0, "grip restores in 0.40 seconds")
	var a := VehicleState.new()
	var b := a.copy()
	for tick in range(3600):
		var input := InputFrame.make(sin(tick * .003) * .3, 1)
		VehicleSim.step(a, input, car, query)
		VehicleSim.step(b, input, car, query)
	check(a.position.distance_to(b.position) < 0.02, "60-second repeated fixture agrees within 2 cm")
	print("Driving fixtures: 0–100 %.3f s; stop %.3f m; failures %d" % [launch_ticks / 60.0, stop_distance, failures])
	quit(1 if failures else 0)

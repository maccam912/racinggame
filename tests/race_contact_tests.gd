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
	var scene := Node3D.new()
	root.add_child(scene)
	var collision := RouteCollision.new()
	collision.build(Catalog.tracks[0])
	scene.add_child(collision)
	await physics_frame
	await physics_frame
	var race := RaceSession.new()
	var cars: Array[int] = [0, 0]
	race.setup(Catalog.tracks[0], cars, scene.get_world_3d(), 1)
	var inputs := {0:InputFrame.make(0, 1), 1:InputFrame.make(0, 1)}
	var initial := race.states[0].position
	for tick in range(300):
		race.step(inputs)
	check(race.elapsed_ticks == 0 and race.states[0].position == initial and race.phase == RaceSession.Phase.RACING, "grid/countdown are frozen for exactly 300 ticks")
	race.step(inputs)
	check(race.elapsed_ticks == 1 and race.states[0].ghost_ticks == 89, "GO moves cars and starts collision grace together")
	var first := race.states[0]
	var second := race.states[1]
	for case in range(20):
		var pose := race.track.pose(20 + case * 2)
		var right := pose.basis.x
		first.position = pose.origin + Vector3.UP * .35 - right * .8
		second.position = pose.origin + Vector3.UP * .35 + right * .8
		first.yaw = atan2(-pose.basis.z.x, pose.basis.z.z)
		second.yaw = first.yaw
		first.velocity = -pose.basis.z * 30 + right * 5
		second.velocity = -pose.basis.z * 30 - right * 5
		first.ghost_ticks = 0
		second.ghost_ticks = 0
		var before_first := first.velocity
		var before_second := second.velocity
		var position_a := first.position
		CarContact.resolve(race.states, race.queries)
		check((first.velocity - before_first).length() <= 4.001 and (second.velocity - before_second).length() <= 4.001, "10 m/s contact impulse bound")
		check(first.position.distance_to(position_a) <= .251, "per-tick overlap correction <= .25 m")
		check(absf(first.velocity.dot(-pose.basis.z) - 30) < .01, "contact preserves tangential velocity")
		check(first.yaw == second.yaw, "contact has no angular impulse")
	first.finished = true
	first.finish_time = 10.0002
	second.finished = true
	second.finish_time = 10.0001
	check(race.standings()[0] == second, "sub-tick finish order")
	second.finish_time = first.finish_time
	check(race.standings()[0] == first, "exact finish tie uses stable slot")
	second.finished = false
	first.finished = false
	race.elapsed_ticks = 35999
	race.step({})
	check(first.dnf_reason != "" and second.dnf_reason != "", "600-second hard limit")
	for tick in range(120):
		race.step({})
	check(race.phase == RaceSession.Phase.RESULTS, "two-second final settling period")
	race = null
	scene.queue_free()
	await process_frame
	print("Race/contact fixtures: 20 bounded bumps, countdown, precise finishes and hard cap; failures %d" % failures)
	quit(1 if failures else 0)

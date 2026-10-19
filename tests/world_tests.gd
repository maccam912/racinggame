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
	for data: Array in [[Vector3(0, -.5, 0), Vector3(2000, 1, 2000)], [Vector3(10.5, 2, 0), Vector3(1, 4, 2000)]]:
		var body := StaticBody3D.new()
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = data[1]
		collider.shape = shape
		body.position = data[0]
		body.add_child(collider)
		scene.add_child(body)
	await physics_frame
	await physics_frame
	var query := WorldQuery.new(scene.get_world_3d(), Catalog.tracks[0])
	var state := VehicleState.new()
	state.position = Vector3(0, .35, -20)
	var ground := query.ground(state)
	check(ground.supported and absf(ground.height) < .01, "four-probe flat support")
	var position := Vector3(7, .35, 0)
	var velocity := Vector3(sin(deg_to_rad(15)) * 40, 0, -cos(deg_to_rad(15)) * 40)
	var first_speed := 0.0
	var contact_count := 0
	for tick in range(120):
		var result := query.sweep(position, velocity, 0, 1.0 / 60, contact_count == 0)
		position = result.position
		velocity = result.velocity
		if result.hit:
			contact_count += 1
			if first_speed == 0:
				first_speed = velocity.length()
			velocity.x = .15 # Deliberately maintain contact for the persistent scrape test.
	check(contact_count > 10, "continuous wall scrape was exercised")
	check(position.x < 9.06, "rounded chassis does not penetrate static wall by >5 cm")
	check(absf(velocity.z) > 32, "persistent contact retains tangential velocity")
	check(first_speed > 36, "first impact tangential retention is 96%")
	print("World fixtures: wall contacts %d; initial %.3f m/s; final tangent %.3f m/s; x %.4f; failures %d" % [contact_count, first_speed, absf(velocity.z), position.x, failures])
	scene.queue_free()
	await process_frame
	quit(1 if failures else 0)

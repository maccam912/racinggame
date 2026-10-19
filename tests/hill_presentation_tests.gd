extends SceneTree
## Actual road collision at the new grade limit and all supported render rates.


func _initialize() -> void: call_deferred("run")


func run() -> void:
	Catalog.load_all()
	root.size = Vector2i(1280,720)
	for grade: float in [-.24,0.0,.24]:
		var normal := Vector3(0,1,grade).normalized()
		var scene := Node3D.new()
		root.add_child(scene)
		var body := StaticBody3D.new()
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(2000,1,2000)
		collider.shape = shape
		body.add_child(collider)
		body.rotation.x = atan(grade)
		body.position = -normal*.5
		scene.add_child(body)
		await physics_frame
		await physics_frame
		for fps in [30,60,120]:
			var camera := ChaseCamera.new()
			scene.add_child(camera)
			camera.current = true
			var visual := CarVisual.new()
			visual.build(Catalog.paints[0])
			scene.add_child(visual)
			var state := VehicleState.new()
			state.ground_normal = normal
			state.velocity = Vector3(0,grade,-1)*85
			for frame in range(fps*2):
				var z: float = -20.0-frame*85.0/fps
				state.position = Vector3(0,-z*grade+.35,z)
				camera.follow(state,1.0/fps)
				visual.present(state,InputFrame.make(),1.0/fps)
				assert(camera.boom_fraction>.97,"steep road must not collapse the camera boom at 190 mph")
				assert(camera.position.distance_to(state.position)<6.5,"translation follows the car without speed-dependent lag")
				assert((camera.position-Vector3(0,-camera.position.z*grade,camera.position.z)).dot(normal)>.5)
				assert(camera.is_position_in_frustum(state.position+normal*.6),"the car stays in the chase view through climbs and drops")
				assert(visual.basis.y.dot(normal)>.9999)
				for wheel: Node3D in visual.wheels:
					var rest: Transform3D = visual.wheel_rest[wheel]
					assert(wheel.global_position.distance_to(visual.global_transform*rest.origin)<.001)
			var up_before := visual.visual_up
			state.grounded = false
			state.ground_normal = Vector3.UP
			visual.present(state,InputFrame.make(),.2)
			camera.follow(state,.2)
			assert(visual.visual_up.is_equal_approx(up_before) and camera.follow_up.dot(normal)>.9999,"flight retains the takeoff slope")
			camera.free()
			visual.free()
		scene.queue_free()
		await process_frame
	print("CHASE_CAR_WHEELS_24_PERCENT_CLIMBS_DROPS_190_MPH_30_60_120_FPS_NO_BOOM_COLLAPSE_PASS")
	quit()

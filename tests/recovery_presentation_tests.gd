extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	Catalog.load_all()
	var scene := Node3D.new()
	root.add_child(scene)
	var visual := CarVisual.new()
	visual.build(Catalog.paints[0])
	scene.add_child(visual)
	var state := VehicleState.new()
	state.position = Vector3(2,.35,-20)
	visual.present(state,InputFrame.make(),.016)
	assert(visual.opacity==1 and visual.applied_material==visual.surface)
	state.ghost_ticks = 90
	visual.present(state,InputFrame.make(),.016)
	assert(visual.opacity==.75 and visual.applied_material==visual.fade_surface)
	var old := visual.position
	state.position += Vector3(100,0,100)
	state.recovery_ticks = 60
	state.ghost_ticks = 180
	visual.present(state,InputFrame.make(),.016)
	assert(visual.position==old and visual.opacity==1)
	state.recovery_ticks = 45
	visual.present(state,InputFrame.make(),.016)
	assert(visual.position==old and visual.opacity==.5)
	state.recovery_ticks = 30
	visual.present(state,InputFrame.make(),.016)
	assert(visual.position==state.position and is_zero_approx(visual.opacity) and not visual.visible)
	state.recovery_ticks = 15
	visual.present(state,InputFrame.make(),.016)
	assert(visual.opacity==.375 and visual.visible)
	state.recovery_ticks = 0
	visual.present(state,InputFrame.make(),.016)
	assert(visual.opacity==.75)
	state.ghost_ticks = 0
	visual.present(state,InputFrame.make(),.016)
	assert(visual.opacity==1 and visual.applied_material==visual.surface)
	var late := CarVisual.new()
	late.build(Catalog.paints[1],"needle")
	scene.add_child(late)
	state.recovery_ticks = 45
	late.present(state,InputFrame.make(),.016)
	state.recovery_ticks = 44
	late.present(state,InputFrame.make(),.016)
	assert(late.position==state.position,"joining mid-recovery never freezes an uninitialized pose at world zero")
	var camera := ChaseCamera.new()
	scene.add_child(camera)
	state = VehicleState.new()
	state.position.y = .35
	camera.follow(state,.06,true)
	assert(is_equal_approx(camera.look_blend,.5))
	camera.follow(state,.06,true)
	assert(is_equal_approx(camera.look_blend,1))
	camera.follow(state,.12,false)
	assert(is_zero_approx(camera.look_blend))
	camera.shake_scale = 1
	camera.impact()
	for index in range(10):
		camera.follow(state,.012)
		assert(Vector2(camera.h_offset,camera.v_offset).length()<=.025001)
	assert(camera.shake_remaining<.0001)
	camera.reduce_motion = true
	camera.impact()
	camera.follow(state,.016)
	assert(is_zero_approx(camera.h_offset) and is_zero_approx(camera.v_offset) and is_zero_approx(camera.shake_remaining))
	var wall := StaticBody3D.new()
	wall.collision_layer = 2
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20,6,.4)
	collision.shape = box
	wall.add_child(collision)
	wall.position = Vector3(0,2,3)
	scene.add_child(wall)
	await physics_frame
	await physics_frame
	camera.follow(state,.016)
	assert(camera.boom_fraction<.6,"the 0.25 m camera sphere shortens against camera-only scenery")
	assert(camera.position.z<2.6,"smoothed translation cannot keep the rendered camera behind the blocking wall")
	wall.queue_free()
	await physics_frame
	await physics_frame
	for index in range(6): camera.follow(state,.05)
	assert(is_equal_approx(camera.boom_fraction,1),"clear boom restores over 0.3 seconds")
	scene.queue_free()
	await process_frame
	print("CAR_CONTACT_OPACITY_FROZEN_RECOVERY_FADE_CAMERA_LOOKBACK_BOOM_SHAKE_CAPS_PASS")
	quit()

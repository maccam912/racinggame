class_name ChaseCamera
extends Camera3D

var mode: int = 0
var reduce_motion: bool = false
var dynamic_fov: bool = true
var base_fov: float = 65.0
var follow_yaw: float = 0.0
var steering_offset: float = 0.0
var initialized: bool = false
var sphere := SphereShape3D.new()
var look_blend: float = 0
var boom_fraction: float = 1
var shake_remaining: float = 0
var shake_scale: float = .5

func impact() -> void:
	if not reduce_motion and shake_scale>0: shake_remaining = .12


func follow(state: VehicleState, dt: float, look_back: bool = false) -> void:
	if not initialized:
		follow_yaw = state.yaw
	var difference := angle_difference(follow_yaw, state.yaw)
	follow_yaw += difference * (1.0 - exp(-8.0 * dt))
	if absf(angle_difference(follow_yaw, state.yaw)) > deg_to_rad(12):
		follow_yaw = state.yaw - signf(difference) * deg_to_rad(12)
	look_blend = move_toward(look_blend,1.0 if look_back else 0.0,dt/.12)
	var view_yaw := follow_yaw+PI*look_blend
	var forward := Vector3(sin(view_yaw), 0, -cos(view_yaw))
	var right := forward.cross(Vector3.UP)
	steering_offset = lerpf(steering_offset, state.steer_filter, 1.0 - exp(-4 * dt))
	var distance := 5.8 if mode == 0 else 8.2
	var height := 2.4 if mode == 0 else 3.4
	var target_position := state.position - forward * distance + Vector3.UP * (height - .35)
	var aim := state.position + forward * (10 if mode == 0 else 12) + Vector3.UP * .8 + right * steering_offset
	if mode == 2:
		target_position = state.position + forward * 1.1 + Vector3.UP * .80
		aim = target_position + forward * 20
	else:
		var start := state.position + Vector3.UP * 1.3
		sphere.radius = .25
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = sphere
		query.transform.origin = start
		query.motion = target_position - start
		query.collision_mask = 3 # Shared driving barriers plus render-only scenery camera bounds.
		var cast := get_world_3d().direct_space_state.cast_motion(query)
		var fraction := float(cast[0])
		boom_fraction = fraction if fraction<boom_fraction else move_toward(boom_fraction,fraction,dt/.3)
		target_position = start + query.motion * boom_fraction
	position = position.lerp(target_position, 1.0 - exp(-10 * dt)) if initialized else target_position
	if mode!=2:
		# Translation smoothing must not leave the camera behind a newly met wall.
		var query := PhysicsShapeQueryParameters3D.new()
		query.shape = sphere
		query.transform.origin = state.position+Vector3.UP*1.3
		query.motion = position-query.transform.origin
		query.collision_mask = 3
		var safe := get_world_3d().direct_space_state.cast_motion(query)
		position = query.transform.origin+query.motion*safe[0]
	position.y = maxf(position.y, state.position.y + .5)
	look_at(aim, Vector3.UP)
	h_offset = 0
	v_offset = 0
	if reduce_motion: shake_remaining = 0
	if shake_remaining>0:
		var t := .12-shake_remaining
		var offset := Vector2(sin(t*119),sin(t*173)).limit_length(1)*.025*shake_scale*shake_remaining/.12
		h_offset = offset.x
		v_offset = offset.y
		rotate_object_local(Vector3.FORWARD,deg_to_rad(.4)*shake_scale*sin(t*143)*shake_remaining/.12)
		shake_remaining = maxf(0,shake_remaining-dt)
	keep_aspect = Camera3D.KEEP_HEIGHT
	fov = base_fov + (8 * clampf((state.speed() - 15) / 40, 0, 1) if dynamic_fov and not reduce_motion else 0)
	near = .15
	initialized = true

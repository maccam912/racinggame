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


func follow(state: VehicleState, dt: float, look_back: bool = false) -> void:
	if not initialized:
		follow_yaw = state.yaw
	var difference := angle_difference(follow_yaw, state.yaw)
	follow_yaw += difference * (1.0 - exp(-8.0 * dt))
	if absf(angle_difference(follow_yaw, state.yaw)) > deg_to_rad(12):
		follow_yaw = state.yaw - signf(difference) * deg_to_rad(12)
	var forward := Vector3(sin(follow_yaw), 0, -cos(follow_yaw))
	if look_back:
		forward = -forward
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
		target_position = start + query.motion * cast[0]
	position = position.lerp(target_position, 1.0 - exp(-10 * dt)) if initialized else target_position
	position.y = maxf(position.y, state.position.y + .5)
	look_at(aim, Vector3.UP)
	keep_aspect = Camera3D.KEEP_HEIGHT
	fov = base_fov + (8 * clampf((state.speed() - 15) / 40, 0, 1) if dynamic_fov and not reduce_motion else 0)
	near = .15
	initialized = true

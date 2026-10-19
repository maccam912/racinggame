class_name WorldQuery
extends RefCounted
## Static-world adapter injected into VehicleSim, one instance per car.

var world: World3D
var track: TrackDefinition
var hint: int = 0
var shape := ConvexPolygonShape3D.new()
var body: RID


func _init(space: World3D, route: TrackDefinition, starting_s: float = 0.0) -> void:
	world = space
	track = route
	hint = track.sample_index(starting_s)
	var points := PackedVector3Array()
	for y: float in [0.0, 1.1]:
		for corner: Vector2 in [Vector2(.7, 1.85), Vector2(-.7, 1.85), Vector2(-.7, -1.85), Vector2(.7, -1.85)]:
			for angle in range(0, 360, 30):
				var radians := deg_to_rad(angle)
				points.append(Vector3(corner.x + cos(radians) * .25, y, corner.y + sin(radians) * .25))
	shape.points = points
	body = PhysicsServer3D.body_create()
	PhysicsServer3D.body_set_mode(body, PhysicsServer3D.BODY_MODE_KINEMATIC)
	PhysicsServer3D.body_set_space(body, world.space)
	PhysicsServer3D.body_add_shape(body, shape.get_rid())
	PhysicsServer3D.body_set_collision_layer(body, 0)
	PhysicsServer3D.body_set_collision_mask(body, 1)


func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE and body.is_valid():
		PhysicsServer3D.free_rid(body)


func nearest(position: Vector3) -> Dictionary:
	var best := INF
	var result: Dictionary = {}
	for offset in range(-40, 41):
		var i := posmod(hint + offset, track.points.size())
		var j := (i + 1) % track.points.size()
		var a := track.points[i]
		var ab := track.points[j] - a
		var fraction := clampf((position - a).dot(ab) / ab.length_squared(), 0, 1)
		var point := a + ab * fraction
		var distance := Vector2(position.x - point.x, position.z - point.z).length_squared()
		if distance < best:
			best = distance
			result = {"i": i, "lateral": (position - point).dot(track.forwards[i].cross(Vector3.UP)), "s": track.distances[i] + fraction * ab.length()}
	hint = result.i
	return result


func ground(state: VehicleState) -> Dictionary:
	var supported := 0
	var height := 0.0
	var normal := Vector3.ZERO
	var basis := Basis(Vector3.UP, -state.yaw)
	for x: float in [-.75, .75]:
		for z: float in [-1.35, 1.35]:
			var origin := state.position + basis * Vector3(x, .8, z)
			var ray := PhysicsRayQueryParameters3D.create(origin, origin + Vector3.DOWN * 2.5, 1)
			var hit := world.direct_space_state.intersect_ray(ray)
			if not hit.is_empty() and hit.normal.dot(Vector3.UP) >= cos(deg_to_rad(50)) and state.position.y - (hit.position.y + .35) <= .65:
				supported += 1
				height += hit.position.y
				normal += hit.normal
	var route := nearest(state.position)
	var surface: String = "asphalt" if absf(route.lateral) <= float(track.bake.samples[hint][8]) / 2 else track.definition.surface
	return {"supported": supported >= 2, "height": height / maxf(supported, 1), "normal": normal.normalized() if supported else Vector3.UP, "surface": surface, "lateral": route.lateral, "s": route.s}


func sweep(position: Vector3, velocity: Vector3, yaw: float, dt: float, new_impact: bool) -> Dictionary:
	var current := position
	var motion := velocity * dt
	var output_velocity := velocity
	var hit_any := false
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.collision_mask = 1
	for iteration in range(4):
		if motion.length_squared() < .0000001:
			break
		var parameters := PhysicsTestMotionParameters3D.new()
		parameters.from = Transform3D(Basis(Vector3.UP, -yaw), current)
		parameters.motion = motion
		parameters.margin = .005
		parameters.recovery_as_collision = true
		var collision := PhysicsTestMotionResult3D.new()
		if not PhysicsServer3D.body_test_motion(body, parameters, collision):
			current += motion
			break
		current += collision.get_travel()
		var normal := collision.get_collision_normal()
		# Ground is resolved by probes, not treated as a wall impact.
		if normal.y > .64:
			motion = collision.get_remainder().slide(normal)
			continue
		hit_any = true
		output_velocity = output_velocity.slide(normal)
		if new_impact:
			output_velocity *= .96
			new_impact = false
		else:
			output_velocity = output_velocity.move_toward(Vector3.ZERO, 2.0 * dt)
		motion = collision.get_remainder().slide(normal)
	query.transform = Transform3D(Basis(Vector3.UP, -yaw), current)
	query.motion = Vector3.ZERO
	query.margin = .2
	var nearby := world.direct_space_state.intersect_shape(query, 1)
	return {"position": current, "velocity": output_velocity, "hit": hit_any, "separated": nearby.is_empty()}

class_name VehicleSim
extends RefCounted
## Shared 60 Hz kinematic rules. No scene tree, input devices, rendering, or network.

const DT: float = 1.0 / 60.0
const BOOST_TICKS: int = 120
const BOOST_ACCELERATION: float = 14.0
const BOOST_SPEED_FACTOR: float = 1.14
const DRIFT_STEER_ENTRY: float = 0.90
const DRIFT_STEER_HOLD: float = 0.75
const CORNER_GRIP_MULTIPLIER: float = 2.0
const FULL_LOCK_TURN_MULTIPLIER: float = 2.0
const LEADER_SPEED_FACTOR: float = .95
const CHASER_ROADSIDE_FACTOR: float = .35


static func step(state: VehicleState, frame: InputFrame, car: CarDefinition, query: Variant) -> void:
	state.events.clear()
	state.contact_ticks = maxi(0, state.contact_ticks - 1)
	state.last_ack = frame.sequence
	state.ghost_ticks = maxi(0, state.ghost_ticks - 1)
	state.braking = frame.brake > .1 or frame.handbrake
	var boost_pressed := frame.boost and state.boost_latched == 0
	state.boost_latched = int(frame.boost)
	# A burst uses one charge on a fresh press; held input never spends another.
	# Recovery cancels the burst without refunding it. Laps never refill charges.
	if state.recovery_ticks > 0:
		state.boost_ticks = 0
		state.recovery_ticks -= 1
		state.velocity = Vector3.ZERO
		if state.recovery_ticks == 0:
			state.velocity = state.forward().slide(state.ground_normal).normalized() * state.recovery_speed
			state.recovery_speed = 0.0
		return
	if boost_pressed and car.boost_charges > 0 and state.boost_charges > 0 and state.boost_ticks == 0 and state.grounded and not state.reversing and frame.brake == 0 and not frame.handbrake and not state.finished and state.dnf_reason == "":
		state.boost_charges -= 1
		state.boost_ticks = BOOST_TICKS
	var boosting := state.boost_ticks > 0 and car.boost_charges > 0
	state.boost_ticks = maxi(0, state.boost_ticks - 1)
	var old_grounded := state.grounded
	var pace := LEADER_SPEED_FACTOR if state.race_role == 1 else 1.0
	var roadside := CHASER_ROADSIDE_FACTOR if state.race_role == 2 else 1.0
	var ground: Dictionary = query.ground(state)
	# Landing is relative to the supported plane. A car following an uphill
	# road can move upward in world space while descending toward the road.
	state.grounded = ground.supported and state.launch_ticks == 0 and (old_grounded or state.velocity.dot(ground.normal) <= 1.0)
	state.launch_ticks = maxi(0, state.launch_ticks - 1)
	state.ground_normal = ground.normal if state.grounded else Vector3.UP
	state.surface = ground.surface
	var filter_rate := 5.0 if signf(frame.steer) == signf(state.steer_filter) and absf(frame.steer) > absf(state.steer_filter) else 7.0
	state.steer_filter = move_toward(state.steer_filter, frame.steer, filter_rate * DT)
	var forward := state.forward().slide(state.ground_normal).normalized()
	var vf := state.velocity.dot(forward)
	var grip_factor := 1.0
	var yaw_factor := 1.0
	# Full lock breaks traction without requiring the handbrake. A lower hold
	# threshold keeps small stick/touch changes from repeatedly grabbing grip;
	# releasing or countersteering starts the existing smooth recovery.
	var steer_threshold := DRIFT_STEER_HOLD if state.drift_phase == 1 else DRIFT_STEER_ENTRY
	var steering_slide := absf(frame.steer) >= steer_threshold and absf(state.steer_filter) >= steer_threshold and signf(frame.steer) == signf(state.steer_filter)
	var handbrake_slide := frame.handbrake and absf(state.steer_filter) > 0.25
	if state.grounded and vf > 15.0 and (steering_slide or handbrake_slide):
		state.drift_entry = minf(.1, state.drift_entry + DT)
		if state.drift_entry >= 0.10 - 0.00001:
			state.drift_phase = 1
			state.drift_timer = 0.0
	else:
		state.drift_entry = 0.0
		if state.drift_phase == 1:
			state.drift_phase = 2
			state.drift_timer = 0.0
	if state.drift_phase == 1:
		grip_factor = 0.45
		yaw_factor = 1.20
	elif state.drift_phase == 2:
		state.drift_timer = minf(0.4, state.drift_timer + DT)
		grip_factor = lerpf(0.45, 1.0, state.drift_timer / 0.4)
		yaw_factor = lerpf(1.20, 1.0, state.drift_timer / 0.4)
		if state.drift_timer >= 0.4 - 0.00001:
			state.drift_phase = 0
	# Add authority progressively near full lock at road speed. Small corrections
	# and parking keep their response; doubled grip lets the travel direction
	# follow the tighter arc while the existing drift still breaks traction.
	var full_lock := smoothstep(0.5, 1.0, absf(state.steer_filter)) * smoothstep(15.0, 40.0, absf(vf)) if state.grounded else 0.0
	var turn_multiplier := lerpf(1.0, FULL_LOCK_TURN_MULTIPLIER, full_lock)
	var target_yaw := state.steer_filter * car.turn_factor * lerpf(100.0, 35.0, clampf(absf(vf) / 55.0, 0.0, 1.0)) * clampf(absf(vf) / 5.0, 0.0, 1.0) * yaw_factor * turn_multiplier
	if state.grounded and state.drift_phase != 0 and vf > 0.0:
		var sideways := state.velocity.dot(forward.cross(state.ground_normal))
		# Ease rotation into a growing slide so full lock settles into an arc.
		# Opposite steering keeps its full authority to catch the rear end.
		var into_slide := -signf(state.steer_filter) * atan2(sideways, vf)
		target_yaw *= lerpf(1.0, 0.10, smoothstep(deg_to_rad(10.0), deg_to_rad(30.0), into_slide))
	if vf < -0.1:
		target_yaw = -target_yaw
	if not state.grounded:
		target_yaw *= 0.2
	state.yaw_rate = move_toward(state.yaw_rate, deg_to_rad(target_yaw), deg_to_rad(240) * DT)
	state.yaw = wrapf(state.yaw + state.yaw_rate * DT, -PI, PI)
	forward = state.forward().slide(state.ground_normal).normalized()
	var right := forward.cross(state.ground_normal).normalized()
	vf = state.velocity.dot(forward)
	var lateral := state.velocity.dot(right)
	if state.grounded:
		if not old_grounded:
			vf *= 0.97
			state.events.append("land")
		state.position.y = maxf(ground.height + 0.35, state.position.y - 0.4)
		var braking := frame.brake > 0.0
		if absf(vf) < 0.5 and braking:
			state.reverse_hold = minf(.35, state.reverse_hold + DT)
			if state.reverse_hold >= 0.35 - 0.00001:
				state.reversing = true
		else:
			state.reverse_hold = 0.0
		if state.reversing:
			if frame.throttle > 0.0:
				vf = move_toward(vf, 0.0, 14.0 * frame.throttle * DT)
				if vf >= -0.001:
					state.reversing = false
			elif braking:
				vf = maxf(-8.0, vf - 7.0 * frame.brake * DT)
			else:
				vf = move_toward(vf, 0.0, 0.3 * DT)
		elif vf < -0.1:
			vf = move_toward(vf, 0.0, (14.0 * frame.throttle + 0.3) * DT)
		else:
			var throttle := frame.throttle if not braking else 0.0
			var top_speed := car.top_speed * pace * (BOOST_SPEED_FACTOR if boosting else 1.0)
			var acceleration := car.acceleration * throttle * maxf(0.0, 1.0 - pow(maxf(vf, 0.0) / top_speed, 2)) - 18.0 * frame.brake
			if boosting: acceleration += BOOST_ACCELERATION * throttle
			if vf > 0.0:
				acceleration -= 0.30 + 0.00010 * vf * absf(vf)
			if frame.handbrake:
				acceleration -= 3.0 if state.drift_phase == 1 else 10.0 if vf <= 15.0 else 0.0
			if vf > top_speed:
				acceleration -= 6.0
			var extra_drag := 1.2 if state.surface == "dirt" else 5.0 if state.surface == "sand" else 6.0 if state.surface == "grass" else 0.0
			if vf > 12.0:
				acceleration -= extra_drag * roadside
			vf = maxf(0.0, vf + acceleration * DT)
			vf += Vector3.DOWN.dot(forward) * 9.81 * 0.4 * DT
			vf = minf(vf, car.top_speed * pace * (BOOST_SPEED_FACTOR if car.boost_charges > 0 else 1.08))
		var surface_grip := 0.78 if state.surface == "dirt" else 0.65 if state.surface == "sand" else 0.70 if state.surface == "grass" else 1.0
		lateral = move_toward(lateral, 0.0, car.grip * CORNER_GRIP_MULTIPLIER * surface_grip * grip_factor * DT)
		state.velocity = forward * vf + right * lateral
	else:
		state.velocity += forward * car.acceleration * frame.throttle * 0.15 * DT
		state.velocity.y -= 22.0 * DT
	var result: Dictionary = query.sweep(state.position, state.velocity, state.yaw, DT, not state.wall_contact, roadside) if query is WorldQuery else query.sweep(state.position, state.velocity, state.yaw, DT, not state.wall_contact)
	state.position = result.position
	state.velocity = result.velocity
	if result.hit:
		if not state.wall_contact:
			state.events.append("wall")
		state.wall_contact = true
		state.wall_separation_ticks = 0
	elif result.separated:
		state.wall_separation_ticks += 1
		if state.wall_separation_ticks >= 12:
			state.wall_contact = false

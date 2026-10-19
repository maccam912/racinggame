class_name VehicleSim
extends RefCounted
## Shared 60 Hz kinematic rules. No scene tree, input devices, rendering, or network.

const DT: float = 1.0 / 60.0


static func step(state: VehicleState, frame: InputFrame, car: CarDefinition, query: Variant) -> void:
	state.events.clear()
	state.contact_ticks = maxi(0, state.contact_ticks - 1)
	state.last_ack = frame.sequence
	state.ghost_ticks = maxi(0, state.ghost_ticks - 1)
	if state.recovery_ticks > 0:
		state.recovery_ticks -= 1
		state.velocity = Vector3.ZERO
		return
	var old_grounded := state.grounded
	var ground: Dictionary = query.ground(state)
	state.grounded = ground.supported and state.launch_ticks == 0 and (old_grounded or state.velocity.y <= 1.0)
	state.launch_ticks = maxi(0, state.launch_ticks - 1)
	state.ground_normal = ground.normal if state.grounded else Vector3.UP
	state.surface = ground.surface
	var filter_rate := 5.0 if signf(frame.steer) == signf(state.steer_filter) and absf(frame.steer) > absf(state.steer_filter) else 7.0
	state.steer_filter = move_toward(state.steer_filter, frame.steer, filter_rate * DT)
	var forward := state.forward().slide(state.ground_normal).normalized()
	var vf := state.velocity.dot(forward)
	var grip_factor := 1.0
	var yaw_factor := 1.0
	if frame.handbrake and vf > 15.0 and absf(state.steer_filter) > 0.25:
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
	var target_yaw := state.steer_filter * car.turn_factor * lerpf(100.0, 35.0, clampf(absf(vf) / 55.0, 0.0, 1.0)) * clampf(absf(vf) / 5.0, 0.0, 1.0) * yaw_factor
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
			var acceleration := car.acceleration * throttle * maxf(0.0, 1.0 - pow(maxf(vf, 0.0) / car.top_speed, 2)) - 18.0 * frame.brake
			if vf > 0.0:
				acceleration -= 0.30 + 0.00010 * vf * absf(vf)
			if frame.handbrake:
				acceleration -= 3.0 if state.drift_phase == 1 else 10.0 if vf <= 15.0 else 0.0
			if vf > car.top_speed:
				acceleration -= 6.0
			var extra_drag := 5.0 if state.surface == "sand" else 6.0 if state.surface == "grass" else 0.0
			if vf > 12.0:
				acceleration -= extra_drag
			vf = maxf(0.0, vf + acceleration * DT)
			vf += Vector3.DOWN.dot(forward) * 9.81 * 0.4 * DT
			vf = minf(vf, car.top_speed * 1.08)
		var surface_grip := 0.65 if state.surface == "sand" else 0.70 if state.surface == "grass" else 1.0
		lateral = move_toward(lateral, 0.0, car.grip * surface_grip * grip_factor * DT)
		state.velocity = forward * vf + right * lateral
	else:
		state.velocity += forward * car.acceleration * frame.throttle * 0.15 * DT
		state.velocity.y -= 22.0 * DT
	var result: Dictionary = query.sweep(state.position, state.velocity, state.yaw, DT, not state.wall_contact)
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

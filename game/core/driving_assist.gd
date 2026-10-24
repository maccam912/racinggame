class_name DrivingAssist
extends RefCounted
## A bounded steering nudge, shared by authority and local input prediction.
## No corner-following planner: players still supply the steering for bends.

static func apply(state: VehicleState, frame: InputFrame, query: WorldQuery, level: int) -> InputFrame:
	if level <= 0 or state.finished or state.dnf_reason != "" or state.recovery_ticks > 0 or not state.grounded or state.reversing or frame.handbrake or state.velocity.dot(state.forward()) < 5.0:
		return frame
	var nearest := query.nearest(state.position)
	var forward := query.track.forwards[int(nearest.i)]
	var right := forward.cross(Vector3.UP).normalized()
	# A weak centering spring, damped by sideways travel and yaw, catches the
	# overshoot that otherwise encourages repeated left/right overcorrection.
	var heading := atan2(state.forward().x * forward.z - state.forward().z * forward.x, state.forward().x * forward.x + state.forward().z * forward.z)
	if absf(heading) > PI / 2: return frame # Preserve deliberate turning/reversing.
	var center := clampf(-float(nearest.lateral) / 20.0 - state.velocity.dot(right) / 25.0, -.35, .35)
	var limit := .12 if level == 1 else .24
	var nudge := clampf((heading + center) * .7 - state.yaw_rate * .12, -limit, limit) * smoothstep(5.0, 15.0, state.speed())
	var assisted := InputFrame.make(frame.steer + nudge, frame.throttle, frame.brake, frame.handbrake)
	assisted.sequence = frame.sequence
	assisted.tick = frame.tick
	assisted.recover = frame.recover
	assisted.boost = frame.boost
	return assisted

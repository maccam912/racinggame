class_name CornerAssist
extends RefCounted
## Optional braking help shared by local driving and online prediction. Uses the canonical braking line, never steers.

static func apply(state: VehicleState, frame: InputFrame, car: CarDefinition, query: WorldQuery) -> InputFrame:
	if state.finished or state.dnf_reason != "" or state.recovery_ticks > 0 or not state.grounded or state.reversing or frame.handbrake or frame.recover or frame.boost or state.boost_ticks > 0:
		return frame
	if state.velocity.dot(state.forward()) < 5.0: return frame
	var nearest := query.nearest(state.position)
	var forward := query.track.forwards[int(nearest.i)]
	if state.forward().dot(forward) < .5 or absf(float(nearest.lateral)) > float(query.track.bake.samples[int(nearest.i)][8])/2+4:
		return frame
	var speed := state.velocity.dot(state.forward())
	var safe := float(query.track.bake.ai_speeds[car.id][int(nearest.i)])
	if safe >= car.top_speed*.94: return frame
	# Technical roads need more margin for closely spaced direction changes.
	var target := safe*(.90 if query.track.smooth_road() else .80)
	var excess := speed-target
	if excess <= 1.0: return frame
	var assisted := InputFrame.make(frame.steer,frame.throttle*clampf(1.0-excess/4.0,0,1),maxf(frame.brake,clampf((excess-2.0)/8.0,0,.65)),frame.handbrake)
	assisted.sequence = frame.sequence
	assisted.tick = frame.tick
	assisted.recover = frame.recover
	assisted.boost = frame.boost
	return assisted

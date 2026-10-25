class_name BotDriver
extends RefCounted
## Canonical centerline controller; also drives repeatable network fixtures.
const TRAFFIC_PLANE_HEIGHT_M := 2.5
const EXPERT := 3

var planning_ticks: int = 0
var previous := InputFrame.make()
var difficulty: int = 1
var offset: float = 0.0
var stuck_ticks: int = 0
var recover_hold_ticks: int = 0


func sample(state: VehicleState, car: CarDefinition, track: TrackDefinition, query: WorldQuery, others: Array[VehicleState] = [], pace: float = 1.0) -> InputFrame:
	if state.recovery_ticks > 0:
		stuck_ticks = 0
		recover_hold_ticks = 0
		planning_ticks = 0
		previous = InputFrame.make()
		return previous
	if recover_hold_ticks > 0:
		recover_hold_ticks -= 1
		var recovery := InputFrame.make()
		recovery.recover = true
		return recovery
	if state.speed() < 2 and previous.throttle > .7:
		stuck_ticks += 1
	else:
		stuck_ticks = 0
	if stuck_ticks >= 240:
		stuck_ticks = 0
		recover_hold_ticks = 30
		var recovery := InputFrame.make()
		recovery.recover = true
		return recovery
	planning_ticks -= 1
	if planning_ticks > 0:
		return previous
	planning_ticks = [12, 6, 3, 1][clampi(difficulty, 0, EXPERT)]
	var nearest := query.nearest(state.position)
	var target_s: float = nearest.s + clampf(8 + .45 * state.speed(), 12, 35)
	var safe_speed: float = track.bake.ai_speeds[car.id][nearest.i]
	var target_speed: float = minf(safe_speed, safe_speed * [.78, .90, 1.0, 1.0][clampi(difficulty, 0, EXPERT)] * pace)
	if difficulty == EXPERT:
		target_speed = expert_speed(car, track, float(nearest.s), pace)
		target_s = float(nearest.s) + clampf(6 + .30 * state.speed(), 10, 28)
	if state.finished:
		target_speed *= .6
	var boost_clear := car.boost_charges > 0 and not state.finished and state.grounded and absf(float(nearest.lateral)) < 1.5 and absf(state.steer_filter) < .10
	if boost_clear:
		for ahead in range(0,401,10):
			var i := track.sample_index(float(nearest.s)+ahead)
			if float(track.bake.ai_speeds[car.id][i]) < car.top_speed*.94 or absf(track.forwards[i].y) > .03 or float(track.bake.samples[i][10]) > .01:
				boost_clear = false
				break
		for rival: VehicleState in others:
			if rival == state: continue
			var delta := rival.position-state.position
			if delta.dot(state.forward()) > 0 and delta.length() < 160: boost_clear = false
	if boost_clear and state.boost_ticks > 0: target_speed = car.top_speed*VehicleSim.BOOST_SPEED_FACTOR
	var passing := passing_plan(state,nearest,track,others,target_speed)
	target_speed = passing.speed
	offset = move_toward(offset,float(passing.offset),2*planning_ticks/60.0)
	var target := track.pose(target_s, offset).origin - state.position
	var forward := state.forward()
	var error := atan2(forward.x * target.z - forward.z * target.x, forward.x * target.x + forward.z * target.z)
	previous = InputFrame.make(clampf(rad_to_deg(error) / 30, -1, 1), clampf((target_speed - state.speed()) / 6, 0, 1), clampf((state.speed() - target_speed) / 6, 0, 1))
	if difficulty == EXPERT:
		# Aim the travel direction into the corner; catch a developing slide
		# with countersteer instead of continuing to wind on steering lock.
		var sideways := state.velocity.dot(forward.cross(Vector3.UP))
		previous.steer = clampf(rad_to_deg(error) / 22.0 + sideways * .035, -1, 1)
		var bend: float = track.bake.samples[track.sample_index(float(nearest.s)+12)][6]
		var sliding := state.drift_phase == 1
		previous.handbrake = state.grounded and state.speed() > 22 and state.speed() < 55 and absf(bend) > .009 and absf(float(nearest.lateral)) < 1.4 and absf(sideways) < (6.0 if sliding else 3.0) and absf(previous.steer) > .35 and signf(previous.steer) == signf(bend) and others.all(func(rival: VehicleState) -> bool: return rival == state or rival.position.distance_to(state.position) > 12)
	previous.boost = boost_clear and state.boost_charges > 0 and state.boost_ticks == 0 and state.boost_latched == 0 and state.speed() > car.top_speed*.65
	return previous

func passing_plan(state: VehicleState, nearest: Dictionary, track: TrackDefinition, others: Array[VehicleState], target_speed: float) -> Dictionary:
	var lead: VehicleState
	var lead_ahead: float = INF
	var forward := state.forward()
	var right := track.forwards[int(nearest.i)].cross(Vector3.UP).normalized()
	var normal := traffic_normal(track,int(nearest.i))
	for rival: VehicleState in others:
		if rival==state or rival.finished or rival.dnf_reason!="": continue
		var delta := rival.position-state.position
		if absf(delta.dot(normal))>TRAFFIC_PLANE_HEIGHT_M: continue
		var ahead := delta.dot(forward)
		if ahead<=0 or ahead>=25 or absf(delta.dot(forward.cross(Vector3.UP)))>=3: continue
		if ahead<lead_ahead-.01 or absf(ahead-lead_ahead)<=.01 and (lead==null or rival.slot<lead.slot):
			lead = rival
			lead_ahead = ahead
	if lead==null: return {"offset":0.0,"speed":target_speed}
	var half_width: float = float(track.bake.samples[int(nearest.i)][8])/2
	var lead_lateral: float = float(nearest.lateral)+(lead.position-state.position).dot(right)
	var clearance := {-1:half_width+lead_lateral,1:half_width-lead_lateral}
	var available: Array[int] = []
	for side: int in [-1,1]:
		var candidate := side*3.0
		if half_width-absf(candidate)<2.5: continue
		var blocked := false
		for rival: VehicleState in others:
			if rival==state or rival.finished or rival.dnf_reason!="": continue
			var delta := rival.position-state.position
			if absf(delta.dot(normal))>TRAFFIC_PLANE_HEIGHT_M: continue
			var ahead := delta.dot(forward)
			if ahead>=-5 and ahead<25 and absf(candidate-float(nearest.lateral)-delta.dot(right))<2.5:
				blocked = true
				break
		if not blocked: available.append(side)
	if available.is_empty(): return {"offset":0.0,"speed":minf(target_speed,maxf(0,lead.speed()-1))}
	var side: int = available[0]
	if available.size()==2:
		side = -1 if float(clearance[-1])>float(clearance[1])+.01 else 1 if float(clearance[1])>float(clearance[-1])+.01 else (-1 if state.slot%2==0 else 1)
	return {"offset":side*3.0,"speed":target_speed}


static func traffic_normal(track: TrackDefinition, index: int) -> Vector3:
	# Use the collision surface so grade, banking and baked launch ramps count.
	# Absolute world Y would wrongly ignore real traffic on a steep climb.
	var center := RouteGeometry.point(track,index,0)
	var across := RouteGeometry.point(track,index,1)-center
	var along := RouteGeometry.point(track,(index+1)%track.points.size(),0)-center
	return across.cross(along).normalized()


func expert_speed(car: CarDefinition, track: TrackDefinition, s: float, pace: float) -> float:
	# The legacy line reserves most of the available grip. Expert uses more of
	# it, but still brakes for the next corner and respects ramps and grades.
	var target := car.top_speed * .99
	var multiplier := clampf(1.42 * pace, 1.18, 1.55)
	for ahead in range(0, 161, 10):
		var i := track.sample_index(s + ahead)
		var safe: float = track.bake.ai_speeds[car.id][i]
		var rough := absf(track.forwards[i].y) > .12 or float(track.bake.samples[i][10]) > .01
		var limit := minf(car.top_speed * .99, safe * (1.0 if rough else multiplier))
		target = minf(target, sqrt(limit * limit + 24.0 * ahead))
	return target

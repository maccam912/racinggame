extends "res://tests/lobby_network_client.gd"
## Exercise clear road as well as traffic, using shipped AI planning and only
## ordinary client snapshots. No authority mutation or physics/stat changes.

var launch_hold_ticks: int = 0
var drive_trace_at: int = 0
const PACE := [1.0,.96,.985,.945,.97,.955,.93,.995]


func launch_plan(track: TrackDefinition) -> Array[Dictionary]:
	# Public car/course data estimates a release order; no authority positions.
	# Faster cars leave first so slower leaders do not form a whole-race platoon.
	var order: Array[Dictionary] = []
	for racer in range(8):
		var speeds: Array = track.bake.ai_speeds[Catalog.cars[racer%4].id]
		var estimate := 0.0
		for sample in range(track.points.size()):
			var next := (sample+1)%track.points.size()
			estimate += track.points[sample].distance_to(track.points[next])/maxf(1,float(speeds[sample])*.9*float(PACE[racer]))
		order.append({"index":racer,"estimated_line_seconds":estimate})
	order.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.estimated_line_seconds<b.estimated_line_seconds if absf(a.estimated_line_seconds-b.estimated_line_seconds)>.001 else a.index<b.index)
	for rank in range(order.size()): order[rank]["hold_ticks"] = rank*60
	return order

class PacedDriver extends BotDriver:
	var pace: float = 1.0
	func passing_plan(state: VehicleState, nearest: Dictionary, track: TrackDefinition, others: Array[VehicleState], target_speed: float) -> Dictionary:
		return super.passing_plan(state, nearest, track, others, target_speed * pace)

func start_race(config: Dictionary) -> void:
	super.start_race(config)
	var paced := PacedDriver.new()
	paced.pace = PACE[index]
	bot = paced
	# Ordinary brake-only holds after GO; unchanged physics and finish grace.
	var releases := launch_plan(link.prediction.track)
	for release: Dictionary in releases:
		if release.index==index: launch_hold_ticks = release.hold_ticks
	print("SOAK_LAUNCH_PLAN "+JSON.stringify({"race":link.race_id,"track":link.prediction.track.id,"index":index,"hold_ticks":launch_hold_ticks,"order":releases}))
	link.input_provider = func() -> InputFrame:
		if launch_hold_ticks > 0:
			launch_hold_ticks -= 1
			return InputFrame.make(0, 0, 1)
		var rivals: Array[VehicleState] = []
		if bot.planning_ticks <= 1:
			for state: VehicleState in link.latest_snapshot.get("states", []):
				if state.slot != link.slot: rivals.append(state)
		var frame := bot.sample(link.prediction.state, link.prediction.car, link.prediction.track, link.prediction.query, rivals)
		if "--trace-driving" in OS.get_cmdline_user_args() and Time.get_ticks_msec()>=drive_trace_at:
			drive_trace_at = Time.get_ticks_msec()+5000
			var state: VehicleState = link.prediction.state
			var others: Array = []
			for rival: VehicleState in link.latest_snapshot.get("states",[]):
				if rival.slot!=link.slot and rival.position.distance_to(state.position)<60:
					others.append({"slot":rival.slot,"delta":[rival.position.x-state.position.x,rival.position.y-state.position.y,rival.position.z-state.position.z],"speed":rival.speed(),"finished":rival.finished})
			print("DRIVE_TRACE "+JSON.stringify({"index":index,"race":link.race_id,"slot":link.slot,"s":state.route_s,"position":[state.position.x,state.position.y,state.position.z],"speed":state.speed(),"steer":frame.steer,"throttle":frame.throttle,"brake":frame.brake,"offset":bot.offset,"others":others}))
		return frame

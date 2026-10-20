extends "res://tests/lobby_network_client.gd"
## Exercise clear road as well as traffic, using shipped AI planning and only
## ordinary client snapshots. No authority mutation or physics/stat changes.

var launch_hold_ticks: int = 0

class PacedDriver extends BotDriver:
	var pace: float = 1.0
	func passing_plan(state: VehicleState, nearest: Dictionary, track: TrackDefinition, others: Array[VehicleState], target_speed: float) -> Dictionary:
		return super.passing_plan(state, nearest, track, others, target_speed * pace)

func start_race(config: Dictionary) -> void:
	super.start_race(config)
	var paced := PacedDriver.new()
	paced.pace = [1.0,.96,.985,.945,.97,.955,.93,.995][index]
	bot = paced
	# The input provider runs only after GO. Half-second start offsets give the
	# correction population genuine moving clear road without teleporting cars,
	# weakening the 500-sample gate or extending the ordinary finish grace.
	launch_hold_ticks = index * 30
	link.input_provider = func() -> InputFrame:
		if launch_hold_ticks > 0:
			launch_hold_ticks -= 1
			return InputFrame.make(0, 0, 1)
		var rivals: Array[VehicleState] = []
		if bot.planning_ticks <= 1:
			for state: VehicleState in link.latest_snapshot.get("states", []):
				if state.slot != link.slot: rivals.append(state)
		return bot.sample(link.prediction.state, link.prediction.car, link.prediction.track, link.prediction.query, rivals)

extends "res://tests/lobby_network_client.gd"
## Exercise clear road as well as traffic, using shipped AI planning and only
## ordinary client snapshots. No authority mutation or physics/stat changes.

class PacedDriver extends BotDriver:
	var pace: float = 1.0
	func passing_plan(state: VehicleState, nearest: Dictionary, track: TrackDefinition, others: Array[VehicleState], target_speed: float) -> Dictionary:
		return super.passing_plan(state, nearest, track, others, target_speed * pace)

func start_race(config: Dictionary) -> void:
	super.start_race(config)
	var paced := PacedDriver.new()
	paced.pace = [1.0,.91,1.04,.94,.88,.97,.85,1.01][index]
	bot = paced
	link.input_provider = func() -> InputFrame:
		var rivals: Array[VehicleState] = []
		if bot.planning_ticks <= 1:
			for state: VehicleState in link.latest_snapshot.get("states", []):
				if state.slot != link.slot: rivals.append(state)
		return bot.sample(link.prediction.state, link.prediction.car, link.prediction.track, link.prediction.query, rivals)

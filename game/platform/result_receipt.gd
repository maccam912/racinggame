class_name ResultReceipt
extends RefCounted
## Freeze a completed result before the live scene or online lobby moves on.
## Commit retries use these exact rows, UUID and ghost samples.

var session := RaceSession.new()
var samples: Array[Dictionary] = []
var order: Array[int] = []
var summary: Dictionary = {"saved":false,"new_best":false}
var dismissed: bool = false

static func capture(source: RaceSession, ghost_samples: Array[Dictionary], official_rows: Array = []) -> ResultReceipt:
	var receipt := ResultReceipt.new()
	for key: String in ["race_id","race_uuid","event_uuid","mode","cup_event","human_slot","seed","lap_count","elapsed_ticks"]:
		receipt.session.set(key,source.get(key))
	receipt.session.track = source.track
	receipt.session.phase = RaceSession.Phase.RESULTS
	receipt.session.roster = source.roster.duplicate(true)
	receipt.session.cars.assign(source.cars)
	for state: VehicleState in source.states:
		receipt.session.states.append(state.copy())
	receipt.samples.assign(ghost_samples.duplicate(true))
	if source.mode=="online":
		for row: Dictionary in official_rows:
			receipt.order.append(int(row.slot))
	if receipt.order.is_empty():
		for state: VehicleState in receipt.session.standings():
			receipt.order.append(state.slot)
	return receipt

func commit(data: AppData) -> Dictionary:
	if session.mode=="cup" and data.commit_cup(session)!=OK:
		summary = {"saved":false,"new_best":false}
	else:
		summary = data.commit_result(session,samples)
	return summary

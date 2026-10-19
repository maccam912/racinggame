class_name SnapshotEvents
extends RefCounted
## Latch presentation flags over the three simulation steps between snapshots.
const ALLOWED: Array[String] = ["wall","bump","recovery","land"]
var pending: Dictionary = {}

func collect(session: RaceSession) -> void:
	if session.phase==RaceSession.Phase.RESULTS: return
	for state: VehicleState in session.states:
		if not state.dnf_reason.is_empty(): continue
		if not pending.has(state.slot): pending[state.slot] = []
		for event: String in state.events:
			if event in ALLOWED and not event in pending[state.slot]: pending[state.slot].append(event)

func encode(session: RaceSession, tick: int, hash_prefix: PackedByteArray) -> PackedByteArray:
	var view := RaceSession.new()
	view.race_id = session.race_id
	view.phase = session.phase
	view.elapsed_ticks = session.elapsed_ticks
	for state: VehicleState in session.states:
		var events: Array = pending.get(state.slot,[])
		if state.events==events: view.states.append(state)
		else:
			var copy := state.copy()
			copy.events.assign(events)
			view.states.append(copy)
	var packet := NetCodec.encode_snapshot(view,tick,hash_prefix)
	if not packet.is_empty(): pending.clear()
	return packet

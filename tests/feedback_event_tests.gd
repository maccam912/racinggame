extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	Catalog.load_all()
	var session := RaceSession.new()
	session.phase = RaceSession.Phase.RACING
	var a := VehicleState.new()
	var b := VehicleState.new()
	b.slot = 1
	session.states.assign([a,b])
	var latch := SnapshotEvents.new()
	a.events.assign(["wall"])
	latch.collect(session)
	a.events.assign(["land"])
	b.events.assign(["bump"])
	latch.collect(session)
	a.events.clear()
	b.events.clear()
	var hash_prefix := Compatibility.content_hash().hex_decode()
	var decoded := NetCodec.decode_snapshot(latch.encode(session,3,hash_prefix),session.race_id,hash_prefix)
	assert(decoded.states[0].events==["wall","land"] and decoded.states[1].events==["bump"])
	assert(a.events.is_empty() and b.events.is_empty(),"presentation latching never mutates per-tick simulation events")
	decoded = NetCodec.decode_snapshot(latch.encode(session,6,hash_prefix),session.race_id,hash_prefix)
	assert(decoded.states[0].events.is_empty() and decoded.states[1].events.is_empty(),"sent flags never repeat in the next snapshot")
	a.events.assign(["wall"])
	a.dnf_reason = "Reconnect expired"
	latch.collect(session)
	decoded = NetCodec.decode_snapshot(latch.encode(session,9,hash_prefix),session.race_id,hash_prefix)
	assert(decoded.states[0].events.is_empty(),"a frozen DNF state cannot re-latch its last impact forever")
	a.dnf_reason = ""
	var client := NetworkClient.new()
	root.add_child(client)
	client.connected = true
	client.start_tick = 0
	client.phase = RaceSession.Phase.RACING
	client.config = {"track":0,"laps":2}
	var packets: Array[Dictionary] = []
	for tick in [12,9,15]:
		a.events.assign(["wall"] if tick==9 else ["land"] if tick==12 else [])
		packets.append({"channel":2,"bytes":NetCodec.encode_snapshot(session,tick,hash_prefix)})
	client.receive_packets(packets)
	assert(client.latest_snapshot_tick==15 and client.coalesced_snapshots==2)
	var events := client.feedback_since(0)
	assert(events.size()==2 and events[0].events==["land"] and events[1].events==["wall"],"coalescing preserves cues from every valid received snapshot")
	var cursor := client.feedback_sequence
	client.receive_packets(packets)
	assert(client.feedback_since(cursor).is_empty(),"duplicates/late snapshots cannot repeat effects")
	for tick in range(18,600,3):
		a.events.assign(["wall"])
		client.observe_feedback({"tick":tick,"states":[a]})
	assert(client.feedback_events.size()<=128 and client.feedback_seen.size()<=64)
	for row: Dictionary in client.feedback_events: row.at_ms = Time.get_ticks_msec()-501
	assert(client.feedback_since(0).is_empty(),"old cues are bounded to a 500 ms local delivery window")
	client.reset_feedback()
	assert(client.feedback_events.is_empty() and client.feedback_seen.is_empty())
	client.queue_free()
	await process_frame
	print("PRESENTATION_EVENTS_THREE_TICK_LATCH_COALESCE_DEDUP_BOUNDS_NO_SIMULATION_WRITES_PASS")
	quit()

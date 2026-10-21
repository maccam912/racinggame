extends SceneTree
func _initialize() -> void: call_deferred("run")

func run() -> void:
	Catalog.load_all()
	var hash := Compatibility.content_hash().hex_decode()
	var cases := 0
	for track: TrackDefinition in Catalog.tracks:
		var race := RaceSession.new()
		for slot in range(8):
			var state := VehicleState.new()
			state.slot = slot
			race.states.append(state)
		for gate in range(track.bake.gates.size()):
			for state: VehicleState in race.states: state.last_gate = gate
			var packet := NetCodec.encode_snapshot(race,100+gate,hash)
			var decoded := NetCodec.decode_snapshot(packet,1,hash)
			print("SNAPSHOT_COURSE ",track.id," gate=",gate," accepted=",not decoded.is_empty())
			assert(not decoded.is_empty(),"every authored gate must round-trip in the eight-car snapshot")
			assert(packet.size()==743 and decoded.states[7].last_gate==gate)
			cases += 1
		for state: VehicleState in race.states: state.last_gate = track.bake.gates.size()-1
		var packet := NetCodec.encode_snapshot(race,1000,hash)
		var client := NetworkClient.new()
		client.config = {"track":Catalog.tracks.find(track),"laps":1}
		client.race_id = 1
		client.connected = true
		client.start_tick = 0
		client.phase = RaceSession.Phase.RACING
		client.receive_snapshot(packet)
		assert(client.latest_snapshot_tick==1000,"direct receipt retains final-checkpoint snapshots")
		client.latest_snapshot_tick = -1
		client.receive_packets([{"channel":2,"bytes":packet}])
		assert(client.latest_snapshot_tick==1000,"batched receipt retains final-checkpoint snapshots")
		for state: VehicleState in race.states: state.last_gate = track.bake.gates.size()
		client.receive_snapshot(NetCodec.encode_snapshot(race,1001,hash))
		assert(client.latest_snapshot_tick==1000,"per-course guard rejects a checkpoint outside this route")
		client.wire.close()
		client.free()
		for invalid in [-2,Catalog.maximum_gate_count(),127]:
			for state: VehicleState in race.states: state.last_gate = invalid
			assert(NetCodec.decode_snapshot(NetCodec.encode_snapshot(race,2000,hash),1,hash).is_empty(),"wire decoder rejects checkpoints outside the current catalog")
	await process_frame
	print("ALL_COURSE_CHECKPOINT_SNAPSHOTS_PASS cases=",cases)
	quit()

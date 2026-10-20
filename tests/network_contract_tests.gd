extends SceneTree

class TimelinePrediction extends PredictionBuffer:
	func simulate(_frame: InputFrame) -> void:
		elapsed_ticks += 1
		state.position.x += 1


var failures: int = 0


func check(condition: bool, message: String) -> void:
	if not condition:
		push_error("TEST FAIL: " + message)
		failures += 1


func _initialize() -> void:
	Catalog.load_all()
	var session := RaceSession.new()
	var hash_prefix := "0123456789abcdef".hex_decode()
	for i in range(8):
		var state := VehicleState.new()
		state.slot = i
		state.position = Vector3(i * 12.3456, 34.5678, -800.8912)
		state.velocity = Vector3(-12.3456, 3.4567, -58.8765)
		state.yaw = deg_to_rad(35.123)
		state.yaw_rate = .321
		state.steer_filter = -.8
		state.drift_phase = 2
		state.drift_timer = .234
		state.drift_entry = .1
		state.last_ack = 456
		state.last_gate = 12
		state.braking = i%2==0
		state.surface = ["asphalt","sand","grass","dirt"][i%4]
		state.jump_lap = i*8+7
		session.states.append(state)
	var packet := NetCodec.encode_snapshot(session, 1234, hash_prefix)
	check(packet.size()==727,"protocol 5 uses the last flag bit without growing the eight-car snapshot")
	check(packet.size() > 0 and packet.size() < 1200, "full eight-car snapshot payload budget")
	var decoded := NetCodec.decode_snapshot(packet, 1, hash_prefix)
	check(not decoded.is_empty(), "snapshot round trip")
	if not decoded.is_empty():
		for i in range(8):
			var restored: VehicleState = decoded.states[i]
			check(restored.position.distance_to(session.states[i].position) <= .01, "position quantization <= 1 cm")
			check(restored.velocity.distance_to(session.states[i].velocity) <= .01, "velocity quantization <= 1 cm/s")
			check(absf(restored.yaw - session.states[i].yaw) <= deg_to_rad(.02), "angle quantization <= .02 degrees")
			check(restored.last_ack == 456 and restored.drift_phase == 2, "replay state retained")
			check(restored.braking==(i%2==0),"authoritative brake lamps round trip independently per car")
			check(restored.surface==session.states[i].surface and restored.jump_lap==i*8+7,"dirt and all three consumed launch bits survive snapshots")
	var old_protocol := packet.duplicate()
	old_protocol[4] = 5
	check(NetCodec.decode_snapshot(old_protocol,1,hash_prefix).is_empty(),"protocol 4 clients cannot silently reinterpret the new lamp flag")
	for length in range(packet.size()):
		check(NetCodec.decode_snapshot(packet.slice(0, length), 1, hash_prefix).is_empty(), "truncated snapshot rejected")
	var frames: Array[InputFrame] = []
	for i in range(6):
		var frame := InputFrame.make(-.75, .9, .2, true)
		frame.sequence = i + 1
		frame.tick = 100 + i
		frames.append(frame)
	var inputs := NetCodec.encode_inputs(1, frames)
	check(inputs.size() == 82 and NetCodec.decode_inputs(inputs, 1).size() == 6, "redundant six-frame input batch")
	check(NetCodec.decode_inputs(inputs, 2).is_empty(), "wrong race input rejected")
	var malformed := inputs.duplicate()
	malformed[21] = 128
	check(NetCodec.decode_inputs(malformed, 1).is_empty(), "unknown button bits rejected")
	var buffer := InputBuffer.new()
	for frame: InputFrame in frames:
		buffer.push(frame, 100)
		buffer.push(frame, 100)
	check(buffer.frames.size() == 6, "redundant packets deduplicated")
	check(buffer.sample(102).throttle == 0, "fixed three-tick input buffer")
	check(buffer.sample(103).sequence == 1, "oldest eligible input applied once")
	for tick in range(104, 125):
		buffer.sample(tick)
	check(buffer.sample(125).throttle == 0 and buffer.last_sequence == 6, "six missing ticks neutralize controls")
	check(InputBuffer.newer(1, 0xffffffff) and not InputBuffer.newer(0xfffffffe, 1), "uint32 wrap ordering")
	check(PeerAddress.parse("example.com:27020").port == 27020 and PeerAddress.parse("[::1]:27020").host == "::1", "hostname/IPv6 parsing")
	for address in ["http://server/path", "host:0", "host:65536", "host:27020/../file", "bad..host:27020", "server"]:
		check(PeerAddress.parse(address).is_empty(), "invalid direct address rejected")
	check(not NetEvents.server_event({"type":"welcome", "slot":99}) and not NetEvents.server_event({"type":"results", "results":[{"slot":0}]}), "malformed reliable state rejected")
	var remote := RemoteBuffer.new()
	var remote_states: Array[VehicleState] = [VehicleState.new()]
	remote_states[0].velocity = Vector3(10, 0, 0)
	remote.push(100, remote_states)
	check(absf(remote.sample(0, 1000).position.x - 1.5) < .001, "remote extrapolation stops after 150 ms")
	var lamps: Array[VehicleState] = [remote_states[0].copy()]
	lamps[0].braking = true
	remote.push(103,lamps)
	check(not remote.sample(0,108).braking and remote.sample(0,109).braking,"interpolated brake flag switches at its authoritative target tick")
	var invalid := session.states[0].copy()
	invalid.ghost_ticks = 100000
	session.states[0] = invalid
	check(NetCodec.encode_snapshot(session, 1234, hash_prefix).is_empty(), "quantization overflow rejected instead of wrapped")
	var terminal := PredictionBuffer.new()
	terminal.state = VehicleState.new()
	terminal.track = Catalog.tracks[0]
	terminal.query = WorldQuery.new(root.world_3d, terminal.track)
	terminal.car = Catalog.cars[0]
	var finish := VehicleState.new()
	finish.finished = true
	finish.position = Vector3(1, 4, 3)
	terminal.history = [InputFrame.make(1, 1)]
	terminal.reconcile(finish, 4000)
	check(terminal.history.is_empty() and terminal.state.position == finish.position, "finished authority does not replay stale human input over AI")
	check(terminal.terminal_corrections.size() == 1 and terminal.clear_corrections.is_empty(), "autopilot corrections are reported separately from active driving")
	var timeline := TimelinePrediction.new()
	timeline.state = VehicleState.new()
	timeline.track = Catalog.tracks[0]
	timeline.query = terminal.query
	timeline.car = Catalog.cars[0]
	for index in range(13):
		var frame := InputFrame.make()
		frame.sequence = 101 + index
		frame.tick = 95 + index
		timeline.history.append(frame)
	var held := VehicleState.new()
	held.last_ack = 100
	held.position.x = 100
	timeline.reconcile(held, 600, 106)
	check(timeline.state.position.x == 104, "elapsed missing-input ticks are not replayed twice")
	held.position.x = 103
	timeline.reconcile(held, 603, 109)
	check(timeline.state.position.x == 104, "coalesced snapshots with unchanged ack preserve the same predicted endpoint")
	check(timeline.history.size() == 13, "unacknowledged inputs remain available for redundant transmission")
	var clocked := NetworkClient.new()
	clocked.prediction = TimelinePrediction.new()
	clocked.prediction.state = VehicleState.new()
	clocked.connected = true
	clocked.server_tick = 500.6
	clocked.start_tick = 0
	clocked.control_tick = 0
	clocked.phase = RaceSession.Phase.RACING
	clocked._physics_process(1.0 / 60)
	clocked.server_tick -= .8
	clocked._physics_process(1.0 / 60)
	check(clocked.prediction.history[1].tick == clocked.prediction.history[0].tick + 1, "clock smoothing never duplicates an input tick")
	clocked.prediction.query = terminal.query
	clocked.prediction.track = Catalog.tracks[0]
	clocked.slot = 0
	var clock_authority := VehicleState.new()
	clock_authority.last_ack = 49
	clock_authority.position.x = 200
	clocked.latest_snapshot = {"tick":595,"elapsed":295,"states":[clock_authority]}
	clocked.latest_snapshot_tick = 595
	clocked.server_tick = 600
	clocked.sequence = 50
	clocked.next_input_tick = 410
	clocked.tick_counter = 0
	clocked._physics_process(1.0/60)
	check(clocked.clock_rebase_count==1 and clocked.prediction.history.size()==1,"lost fixed ticks rebase once and discard stale prediction history")
	var rebased: InputFrame = clocked.prediction.history[0]
	check(rebased.tick==601 and rebased.sequence==51,"rebase changes intended tick while preserving sequence monotonicity")
	var accepted := InputBuffer.new()
	accepted.last_sequence = 49
	accepted.push(rebased,607)
	check(accepted.sample(607).sequence==51 and accepted.rejected==0,"fresh rebased input arrives inside the unchanged server window")
	check(clocked.prediction.clock_corrections.size()==1 and clocked.prediction.reconnect_corrections.is_empty(),"hitch restores are reported independently of reconnect and ordinary corrections")
	clocked.rtt_ms = 2200
	clocked.clock_samples = [{"at":Time.get_ticks_msec()-1000,"rtt":180.0}]
	check(is_equal_approx(clocked.clock_transit_ticks(),5.4),"local scheduling delay must not become a one-way transit estimate")
	clocked.observe_clock(200,.25)
	check(clocked.server_tick>=595,"an old queued pong cannot rewind the latest authority")
	var queued := RaceSession.new()
	queued.phase = RaceSession.Phase.RACING
	queued.elapsed_ticks = 307
	queued.states = [clock_authority]
	clocked.server_tick = 400
	clocked.next_input_tick = 400
	var received_before := clocked.prediction.snapshot_count
	var queued_packets: Array[Dictionary] = []
	for tick in [601,607,604]:
		queued_packets.append({"channel":2,"bytes":NetCodec.encode_snapshot(queued,tick,Compatibility.content_hash().hex_decode())})
	clocked.receive_packets(queued_packets)
	check(clocked.latest_snapshot_tick==607 and clocked.coalesced_snapshots==2,"a stalled receive pass applies its newest valid snapshot even when delivery is reordered")
	check(clocked.quality.measure().delivery_samples>=3,"delivery quality counts every decoded snapshot before coalescing")
	check(clocked.prediction.snapshot_count==received_before+1 and clocked.clock_rebase_count==2,"the batch restores one authority state before resuming fresh input")
	clock_authority.finished = true
	queued.phase = RaceSession.Phase.GRACE
	clocked.next_input_tick = 400
	clocked.receive_snapshot(NetCodec.encode_snapshot(queued,610,Compatibility.content_hash().hex_decode()))
	check(clocked.clock_rebase_count==2 and clocked.prediction.history.is_empty(),"a finisher's intentionally stopped input clock must not rebase during autopilot")
	clocked.phase = RaceSession.Phase.RESULTS
	clock_authority.finished = false
	clock_authority.position.x = 999
	clocked.receive_snapshot(NetCodec.encode_snapshot(queued,613,Compatibility.content_hash().hex_decode()))
	check(clocked.latest_snapshot_tick==610 and clocked.prediction.state.finished,"queued racing snapshots cannot undo terminal results")
	clocked.wire.close()
	clocked.free()
	var transport := WirePeer.new()
	transport.active_peers[42] = true
	transport.send(42, 0, "queued".to_ascii_buffer(), true)
	transport.disconnect_target(42)
	transport.disconnect_target(42)
	check(transport.active_peers.is_empty() and transport.pending.is_empty(), "forced disconnect removes mirrored identity and pending sends exactly once")
	transport.close()
	print("Network contract fixtures: eight-car snapshot %d bytes; input batch %d bytes; failures %d" % [packet.size(), inputs.size(), failures])
	quit(1 if failures else 0)

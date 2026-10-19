extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	Catalog.load_all()
	var link := NetworkClient.new()
	var worker := RoomServer.new()
	var roster: Array[Dictionary] = []
	for index in range(8):
		var id := RaceSetup.uuid()
		var row := {"id":id, "name":"👨‍👩‍👧‍👦".repeat(3) + "a" + String.chr(97 + index), "car":index % 4, "paint":index, "bot":false}
		roster.append(row)
		worker.lobby.join(id, row.name, index, int(row.car), index)
	var session := RaceSession.new()
	session.roster = roster
	session.race_id = 1
	session.race_uuid = RaceSetup.uuid()
	worker.session = session
	worker.race_number = 1
	link.race_id = 1
	link.start_tick = 100
	link.config = {"roster":roster, "track":0, "laps":2}
	link.lobby = worker.lobby.public_state(100)
	var presence := worker.racing_presence()
	assert(NetEvents.server_event(presence))
	assert(JSON.stringify(presence).to_utf8_buffer().size() + 4 <= 1200)
	link.apply_presence(presence)
	assert(link.lobby.members.size() == 8 and link.lobby.host == roster[0].id)
	var cars: Array = []
	for row: Dictionary in roster:
		cars.append([row.id, row.car, row.paint, row.bot])
	var resume := {"type":"resume", "race":1, "race_uuid":session.race_uuid, "slot":0, "start_tick":100, "control_tick":900, "count":8, "track":0, "laps":2, "cars":cars, "contact":true}
	assert(NetEvents.server_event(resume))
	assert(JSON.stringify(resume).to_utf8_buffer().size() + 4 <= 1200)
	var expanded := link.expand_resume(resume)
	assert(NetEvents.server_event(expanded) and expanded.roster == roster)
	assert(JSON.stringify(expanded).to_utf8_buffer().size() + 4 > 1200)
	link.phase = RaceSession.Phase.RACING
	link.receive_event(resume)
	assert(link.resume_count == 1 and link.large_racing_events == 0)
	var invalid := resume.duplicate(true)
	invalid.cars[1][0] = invalid.cars[0][0]
	assert(not NetEvents.server_event(invalid))
	invalid = presence.duplicate(true)
	invalid.members[0][0] = 8
	assert(not NetEvents.server_event(invalid))
	invalid = presence.duplicate(true)
	invalid.host_slot = 9
	assert(not NetEvents.server_event(invalid))
	var missing := resume.duplicate(true)
	missing.cars[0][0] = RaceSetup.uuid()
	assert(link.expand_resume(missing).is_empty())
	# Excluded human names are never reconstructed or invented. Known bot names
	# may be resolved from the shipped callsign catalog after a loading exclusion.
	missing.cars[0] = ["bot_sunny",0,0,true]
	assert(link.expand_resume(missing).roster[0].name == "Sunny")
	var wire := WirePeer.new()
	wire.racing = true
	wire.event(1, expanded)
	assert(wire.pending.is_empty() and wire.rejected_large_racing_events == 1)
	wire.event(1, resume)
	assert(wire.pending.size() == 1 and wire.pending[0].bytes.size() <= 1200)
	wire.close()
	worker.wire.close()
	worker.session = null
	worker.free()
	link.wire.close()
	link.free()
	print("Compact race control: eight Unicode names, cached reconnect, presence, packet guard and malformed rows pass")
	quit()

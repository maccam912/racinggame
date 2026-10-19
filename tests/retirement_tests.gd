extends SceneTree

func _initialize() -> void:
	var server := RoomServer.new()
	assert(not server.retirement_due(1000))
	assert(server.retire_requested_ms == -1)
	server.retiring = true
	server.session = RaceSession.new()
	assert(not server.retirement_due(1000))
	assert(not server.retirement_due(600999))
	assert(server.retirement_due(601000), "Ten-minute active-race retirement wall bound")
	server.retire_requested_ms = -1
	server.result_sent = true
	assert(not server.retirement_due(1000))
	assert(server.retire_results_until_ms == 6000)
	assert(not server.retirement_due(5999))
	assert(server.retire_results_until_ms == 6000, "Repeated retirement reports must not extend result delivery")
	assert(server.retirement_due(6000))
	server.session = null
	assert(server.retirement_due(1001), "Idle worker needs no unfinished-race drain")
	server.wire.close()
	server.free()
	print("WORKER_RETIREMENT_ACTIVE_10_MINUTE_BOUND_RESULTS_5_SECOND_STABLE_DEADLINE_IDLE_PASS")
	quit()

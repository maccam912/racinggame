extends SceneTree

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var link := WorkerDirectory.new()
	root.add_child(link)
	var observed := {"retirements":0}
	link.retire_requested.connect(func() -> void: observed.retirements += 1)
	var response := JSON.stringify({"commands":[],"drain":false}).to_utf8_buffer()
	link.heartbeat_complete(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),response)
	assert(link.healthy and not link.retired)
	await create_timer(15.1).timeout
	assert(not link.healthy and link.retired and observed.retirements == 1, "Supervisor loss must retire a surviving worker")
	link.heartbeat_complete(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),response)
	assert(not link.healthy and link.retired, "A late successful response cannot reopen retirement")
	await process_frame
	assert(observed.retirements == 1)
	link.queue_free()
	await process_frame
	print("WORKER_PRIVATE_LINK_15_SECONDS_LOST_RETIRES_ONCE_LATE_HEARTBEAT_CANNOT_REOPEN_PASS")
	quit()

extends SceneTree

func _initialize() -> void: call_deferred("run")

func run() -> void:
	var link := WorkerDirectory.new()
	root.add_child(link)
	var observed := {"retirements":0,"at_ms":-1}
	link.retire_requested.connect(func() -> void:
		observed.retirements += 1
		observed.at_ms = Time.get_ticks_msec()
	)
	var response := JSON.stringify({"commands":[],"drain":false}).to_utf8_buffer()
	link.heartbeat_complete(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),response)
	assert(link.healthy and not link.retired)
	var started := link.last_success
	# SceneTreeTimer follows engine delta, whereas the private-link lease uses
	# monotonic wall time. Poll that same clock, with a separate bounded deadline.
	while not link.retired and Time.get_ticks_msec()-started < 20000:
		await process_frame
	assert(not link.healthy and link.retired and observed.retirements == 1, "Supervisor loss must retire a surviving worker")
	assert(observed.at_ms-started >= 15000 and observed.at_ms-started < 20000,"Retirement must obey the real 15-second lease")
	link.heartbeat_complete(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),response)
	assert(not link.healthy and link.retired, "A late successful response cannot reopen retirement")
	for status in [401,404,401]:
		link.heartbeat_complete(HTTPRequest.RESULT_SUCCESS,status,PackedStringArray(),PackedByteArray())
	var drain := JSON.stringify({"commands":[],"drain":true}).to_utf8_buffer()
	link.heartbeat_complete(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),drain)
	await process_frame
	assert(observed.retirements == 1,"Repeated denial/drain responses cannot re-emit retirement")
	link.queue_free()
	await process_frame
	for first_status in [200,401,404]:
		var denied := WorkerDirectory.new()
		root.add_child(denied)
		var count := {"retirements":0}
		denied.retire_requested.connect(func() -> void: count.retirements += 1)
		for attempt in range(3):
			denied.heartbeat_complete(HTTPRequest.RESULT_SUCCESS,first_status,PackedStringArray(),drain)
		assert(denied.retired and not denied.healthy and count.retirements==1,"Each terminal HTTP path retires once")
		denied.heartbeat_complete(HTTPRequest.RESULT_SUCCESS,200,PackedStringArray(),response)
		assert(denied.retired and not denied.healthy and count.retirements==1)
		denied.queue_free()
		await process_frame
	print("WORKER_PRIVATE_LINK_REAL_15_SECONDS_LOST_RETIRES_ONCE_DENIAL_DRAIN_LATE_HEARTBEAT_PASS elapsed_ms=",observed.at_ms-started)
	quit()

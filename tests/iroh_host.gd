extends SceneTree
var rooms := IrohRooms.new()


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	Catalog.load_all()
	root.add_child(rooms)
	var output := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--report="): output = arg.trim_prefix("--report=")
	var result := await rooms.host()
	assert(result.ok,str(result.get("message","")))
	var first := rooms.code
	var first_resolution := await rooms.rendezvous.resolve(first)
	assert(first_resolution.ok)
	var renewed := await rooms.regenerate()
	assert(renewed.ok)
	var revoked := await rooms.rendezvous.resolve(first)
	# Revocation runs asynchronously. Wait for the actual DELETE to complete.
	var deadline := Time.get_ticks_msec()+12000
	while revoked.ok and Time.get_ticks_msec()<deadline:
		await create_timer(.1).timeout
		revoked = await rooms.rendezvous.resolve(first)
	assert(not revoked.ok,"regeneration must revoke the old code")
	var file := FileAccess.open(output,FileAccess.WRITE)
	file.store_string(JSON.stringify({"endpoint":rooms.endpoint,"code":rooms.code,"regenerated":true,"revoked":true,"service":IrohRendezvous.URL}))
	file.close()
	print("PACIFIC_IROH_HOST_READY")
	var stop_path := output+".stop"
	deadline = Time.get_ticks_msec()+700000
	while not FileAccess.file_exists(stop_path) and Time.get_ticks_msec()<deadline:
		await create_timer(.1).timeout
	var old_code := rooms.code
	var token := rooms.revoke_token
	rooms.code = ""
	await rooms.rendezvous.revoke(old_code,token)
	rooms.close()
	rooms.queue_free()
	await process_frame
	quit()

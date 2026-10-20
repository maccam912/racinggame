extends SceneTree

class Discovery extends IrohRendezvous:
	signal released
	var hold: bool = false
	var calls: int = 0
	var reply: Dictionary = {"ok":true,"payload":{}}
	func request(_path: String, _method: int = HTTPClient.METHOD_GET, _payload: Dictionary = {}, _token: String = "") -> Dictionary:
		calls += 1
		if hold: await released
		else: await get_tree().process_frame
		return reply.duplicate(true)


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	Catalog.load_all()
	assert(IrohRendezvous.normalize(" abcd ")=="ABCD")
	for value in ["ABCD","2345","wxyz"]: assert(IrohRendezvous.valid_code(value))
	for value in ["","AB","ABCD1234","A0CD","A1CD","AILO","AB-C","AB\nC","ＡBCD"]:
		assert(not IrohRendezvous.valid_code(value))
	var service := Discovery.new()
	root.add_child(service)
	service.reply = {"ok":true,"payload":{"endpoint_id":"A".repeat(43),"session_id":"paint-n-seek"}}
	var result := await service.resolve("ABCD")
	assert(not result.ok and result.message==I18n.t("online.iroh_incompatible"),"shared discovery must not connect to a different game")
	service.reply.payload.session_id = IrohRendezvous.session_id()
	service.reply.payload.endpoint_id = "invalid"
	result = await service.resolve("ABCD")
	assert(not result.ok)
	service.reply.payload.endpoint_id = "A".repeat(43)
	result = await service.resolve("abcd")
	assert(result.ok)
	var count := service.calls
	result = await service.resolve("bad")
	assert(not result.ok and service.calls==count,"invalid codes must never be requested")
	service.queue_free()
	var app: Node = load("res://game/client_app.gd").new()
	root.add_child(app)
	await process_frame
	app.data.mobile = false
	app.iroh_rooms.rendezvous.queue_free()
	var held := Discovery.new()
	held.hold = true
	held.reply = {"ok":true,"payload":{"endpoint_id":"A".repeat(43),"session_id":IrohRendezvous.session_id()}}
	app.iroh_rooms.rendezvous = held
	app.iroh_rooms.add_child(held)
	app.iroh_page.show_join()
	app.iroh_page.join("ABCD")
	for frame in range(3): await process_frame
	assert(app.iroh_page.pending and app.connection_button.disabled,"pending=%s disabled=%s calls=%d page=%s status=%s" % [app.iroh_page.pending,app.connection_button.disabled,held.calls,app.page,app.iroh_page.status.text])
	app.iroh_page.join("ABCD")
	assert(held.calls==1,"double activation cannot send another lookup")
	app.iroh_page.cancel()
	held.released.emit()
	await process_frame
	assert(app.network==null and app.page=="online" and not app.iroh_page.pending,"late resolution cannot reopen a cancelled room")
	app.queue_free()
	await process_frame
	await create_timer(.5).timeout
	print("IROH_CODE_GAME_VERSION_ENDPOINT_VALIDATION_DOUBLE_ACTIVATION_CANCEL_PASS")
	quit()

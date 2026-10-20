extends SceneTree


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	var app: Node = load("res://game/client_app.gd").new()
	root.add_child(app)
	await process_frame
	app.data.mobile = false
	app.data.settings.ui_scale = 150
	app.menu.settings = app.data.settings
	app.show_online()
	await capture("online")
	app.iroh_page.show_host()
	var deadline := Time.get_ticks_msec()+35000
	while app.page!="lobby" and Time.get_ticks_msec()<deadline: await process_frame
	assert(app.page=="lobby" and IrohRendezvous.valid_code(app.iroh_rooms.code))
	assert(app.network.connected and app.iroh_rooms.authority_world.own_world_3d)
	assert(app.iroh_rooms.authority.get_world_3d()!=app.get_world_3d(),"listen authority must have an isolated physics world")
	await capture("host")
	var initial_code: String = app.iroh_rooms.code
	var identity: String = app.network.guest_id
	app.iroh_rooms.expires_at = Time.get_unix_time_from_system()-1
	app.lobby_page.update_countdown()
	assert(app.lobby_page.iroh_copy.disabled and app.lobby_page.iroh_code_caption.text==I18n.t("online.iroh_code_expired"))
	app.iroh_page.regenerate()
	app.iroh_page.regenerate()
	deadline = Time.get_ticks_msec()+15000
	while app.iroh_rooms.busy and Time.get_ticks_msec()<deadline: await process_frame
	assert(app.iroh_rooms.code!=initial_code and app.network.guest_id==identity)
	await process_frame
	assert(not app.lobby_page.iroh_copy.disabled)
	var code: String = app.iroh_rooms.code
	# A real mobile lifecycle event closes a listen host rather than simulating
	# in the background or leaving a mapping pointing at a dead authority.
	app.data.mobile = true
	app.foreground = true
	app.handle_background()
	assert(app.iroh_rooms.authority==null and app.network==null and app.page=="connection_lost")
	await capture("host-background")
	var reply: Dictionary = await app.iroh_rooms.rendezvous.resolve(code)
	deadline = Time.get_ticks_msec()+10000
	while reply.ok and Time.get_ticks_msec()<deadline:
		await create_timer(.1).timeout
		reply = await app.iroh_rooms.rendezvous.resolve(code)
	assert(not reply.ok)
	app.queue_free()
	await process_frame
	await create_timer(.6).timeout
	print("IROH_REAL_APP_HOST_SELF_ADMISSION_ISOLATED_AUTHORITY_CODE_EXPIRY_REGENERATE_MOBILE_SHUTDOWN_REVOKE_PASS")
	quit()


func capture(label: String) -> void:
	if DisplayServer.get_name()=="headless": return
	await create_timer(.3).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://reports/iroh-ui-"+label+".png")

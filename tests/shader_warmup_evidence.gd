extends SceneTree
var app: Node
var rows: Array[Dictionary] = []
var folder: String
func _initialize() -> void: call_deferred("run")
func hold_graphics(child: Node) -> void:
	if child is TrackLoader:
		# frame_post_draw may complete the two submissions between SceneTree
		# process_frame observations on a slow renderer. Hold the existing
		# foreground guard before its first draw so the phase is observable.
		child.set_meta("fixture_foreground",child.active)
		child.active = func() -> bool: return false
		print("SHADER_FIXTURE_HOLD id="+str(child.get_instance_id())+" valid="+str(child.active.is_valid())+" allowed="+str(child.active.call()))
func release_graphics(job: TrackLoader) -> void:
	print("SHADER_FIXTURE_RELEASE "+JSON.stringify(loader_state()))
	job.active = job.get_meta("fixture_foreground")
	job.warmer.active = job.active
func loader_state() -> Dictionary:
	var result := {"page":app.page,"foreground":app.foreground}
	if not is_instance_valid(app.track_loader): return result
	var job: TrackLoader = app.track_loader
	result.merge({"id":job.get_instance_id(),"warming":job.warming,"done":job.done,"graphics_error":job.graphics_error,"guard_saved":job.has_meta("fixture_foreground"),"active_valid":job.active.is_valid(),"active":bool(job.active.call()) if job.active.is_valid() else null,"world_stage":job.world.build_stage if is_instance_valid(job.world) else -1})
	if is_instance_valid(job.warmer): result["warmer"] = {"allowed":job.warmer.allowed(),"frames":job.warmer.rendered_frames,"submissions":job.warmer.submissions,"draws":job.warmer.draw_calls,"finished":job.warmer.finished,"update_mode":job.warmer.viewport.render_target_update_mode}
	return result
func until(condition: Callable, label: String = "") -> void:
	var deadline := Time.get_ticks_msec()+15000
	while not condition.call() and Time.get_ticks_msec()<deadline: await process_frame
	if not condition.call(): print("SHADER_FIXTURE_TIMEOUT "+label+" "+JSON.stringify(loader_state()))
	assert(condition.call(),"native graphics preparation completed before deadline: "+label)
func run() -> void:
	assert(DisplayServer.get_name()!="headless")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://reports"))
	root.size = Vector2i(1920,1080)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_size = Vector2i(1280,720)
	folder = "user://tests/shader-evidence-"+RaceSetup.uuid()
	app = load("res://game/client_app.gd").new()
	app.capture_path = "user://unused-shader-reference.png"
	app.capture_frame = 1000000
	app.child_entered_tree.connect(hold_graphics)
	root.add_child(app)
	await process_frame
	app.data = AppData.new(folder,false)
	app.data.profile.first_run_complete = true
	for index in range(6):
		print("SHADER_FIXTURE_COURSE_BEGIN "+Catalog.tracks[index].id)
		app.data.settings.msaa = [4,2,0][index%3]
		var started := Time.get_ticks_msec()
		app.request_drive({"mode":"quick","track":index,"opponents":7,"car":index%4},app.show_menu)
		var job: TrackLoader = app.track_loader
		await until(func() -> bool: return job.warming,"course_"+str(index)+"_warming")
		assert(not job.done and job.world.get_parent()==null and app.loading_bar.value<1)
		assert(job.warmer.viewport.find_world_3d()!=app.get_world_3d())
		if index==0:
			job.warmer.active = func() -> bool: return false
			for frame in range(5): await process_frame
			assert(not job.done and job.warmer.rendered_frames==0,"background does not complete or acknowledge GPU preparation")
			await RenderingServer.frame_post_draw
			assert(root.get_texture().get_image().save_png("res://reports/m5-shader-loading.png")==OK)
			assert(job.warmer.viewport.get_texture().get_image().save_png("res://reports/m5-shader-material-grid.png")==OK)
		release_graphics(job)
		await until(func() -> bool: return app.page=="race")
		app.drive.set_physics_process(false)
		var evidence: Dictionary = app.drive.world.shader_warmup.duplicate(true)
		assert(evidence.gpu_warmed and evidence.rendered_frames>=2 and evidence.draw_calls>0 and evidence.visible_objects>0)
		assert(evidence.image_size==[256,256] and app.drive.world.warmed_resources.size()>=4)
		assert(app.drive.session.phase==RaceSession.Phase.GRID and app.drive.session.elapsed_ticks==0)
		evidence["track"] = Catalog.tracks[index].id
		evidence["msaa"] = app.data.settings.msaa
		evidence["load_ms"] = Time.get_ticks_msec()-started
		rows.append(evidence)
		app.show_menu()
		await process_frame
	app.request_drive({"mode":"quick","track":0,"opponents":0},app.show_menu)
	var failing: TrackLoader = app.track_loader
	await until(func() -> bool: return failing.warming)
	failing.warmer.force_failure = true
	release_graphics(failing)
	await until(func() -> bool: return failing.graphics_error)
	assert(app.page=="loading" and app.drive==null and not failing.done and app.loading_bar.value<1)
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("res://reports/m5-shader-retry.png")==OK)
	var retry: Button
	for button: Button in app.menu.root.find_children("*","Button",true,false):
		if button.text==I18n.t("button.retry"): retry = button
	assert(retry!=null)
	retry.pressed.emit()
	await until(func() -> bool: return app.page=="race")
	app.drive.set_physics_process(false)
	assert(app.drive.world.shader_warmup.gpu_warmed)
	app.show_menu()
	app.request_drive({"mode":"quick","track":2,"opponents":0},app.show_menu)
	var cancelling: TrackLoader = app.track_loader
	await until(func() -> bool: return cancelling.warming)
	app.back_action.call()
	for frame in range(5): await process_frame
	assert(app.page=="main" and app.drive==null and app.track_loader==null and app.data.profile.races_completed==0)
	# Actual ENet readiness waits for the same GPU stage as offline loading.
	var socket := PacketPeerUDP.new()
	assert(socket.bind(0,"127.0.0.1")==OK)
	var port := socket.get_local_port()
	socket.close()
	var server := RoomServer.new()
	server.port = port
	root.add_child(server)
	app.show_connection_form()
	app.connect_address("127.0.0.1:"+str(port))
	await until(func() -> bool: return app.page=="lobby")
	var client: NetworkClient = app.network
	var identity := client.guest_id
	client.command("ready",{"value":true})
	await until(func() -> bool: return server.lobby.all_ready())
	client.command("start")
	await until(func() -> bool: return is_instance_valid(app.track_loader) and app.track_loader.warming)
	app.track_loader.warmer.active = func() -> bool: return false
	for frame in range(8): await process_frame
	assert(not server.players[0].loaded and client.loaded_race==-1 and server.session==null,"authority receives no Loaded until real shader submissions finish")
	release_graphics(app.track_loader)
	await until(func() -> bool: return app.page=="race")
	app.drive.set_physics_process(false)
	assert(app.drive.world.shader_warmup.gpu_warmed and server.players[0].loaded and client.guest_id==identity)
	app.show_menu()
	server.queue_free()
	var file := FileAccess.open("res://reports/m5-shader-warmup.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":true,"renderer":RenderingServer.get_current_rendering_method(),"tracks":rows,"failed_readback_retry":true,"cancel_during_graphics":true,"background_waits":true,"real_enet_loaded_after_gpu":true,"no_stats":true,"boundary":"Actual native Compatibility material/mesh/instanced submissions, two drawn frames, GPU readback and loading UI. Not a universal hardware no-stutter guarantee or physical thermal test."},"  "))
	file.close()
	app.queue_free()
	await create_timer(.5).timeout
	assert(AppData.remove_tree(ProjectSettings.globalize_path(folder))==OK)
	print("NATIVE_ALL_SIX_TRACKS_SHADER_READBACK_BEFORE_GRID_REAL_ENET_LOADED_FAILURE_RETRY_CANCEL_BACKGROUND_NO_STATS_PASS")
	quit()

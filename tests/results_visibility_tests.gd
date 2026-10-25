extends SceneTree

func _initialize() -> void: call_deferred("run")
func settle() -> void:
	for index in range(8): await process_frame

func receipt(rank: int) -> ResultReceipt:
	var race := RaceSession.new()
	race.track = Catalog.tracks[0]
	race.mode = "quick"
	race.race_uuid = RaceSetup.uuid()
	race.roster = RaceSetup.roster(7,0,0,"👨‍👩‍👧‍👦👨‍👩‍👧‍👦👨‍👩‍👧‍👦ab")
	for index in range(8):
		var record: Dictionary = race.roster[index]
		race.cars.append(Catalog.cars[int(record.car)])
		var state := VehicleState.new()
		state.slot = index
		state.finished = true
		state.finish_time = 90.125+index
		state.best_lap_time = 43.0625+index
		if record.id=="local":
			race.human_slot = index
			state.finish_time = 89.125 if rank==0 else 100.125
		race.states.append(state)
	return ResultReceipt.capture(race,[])

func run() -> void:
	assert("--profile=ci_tests" in OS.get_cmdline_user_args(),"Isolated fixture profile required")
	Catalog.load_all()
	var viewport_root := SubViewport.new()
	viewport_root.size = Vector2i(2400,1080)
	viewport_root.own_world_3d = true
	viewport_root.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(viewport_root)
	var app: Node = load("res://game/client_app.gd").new()
	viewport_root.add_child(app)
	await settle()
	app.menu.settings.reduce_motion = true
	var cases: Array[Dictionary] = []
	for viewport: Dictionary in [{"id":"phone","size":Vector2i(2400,1080),"unit":2.625,"mobile":true},{"id":"tablet","size":Vector2i(1920,1200),"unit":1.6,"mobile":true},{"id":"desktop","size":Vector2i(1280,720),"unit":1.0,"mobile":false}]:
		viewport_root.size = viewport.size
		app.menu.mobile_override = viewport.mobile
		app.menu.logical_unit_override = viewport.unit
		for scale in [100,125,150]:
			app.menu.settings.ui_scale = scale
			for rank in [7,0]:
				app.result_receipt = receipt(rank)
				app.result_summary = {"saved":true,"new_best":false}
				app.render_results()
				await settle()
				var list: VBoxContainer = app.menu.body.get_child(0).get_child(0)
				var row := list.get_child(rank) as PanelContainer
				assert(row!=null,"local result retains highlighted panel")
				var local_car: CarDefinition = app.result_receipt.session.cars[app.result_receipt.session.human_slot]
				var portrait := row.find_child("ResultCar",true,false) as TextureRect
				assert(portrait!=null and portrait.texture.resource_path.ends_with(local_car.id+"-"+str(app.result_receipt.session.roster[app.result_receipt.session.human_slot].paint)+".png"))
				assert(row.find_child("FinishingPlace",true,false).text==str(rank+1))
				var text := " ".join(row.find_children("*","Label",true,false).map(func(n: Label) -> String: return n.text))
				assert(text.contains(I18n.t("results.time")) and text.contains(I18n.t("results.best_lap")) and text.contains(I18n.t("results.gap")))
				var scroll: ScrollContainer = list.get_parent()
				assert(scroll.get_global_rect().encloses(row.get_global_rect()),"Local result must be visible: "+str([viewport.id,scale,rank,row.get_global_rect(),scroll.get_global_rect(),scroll.scroll_vertical]))
				assert(viewport_root.gui_get_focus_owner() is Button and app.menu.footer.is_ancestor_of(viewport_root.gui_get_focus_owner()),"revealing a result preserves keyboard/controller action focus")
				cases.append({"layout":viewport.id,"scale":scale,"rank":rank+1,"scroll":scroll.scroll_vertical,"viewport":[viewport_root.get_visible_rect().size.x,viewport_root.get_visible_rect().size.y]})
				if rank==7 and DisplayServer.get_name()!="headless":
					await RenderingServer.frame_post_draw
					DirAccess.make_dir_recursive_absolute("res://reports/results-visibility")
					assert(viewport_root.get_texture().get_image().save_png("res://reports/results-visibility/"+viewport.id+"-"+str(scale)+".png")==OK)
			app.result_receipt = receipt(7)
			var last_state: VehicleState = app.result_receipt.session.states[app.result_receipt.session.human_slot]
			last_state.finished = false
			last_state.finish_time = -1
			last_state.dnf_reason = "Time limit"
			app.result_summary = {"saved":true,"new_best":false}
			app.render_results()
			await settle()
			var dnf_list: VBoxContainer = app.menu.body.get_child(0).get_child(0)
			var dnf_row := dnf_list.get_child(7) as PanelContainer
			assert(dnf_list.get_parent().get_global_rect().encloses(dnf_row.get_global_rect()))
			var dnf_text := " ".join(dnf_row.find_children("*","Label",true,false).map(func(n: Label) -> String: return n.text))
			assert(dnf_text.contains(I18n.t("results.dnf")) and dnf_text.contains("Time limit"),"unfinished races stay clearly labelled")
			# Save failure and its Retry action take priority over scrolling to rank 8.
			app.result_receipt = receipt(7)
			app.result_summary = {"saved":false,"new_best":false}
			app.render_results()
			await settle()
			var scroll: ScrollContainer = app.menu.body.get_child(0)
			assert(scroll.scroll_vertical==0 and viewport_root.gui_get_focus_owner().text==I18n.t("data.retry_save"),"Save Retry must keep first focus: "+str([viewport.id,scale,scroll.scroll_vertical,viewport_root.gui_get_focus_owner().text]))
	# A deferred reveal from the previous page cannot scroll a replacement menu.
	var list: VBoxContainer = app.menu.scroll_column(app.menu.reset("Old"))
	for index in range(20): list.add_child(app.menu.ui.label("Old row "+str(index)))
	app.menu.reveal_later(list.get_child(19))
	list = app.menu.scroll_column(app.menu.reset("New"))
	for index in range(20): list.add_child(app.menu.ui.label("New row "+str(index)))
	await settle()
	assert(list.get_parent().scroll_vertical==0)
	DirAccess.make_dir_recursive_absolute("res://reports/results-visibility")
	var file := FileAccess.open("res://reports/results-visibility/"+("headless" if DisplayServer.get_name()=="headless" else "native")+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":true,"cases":cases,"save_failure_priority":true,"stale_page_guard":true,"backend":DisplayServer.get_name()},"  "))
	file.close()
	viewport_root.queue_free()
	await create_timer(.5).timeout
	print("RESULTS_LOCAL_ROW_VISIBLE_18_LAYOUT_SCALE_RANK_CASES_SAVE_RETRY_PRIORITY_STALE_PAGE_PASS")
	quit()

extends SceneTree
## Real filter widgets, random selection and a launch from the filtered roster.
func _initialize() -> void: call_deferred("run")

func pick(control: Node, index: int) -> void:
	control.selected = index
	control.item_selected.emit(index)

func run() -> void:
	Catalog.load_all()
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var app: Node = load("res://game/client_app.gd").new()
	app.capture_path = "user://unused-event-filter.png"
	app.capture_frame = 1000000000
	root.add_child(app)
	await process_frame
	var folder := "user://tests/event-filter-"+RaceSetup.uuid()
	app.data = AppData.new(folder,false)
	app.checkpoint = RaceCheckpoint.new(app.data)
	app.menu.settings = app.data.settings
	app.data.profile.first_run_complete = true
	app.data.settings.reduce_motion = true
	app.data.settings.ui_scale = 100
	var reports: Array[Dictionary] = []
	for mobile: bool in [false,true]:
		root.size = Vector2i(884,398) if mobile else Vector2i(1280,720)
		app.data.mobile = mobile
		app.menu.mobile_override = mobile
		app.menu.logical_unit_override = 1.0
		app.data.settings.ui_scale = 150 if mobile else 100
		for mode: String in ["quick","trial"]:
			app.events.mode = mode
			app.events.filter_index = 0
			app.events.show_event()
			await process_frame
			var picker: Node = app.menu.root.find_child("TrackFilter",true,false)
			for filter in range(EventMenu.FILTERS.size()):
				pick(picker,filter)
				for frame in range(3): await process_frame
				for button: Button in app.menu.footer.find_children("*","Button",true,false):
					assert(root.get_visible_rect().encloses(button.get_global_rect()),"filter/random/start must stay inside the phone viewport")
				assert(app.events.detail_scroll.size.y>=48*app.menu.ui.unit)
				var key: String = EventMenu.FILTERS[filter]
				var included: Array[int] = app.events.visible_tracks
				if key=="all": assert(included.size()==40)
				elif key=="new": assert(included.size()==30 and included.min()>=10)
				elif key=="classic": assert(included.size()==10 and included.max()<10)
				else: assert(not included.is_empty())
				assert(app.events.track_index in included and str(app.events.filter_picker.text).ends_with("("+str(included.size())+")"))
				for index in range(40):
					assert(app.events.track_cards[index].visible==(index in included))
					if index not in included: continue
					var track: TrackDefinition = Catalog.tracks[index]
					if key in ["asphalt","dirt"]: assert(track.road_surface()==key)
					if key=="space": assert(CourseArt.spec(track.id).get("space",false))
				var random_button := app.menu.footer.get_node("RandomTrack") as Button
				assert(not random_button.disabled)
				for roll in range(64):
					var before: int = app.events.track_index
					random_button.pressed.emit()
					assert(app.events.track_index in included and app.events.track_index!=before)
					assert(app.events.preview.track==Catalog.tracks[app.events.track_index])
				reports.append({"mobile":mobile,"mode":mode,"filter":key,"tracks":included.size()})
				if "--capture" in OS.get_cmdline_user_args() and mode=="quick" and key in ["new","space","dirt"]:
					for frame in range(8): await process_frame
					await RenderingServer.frame_post_draw
					var path := "res://reports/filter-%s-%s.png"%["phone" if mobile else "desktop",key]
					assert(root.get_texture().get_image().save_png(path)==OK)
	root.size = Vector2i(1280,720)
	app.data.settings.ui_scale = 100
	app.data.mobile = false
	app.menu.mobile_override = false
	app.events.mode = "quick"
	app.events.filter_index = EventMenu.FILTERS.find("dirt")
	app.events.show_event()
	pick(app.menu.root.find_child("LapsPicker",true,false),2)
	pick(app.menu.root.find_child("OpponentsPicker",true,false),0)
	pick(app.menu.root.find_child("DifficultyPicker",true,false),2)
	var contact := app.menu.root.find_child("CarContact",true,false) as CheckButton
	contact.button_pressed = false
	assert(app.events.laps==3 and app.events.opponents==0 and app.events.difficulty==2 and not app.events.contact)
	app.events.select_random_track()
	var expected: int = app.events.track_index
	app.events.start()
	for frame in range(1200):
		if app.page=="race": break
		await process_frame
	assert(app.page=="race" and app.drive.track==Catalog.tracks[expected])
	assert(app.drive.track.road_surface()=="dirt" and app.drive.lap_count==3 and app.drive.session.states.size()==1 and not app.drive.session.contact_enabled)
	app.show_menu()
	await process_frame
	app.queue_free()
	await create_timer(.5).timeout
	assert(AppData.remove_tree(ProjectSettings.globalize_path(folder))==OK)
	var file := FileAccess.open("res://reports/event-filters.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":true,"cases":reports,"filtered_start_track":Catalog.tracks[expected].id,"boundary":"Actual desktop/mobile-mode widgets, seven filters in Quick Race and Trial, 64 random picks per case and a real filtered dirt launch with changed race options. Native captures use a desktop renderer with phone layout overrides."},"\t")+"\n")
	file.close()
	print("EVENT_FILTERS_RANDOM_SUBSETS_COMPACT_PHONE_AND_FILTERED_LAUNCH_PASS cases=",reports.size())
	quit()

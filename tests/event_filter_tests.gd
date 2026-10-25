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
				if mobile:
					var footer_y: float = app.menu.footer.get_child(0).get_global_rect().position.y
					for control: Control in app.menu.footer.get_children(): assert(absf(control.get_global_rect().position.y-footer_y)<1,"every filter keeps footer on one row")
				var key: String = EventMenu.FILTERS[filter]
				var included: Array[int] = app.events.visible_tracks
				if key=="all": assert(included.size()==40)
				elif key=="smooth": assert(included.size()==6)
				elif key=="technical": assert(included.size()==34)
				elif key=="new": assert(included.size()==30 and included.min()>=10)
				elif key=="classic": assert(included.size()==10 and included.max()<10)
				else: assert(not included.is_empty())
				assert(app.events.track_index in included and str(app.events.filter_picker.text).ends_with("("+str(included.size())+")"))
				for index in range(40):
					assert(app.events.track_cards[index].visible==(index in included))
					if index not in included: continue
					var track: TrackDefinition = Catalog.tracks[index]
					if key in ["asphalt","dirt"]: assert(track.road_surface()==key)
					if key=="smooth": assert(track.smooth_road())
					if key=="technical": assert(not track.smooth_road())
					if key=="space": assert(CourseArt.spec(track.id).get("space",false))
				var random_button := app.menu.footer.get_node("RandomTrack") as Button
				assert(not random_button.disabled)
				app.events.track_shuffle = TrackShuffle.new(2000+filter)
				var seen: Array[int] = [app.events.track_index]
				var rolls := maxi(64,included.size()*2+5)
				for roll in range(rolls):
					if seen.size()==included.size(): seen.clear()
					var before: int = app.events.track_index
					random_button.pressed.emit()
					assert(app.events.track_index in included and app.events.track_index!=before)
					assert(not app.events.track_index in seen,"Random completes the visible roster before repeating")
					seen.append(app.events.track_index)
					assert(app.events.preview.track==Catalog.tracks[app.events.track_index])
				for frame in range(8): await process_frame
				var selected_button: Button = app.events.buttons[app.events.track_index]
				var list_scroll: MenuScroll = app.events.detail_scroll.get_parent().get_child(0)
				var shown := selected_button.get_global_rect().intersection(list_scroll.get_global_rect())
				var minimum_visible := minf(list_scroll.size.y,minf(selected_button.size.y,app.menu.ui.row_height()))
				if not selected_button.has_focus() or shown.size.y<minimum_visible-1:
					print("RANDOM_FOCUS_DIAGNOSTIC ",{"mobile":mobile,"mode":mode,"filter":key,"selected":app.events.track_index,"focus":selected_button.has_focus(),"button":selected_button.get_global_rect(),"scroll":list_scroll.get_global_rect(),"scroll_y":list_scroll.scroll_vertical,"max":list_scroll.get_v_scroll_bar().max_value,"page":list_scroll.get_v_scroll_bar().page,"shown":shown})
				assert(selected_button.has_focus() and shown.size.y>=minimum_visible-1,"random selection stays focused and visible after layout/focus scrolling")
				assert(app.events.info.text.contains(I18n.t("route.description."+Catalog.tracks[app.events.track_index].id)))
				reports.append({"mobile":mobile,"mode":mode,"filter":key,"tracks":included.size(),"random_picks":rolls,"random_selected_visible":true})
				if "--capture" in OS.get_cmdline_user_args() and mode=="quick" and key in ["smooth","technical","dirt"]:
					for frame in range(8): await process_frame
					await RenderingServer.frame_post_draw
					var path := "res://reports/filter-%s-%s.png"%["phone" if mobile else "desktop",key]
					assert(root.get_texture().get_image().save_png(path)==OK)
	# Actual menu/filter/mode rebuilds retain an unfinished tour.
	app.events.track_shuffle = TrackShuffle.new(405)
	app.events.filter_index = EventMenu.FILTERS.find("classic")
	app.events.show_event()
	app.events.select_random_track()
	app.events.select_random_track()
	var classic: Array[int] = app.events.visible_tracks.duplicate()
	var key: String = str(app.events.track_shuffle.normalized(classic))
	var pending: Array[int] = app.events.track_shuffle.remaining[key].duplicate()
	pick(app.events.filter_picker,EventMenu.FILTERS.find("new"))
	app.events.select_random_track()
	pick(app.events.filter_picker,EventMenu.FILTERS.find("classic"))
	assert(app.events.track_shuffle.remaining[key]==pending,"returning from another filter retains the unfinished classic tour")
	app.events.mode = "trial"
	app.events.show_event()
	assert(app.events.track_shuffle.remaining[key]==pending,"Quick/Trial share the same session tour")
	app.events.select_random_track()
	assert(app.events.track_index==pending[-1])
	pending.pop_back()
	var manual: int = pending[0]
	app.events.buttons[manual].pressed.emit()
	pending.erase(manual)
	assert(app.events.track_shuffle.remaining[key]==pending,"manual card selection counts as a visit")
	app.events.select_random_track()
	assert(app.events.track_index==pending[-1])
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
	file.store_string(JSON.stringify({"passed":true,"cases":reports,"filtered_start_track":Catalog.tracks[expected].id,"boundary":"Actual desktop/mobile-mode widgets, nine filters in Quick Race and Trial, 64 or more random picks per case, complete nonrepeating tours, preserved filter/mode queues and manual visits, visible random focus after layout and a real filtered dirt launch with changed race options. Native captures use a desktop renderer with phone layout overrides."},"\t")+"\n")
	file.close()
	print("EVENT_FILTERS_SHUFFLED_TOURS_MANUAL_VISITS_COMPACT_PHONE_AND_FILTERED_LAUNCH_PASS cases=",reports.size())
	quit()

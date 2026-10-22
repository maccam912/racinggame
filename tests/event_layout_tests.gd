extends SceneTree
## Actual layout geometry must fit the safe frame at every supported scale.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	Catalog.load_all()
	root.mode = Window.MODE_WINDOWED
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var app: Node = load("res://game/client_app.gd").new()
	# Match the other layout fixtures: suppress saved display-mode application.
	app.capture_path = "user://unused-event-layout.png"
	app.capture_frame = 1000000000
	root.add_child(app)
	await process_frame
	var folder := "user://tests/event-layout-"+RaceSetup.uuid()
	app.data = AppData.new(folder,false)
	app.menu.settings = app.data.settings
	app.data.profile.first_run_complete = true
	app.data.settings.reduce_motion = true
	var cases: Array[Dictionary] = []
	for mobile: bool in [false,true]:
		for size: Vector2i in [Vector2i(1280,720),Vector2i(1280,800),Vector2i(1680,720),Vector2i(960,720)]:
			root.size = size
			app.data.mobile = mobile
			app.menu.mobile_override = mobile
			app.menu.logical_unit_override = 1.5 if mobile else 1.0
			for scale: int in [90,100,110,125,150]:
				app.data.settings.ui_scale = scale
				for mode: String in ["quick","trial"]:
					if "--narrow-probe" in OS.get_cmdline_user_args() and (not mobile or size!=Vector2i(960,720) or scale!=125): continue
					app.events.mode = mode
					app.events.track_index = Catalog.tracks.size()-1
					app.events.show_event()
					assert(is_equal_approx(app.menu.ui.scale,float(scale)/100),"the fixture must apply the requested scale to actual controls")
					app.events.buttons[Catalog.tracks.size()-1].grab_focus()
					for frame in range(8): await process_frame
					var width := minf(size.x*.9,size.y*16.0/9*.9)
					var left := (size.x-width)*.5
					var right := left+width
					var details: Rect2 = app.events.detail_scroll.get_global_rect()
					if details.position.x<left-1 or details.end.x>right+1:
						print("EVENT_LAYOUT_WINDOW_DIAGNOSTIC ",{"requested":size,"root_size":root.size,"visible":root.get_visible_rect(),"canvas":root.content_scale_size,"scale_mode":root.content_scale_mode,"window_mode":root.mode,"safe_frame_width":app.menu.safe_frame_width(),"frame":app.menu.frame.get_global_rect()})
						for child: Control in app.menu.column.get_children():
							print("EVENT_LAYOUT_CHILD ",child.get_class()," minimum=",child.get_combined_minimum_size()," size=",child.size)
						for child: Control in app.events.detail_scroll.get_parent().get_children():
							print("EVENT_LAYOUT_WORKSPACE ",child.get_class()," minimum=",child.get_combined_minimum_size()," size=",child.size)
					assert(details.position.x>=left-1 and details.end.x<=right+1,"event detail panel escapes safe frame: mobile=%s size=%s scale=%s rect=%s right=%s"%[mobile,size,scale,details,right])
					var button: Rect2 = app.events.buttons[Catalog.tracks.size()-1].get_global_rect()
					assert(button.position.x>=left-1 and button.end.x<=right+1,"highest course button must fit horizontally")
					assert(app.events.track_index==Catalog.tracks.size()-1 and app.events.buttons[Catalog.tracks.size()-1].has_focus())
					cases.append({"mobile":mobile,"viewport":[size.x,size.y],"ui_scale":scale,"mode":mode,"detail_right":details.end.x,"safe_right":right})
	assert(cases.size()==(2 if "--narrow-probe" in OS.get_cmdline_user_args() else 80))
	app.queue_free()
	await create_timer(.5).timeout
	assert(AppData.remove_tree(ProjectSettings.globalize_path(folder))==OK)
	DirAccess.make_dir_recursive_absolute("res://reports")
	var file := FileAccess.open("res://reports/event-layout-"+("headless" if DisplayServer.get_name()=="headless" else "native")+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":true,"display_server":DisplayServer.get_name(),"renderer":RenderingServer.get_current_rendering_method(),"cases":cases,"boundary":"Actual Control geometry in the current display server; native 150-percent references are separate."},"\t")+"\n")
	file.close()
	print("EVENT_SELECTION_SAFE_FRAME_FOCUS_AND_LAST_COURSE_LAYOUTS_PASS cases=",cases.size())
	quit()

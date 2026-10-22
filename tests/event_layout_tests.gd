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
		for size: Vector2i in [Vector2i(1280,720),Vector2i(1280,800),Vector2i(1680,720),Vector2i(960,720),Vector2i(884,398)]:
			if not mobile and size==Vector2i(884,398): continue
			root.size = size
			app.data.mobile = mobile
			app.menu.mobile_override = mobile
			app.menu.logical_unit_override = 1.5 if mobile and size.y>=500 else 1.0
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
					var list_scroll := app.events.detail_scroll.get_parent().get_child(0) as MenuScroll
					var shown := button.intersection(list_scroll.get_global_rect())
					assert(list_scroll.size.y>=48*app.menu.ui.unit,"the course list retains at least one full touch row")
					assert(shown.size.y>=minf(button.size.y,app.menu.ui.row_height())-1,"the selected course button must remain visible after focus scrolling")
					for footer_button: Button in app.menu.footer.find_children("*","Button",true,false):
						assert(root.get_visible_rect().encloses(footer_button.get_global_rect()),"Random Track and Start remain usable inside every supported viewport")
					assert(app.events.track_index==Catalog.tracks.size()-1 and app.events.buttons[Catalog.tracks.size()-1].has_focus())
					# Interior selection also needs a fresh layout; end clamping can hide a stale scroll.
					app.events.track_index = 30
					app.events.show_event()
					for frame in range(8): await process_frame
					button = app.events.buttons[30].get_global_rect()
					list_scroll = app.events.track_list
					shown = button.intersection(list_scroll.get_global_rect())
					assert(app.events.buttons[30].has_focus() and shown.size.y>=minf(list_scroll.size.y,minf(button.size.y,app.menu.ui.row_height()))-1,"initial interior course remains visible after layout")
					details = app.events.detail_scroll.get_global_rect()
					assert(details.position.x>=left-1 and details.end.x<=right+1)

					if mobile:
						var footer_y: float = app.menu.footer.get_child(0).get_global_rect().position.y
						for control: Control in app.menu.footer.get_children():
							assert(absf(control.get_global_rect().position.y-footer_y)<1,"footer stays on one row")
						for card_button: Button in app.events.buttons:
							var font := card_button.get_theme_font("font")
							var point_size := card_button.get_theme_font_size("font_size")
							assert(point_size>=roundi(16*app.menu.ui.unit))
							var skin := card_button.get_theme_stylebox("normal")
							var available: float = card_button.size.x-skin.get_content_margin(SIDE_LEFT)-skin.get_content_margin(SIDE_RIGHT)-2*app.menu.ui.unit
							for word: String in card_button.text.split(" "):
								assert(font.get_string_size(word,HORIZONTAL_ALIGNMENT_LEFT,-1,point_size).x<=available+.5,"whole words fit with outline margin")
						for header: Control in app.menu.headers:
							assert(header.get_global_rect().position.x>=left-1 and header.get_global_rect().end.x<=right+1)
					cases.append({"mobile":mobile,"viewport":[size.x,size.y],"ui_scale":scale,"mode":mode,"detail_right":details.end.x,"safe_right":right,"initial_courses":[Catalog.tracks.size()-1,30],"body_height":app.menu.body.size.y,"header_rows":app.menu.headers.size(),"footer_height":app.menu.footer.get_parent().size.y})
					if "--capture" in OS.get_cmdline_user_args() and mode=="quick" and (size in [Vector2i(1280,720),Vector2i(960,720)] and scale==150 or size==Vector2i(884,398) and scale in [100,150]):
						app.menu.footer.get_node("RandomTrack").pressed.emit()
						for frame in range(8): await process_frame
						await RenderingServer.frame_post_draw
						var path := "res://reports/random-track-%s-%dx%d.png"%["mobile" if mobile else "desktop",size.x,size.y]
						if size==Vector2i(884,398): path = path.trim_suffix(".png")+"-scale"+str(scale)+".png"
						assert(root.get_texture().get_image().save_png(path)==OK)
	assert(cases.size()==(2 if "--narrow-probe" in OS.get_cmdline_user_args() else 90))
	app.queue_free()
	await create_timer(.5).timeout
	assert(AppData.remove_tree(ProjectSettings.globalize_path(folder))==OK)
	DirAccess.make_dir_recursive_absolute("res://reports")
	var file := FileAccess.open("res://reports/event-layout-"+("headless" if DisplayServer.get_name()=="headless" else "native")+".json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":true,"display_server":DisplayServer.get_name(),"renderer":RenderingServer.get_current_rendering_method(),"cases":cases,"boundary":"Actual Control geometry in the current display server, all forty mobile name-word widths with outline margin, minimum fonts, one-row mobile footer and fixed-header safe frame and both last/interior initial selections; native references are separate."},"\t")+"\n")
	file.close()
	print("EVENT_SELECTION_SAFE_FRAME_FOCUS_AND_LAST_COURSE_LAYOUTS_PASS cases=",cases.size())
	quit()

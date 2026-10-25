extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	var app: Node = load("res://game/client_app.gd").new()
	app.capture_path = "user://unused-garage-portrait.png"
	app.capture_frame = 1000000000
	root.add_child(app)
	await process_frame
	var folder := "user://tests/garage-portrait-"+RaceSetup.uuid()
	app.data = AppData.new(folder,false)
	app.data.settings.reduce_motion = true
	app.menu.settings = app.data.settings
	for mobile: bool in [false,true]:
		root.size = Vector2i(884,398) if mobile else Vector2i(1280,720)
		app.data.mobile = mobile
		app.menu.mobile_override = mobile
		app.menu.logical_unit_override = 1.0
		app.data.settings.ui_scale = 150 if mobile else 100
		for index in range(Catalog.cars.size()):
			app.data.profile.selected_car = 0
			app.data.profile.selected_paint = 2
			app.show_garage("quick")
			for i in range(5): await process_frame
			var portrait := app.menu.root.find_child("CarPortrait_"+Catalog.cars[index].id,true,false) as TextureButton
			assert(portrait != null and portrait.texture_normal.get_size()==Vector2(384,216))
			assert(portrait.focus_mode==Control.FOCUS_NONE, "each car keeps one named keyboard choice")
			app.menu.reveal_later(portrait)
			for i in range(8): await process_frame
			assert(portrait.get_global_rect().end.x <= app.menu.frame.get_global_rect().end.x+1)
			var center := portrait.get_global_rect().get_center()
			for pressed: bool in [true,false]:
				var event := InputEventMouseButton.new()
				event.button_index = MOUSE_BUTTON_LEFT
				event.pressed = pressed
				event.position = center
				event.global_position = center
				root.push_input(event,true)
			await process_frame
			assert(int(app.data.profile.selected_car)==index, "picture click selects its car")
			assert(app.data.profile.selected_paint==2 and app.stage.car.model_id==Catalog.cars[index].mesh_id)
		for paint_index in range(8):
			var paint_picker: Variant = app.menu.root.find_child("GaragePaintPicker",true,false)
			assert(app.menu.footer.get_global_rect().grow(1).encloses(paint_picker.get_global_rect()),"paint is reachable without scrolling past eight cars")
			if mobile:
				paint_picker.open_sheet()
				for i in range(3): await process_frame
				paint_picker.choose(paint_index)
			else:
				paint_picker.item_selected.emit(paint_index)
			for i in range(8): await process_frame
			assert(app.data.profile.selected_paint==paint_index and app.data.profile.selected_car==7)
			assert(root.gui_get_focus_owner().name=="GaragePaintPicker","choice returns focus to the visible paint shortcut")
		if "--capture" in OS.get_cmdline_user_args():
			app.data.profile.selected_car = 0
			app.show_garage("quick")
			for i in range(10): await process_frame
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://reports/garage-portraits-"+("phone" if mobile else "desktop")+".png")
	app.queue_free()
	await create_timer(.5).timeout
	assert(AppData.remove_tree(ProjectSettings.globalize_path(folder))==OK)
	print("GARAGE_EIGHT_ACTUAL_MODEL_PORTRAIT_CLICKS_PAINT_PRESERVATION_DESKTOP_PHONE_PASS")
	quit()

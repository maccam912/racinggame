extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	Catalog.load_all()
	assert(UIIcons.entries().size()==60)
	for row: Dictionary in UIIcons.entries().values():
		var texture := UIIcons.texture(row.id)
		assert(texture.get_size()==Vector2(64,64) and texture.get_image().has_mipmaps(),row.id)
	var app: Node = load("res://game/client_app.gd").new()
	root.add_child(app)
	await process_frame
	var folder := "user://tests/ui-icons-"+str(Time.get_ticks_usec())
	app.data = AppData.new(folder,false)
	app.data.profile.selected_car = 0
	app.data.settings.bindings = BindingBook.defaults()
	BindingBook.apply(app.data.settings.bindings)
	app.show_garage("trial")
	await process_frame
	assert(app.garage_car_buttons.size()==4 and app.garage_paint_buttons.size()==8)
	for index in range(4): assert(app.garage_car_buttons[index].icon==UIIcons.texture("car_"+Catalog.cars[index].id))
	var bars: Array[Node] = app.menu.root.find_children("*","ProgressBar",true,false)
	assert(bars.size()==8)
	for index in range(4):
		assert(bars[index*2].value==Catalog.cars[index].acceleration and bars[index*2].max_value==15)
		assert(bars[index*2+1].value==Catalog.cars[index].grip and bars[index*2+1].max_value==22)
	var shoulder := InputEventJoypadButton.new()
	shoulder.button_index = JOY_BUTTON_RIGHT_SHOULDER
	shoulder.pressed = true
	Input.parse_input_event(shoulder)
	Input.flush_buffered_events()
	await process_frame
	assert(app.data.profile.selected_car==1 and app.stage.car.model_id=="needle" and app.garage_mode=="trial")
	shoulder.button_index = JOY_BUTTON_LEFT_SHOULDER
	Input.parse_input_event(shoulder)
	Input.flush_buffered_events()
	await process_frame
	assert(app.data.profile.selected_car==0)
	Input.parse_input_event(shoulder)
	Input.flush_buffered_events()
	await process_frame
	assert(app.data.profile.selected_car==3 and app.stage.car.model_id=="sunset","shoulder cycling wraps while preserving mode")
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(30,0)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	app.stage.interactive = true
	var angle: float = app.stage.rotation_offset
	app.stage.preview_input(motion)
	assert(is_equal_approx(app.stage.rotation_offset,angle-.24))
	app.stage.interactive = false
	angle = app.stage.rotation_offset
	app.stage.preview_input(motion)
	assert(app.stage.rotation_offset==angle,"preview input is scoped to Garage")
	app.data.profile.selected_car = 0
	var track: TrackDefinition = Catalog.tracks[0]
	var key: String = app.data.record_key("trial",track.id,"comet")
	app.data.records.times[key] = {"time":Medals.thresholds(track.length)[0]}
	app.events.mode = "trial"
	app.events.show_event()
	assert(app.events.medal_icons[0].texture==UIIcons.texture("medal_gold"))
	app.events.select_track(2)
	var ghost_toggle: CheckButton
	for toggle: CheckButton in app.menu.root.find_children("*","CheckButton",true,false):
		if toggle.text==I18n.t("event.ghost"): ghost_toggle = toggle
	assert(ghost_toggle!=null)
	ghost_toggle.button_pressed = false
	app.show_garage("trial")
	app.events.show_event()
	assert(not app.events.ghost and app.events.track_index==2,"back/car selection retains the trial ghost and course choices")
	app.data.profile.selected_car = 1
	app.events.show_event()
	assert(app.events.medal_icons[0].texture==UIIcons.texture("medal_none"),"track medal follows exact selected car/content record key")
	app.data.mobile = true
	app.data.settings.ui_scale = 150
	app.menu.mobile_override = true
	app.menu.logical_unit_override = 1.5
	app.events.show_event()
	app.events.info.custom_minimum_size.y = 2000 # Exercise overflow without depending on Dummy font metrics.
	for index in range(4): await process_frame
	var details: MenuScroll = app.events.detail_scroll
	assert(details.get_v_scroll_bar().max_value>details.get_v_scroll_bar().page)
	var start := InputEventScreenTouch.new()
	start.index = 4
	start.position = details.get_global_rect().get_center()
	start.pressed = true
	root.push_input(start,true)
	var drag := InputEventScreenDrag.new()
	drag.index = 4
	drag.position = start.position-Vector2(0,100)
	drag.relative = Vector2(0,-100)
	root.push_input(drag,true)
	var release := start.duplicate() as InputEventScreenTouch
	release.pressed = false
	release.position = drag.position
	root.push_input(release,true)
	assert(details.scroll_vertical>0,"large-text touch swipe reaches the independently scrolling course description")
	app.queue_free()
	await process_frame
	await create_timer(.5).timeout
	assert(AppData.remove_tree(ProjectSettings.globalize_path(folder))==OK)
	print("ORIGINAL_ICON_IMPORT_STAT_VALUES_REAL_SHOULDER_WRAP_SCOPED_PREVIEW_AND_CAR_SPECIFIC_MEDALS_PASS")
	quit()

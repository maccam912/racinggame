extends SceneTree

func _initialize() -> void:
	call_deferred("run")

func key(code: int,pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func pad(code: int,pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.device = 0
	event.button_index = code
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func touch(id: int,pressed: bool,position: Vector2,canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = id
	event.pressed = pressed
	event.position = position
	event.canceled = canceled
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func settle() -> void:
	await process_frame
	await process_frame

func run() -> void:
	root.size = Vector2i(1280,720)
	await settle()
	var app: Node = load("res://game/client_app.gd").new()
	root.add_child(app)
	await settle()
	app.data = AppData.new("user://tests/touch-editor-"+str(Time.get_ticks_usec()),true)
	app.start_drive({"mode":"quick","opponents":0})
	await physics_frame
	app.drive.show_pause()
	app.settings_page.show_tab("touch",app.show_pause)
	await settle()
	var sections: Variant = app.menu.root.find_child("settings_sections",true,false)
	assert(sections!=null and sections.item_count==8 and sections.selected==4,"phone sections use a compact, keyboard-accessible selector")
	var original: RaceDrive = app.drive
	var position := original.state.position
	var ticks: int = original.session.elapsed_ticks
	app.show_touch_editor()
	await settle()
	var editor: TouchLayoutEditor = app.touch_editor
	assert(app.page=="touch_layout" and not app.menu.visible and not editor.previewing)
	assert(editor.sample.paused and original.paused and root.disable_3d)
	assert(not app.presentation.visible and app.presentation.viewport.render_target_update_mode==SubViewport.UPDATE_DISABLED,"editor suspends the underlying world render")
	assert(editor.sample.get_world_3d()!=original.get_world_3d(),"sample has its own collision/render world")
	var previous: Dictionary = app.data.settings.touch_layouts.duplicate(true)
	var initial: Rect2 = editor.controls.steer
	var center: Vector2 = initial.get_center()*editor.unit
	touch(7,true,center)
	assert(editor.pointer==7 and editor.selected=="steer")
	var drag := InputEventScreenDrag.new()
	drag.index = 7
	drag.position = center-Vector2(0,32*editor.unit)
	Input.parse_input_event(drag)
	Input.flush_buffered_events()
	touch(7,false,drag.position,true)
	assert(editor.pointer==-1 and editor.controls.steer.position.y<initial.position.y)
	assert(TouchDriving.legal_layout(editor.controls,editor.safe))
	editor.cancel()
	await settle()
	assert(app.touch_editor==null and app.data.settings.touch_layouts==previous and root.disable_3d and app.presentation.visible and app.presentation.viewport.render_target_update_mode==SubViewport.UPDATE_ALWAYS,"Cancel does not mutate settings and restores the world presentation")
	assert(app.drive==original and original.paused and original.state.position==position)
	app.show_touch_editor()
	await settle()
	editor = app.touch_editor
	editor.selected = "steer"
	editor.buttons.steer.grab_focus()
	key(KEY_ENTER,true)
	key(KEY_ENTER,false)
	await settle()
	assert(editor.moving,"Confirm selects an outline for keyboard movement")
	var prior_y: float = editor.controls.steer.position.y
	key(KEY_UP,true)
	await settle()
	key(KEY_UP,false)
	assert(editor.controls.steer.position.y<prior_y,"keyboard confirm/move path uses menu actions")
	key(KEY_ESCAPE,true)
	key(KEY_ESCAPE,false)
	await settle()
	assert(not editor.moving and app.touch_editor==editor,"Back ends move mode without leaving the editor")
	editor.buttons.steer.grab_focus()
	pad(JOY_BUTTON_A,true)
	pad(JOY_BUTTON_A,false)
	await settle()
	assert(editor.moving)
	prior_y = editor.controls.steer.position.y
	pad(JOY_BUTTON_DPAD_UP,true)
	await settle()
	pad(JOY_BUTTON_DPAD_UP,false)
	assert(editor.controls.steer.position.y<prior_y,"controller directions nudge the selected outline")
	pad(JOY_BUTTON_B,true)
	pad(JOY_BUTTON_B,false)
	await settle()
	assert(not editor.moving and app.touch_editor==editor)
	var phone_key: String = editor.key
	var phone_rect: Rect2 = editor.controls.steer
	root.size = Vector2i(1024,768)
	await settle()
	assert(editor.key.contains("tablet") and TouchDriving.legal_layout(editor.controls,editor.safe))
	root.size = Vector2i(1280,720)
	await settle()
	assert(editor.key==phone_key and editor.controls.steer.position.distance_to(phone_rect.position)<.001,"resize restores the phone draft without saving it")
	app.data.store.fail_component = "settings"
	app.data.store.fail_stage = "before_replace"
	editor.save_layout()
	assert(app.touch_editor==editor and app.data.settings.touch_layouts==previous and editor.status.text==I18n.t("data.save_failed"))
	app.data.store.fail_stage = ""
	var saved_centers := TouchLayoutBook.centers(editor.controls,editor.safe)
	var profile: String = editor.key
	editor.save_layout()
	await settle()
	assert(app.touch_editor==null and app.data.settings.touch_layouts[profile]==saved_centers)
	assert(original.paused and original.session.elapsed_ticks==ticks and original.state.position==position)
	app.show_touch_editor()
	await settle()
	editor = app.touch_editor
	var expected: Rect2 = editor.controls.steer
	editor.begin_preview()
	await settle()
	assert(editor.previewing and not editor.sample.paused and not editor.toolbar.visible)
	assert(editor.sample.session.mode=="layout_preview" and editor.sample.network==null)
	assert(editor.sample.touch.controls.steer.position.distance_to(expected.position*editor.unit)<.0001)
	var preview_steer: Vector2 = editor.sample.touch.controls.steer.get_center()
	touch(9,true,preview_steer)
	assert(editor.sample.touch.captures.has(9),"preview receives actual viewport touch events")
	for frame: int in range(200):
		await physics_frame
	assert(editor.sample.state.speed()>1.0,"preview input drives the real chassis")
	touch(9,false,preview_steer)
	# The sample drives for the full noncompetitive interval. The paused event
	# remains byte-for-byte untouched and no preview result reaches AppData.
	for frame: int in range(2050):
		if not editor.previewing:
			break
		await physics_frame
	assert(not editor.previewing and editor.sample.paused and editor.toolbar.visible,"30-second preview returns to editor")
	assert(original.paused and original.session.elapsed_ticks==ticks and original.state.position==position)
	assert(app.data.profile.races_completed==0 and app.data.records.committed.is_empty())
	editor.begin_preview()
	await settle()
	key(KEY_ESCAPE,true)
	key(KEY_ESCAPE,false)
	await settle()
	assert(not editor.previewing and app.touch_editor==editor,"Back from practice returns to editor")
	editor.cancel()
	await settle()
	# Restore affects only the active layout profile; a failed write is reverted.
	app.data.settings.touch_layouts["other"] = {"brake":[.8,.8]}
	previous = app.data.settings.touch_layouts.duplicate(true)
	app.data.store.fail_stage = "before_replace"
	app.settings_page.restore_layout()
	assert(app.data.settings.touch_layouts==previous)
	app.data.store.fail_stage = ""
	app.settings_page.restore_layout()
	assert(not app.data.settings.touch_layouts.has(profile) and app.data.settings.touch_layouts.has("other"))
	# An online race cannot alter layout geometry through editor, row or restore.
	app.network = NetworkClient.new()
	app.add_child(app.network)
	original.network = app.network
	app.settings_page.show_tab("touch",app.show_pause)
	app.show_touch_editor()
	assert(app.touch_editor==null)
	previous = app.data.settings.touch_layouts.duplicate(true)
	app.settings_page.restore_layout()
	app.settings_page.restore_this_tab()
	assert(app.data.settings.touch_layouts==previous)
	original.network = null
	app.queue_free()
	await settle()
	print("Touch editor: real pointer drag/cancel, keyboard move, transactional Save/Cancel/Restore, isolated 30-second practice, paused-race preservation and online lock pass")
	quit()

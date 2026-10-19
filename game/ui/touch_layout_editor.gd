class_name TouchLayoutEditor
extends CanvasLayer

signal closed

var app: Node
var canvas := Control.new()
var container := SubViewportContainer.new()
var viewport := SubViewport.new()
var outlines := Control.new()
var toolbar := PanelContainer.new()
var practice_bar := HBoxContainer.new()
var status: Label
var practice_time: Label
var save_button: Button
var preview_button: Button
var sample: RaceDrive
var buttons: Dictionary = {}
var controls: Dictionary = {}
var draft_profiles: Dictionary = {}
var safe: Rect2
var unit: float = 1.0
var key: String = ""
var selected: String = ""
var moving: bool = false
var pointer: int = -1
var drag_offset := Vector2.ZERO
var previewing: bool = false
var host_viewport: Viewport
var previous_disable_3d: bool = false

func _ready() -> void:
	layer = 10
	host_viewport = get_viewport()
	previous_disable_3d = host_viewport.disable_3d
	host_viewport.disable_3d = true
	draft_profiles = app.data.settings.touch_layouts.duplicate(true)
	canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(canvas)
	container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	container.stretch = true
	canvas.add_child(container)
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	container.add_child(viewport)
	outlines.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	outlines.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(outlines)
	var ui := UIFactory.new(get_viewport(),app.data.settings)
	canvas.theme = ui.theme
	var column := VBoxContainer.new()
	toolbar.add_child(column)
	status = ui.paragraph(help_text())
	column.add_child(status)
	var actions := HFlowContainer.new()
	column.add_child(actions)
	save_button = ui.button(I18n.t("button.save"),save_layout)
	preview_button = ui.button(I18n.t("touch.preview"),begin_preview)
	for button: Button in [save_button,ui.button(I18n.t("button.cancel"),cancel),preview_button,ui.button(I18n.t("button.restore"),restore_layout)]:
		actions.add_child(button)
	canvas.add_child(toolbar)
	practice_time = ui.label("")
	practice_bar.add_child(ui.panel(practice_time))
	practice_bar.add_child(ui.button(I18n.t("touch.return_editor"),finish_preview))
	canvas.add_child(practice_bar)
	practice_bar.hide()
	get_viewport().size_changed.connect(reflow)
	reflow()
	replace_sample(false)
	focus_ready.call_deferred("save")

func focus_ready(which: String) -> void:
	var control: Button = save_button if which=="save" else preview_button
	if is_inside_tree() and is_instance_valid(control) and control.is_inside_tree() and control.is_visible_in_tree():
		control.grab_focus()

func help_text() -> String:
	return I18n.t("touch.editor_help_touch" if app.touch_demo or OS.has_feature("mobile") else "touch.editor_help")

func automatic() -> bool:
	return bool(app.data.settings.touch_auto_accelerate)

func steering() -> String:
	return str(app.data.settings.steering_style)

func mirrored() -> bool:
	return bool(app.data.settings.left_handed)

func reflow() -> void:
	if not is_inside_tree():
		return
	pointer = -1
	moving = false
	if not controls.is_empty() and TouchDriving.legal_layout(controls,safe):
		draft_profiles = TouchLayoutBook.with_profile(draft_profiles,key,controls,safe)
	var geometry := TouchDriving.safe_geometry(get_viewport().get_visible_rect().size)
	unit = geometry.unit
	safe = geometry.safe
	key = TouchLayoutBook.profile_key(safe,automatic(),steering(),mirrored())
	var base := TouchDriving.build_layout(safe,automatic(),steering(),float(app.data.settings.button_size)/100,mirrored())
	var resolved := TouchLayoutBook.resolve(base,safe,draft_profiles.get(key,{}))
	controls = resolved.controls
	for button: Button in buttons.values():
		button.hide()
		button.queue_free()
	buttons.clear()
	for action: String in controls:
		var button := Button.new()
		button.text = I18n.t("touch.control."+action)
		button.add_theme_font_size_override("font_size",roundi(16*unit))
		for state: String in ["normal","hover","pressed"]:
			var style := StyleBoxFlat.new()
			style.bg_color = Color(.04,.10,.14,.35)
			style.border_color = UIFactory.CREAM
			style.set_border_width_all(maxi(2,roundi(unit)))
			button.add_theme_stylebox_override(state,style)
		button.pressed.connect(func() -> void:
			selected = action
			moving = not moving
			status.text = I18n.t("touch.editor_nudge" if moving else "touch.editor_help"))
		outlines.add_child(button)
		buttons[action] = button
	toolbar.position = Vector2((safe.position.x+safe.size.x*.12)*unit,(safe.position.y+16)*unit)
	toolbar.size = Vector2(safe.size.x*.76*unit,0)
	for button: Node in toolbar.find_children("*","Button",true,false):
		button.custom_minimum_size.y = 48*unit
	practice_bar.position = Vector2((safe.position.x+safe.size.x*.30)*unit,(safe.position.y+72)*unit)
	update_outlines()
	if previewing and is_instance_valid(sample):
		sample.touch.layouts = TouchLayoutBook.with_profile(draft_profiles,key,controls,safe)
		sample.touch.rebuild.call_deferred()
	if resolved.reset:
		status.text = I18n.t("touch.layout_reset")

func update_outlines() -> void:
	var legal := not controls.is_empty() and TouchDriving.legal_layout(controls,safe)
	save_button.disabled = not legal
	preview_button.disabled = not legal
	for action: String in controls:
		buttons[action].position = controls[action].position*unit
		buttons[action].size = controls[action].size*unit
		buttons[action].modulate = Color.WHITE if legal else UIFactory.CORAL
	if not legal:
		status.text = I18n.t("touch.editor_invalid")

func move_selected(center: Vector2) -> void:
	if not controls.has(selected):
		return
	var dimensions: Vector2 = controls[selected].size
	var clamped := TouchLayoutBook.snapped_center(safe,center,dimensions,selected)
	controls[selected] = Rect2(clamped-dimensions/2,dimensions)
	update_outlines()

func pointer_down(id: int,at: Vector2) -> bool:
	if previewing or pointer!=-1:
		return false
	for action: String in controls:
		if controls[action].has_point(at/unit):
			selected = action
			moving = false
			pointer = id
			drag_offset = controls[action].get_center()-at/unit
			buttons[action].grab_focus()
			return true
	return false

func _input(event: InputEvent) -> void:
	if event is InputEventMouse and event.device == -1:
		# Godot may generate a mouse event for the same finger. It must not
		# capture a second pointer or click an outline after the drag releases.
		if pointer!=-1 or controls.values().any(func(rect: Rect2) -> bool: return rect.has_point(event.position/unit)):
			get_viewport().set_input_as_handled()
		return
	if previewing:
		if event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause"):
			finish_preview.call_deferred()
			get_viewport().set_input_as_handled()
		return
	var handled := false
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled:
			handled = pointer_down(event.index,event.position)
		elif pointer==event.index:
			pointer = -1
			handled = true
	elif event is InputEventScreenDrag and pointer==event.index:
		move_selected(event.position/unit+drag_offset)
		handled = true
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if event.pressed:
			handled = pointer_down(-2,event.position)
		elif pointer==-2:
			pointer = -1
			handled = true
	elif event is InputEventMouseMotion and pointer==-2:
		move_selected(event.position/unit+drag_offset)
		handled = true
	elif moving and event.is_action_pressed("ui_cancel"):
		moving = false
		status.text = help_text()
		handled = true
	elif moving and event is InputEventAction and event.pressed:
		var direction: Vector2 = {"ui_left":Vector2.LEFT,"ui_right":Vector2.RIGHT,"ui_up":Vector2.UP,"ui_down":Vector2.DOWN}.get(event.action,Vector2.ZERO)
		if direction!=Vector2.ZERO:
			move_selected(controls[selected].get_center()+direction*8)
			handled = true
	if handled:
		get_viewport().set_input_as_handled()

func restore_layout() -> void:
	draft_profiles.erase(key)
	controls.clear()
	reflow()
	status.text = help_text()

func save_layout() -> void:
	if controls.is_empty() or not TouchDriving.legal_layout(controls,safe):
		return
	var previous: Dictionary = app.data.settings.touch_layouts
	app.data.settings.touch_layouts = TouchLayoutBook.with_profile(draft_profiles,key,controls,safe)
	if app.data.save_settings()!=OK:
		app.data.settings.touch_layouts = previous
		status.text = I18n.t("data.save_failed")
		return
	closed.emit()

func cancel() -> void:
	closed.emit()

func replace_sample(practice: bool) -> void:
	var world: TrackWorld
	if is_instance_valid(sample):
		world = sample.world
		sample.remove_child(world)
		viewport.remove_child(sample)
		sample.queue_free()
	sample = RaceDrive.new()
	sample.app_data = app.data
	sample.config = {"mode":"layout_preview","track":0,"car":int(app.data.profile.selected_car),"paint":int(app.data.profile.selected_paint),"opponents":0,"laps":3,"contact":false}
	sample.prepared_world = world
	sample.external_menus = true
	sample.show_touch = true
	sample.reduce_motion = bool(app.data.settings.reduce_motion)
	sample.pause_requested.connect(func() -> void: finish_preview.call_deferred())
	sample.results_ready.connect(func() -> void: finish_preview.call_deferred())
	viewport.add_child(sample)
	sample.paused = not practice
	sample.ui.visible = practice
	sample.help_label.hide()
	sample.touch.enabled = practice
	if practice:
		sample.session.phase = RaceSession.Phase.COUNTDOWN
		sample.touch.layouts = TouchLayoutBook.with_profile(draft_profiles,key,controls,safe)
		sample.touch.rebuild()
		sample.driver.context_reset()

func begin_preview() -> void:
	if preview_button.disabled:
		return
	previewing = true
	moving = false
	pointer = -1
	toolbar.hide()
	outlines.hide()
	practice_bar.show()
	app.menu_repeat.clear_context()
	replace_sample(true)

func finish_preview() -> void:
	if not previewing:
		return
	previewing = false
	replace_sample(false)
	practice_bar.hide()
	toolbar.show()
	outlines.show()
	app.menu_repeat.clear_context()
	focus_ready.call_deferred("preview")

func _physics_process(_dt: float) -> void:
	if previewing and is_instance_valid(sample):
		practice_time.text = I18n.t("touch.preview_seconds",[maxi(0,30-sample.session.elapsed_ticks/60)])
		if sample.session.elapsed_ticks>=1800:
			finish_preview()

func _process(_dt: float) -> void:
	# Word wrapping can initially enlarge an unattached container before its
	# width is known. Shrink to the newly measured content after layout settles.
	toolbar.size.y = toolbar.get_combined_minimum_size().y

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]:
		pointer = -1
		moving = false
		finish_preview()

func _exit_tree() -> void:
	if is_instance_valid(host_viewport):
		host_viewport.disable_3d = previous_disable_3d

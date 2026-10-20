class_name RaceNameplates
extends Control
## Four native-resolution labels, with bounded environment visibility queries.

var drive: Node
var enabled: bool = true
var plates: Array[PanelContainer] = []
var captions: Array[Label] = []
var badges: Array[Label] = []
var rows: Array[HBoxContainer] = []
var plate_styles: Dictionary = {}
var style_context: String = ""
var visible_slots: Array[int] = []
var cooldown: float = 0

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_priority = 110 # After WorldPresentation synchronizes its render camera.
	for index in range(4):
		var panel := PanelContainer.new()
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		panel.add_child(row)
		var badge := Label.new()
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		badge.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		badge.add_theme_font_override("font",RaceHUD.DISPLAY_FONT)
		badge.add_theme_color_override("font_outline_color",Color("101333"))
		badge.add_theme_constant_override("outline_size",1)
		row.add_child(badge)
		var label := Label.new()
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		label.add_theme_font_override("font",RaceHUD.HUD_FONT)
		label.add_theme_color_override("font_outline_color",Color("101333"))
		label.add_theme_constant_override("outline_size",1)
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		add_child(panel)
		plates.append(panel)
		captions.append(label)
		badges.append(badge)
		rows.append(row)


func plate_style(slot: int, factor: float) -> StyleBox:
	var context := str([factor,drive.hud.high_contrast,drive.hud.palette])
	if context!=style_context:
		plate_styles.clear()
		style_context = context
	var key := str(slot) if drive.hud.high_contrast else "chrome"
	if not plate_styles.has(key):
		var style: StyleBox = drive.hud.panel() if drive.hud.high_contrast else UIFactory.chrome_box("panel",factor)
		if style is StyleBoxFlat:
			style.border_color = drive.hud.rival_color(slot)
			style.set_border_width_all(2)
		style.content_margin_left = 12*factor
		style.content_margin_right = 10*factor
		style.content_margin_top = 3*factor
		style.content_margin_bottom = 3*factor
		plate_styles[key] = style
	return plate_styles[key]

func project(camera: Camera3D, point: Vector3, presentation: WorldPresentation = null) -> Variant:
	if camera.is_position_behind(point): return null
	var at := camera.unproject_position(point)
	if presentation:
		var bounds := presentation.image.get_global_rect()
		var pixels := Vector2(presentation.viewport.size)
		var factor := minf(bounds.size.x/pixels.x,bounds.size.y/pixels.y)
		at = bounds.position+(bounds.size-pixels*factor)/2+at*factor
	return at

func candidates(camera: Camera3D) -> Array[int]:
	var result: Array[int] = []
	var states: Dictionary = {}
	for rival: VehicleState in drive.hud.rivals:
		var distance: float = rival.position.distance_to(drive.state.position)
		if distance>=8 and distance<=80:
			states[rival.slot] = rival
			result.append(rival.slot)
	result.sort_custom(func(a: int,b: int) -> bool:
		var first: float = states[a].position.distance_squared_to(drive.state.position)
		var second: float = states[b].position.distance_squared_to(drive.state.position)
		return a<b if is_equal_approx(first,second) else first<second)
	var visible: Array[int] = []
	for slot: int in result:
		var target: Vector3 = states[slot].position+Vector3.UP*1.6
		if camera.is_position_behind(target): continue
		var ray := PhysicsRayQueryParameters3D.create(camera.global_position,target,3)
		if not camera.get_world_3d().direct_space_state.intersect_ray(ray).is_empty(): continue
		visible.append(slot)
		if visible.size()==4: break
	return visible

func _process(dt: float) -> void:
	for panel: PanelContainer in plates: panel.hide()
	if not enabled or not is_instance_valid(drive) or drive.result_sent or drive.paused or not drive.hud.is_visible_in_tree(): return
	var camera: Camera3D = drive.camera
	var presentation: WorldPresentation
	for item: Node in get_tree().get_nodes_in_group("world_presentations"):
		if item.visible:
			presentation = item
			camera = item.camera
			break
	cooldown -= dt
	if cooldown<=0:
		visible_slots = candidates(camera)
		cooldown = .1
	var index := 0
	var occupied: Array[Rect2] = []
	for audio: Node in get_tree().get_nodes_in_group("game_audio"):
		if audio.caption.visible: occupied.append(audio.caption.get_global_rect())
	for slot: int in visible_slots:
		var rival: VehicleState
		for value: VehicleState in drive.hud.rivals:
			if value.slot==slot: rival = value
		if rival==null: continue
		var distance := rival.position.distance_to(drive.state.position)
		if distance<8 or distance>80: continue
		var at: Variant = project(camera,rival.position+Vector3.UP*1.6,presentation)
		if at==null or not get_viewport_rect().grow(-20).has_point(at): continue
		var factor: float = drive.hud.ui_scale
		var label := captions[index]
		var record: Dictionary = drive.session.roster[slot]
		label.text = "%s%s" % [record.name,"  BOT" if record.get("bot",false) else ""]
		label.add_theme_font_size_override("font_size",maxi(16,roundi(16*factor)))
		label.add_theme_color_override("font_color",UIFactory.CREAM)
		badges[index].text = str(slot+1)
		badges[index].add_theme_font_size_override("font_size",label.get_theme_font_size("font_size"))
		badges[index].add_theme_color_override("font_color",drive.hud.rival_color(slot))
		rows[index].add_theme_constant_override("separation",roundi(6*factor))
		var panel := plates[index]
		panel.add_theme_stylebox_override("panel",plate_style(slot,factor))
		var text_width := RaceHUD.HUD_FONT.get_string_size(label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,label.get_theme_font_size("font_size")).x
		var badge_width := RaceHUD.DISPLAY_FONT.get_string_size(badges[index].text,HORIZONTAL_ALIGNMENT_LEFT,-1,label.get_theme_font_size("font_size")).x
		panel.size = Vector2(minf(260*factor,maxf(110*factor,text_width+badge_width+28*factor)),30*factor)
		panel.position = Vector2(at)-Vector2(panel.size.x/2,panel.size.y)
		panel.position.x = clampf(panel.position.x,20,size.x-panel.size.x-20)
		for attempt in range(4):
			var rect := Rect2(panel.position,panel.size).grow(3)
			if not occupied.any(func(other: Rect2) -> bool: return rect.intersects(other)): break
			panel.position.y -= panel.size.y+4*factor
		var bounds := Rect2(panel.position,panel.size)
		var overlaps_hud := false
		for area: Rect2 in drive.hud.timing_rects().values():
			if bounds.intersects(Rect2(area.position*factor,area.size*factor)): overlaps_hud = true
		if overlaps_hud or panel.position.y<20: continue
		occupied.append(bounds)
		panel.show()
		index += 1

class_name RaceHUD
extends Control

const HUD_FONT = preload("res://assets/fonts/body.tres")

var state: VehicleState
var track: TrackDefinition
var ticks: int = 0
var phase_ticks: int = 0
var lap_count: int = 2
var phase: String = "Grid"
var trial: bool = false
var mph: bool = true
var rivals: Array[VehicleState] = []
var map_points := PackedVector2Array()
var map_min := Vector2.ZERO
var map_scale: float = 1.0
var map_size := Vector2.ZERO
var mobile: bool = false
var mobile_unit: float = 1.0
var rank: int = 1
var racers: int = 1
var control_notice: String = ""
var notice_until_ms: int = 0
var recovery_armed: bool = false
var network_level: int = 0
var ui_scale: float = 1.0
var high_contrast: bool = false
var palette: String = "standard"
var ghost_position: Variant = null
var gear: int = 1
var rpm: float = 0
var trial_delta: Variant = null
var announcement: String = ""
var announcement_remaining: float = 0
var observed_laps: int = -1
var dnf_lap_time: float = -1
var pause_bounds := Rect2()
var secondary_bounds := Rect2()
const PALETTES: Dictionary = {
	"standard":["F16B50","20BFC5","F3CD48","8465CC","498DD3","F5EBD3","79C697","B6A4DC"],
	"deuteranopia":["0072B2","E69F00","56B4E9","F0E442","CC79A7","D55E00","AABBDD","FFFFFF"],
	"protanopia":["3388CC","FFCC66","77CCEE","DD99CC","BB7733","CCCCFF","AA4499","FFFFFF"],
	"tritanopia":["FF7799","44BB99","EE9955","9966AA","AA2233","88DDCC","CCBBEE","FFFFFF"]}

func rival_color(slot: int) -> Color:
	var colors: Array = PALETTES.get(palette,PALETTES.standard)
	return Color.html(colors[posmod(slot,colors.size())])


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var min_point := Vector2(INF, INF)
	var max_point := Vector2(-INF, -INF)
	for p: Vector3 in track.points:
		min_point = min_point.min(Vector2(p.x, p.z))
		max_point = max_point.max(Vector2(p.x, p.z))
	map_min = min_point
	map_scale = minf(190 / (max_point.x - min_point.x), 135 / (max_point.y - min_point.y))
	map_size = (max_point-min_point)*map_scale
	for p: Vector3 in track.points:
		map_points.append((Vector2(p.x, p.z) - map_min) * map_scale)
	map_points.append(map_points[0])


func text(at: Vector2, value: String, font_size: int, color: Color = Color("f8f4e8")) -> void:
	draw_string_outline(HUD_FONT,at,value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,2,Color("172c40"))
	draw_string(HUD_FONT, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func time(seconds: float) -> String:
	return format_time(seconds)


static func format_time(seconds: float) -> String:
	return "%d:%06.3f" % [int(seconds / 60), fmod(seconds, 60)]

func elapsed() -> float:
	return state.finish_time if state.finished else ticks/60.0

func current_lap() -> float:
	if state.finished: return maxf(0,state.last_lap_time)
	if dnf_lap_time>=0: return dnf_lap_time
	return maxf(0,elapsed()-state.lap_start_time)

func advance(dt: float) -> void:
	if observed_laps>=0 and state.laps>observed_laps and not state.finished:
		announcement = I18n.t("hud.final_lap") if state.laps+1==lap_count else I18n.t("hud.lap",[state.laps+1,lap_count])
		announcement_remaining = 1.2
	observed_laps = state.laps
	announcement_remaining = maxf(0,announcement_remaining-dt)
	if state.dnf_reason!="" and dnf_lap_time<0: dnf_lap_time = current_lap()
	queue_redraw()

func banner_text() -> String:
	if state.recovery_ticks>0: return I18n.t("hud.recovering")
	if recovery_armed: return I18n.t("hud.recover_confirm")
	if state.dnf_reason!="": return I18n.t("results.dnf")
	if state.wrong_way_ticks>=60: return I18n.t("hud.wrong_way")
	if state.finished: return I18n.t("hud.finish")+"  "+time(state.finish_time)
	if phase=="Grid": return I18n.t("hud.get_ready")
	if phase=="Countdown": return str(clampi(3-phase_ticks/60,1,3))
	if ticks<36 and phase=="Racing": return I18n.t("hud.go")
	return announcement if announcement_remaining>0 else ""

func fitted(at: Vector2,value: String,font_size: int,width: float,color: Color = UIFactory.CREAM) -> void:
	var measured := HUD_FONT.get_string_size(value,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	text(at,value,maxi(16,mini(font_size,int(font_size*width/maxf(1,measured)))),color)

func timing_rects() -> Dictionary:
	var canvas := size/clampf(ui_scale,.9,1.5)
	var safe := canvas*.05
	if not mobile:
		return {"position":Rect2(safe,Vector2(minf(230,canvas.x*.25),80)),"elapsed":Rect2(Vector2(canvas.x/2-110,safe.y),Vector2(220,80)),"lap":Rect2(Vector2(canvas.x-safe.x-255,safe.y),Vector2(255,80))}
	var unit := mobile_unit
	var top := safe.y
	var available_right := canvas.x-safe.x
	if pause_bounds.has_area(): available_right = minf(available_right,pause_bounds.position.x/ui_scale-8*unit)
	var left := Rect2(safe,Vector2(minf(180*unit,canvas.x*.28),45*unit))
	var lap_width := minf(175*unit,canvas.x*.24)
	var lap := Rect2(Vector2(maxf(canvas.x*.67,available_right-lap_width),top),Vector2(lap_width,45*unit))
	# At large text on a short phone, lap moves down beside the minimap.
	if lap.end.x>available_right: lap.position = Vector2(canvas.x-safe.x-lap_width,top+52*unit)
	var gap_left := left.end.x+8*unit
	var gap_right := (lap.position.x if is_equal_approx(lap.position.y,top) else available_right)-8*unit
	var clock_width := minf(210*unit,maxf(1,gap_right-gap_left))
	var center := clampf(canvas.x/2,gap_left+clock_width/2,gap_right-clock_width/2)
	var clock := Rect2(Vector2(center-clock_width/2,top),Vector2(clock_width,60*unit if trial else 45*unit))
	return {"position":left,"elapsed":clock,"lap":lap}


func _draw() -> void:
	if state == null:
		return
	var scale_value := clampf(ui_scale,.9,1.5)
	draw_set_transform(Vector2.ZERO,0,Vector2.ONE*scale_value)
	var canvas := size/scale_value
	if Time.get_ticks_msec() < notice_until_ms:
		text(Vector2(canvas.x * .5 - 180, canvas.y * .18), control_notice, 20)
	var safe := canvas * .05
	var unit := mobile_unit if mobile else 1.0
	var regions := timing_rects()
	var position_box: Rect2 = regions.position
	var clock_box: Rect2 = regions.elapsed
	var lap_box: Rect2 = regions.lap
	for box: Rect2 in [position_box,clock_box,lap_box]: draw_style_box(panel(),box)
	fitted(position_box.position+Vector2(12,29)*unit,I18n.t("hud.trial") if trial else I18n.t("hud.position",[rank,racers]),int(22*unit),position_box.size.x-24*unit,UIFactory.TURQUOISE)
	var lap_text := I18n.t("hud.lap", [mini(lap_count, state.laps + 1), lap_count])
	if mobile:
		fitted(lap_box.position+Vector2(10,29)*unit,lap_text,int(22*unit),lap_box.size.x-20*unit)
	else:
		text(position_box.position+Vector2(12,64),lap_text,28)
		text(lap_box.position+Vector2(12,30),I18n.t("hud.current_lap")+"  "+time(current_lap()),20)
		text(lap_box.position+Vector2(12,62),I18n.t("hud.best_lap")+"  "+(time(state.best_lap_time) if state.best_lap_time>0 else I18n.t("hud.no_lap")),20)
	var clock_text := time(elapsed())
	var clock_font := int(28*unit) if mobile else 36
	var clock_width := HUD_FONT.get_string_size(clock_text,HORIZONTAL_ALIGNMENT_LEFT,-1,clock_font).x
	fitted(Vector2(clock_box.get_center().x-minf(clock_width,clock_box.size.x-16*unit)/2,clock_box.position.y+34*unit),clock_text,clock_font,clock_box.size.x-16*unit)
	if trial:
		var delta_text := I18n.t("hud.delta")+"  "+("%+.3f"%float(trial_delta) if trial_delta!=null else I18n.t("hud.no_lap"))
		var delta_font := int(16*unit) if mobile else 18
		var delta_width := HUD_FONT.get_string_size(delta_text,HORIZONTAL_ALIGNMENT_LEFT,-1,delta_font).x
		fitted(Vector2(clock_box.get_center().x-minf(delta_width,clock_box.size.x-16*unit)/2,clock_box.position.y+56*unit),delta_text,delta_font,clock_box.size.x-16*unit,UIFactory.TURQUOISE if trial_delta!=null and float(trial_delta)<0 else UIFactory.CREAM)
	if network_level>0:
		var origin := lap_box.position+Vector2(lap_box.size.x-28*unit,lap_box.size.y+4*unit)
		draw_style_box(panel(),Rect2(origin-Vector2(4,0)*unit,Vector2(32,32)*unit))
		draw_texture_rect(UIIcons.texture("connection_poor" if network_level==2 else "connection_caution"),Rect2(origin+Vector2(0,4)*unit,Vector2(24,24)*unit),false)
	var map_origin := Vector2(safe.x + 10, canvas.y - safe.y - 155)
	var map_factor := minf(130 * unit / 220, 90 * unit / 160)/scale_value if mobile else 1.0
	if mobile:
		map_origin = Vector2(safe.x + 10 * map_factor, safe.y + 55 * unit + 10 * map_factor)
	draw_style_box(panel(), Rect2(map_origin - Vector2(10, 10) * map_factor, Vector2(220, 160) * map_factor))
	map_origin += (Vector2(200,140)-map_size)*map_factor/2
	var screen_points := PackedVector2Array()
	for p: Vector2 in map_points:
		screen_points.append(map_origin + p * map_factor)
	draw_polyline(screen_points, Color.html("F3E4C4"), 4, true)
	var start := screen_points[0]
	var start_right := Vector2(track.forwards[0].z,-track.forwards[0].x).normalized()
	for index in range(4):
		draw_line(start+start_right*(index-2)*3*map_factor,start+start_right*(index-1)*3*map_factor,UIFactory.CREAM if index%2==0 else UIFactory.NAVY,5*map_factor,true)
	for rival: VehicleState in rivals:
		var point := map_origin+(Vector2(rival.position.x,rival.position.z)-map_min)*map_scale*map_factor
		draw_circle(point,4,rival_color(rival.slot))
		draw_string_outline(HUD_FONT,point+Vector2(5,-4),str(rival.slot+1),HORIZONTAL_ALIGNMENT_LEFT,-1,14,3,Color("172c40"))
		text(point+Vector2(5,-4),str(rival.slot+1),14)
	if ghost_position is Vector3:
		var point := map_origin+(Vector2(ghost_position.x,ghost_position.z)-map_min)*map_scale*map_factor
		for index in range(4): draw_arc(point,6,index*PI/2,index*PI/2+PI/3,5,Color("56DDE5"),2,true)
	var marker := map_origin + (Vector2(state.position.x, state.position.z) - map_min) * map_scale * map_factor
	var direction := Vector2(sin(state.yaw), -cos(state.yaw))
	draw_colored_polygon(PackedVector2Array([marker + direction * 8, marker - direction * 5 + direction.orthogonal() * 5, marker - direction * 5 - direction.orthogonal() * 5]), Color.WHITE)
	var speed := 0 if state.dnf_reason!="" else int(round(state.speed() * (2.236936 if mph else 3.6)))
	var speed_at := Vector2(canvas.x - safe.x - 180, canvas.y - safe.y - 30)
	var speed_unit := unit/scale_value if mobile else unit
	if mobile:
		speed_at = Vector2(canvas.x / 2 - 70 * speed_unit, canvas.y * .81)
		if secondary_bounds.has_area(): speed_at.y = secondary_bounds.position.y/ui_scale-14*speed_unit
	draw_style_box(panel(), Rect2(speed_at - Vector2(10, 26) * speed_unit, Vector2(150, 36) * speed_unit) if mobile else Rect2(speed_at - Vector2(15, 60), Vector2(195, 90)))
	text(speed_at, str(speed), int(30 * speed_unit) if mobile else 64)
	text(speed_at + Vector2(90 * speed_unit if mobile else 125, 0), "MPH" if mph else "KM/H", int(16 * speed_unit) if mobile else 20, Color.html("20BFC5"))
	if not mobile:
		var tach_at := speed_at+Vector2(0,12)*unit
		for index in range(12):
			draw_rect(Rect2(tach_at+Vector2(index*8,0)*unit,Vector2(6,5)*unit),Color.html("F3CD48") if index<rpm*12 else Color("384b58"))
		text(tach_at+Vector2(103,6)*unit,"%d"%gear,int(16*unit))
	var banner := banner_text()
	if trial and not state.trial_valid:
		text(Vector2(canvas.x * .3, canvas.y * .14), I18n.t("hud.invalid"), 20, Color.html("F16B50"))
	if banner != "":
		var font_size := mini(64,maxi(16,int(64*canvas.x*.9/maxf(1,HUD_FONT.get_string_size(banner,HORIZONTAL_ALIGNMENT_LEFT,-1,64).x))))
		var width := HUD_FONT.get_string_size(banner,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		text(Vector2((canvas.x-width)/2,canvas.y*.32),banner,font_size,Color.html("F3CD48"))
	if recovery_armed:
		var help := I18n.t("hud.recover_again")
		var font_size := int(16*unit)
		var width := HUD_FONT.get_string_size(help,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		text(Vector2((canvas.x-width)/2,canvas.y*.39),help,font_size)
	if state.recovery_hold_ticks > 0:
		var center := speed_at-Vector2(35,18)
		draw_texture_rect(UIIcons.texture("action_recover"),Rect2(center-Vector2.ONE*12,Vector2.ONE*24),false)
		draw_arc(center,20,-PI/2,-PI/2+TAU*state.recovery_hold_ticks/30.0,30,UIFactory.YELLOW,5)


func panel() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(.09,.17,.25,1.0 if high_contrast else .94)
	if high_contrast:
		box.border_color = UIFactory.CREAM
		box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	return box

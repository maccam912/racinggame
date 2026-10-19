class_name RaceHUD
extends Control

const HUD_FONT = preload("res://assets/fonts/Barlow-SemiBold.ttf")

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
	for p: Vector3 in track.points:
		map_points.append((Vector2(p.x, p.z) - map_min) * map_scale)
	map_points.append(map_points[0])


func text(at: Vector2, value: String, font_size: int, color: Color = Color("f8f4e8")) -> void:
	draw_string(HUD_FONT, at, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)


func time(seconds: float) -> String:
	return format_time(seconds)


static func format_time(seconds: float) -> String:
	return "%d:%06.3f" % [int(seconds / 60), fmod(seconds, 60)]


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
	draw_style_box(panel(), Rect2(safe, Vector2(180 * unit, 45 * unit) if mobile else Vector2(230, 80)))
	text(safe + Vector2(16, 31) * unit, I18n.t("hud.trial") if trial else I18n.t("hud.position", [rank, racers]), int(22 * unit), Color.html("20BFC5"))
	var lap_text := I18n.t("hud.lap", [mini(lap_count, state.laps + 1), lap_count])
	text(Vector2(canvas.x * .72, safe.y + 30 * unit) if mobile else safe + Vector2(16, 64), lap_text, int(24 * unit) if mobile else 28)
	text(Vector2(canvas.x / 2 - 85 * unit, safe.y + 36 * unit), time(ticks / 60.0), int(28 * unit) if mobile else 36)
	if not mobile:
		text(Vector2(canvas.x - safe.x - 240, safe.y + 30), I18n.t("track." + track.id), 18)
	if network_level>0:
		var origin := Vector2(canvas.x-safe.x-50*unit,safe.y+65*unit)
		draw_style_box(panel(),Rect2(origin-Vector2(8,32)*unit,Vector2(58,42)*unit))
		for index in range(3):
			var height_value := (8+index*8)*unit
			var rect := Rect2(origin+Vector2(index*14*unit,-height_value),Vector2(9*unit,height_value))
			draw_rect(rect,Color("f8f4e8"),index<(1 if network_level==2 else 2),2*unit)
	var map_origin := Vector2(safe.x + 10, canvas.y - safe.y - 155)
	var map_factor := minf(130 * unit / 220, 90 * unit / 160) if mobile else 1.0
	if mobile:
		map_origin = Vector2(safe.x + 10 * map_factor, safe.y + 55 * unit + 10 * map_factor)
	draw_style_box(panel(), Rect2(map_origin - Vector2(10, 10) * map_factor, Vector2(220, 160) * map_factor))
	var screen_points := PackedVector2Array()
	for p: Vector2 in map_points:
		screen_points.append(map_origin + p * map_factor)
	draw_polyline(screen_points, Color.html("F3E4C4"), 4, true)
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
	var speed := int(round(state.speed() * (2.236936 if mph else 3.6)))
	var speed_at := Vector2(canvas.x - safe.x - 180, canvas.y - safe.y - 30)
	if mobile:
		speed_at = Vector2(canvas.x / 2 - 70 * unit, canvas.y * .81)
	draw_style_box(panel(), Rect2(speed_at - Vector2(10, 35) * unit, Vector2(150, 50) * unit) if mobile else Rect2(speed_at - Vector2(15, 60), Vector2(195, 90)))
	text(speed_at, str(speed), int(36 * unit) if mobile else 64)
	text(speed_at + Vector2(90 * unit if mobile else 125, 0), "MPH" if mph else "KM/H", int(16 * unit) if mobile else 20, Color.html("20BFC5"))
	var tach_at := speed_at+Vector2(0,12)*unit
	for index in range(12):
		draw_rect(Rect2(tach_at+Vector2(index*8,0)*unit,Vector2(6,5)*unit),Color.html("F3CD48") if index<rpm*12 else Color("384b58"))
	text(tach_at+Vector2(103,6)*unit,"%d"%gear,int(16*unit))
	var banner := ""
	if state.recovery_ticks > 0:
		banner = I18n.t("hud.recovering")
	elif recovery_armed:
		banner = I18n.t("hud.recover_confirm")
	elif state.wrong_way_ticks >= 60:
		banner = I18n.t("hud.wrong_way")
	elif phase == "Grid":
		banner = I18n.t("hud.get_ready")
	elif phase == "Countdown":
		banner = str(3 - phase_ticks / 60)
	elif ticks < 36 and phase == "Racing":
		banner = I18n.t("hud.go")
	elif state.finished:
		banner = I18n.t("hud.finish") + "  " + time(state.finish_time)
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
		draw_arc(speed_at - Vector2(20, 80), 20, -PI / 2, -PI / 2 + TAU * state.recovery_hold_ticks / 30.0, 30, Color.html("F3CD48"), 5)


func panel() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(.09,.17,.25,1.0 if high_contrast else .94)
	if high_contrast:
		box.border_color = UIFactory.CREAM
		box.set_border_width_all(2)
	box.set_corner_radius_all(8)
	return box

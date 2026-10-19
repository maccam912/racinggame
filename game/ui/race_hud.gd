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
	if Time.get_ticks_msec() < notice_until_ms:
		text(Vector2(size.x * .5 - 180, size.y * .18), control_notice, 20)
	var safe := size * .05
	var unit := mobile_unit if mobile else 1.0
	draw_style_box(panel(), Rect2(safe, Vector2(180 * unit, 45 * unit) if mobile else Vector2(230, 80)))
	text(safe + Vector2(16, 31) * unit, I18n.t("hud.trial") if trial else I18n.t("hud.position", [rank, racers]), int(22 * unit), Color.html("20BFC5"))
	var lap_text := I18n.t("hud.lap", [mini(lap_count, state.laps + 1), lap_count])
	text(Vector2(size.x * .72, safe.y + 30 * unit) if mobile else safe + Vector2(16, 64), lap_text, int(24 * unit) if mobile else 28)
	text(Vector2(size.x / 2 - 85 * unit, safe.y + 36 * unit), time(ticks / 60.0), int(28 * unit) if mobile else 36)
	if not mobile:
		text(Vector2(size.x - safe.x - 240, safe.y + 30), I18n.t("track." + track.id), 18)
	var map_origin := Vector2(safe.x + 10, size.y - safe.y - 155)
	var map_factor := minf(130 * unit / 220, 90 * unit / 160) if mobile else 1.0
	if mobile:
		map_origin = Vector2(safe.x + 10 * map_factor, safe.y + 55 * unit + 10 * map_factor)
	draw_style_box(panel(), Rect2(map_origin - Vector2(10, 10) * map_factor, Vector2(220, 160) * map_factor))
	var screen_points := PackedVector2Array()
	for p: Vector2 in map_points:
		screen_points.append(map_origin + p * map_factor)
	draw_polyline(screen_points, Color.html("F3E4C4"), 4, true)
	for rival: VehicleState in rivals:
			draw_circle(map_origin + (Vector2(rival.position.x, rival.position.z) - map_min) * map_scale * map_factor, 3, Color.html("F16B50"))
	var marker := map_origin + (Vector2(state.position.x, state.position.z) - map_min) * map_scale * map_factor
	var direction := Vector2(sin(state.yaw), -cos(state.yaw))
	draw_colored_polygon(PackedVector2Array([marker + direction * 8, marker - direction * 5 + direction.orthogonal() * 5, marker - direction * 5 - direction.orthogonal() * 5]), Color.WHITE)
	var speed := int(round(state.speed() * (2.236936 if mph else 3.6)))
	var speed_at := Vector2(size.x - safe.x - 180, size.y - safe.y - 30)
	if mobile:
		speed_at = Vector2(size.x / 2 - 70 * unit, size.y * .81)
	draw_style_box(panel(), Rect2(speed_at - Vector2(10, 35) * unit, Vector2(150, 50) * unit) if mobile else Rect2(speed_at - Vector2(15, 60), Vector2(195, 90)))
	text(speed_at, str(speed), int(36 * unit) if mobile else 64)
	text(speed_at + Vector2(90 * unit if mobile else 125, 0), "MPH" if mph else "KM/H", int(16 * unit) if mobile else 20, Color.html("20BFC5"))
	var banner := ""
	if state.recovery_ticks > 0:
		banner = I18n.t("hud.recovering")
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
		text(Vector2(size.x * .3, size.y * .14), I18n.t("hud.invalid"), 20, Color.html("F16B50"))
	if banner != "":
		text(Vector2(size.x / 2 - banner.length() * 18, size.y * .32), banner, 64, Color.html("F3CD48"))
	if state.recovery_hold_ticks > 0:
		draw_arc(speed_at - Vector2(20, 80), 20, -PI / 2, -PI / 2 + TAU * state.recovery_hold_ticks / 30.0, 30, Color.html("F3CD48"), 5)


func panel() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(.09, .17, .25, .94)
	box.set_corner_radius_all(8)
	return box

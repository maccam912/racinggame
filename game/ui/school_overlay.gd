class_name SchoolOverlay
extends Control

var lesson: SchoolLesson
var state: VehicleState
var unit: float = 1
var font: Font = preload("res://assets/fonts/Barlow-SemiBold.ttf")
var elapsed: float = 0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func _process(dt: float) -> void:
	elapsed += dt
	queue_redraw()


func _draw() -> void:
	var at := Vector2(size.x * .28, size.y * .12)
	var box := StyleBoxFlat.new()
	box.bg_color = UIFactory.NAVY
	box.set_corner_radius_all(5)
	draw_style_box(box, Rect2(at - Vector2(16, 25) * unit, Vector2(size.x * .44, 95 * unit)))
	draw_string(font, at, I18n.t("school." + str(lesson.index)), HORIZONTAL_ALIGNMENT_LEFT, -1, int(20 * unit), UIFactory.CREAM)
	var controls := ["W  →  S", "A  ←  →  D", "W  →  S  →  A / D", "W + A / D + SPACE  →  release", "R"]
	var labels: String = controls[lesson.index]
	var pulse := .5 + .5 * sin(elapsed * 3)
	draw_circle(at + Vector2(10, 37) * unit, (6 + pulse * 3) * unit, UIFactory.YELLOW)
	draw_string(font, at + Vector2(30, 43) * unit, labels, HORIZONTAL_ALIGNMENT_LEFT, -1, int(20 * unit), UIFactory.TURQUOISE)

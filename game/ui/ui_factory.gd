class_name UIFactory
extends RefCounted

const CREAM: Color = Color("f8f4e8")
const NAVY: Color = Color("172c40")
const TURQUOISE: Color = Color("20bfc5")
const YELLOW: Color = Color("f3cd48")
const CORAL: Color = Color("f16b50")
var unit: float = 1.0
var scale: float = 1.0
var mobile: bool = false
var body_font: Font
var title_font: Font
var theme: Theme


func _init(viewport: Viewport, settings: Dictionary) -> void:
	mobile = OS.has_feature("mobile")
	if mobile:
		unit = viewport.get_visible_rect().size.y / maxf(DisplayServer.window_get_size().y, 1) * maxf(160, DisplayServer.screen_get_dpi()) / 160.0
	scale = float(settings.get("ui_scale", 100)) / 100
	body_font = load("res://assets/fonts/Barlow-SemiBold.ttf")
	title_font = load("res://assets/fonts/BarlowCondensed-Bold.ttf")
	theme = Theme.new()
	theme.default_font = body_font
	theme.default_font_size = font_size(16)
	for type in ["Label", "Button", "CheckButton", "OptionButton", "LineEdit"]:
		theme.set_color("font_color", type, CREAM)
		theme.set_color("font_focus_color", type, CREAM)
		theme.set_font_size("font_size", type, font_size(20 if mobile and type != "Label" else 19 if type != "Label" else 16))
	if mobile:
		var popup_font_size := font_size(20)
		theme.set_font_size("font_size","PopupMenu",popup_font_size)
		theme.set_constant("v_separation","PopupMenu",popup_separation(body_font,popup_font_size,unit))
		theme.set_stylebox("panel","PopupMenu",style(NAVY,TURQUOISE))
	for type in ["Button", "OptionButton"]:
		theme.set_stylebox("normal", type, style(NAVY, Color(0.25, .39, .47)))
		theme.set_stylebox("hover", type, style(Color(.12, .25, .32), TURQUOISE))
		theme.set_stylebox("pressed", type, style(Color(.08, .32, .36), TURQUOISE))
		theme.set_stylebox("focus", type, style(Color(0, 0, 0, 0), YELLOW, 2))
		theme.set_stylebox("disabled", type, style(Color(.10, .16, .22), Color(.2, .27, .33)))
	theme.set_stylebox("panel", "PanelContainer", style(Color(NAVY, 1.0 if settings.get("high_contrast", false) else .94), Color(.22, .37, .46)))
	theme.set_stylebox("normal", "LineEdit", style(NAVY, TURQUOISE))
	theme.set_stylebox("focus", "LineEdit", style(Color(0, 0, 0, 0), YELLOW, 2))
	for type in ["VBoxContainer", "HBoxContainer", "GridContainer"]:
		theme.set_constant("separation", type, int(10 * unit * scale))


func font_size(base: float) -> int:
	return int(round(maxf(16 * unit, base * unit * scale)))


func row_height() -> float:
	return maxf(48 * unit if mobile else 32.0, (48 if mobile else 36) * unit * scale)


func style(fill: Color, border: Color, width: int = 1) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(maxi(1, roundi(width * unit)))
	box.set_corner_radius_all(roundi(5.333 * unit))
	box.content_margin_left = 14 * unit
	box.content_margin_right = 14 * unit
	box.content_margin_top = 8 * unit
	box.content_margin_bottom = 8 * unit
	return box


func label(text: String, heading: bool = false) -> Label:
	var control := Label.new()
	control.text = text
	if heading:
		control.add_theme_font_override("font", title_font)
		control.add_theme_font_size_override("font_size", font_size(32 if mobile else 43))
	return control


func button(text: String, action: Callable, minimum_width: float = 0) -> Button:
	var control := Button.new()
	control.text = text
	control.custom_minimum_size = Vector2(minimum_width * unit, row_height())
	control.pressed.connect(action)
	control.focus_entered.connect(func() -> void:
		control.create_tween().tween_property(control, "modulate", Color(1.06, 1.06, 1.06), .1))
	control.focus_exited.connect(func() -> void:
		control.create_tween().tween_property(control, "modulate", Color.WHITE, .1))
	return control


func paragraph(text: String) -> Label:
	var control := label(text)
	control.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return control


func panel(child: Control) -> PanelContainer:
	var control := PanelContainer.new()
	control.add_child(child)
	return control


static func popup_separation(font: Font,pixels: int,logical_unit: float) -> int:
	return ceili(maxf(4*logical_unit,48*logical_unit-font.get_height(pixels)))


func configure_picker(control: OptionButton) -> void:
	if not mobile:
		return
	var popup := control.get_popup()
	var fit := func() -> void:
		popup.min_size = Vector2i.ZERO
		popup.max_size = Vector2i(Vector2(DisplayServer.get_display_safe_area().size)*.90)
	fit.call()
	popup.about_to_popup.connect(fit)

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
var owner_viewport: Viewport
var reduce_motion: bool = false


func _init(viewport: Viewport, settings: Dictionary, mobile_override: Variant = null, logical_unit_override: float = 0.0) -> void:
	owner_viewport = viewport
	reduce_motion = bool(settings.get("reduce_motion",false))
	mobile = OS.has_feature("mobile") if mobile_override==null else bool(mobile_override)
	if mobile:
		unit = viewport.get_visible_rect().size.y / maxf(DisplayServer.window_get_size().y, 1) * maxf(160, DisplayServer.screen_get_dpi()) / 160.0
	if logical_unit_override>0:
		unit = logical_unit_override
	scale = float(settings.get("ui_scale", 100)) / 100
	body_font = load("res://assets/fonts/body.tres")
	title_font = load("res://assets/fonts/heading.tres")
	theme = Theme.new()
	theme.default_font = body_font
	theme.default_font_size = font_size(16)
	var contrast: bool = bool(settings.get("high_contrast",false))
	for type in ["Label", "Button", "CheckButton", "OptionButton", "LineEdit"]:
		theme.set_color("font_color", type, CREAM)
		theme.set_color("font_focus_color", type, CREAM)
		theme.set_font_size("font_size", type, font_size(20 if mobile and type != "Label" else 19 if type != "Label" else 16))
	for type in ["Button", "OptionButton"]:
		theme.set_stylebox("normal", type, style(NAVY, CREAM if contrast else Color(0.25, .39, .47),2 if contrast else 1))
		theme.set_stylebox("hover", type, style(Color(.12, .25, .32), TURQUOISE))
		theme.set_stylebox("pressed", type, style(Color(.08, .32, .36), TURQUOISE))
		theme.set_stylebox("focus", type, style(Color(0, 0, 0, 0), YELLOW, 3 if contrast else 2))
		theme.set_stylebox("disabled", type, style(Color(.10, .16, .22), Color(.2, .27, .33)))
	theme.set_stylebox("panel", "PanelContainer", style(Color(NAVY, 1.0 if contrast else .94), CREAM if contrast else Color(.22, .37, .46),2 if contrast else 1))
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


func button(text: String, action: Callable, minimum_width: float = 0, sound: String = "confirm") -> Button:
	var control := Button.new()
	control.text = text
	control.custom_minimum_size = Vector2(minimum_width * unit, row_height())
	control.pressed.connect(func() -> void: AudioLibrary.ui(owner_viewport,sound))
	control.pressed.connect(action)
	control.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed and event.device in [-1,MenuScroll.TAP_DEVICE]:
			DrivingInput.last_device = "touch"
		else:
			DrivingInput.remember_menu_device(event))
	control.focus_entered.connect(func() -> void:
		AudioLibrary.ui(owner_viewport,"move"))
	var pointer := FocusPointer.new()
	pointer.button = control
	pointer.unit = unit
	pointer.instant = reduce_motion
	control.add_child(pointer)
	return control

func selected(control: Button,value: bool) -> void:
	control.add_theme_color_override("font_color",TURQUOISE if value else CREAM)
	control.add_theme_color_override("font_focus_color",TURQUOISE if value else CREAM)
	control.add_theme_color_override("icon_normal_color",TURQUOISE if value else CREAM)

func help(control: Control,value: Variant,disabled: bool = false) -> void:
	control.set_meta("disabled_reason" if disabled else "focus_help",value)

func set_icon(control: Button, id: String) -> void:
	control.icon = UIIcons.texture(id)
	control.expand_icon = true
	control.add_theme_constant_override("icon_max_width",roundi(24*unit*scale))
	control.add_theme_constant_override("h_separation",roundi(10*unit))
	var width := 0.0
	for line: String in control.text.split("\n"):
		width = maxf(width,body_font.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,theme.get_font_size("font_size","Button")).x)
	control.custom_minimum_size.x = maxf(control.custom_minimum_size.x,width+24*unit*scale+38*unit)

func icon(id: String, base_size: float = 24) -> TextureRect:
	var control := TextureRect.new()
	control.texture = UIIcons.texture(id)
	control.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	control.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	control.custom_minimum_size = Vector2.ONE*base_size*unit*scale
	control.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	control.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return control

func stat(caption: String, value: float, maximum: float) -> VBoxContainer:
	var list := VBoxContainer.new()
	list.add_child(paragraph(caption))
	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = maximum
	bar.value = value
	bar.show_percentage = false
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.custom_minimum_size.y = 7*unit*scale
	var fill := StyleBoxFlat.new()
	fill.bg_color = TURQUOISE
	fill.set_corner_radius_all(3)
	var background := fill.duplicate() as StyleBoxFlat
	background.bg_color = Color("384B58")
	bar.add_theme_stylebox_override("fill",fill)
	bar.add_theme_stylebox_override("background",background)
	list.add_child(bar)
	return list


func paragraph(text: String) -> Label:
	var control := label(text)
	control.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return control


func panel(child: Control) -> PanelContainer:
	var control := PanelContainer.new()
	control.add_child(child)
	return control


func choice_picker(subject: String = "") -> Variant:
	if not mobile:
		return OptionButton.new()
	var control := ChoicePicker.new()
	control.ui = self
	control.subject = subject
	control.context_changed.connect(func() -> void:
		if is_instance_valid(owner_viewport) and owner_viewport.is_inside_tree():
			owner_viewport.get_tree().call_group("menu_navigation_repeat","clear_context"))
	return control


static func text_edit() -> LineEdit:
	var edit := LineEdit.new()
	edit.backspace_deletes_composite_character_enabled = true
	return edit

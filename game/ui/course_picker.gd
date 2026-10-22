class_name CoursePicker
extends VBoxContainer
## Random resolves locally before confirmation; only a real catalog index is sent.
signal track_selected(index: int)
var selected: int
var picker: Variant
var showcase: CourseShowcase
var shuffle: TrackShuffle
var roster: Array[int] = []

func configure(ui: UIFactory, settings: Dictionary, index: int, tour: TrackShuffle) -> void:
	name = "CoursePicker"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shuffle = tour
	selected = index
	picker = ui.choice_picker(I18n.t("event.title"))
	picker.name = "TrackPicker"
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.custom_minimum_size.y = ui.row_height()
	picker.add_item(I18n.t("event.random_short"))
	for i in range(Catalog.tracks.size()):
		roster.append(i)
		picker.add_item(I18n.t(Catalog.tracks[i].display_name_key))
	picker.selected = selected+1
	picker.item_selected.connect(choose)
	add_child(picker)
	ui.help(picker,I18n.t("course.random_help"))
	showcase = CourseShowcase.new()
	showcase.configure(ui,settings,Catalog.tracks[selected])
	add_child(showcase)
	showcase.title.hide()
	showcase.move_child(showcase.facts,showcase.get_child_count()-1)

func choose(index: int) -> void:
	if index<0 or index>Catalog.tracks.size(): return
	selected = shuffle.choose(roster,selected) if index==0 else index-1
	shuffle.note_visit(roster,selected)
	picker.selected = selected+1
	showcase.select_track(Catalog.tracks[selected])
	track_selected.emit(selected)

func compact_header(shell: MenuShell) -> void:
	# Keep the selector and both views visible on a landscape phone, at 150% too.
	if not shell.ui.mobile: return
	var heading := shell.headers[0] as Label
	heading.add_theme_font_size_override("font_size",shell.ui.font_size(18))
	heading.custom_minimum_size.x = 140*shell.ui.unit
	heading.size_flags_horizontal = Control.SIZE_FILL
	picker.add_theme_font_size_override("font_size",shell.ui.font_size(18))
	var header := HBoxContainer.new()
	header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shell.column.remove_child(heading)
	remove_child(picker)
	header.add_child(heading)
	header.add_child(picker)
	shell.column.add_child(header)
	shell.column.move_child(header,0)
	shell.headers.assign([header])

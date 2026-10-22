class_name CourseShowcase
extends VBoxContainer
## A resolved course always owns its photograph, map and facts together.
var track: TrackDefinition
var title: Label
var facts: Label
var photograph: TextureRect
var map: RoutePreview
var views: GridContainer
var ui: UIFactory
var settings: Dictionary

func configure(factory: UIFactory, preferences: Dictionary, selected: TrackDefinition) -> void:
	ui = factory
	settings = preferences
	name = "CourseShowcase"
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title = ui.paragraph("")
	title.add_theme_font_override("font",ui.title_font)
	title.add_theme_font_size_override("font_size",ui.font_size(24))
	add_child(title)
	facts = ui.paragraph("")
	add_child(facts)
	views = GridContainer.new()
	views.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(views)
	photograph = TextureRect.new()
	photograph.name = "CoursePhotograph"
	photograph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	photograph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	photograph.custom_minimum_size = Vector2(180,160)*ui.unit
	photograph.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	photograph.mouse_filter = Control.MOUSE_FILTER_IGNORE
	views.add_child(photograph)
	map = RoutePreview.new()
	map.unit = ui.unit
	map.custom_minimum_size = Vector2(180,160 if ui.mobile else 260)*ui.unit
	map.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	views.add_child(map)
	resized.connect(fit_views)
	select_track(selected)

func fit_views() -> void:
	views.columns = 2 if size.x>=540*ui.unit else 1
	photograph.custom_minimum_size.y = ((160 if ui.mobile else 260) if views.columns==2 else 140)*ui.unit

func select_track(selected: TrackDefinition) -> void:
	track = selected
	title.text = I18n.t(track.display_name_key)
	var miles := str(settings.get("units","mph"))=="mph"
	facts.text = "%.2f %s  •  %s  •  %s" % [track.length/(1609.344 if miles else 1000),"mi" if miles else "km",I18n.t("difficulty."+str(track.definition.difficulty).to_lower()),I18n.t("event.filter."+track.road_surface())]
	photograph.texture = load("res://assets/exported/thumbnails/"+track.id+".png")
	photograph.accessibility_name = I18n.t("course.photograph",[title.text])
	map.track = track
	map.accessibility_name = I18n.t("course.map",[title.text])

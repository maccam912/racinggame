class_name RaceResultRow
extends RefCounted
## A readable finishing place, car silhouette and explicitly labelled race times.
static func build(ui: UIFactory, state: VehicleState, car: CarDefinition, racer_name: String, rank: int, gap: String, paint: int = 0) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.name = "ResultRow_"+str(state.slot)
	row.add_theme_constant_override("separation",roundi(12*ui.unit))
	var place := ui.label(str(rank),true)
	place.name = "FinishingPlace"
	place.add_theme_font_size_override("font_size",ui.font_size(32))
	place.add_theme_color_override("font_color",UIFactory.YELLOW if rank==1 and state.finished else UIFactory.CREAM)
	place.custom_minimum_size.x = 32*ui.unit*ui.scale
	place.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	place.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(place)
	var portrait := TextureRect.new()
	portrait.name = "ResultCar"
	portrait.texture = load("res://assets/exported/result_portraits/"+car.id+"-"+str(clampi(paint,0,Catalog.paints.size()-1))+".png")
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.custom_minimum_size = Vector2(88,50)*ui.unit
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait.accessibility_name = I18n.t("paint."+str(paint))+" "+I18n.t("car."+car.id)
	row.add_child(portrait)
	var words := VBoxContainer.new()
	words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(words)
	var name_label := ui.paragraph(racer_name+"  •  "+I18n.t("car."+car.id))
	name_label.name = "RacerName"
	words.add_child(name_label)
	var total := RaceHUD.format_time(state.finish_time) if state.finished else I18n.t("results.dnf")+" "+state.dnf_reason
	words.add_child(ui.paragraph(I18n.t("results.time")+": "+total+"  •  "+I18n.t("results.gap")+": "+gap))
	words.add_child(ui.paragraph(I18n.t("results.best_lap")+": "+(RaceHUD.format_time(state.best_lap_time) if state.best_lap_time>0 else "—")))
	return row

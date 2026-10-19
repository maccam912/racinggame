class_name DesktopDisplay
extends RefCounted
## Display modes are queried read-only. Fullscreen keeps the desktop mode and
## renders the world at the chosen resolution, leaving native-resolution UI.
static var last_signature: String = ""
static var windowed_rect := Rect2i(100,100,1280,720)

static func resolution_size(value: Variant) -> Vector2i:
	if not value is String: return Vector2i.ZERO
	var match_value := RegEx.create_from_string("\\A([0-9]{3,5})x([0-9]{3,5})\\z").search(value)
	if match_value==null: return Vector2i.ZERO
	var size := Vector2i(int(match_value.get_string(1)),int(match_value.get_string(2)))
	return size if size.x>=640 and size.y>=360 and size.x<=16384 and size.y<=16384 else Vector2i.ZERO

static func choices_from_sizes(sizes: Array) -> Array[String]:
	var unique: Array[Vector2i] = []
	for value: Variant in sizes:
		if value is Vector2i and resolution_size("%dx%d"%[value.x,value.y])!=Vector2i.ZERO and not value in unique: unique.append(value)
	unique.sort_custom(func(a: Vector2i,b: Vector2i) -> bool: return a.x*a.y<b.x*b.y if a.x*a.y!=b.x*b.y else a.x<b.x)
	var result: Array[String] = ["native"]
	for size: Vector2i in unique: result.append("%dx%d"%[size.x,size.y])
	return result

static func modes(screen: int) -> Array[String]:
	if OS.has_feature("mobile") or DisplayServer.get_name() in ["headless","Wayland"]: return ["native"]
	if not ClassDB.class_exists("PacificPlatform"): return ["native"]
	var adapter: Object = ClassDB.instantiate("PacificPlatform")
	if not adapter.has_method("screen_modes"): return ["native"]
	screen = clampi(screen,0,DisplayServer.get_screen_count()-1)
	var position := DisplayServer.screen_get_position(screen)
	var size := DisplayServer.screen_get_size(screen)
	var result: Variant = adapter.call("screen_modes",screen,position.x,position.y,size.x,size.y)
	return choices_from_sizes(result if result is Array else [])

static func capture() -> Dictionary:
	if DisplayServer.get_name()=="headless" or OS.has_feature("mobile"): return {}
	return {"mode":DisplayServer.window_get_mode(),"screen":DisplayServer.window_get_current_screen(),"position":DisplayServer.window_get_position(),"size":DisplayServer.window_get_size(),"borderless":DisplayServer.window_get_flag(DisplayServer.WINDOW_FLAG_BORDERLESS),"signature":last_signature,"windowed_rect":windowed_rect}

static func restore(state: Dictionary) -> void:
	if state.is_empty() or DisplayServer.get_name()=="headless": return
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	DisplayServer.window_set_current_screen(clampi(int(state.screen),0,DisplayServer.get_screen_count()-1))
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS,bool(state.borderless))
	DisplayServer.window_set_size(state.size)
	DisplayServer.window_set_position(state.position)
	DisplayServer.window_set_mode(int(state.mode))
	last_signature = state.signature
	windowed_rect = state.windowed_rect

static func fitted_size(requested: Vector2i, usable: Vector2i) -> Vector2i:
	var available := Vector2i(maxi(320,usable.x-32),maxi(180,usable.y-80))
	var factor := minf(1.0,minf(float(available.x)/requested.x,float(available.y)/requested.y))
	return Vector2i(maxi(320,roundi(requested.x*factor)),maxi(180,roundi(requested.y*factor)))

static func apply(settings: Dictionary) -> void:
	if DisplayServer.get_name()=="headless" or OS.has_feature("mobile"): return
	var screen := clampi(int(settings.monitor),0,DisplayServer.get_screen_count()-1)
	var resolution: String = settings.resolution
	if not resolution in modes(screen): resolution = "native"
	settings.monitor = screen
	settings.resolution = resolution
	var requested_mode: int = {"windowed":DisplayServer.WINDOW_MODE_WINDOWED,"borderless":DisplayServer.WINDOW_MODE_FULLSCREEN,"fullscreen":DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN}.get(settings.window_mode,DisplayServer.WINDOW_MODE_WINDOWED)
	var previous_mode := DisplayServer.window_get_mode()
	var monitor_changed := screen!=DisplayServer.window_get_current_screen()
	var signature := "%s:%d:%s"%[settings.window_mode,screen,resolution]
	if previous_mode==DisplayServer.WINDOW_MODE_WINDOWED and requested_mode!=previous_mode:
		windowed_rect = Rect2i(DisplayServer.window_get_position(),DisplayServer.window_get_size())
	if monitor_changed and previous_mode!=DisplayServer.WINDOW_MODE_WINDOWED: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	if monitor_changed: DisplayServer.window_set_current_screen(screen)
	if DisplayServer.window_get_mode()!=requested_mode: DisplayServer.window_set_mode(requested_mode)
	if requested_mode==DisplayServer.WINDOW_MODE_WINDOWED:
		DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_BORDERLESS,false)
		if signature!=last_signature or previous_mode!=requested_mode:
			var usable := DisplayServer.screen_get_usable_rect(screen)
			var requested := resolution_size(resolution)
			if requested==Vector2i.ZERO: requested = windowed_rect.size
			var size := fitted_size(requested,usable.size)
			DisplayServer.window_set_size(size)
			var position := usable.position+(usable.size-size)/2
			if previous_mode!=requested_mode and not monitor_changed and resolution=="native":
				position = Vector2i(clampi(windowed_rect.position.x,usable.position.x,usable.end.x-size.x),clampi(windowed_rect.position.y,usable.position.y,usable.end.y-size.y))
			DisplayServer.window_set_position(position)
	last_signature = signature

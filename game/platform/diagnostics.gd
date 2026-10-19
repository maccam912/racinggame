class_name Diagnostics
extends Node
signal export_finished(state: String)
const FILES: Array[String] = ["build.json","platform.json","settings.json","performance.json","events.json","race.json"]
const MAX_ARCHIVE_BYTES: int = 1048576
var app: Node
var log := DiagnosticLog.new()
var buckets: Array[Dictionary] = []
var previous_physics: int = 0
var last_page: String = ""
var dialog: FileDialog
var cache_path: String = ""
var generation: int = 0
var exporting: bool = false
var wire_instance: int = 0
var previous_sent: int = 0
var previous_received: int = 0

func _ready() -> void:
	OS.add_logger(log)
	previous_physics = Engine.get_physics_frames()

func _process(dt: float) -> void:
	if not is_instance_valid(app): return
	if app.page!=last_page:
		last_page = app.page
		log.event(last_page)
	var now := Time.get_ticks_msec()/1000
	if buckets.is_empty() or int(buckets[-1].second)!=now:
		buckets.append({"second":now,"frames":0,"frame_ms_sum":0.0,"frame_ms_max":0.0,"physics_steps_max":0,"physics_ms_max":0.0,"draw_calls_max":0,"memory_bytes_max":0,"rtt_ms_max":0.0,"delivery_loss_percent_max":0.0,"sent_bytes":0,"received_bytes":0})
	while not buckets.is_empty() and int(buckets[0].second)<now-59: buckets.pop_front()
	var row := buckets[-1]
	row.frames += 1
	row.frame_ms_sum += maxf(0,dt*1000)
	row.frame_ms_max = maxf(row.frame_ms_max,dt*1000)
	row.physics_steps_max = maxi(row.physics_steps_max,Engine.get_physics_frames()-previous_physics)
	previous_physics = Engine.get_physics_frames()
	row.physics_ms_max = maxf(row.physics_ms_max,Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS)*1000)
	row.draw_calls_max = maxi(row.draw_calls_max,RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	row.memory_bytes_max = maxi(row.memory_bytes_max,OS.get_static_memory_usage())
	if is_instance_valid(app.network):
		if wire_instance!=app.network.get_instance_id():
			wire_instance = app.network.get_instance_id()
			previous_sent = 0
			previous_received = 0
		row.rtt_ms_max = maxf(row.rtt_ms_max,app.network.rtt_ms)
		row.delivery_loss_percent_max = maxf(row.delivery_loss_percent_max,app.network.quality.measure(Time.get_ticks_msec(),app.network.start_tick>=0 and app.network.phase!=RaceSession.Phase.RESULTS).loss_percent)
		row.sent_bytes += maxi(0,app.network.wire.sent_bytes-previous_sent)
		row.received_bytes += maxi(0,app.network.wire.received_bytes-previous_received)
		previous_sent = app.network.wire.sent_bytes
		previous_received = app.network.wire.received_bytes

static func safe_settings(saved: Dictionary, mobile: bool) -> Dictionary:
	var clean := SettingsCatalog.sanitize(saved,mobile)
	var result: Dictionary = {}
	for row: Dictionary in SettingsCatalog.rows:
		if row.id=="resolution":
			var resolution: String = str(clean[row.id])
			var pattern := RegEx.create_from_string("\\A[0-9]{3,5}x[0-9]{3,5}\\z")
			result[str(row.id)] = resolution if resolution=="native" or pattern.search(resolution)!=null else "native"
		else: result[str(row.id)] = clean[row.id]
	result["bindings"] = BindingBook.sanitize(clean.bindings)
	var layouts: Dictionary = {}
	for orientation: String in ["portrait","landscape"]:
		for device: String in ["phone","tablet"]:
			for acceleration: String in ["auto","manual"]:
				for steering: String in ["slider","buttons"]:
					for handed: String in ["left","right"]:
						var key := "_".join([orientation,device,acceleration,steering,handed])
						var profile: Variant = clean.touch_layouts.get(key)
						if not profile is Dictionary: continue
						var centers: Dictionary = {}
						for action: String in TouchLayoutBook.ACTIONS:
							if TouchLayoutBook.valid_center(profile.get(action)): centers[action] = profile[action].duplicate()
						if not centers.is_empty(): layouts[key] = centers
	result["touch_layouts"] = layouts
	return result

static func safe_build(value: Variant) -> Dictionary:
	var result := {"version":"Development","engine_version":"4.6.3-stable","protocol_version":NetCodec.PROTOCOL,"save_schema":SaveStore.SCHEMA,"content_hash":Compatibility.content_hash(),"distribution":"source"}
	if not value is Dictionary: return result
	var version := RegEx.create_from_string("\\A[0-9]{1,2}\\.[0-9]{1,2}\\.[0-9]{1,8}(-[a-z0-9]+)?\\z")
	for key: String in ["version","engine_version"]:
		if value.get(key) is String and version.search(value[key])!=null: result[key] = value[key]
	for key: String in ["target_platform","distribution","public_signing"]:
		var allowed: Array = {"target_platform":["linux","windows","macos","android","android_aab","server"],"distribution":["development","production","source"],"public_signing":["not configured","development","production","ad-hoc"]}[key]
		if value.get(key) in allowed: result[key] = value[key]
	for key: String in ["commit","engine_checksum","export_templates_checksum","content_hash","asset_hash"]:
		var pattern := RegEx.create_from_string("\\A[0-9a-f]{%d}\\z"%(40 if key=="commit" else 64))
		if value.get(key) is String and pattern.search(value[key])!=null: result[key] = value[key]
	if NetEvents.integer(value.get("build_number"),1,2147483647): result["build_number"] = int(value.build_number)
	if value.get("working_tree_dirty") is bool: result["working_tree_dirty"] = value.working_tree_dirty
	return result

func snapshot() -> Dictionary:
	var build: Variant = null
	if OS.has_feature("template") and FileAccess.file_exists("res://game/build.json"):
		var parser := JSON.new()
		if parser.parse(FileAccess.get_file_as_string("res://game/build.json"))==OK: build = parser.data
	var performance: Array[Dictionary] = []
	for bucket: Dictionary in buckets:
		var row := bucket.duplicate(true)
		row["age_seconds"] = maxi(0,Time.get_ticks_msec()/1000-int(row.second))
		row.erase("second")
		row["frame_ms_mean"] = float(row.frame_ms_sum)/maxi(1,int(row.frames))
		row.erase("frame_ms_sum")
		if int(row.memory_bytes_max)<=0: row["memory_bytes_max"] = null
		performance.append(row)
	var size := app.get_viewport().get_visible_rect().size
	var pixels := app.get_window().size
	var platform := {"os":OS.get_name(),"mobile":app.data.mobile,"renderer":RenderingServer.get_current_rendering_method(),"processor_count":OS.get_processor_count(),"viewport_width":int(size.x),"viewport_height":int(size.y),"window_pixel_width":pixels.x,"window_pixel_height":pixels.y,"native_save_dialog":DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE)}
	var display: WorldPresentation = app.presentation
	var runtime := {"selected_scale":display.adaptive.selected,"current_scale":display.adaptive.current,"adaptive_enabled":display.adaptive.enabled,"adaptive_changes":display.adaptive.changes,"world_width":display.viewport.size.x,"world_height":display.viewport.size.y,"render_work_ms":display.last_work_seconds*1000,"render_gpu_ms":display.last_gpu_seconds*1000,"presentation_interval_ms":display.last_interval_seconds*1000,"keep_awake":app.mobile_runtime.awake,"memory_warnings":app.mobile_runtime.memory_warnings}
	var race: Dictionary = {}
	if is_instance_valid(app.drive):
		var drive: RaceDrive = app.drive
		race = {"mode":drive.session.mode if drive.session.mode in ["quick","trial","cup","school","online"] else "unknown","track":drive.track.id,"car":drive.car.id,"laps":drive.lap_count,"elapsed_ticks":drive.race_ticks}
		if drive.network==null: race["seed"] = str(drive.session.seed)
	return {"build.json":safe_build(build),"platform.json":platform,"settings.json":safe_settings(app.data.settings,app.data.mobile),"performance.json":{"window_seconds":60,"seconds":performance,"runtime":runtime},"events.json":log.snapshot(),"race.json":race}

static func write_zip(path: String, contents: Dictionary) -> Error:
	if contents.keys().size()!=FILES.size(): return ERR_INVALID_DATA
	var encoded: Dictionary = {}
	var total_bytes: int = 0
	for name_value: String in FILES:
		if not contents.has(name_value) or not SaveStore.json_safe(contents[name_value]): return ERR_INVALID_DATA
		encoded[name_value] = JSON.stringify(contents[name_value],"  ").to_utf8_buffer()
		total_bytes += encoded[name_value].size()
	if total_bytes>MAX_ARCHIVE_BYTES-4096: return ERR_OUT_OF_MEMORY
	var zip := ZIPPacker.new()
	var error := zip.open(path)
	if error!=OK: return error
	for name_value: String in FILES:
		error = zip.start_file(name_value)
		if error==OK: error = zip.write_file(encoded[name_value])
		if error==OK: error = zip.close_file()
		if error!=OK:
			zip.close()
			return error
	return zip.close()

static func verify_archive(path: String) -> bool:
	var input := FileAccess.open(path,FileAccess.READ)
	if input==null or input.get_length()>MAX_ARCHIVE_BYTES: return false
	input.close()
	var reader := ZIPReader.new()
	if reader.open(path)!=OK: return false
	var names := reader.get_files()
	names.sort()
	var expected := PackedStringArray(FILES)
	expected.sort()
	var valid := names==expected
	var total_bytes: int = 0
	if valid:
		for name_value: String in FILES:
			var bytes := reader.read_file(name_value)
			total_bytes += bytes.size()
			var parser := JSON.new()
			if total_bytes>MAX_ARCHIVE_BYTES or parser.parse(bytes.get_string_from_utf8())!=OK or not SaveStore.json_safe(parser.data):
				valid = false
				break
	reader.close()
	return valid

static func copy_archive(source: String, destination: String) -> Error:
	if destination.is_empty() or destination==source: return ERR_INVALID_PARAMETER
	if not verify_archive(source): return ERR_INVALID_DATA
	var uri := destination.begins_with("content://")
	var target := destination if uri else destination+".pacific-"+RaceSetup.uuid()+".tmp"
	var input := FileAccess.open(source,FileAccess.READ)
	if input==null: return ERR_FILE_CANT_READ
	var output := FileAccess.open(target,FileAccess.WRITE)
	if output==null: return ERR_FILE_CANT_WRITE
	var error: Error = OK
	while input.get_position()<input.get_length():
		var amount := mini(32768,input.get_length()-input.get_position())
		var bytes := input.get_buffer(amount)
		if bytes.size()!=amount:
			error = ERR_FILE_CANT_READ
			break
		output.store_buffer(bytes)
		if output.get_error()!=OK:
			error = output.get_error()
			break
	output.flush()
	if error==OK: error = output.get_error()
	output.close()
	input.close()
	if error==OK and not uri: error = DirAccess.rename_absolute(target,destination)
	if error!=OK and not uri: DirAccess.remove_absolute(target)
	return error

func begin_export() -> Error:
	if exporting: return ERR_BUSY
	if app.data.mobile and not DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE): return ERR_UNAVAILABLE
	var folder := "user://diagnostics_cache"
	if DirAccess.make_dir_recursive_absolute(folder)!=OK: return ERR_FILE_CANT_WRITE
	cache_path = folder.path_join(RaceSetup.uuid()+".zip")
	var error := write_zip(cache_path,snapshot())
	if error!=OK:
		cleanup_cache()
		return error
	exporting = true
	generation += 1
	var token := generation
	dialog = FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.use_native_dialog = true
	dialog.title = I18n.t("settings.export")
	dialog.add_filter("*.zip",I18n.t("diagnostics.zip"),"application/zip")
	dialog.current_file = "pacific-rush-diagnostics-"+Time.get_datetime_string_from_system(true).replace(":","-")+"Z.zip"
	add_child(dialog)
	dialog.file_selected.connect(func(path: String) -> void:
		if token!=generation or not exporting: return
		var result := copy_archive(cache_path,path)
		finish("saved" if result==OK else "failed"))
	dialog.canceled.connect(func() -> void:
		if token==generation and exporting: finish("cancelled"))
	dialog.popup_centered_ratio(.8)
	return OK

func cleanup_cache() -> void:
	if not cache_path.is_empty() and FileAccess.file_exists(cache_path): DirAccess.remove_absolute(cache_path)
	cache_path = ""

func finish(state: String) -> void:
	exporting = false
	generation += 1
	if is_instance_valid(dialog): dialog.queue_free()
	dialog = null
	cleanup_cache()
	export_finished.emit(state)

func _exit_tree() -> void:
	OS.remove_logger(log)
	cleanup_cache()

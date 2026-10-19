class_name DiagnosticLog
extends Logger
## Exports known event codes and error locations, never free-form log text.
const MESSAGES: Dictionary = {"PACIFIC_RUSH_CLIENT_READY":"client_ready","PACIFIC_RUSH_DRIVING_READY":"driving_ready","NETWORK_STATUS Connecting":"connecting","NETWORK_STATUS Reconnecting":"reconnecting","NETWORK_STATUS Official room — waiting for racers":"official_lobby","NETWORK_STATUS Community server — waiting for racers":"community_lobby","NETWORK_STATUS Official room — race connected":"official_race","NETWORK_STATUS Community server — race connected":"community_race"}
var mutex := Mutex.new()
var entries: Array[Dictionary] = []
var error_counts: Array[int] = [0,0,0,0]
var omitted_messages: int = 0
var allowed_files: Dictionary = {}
var started: int = Time.get_ticks_msec()

func _init() -> void:
	allowed_files["res://game/client_app.gd"] = true
	allowed_files["res://game/main.gd"] = true
	for entry: Dictionary in ProjectSettings.get_global_class_list():
		if str(entry.path).begins_with("res://game/"): allowed_files[str(entry.path)] = true

func append_locked(row: Dictionary) -> void:
	row["at_ms"] = Time.get_ticks_msec()-started
	entries.append(row)
	if entries.size()>256: entries.pop_front()

func event(code: String) -> void:
	if code=="installation_error":
		mutex.lock()
		append_locked({"kind":"page","code":code})
		mutex.unlock()
		return
	if not code in ["main","name","event","race","pause","settings","touch_layout","school","school_complete","cup","garage","online","online_create","online_rooms","online_code","online_wait","lobby","loading","results","connect","connection_lost","credits","touch_unavailable"]: code = "other"
	mutex.lock()
	append_locked({"kind":"page","code":code})
	mutex.unlock()

func _log_message(message: String, _error: bool) -> void:
	var code: Variant = MESSAGES.get(message.strip_edges())
	mutex.lock()
	if code==null: omitted_messages += 1
	else: append_locked({"kind":"event","code":code})
	mutex.unlock()

func _log_error(_function: String, file: String, line: int, _code: String, _rationale: String, _editor_notify: bool, error_type: int, _script_backtraces: Array[ScriptBacktrace]) -> void:
	var category := clampi(error_type,0,3)
	mutex.lock()
	error_counts[category] += 1
	var row := {"kind":"engine_error","category":category,"line":clampi(line,0,1000000)}
	if allowed_files.has(file): row["resource"] = file
	append_locked(row)
	mutex.unlock()

func snapshot() -> Dictionary:
	mutex.lock()
	var result := {"entries":entries.duplicate(true),"error_counts":error_counts.duplicate(),"omitted_freeform_messages":omitted_messages}
	mutex.unlock()
	return result

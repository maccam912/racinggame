class_name WorkerDirectory
extends Node
## Operator-only private HTTP link. Guest secrets and bearer sessions never enter
## this process; it receives only a per-worker credential and the public key.

signal admitted(sender: int, claims: Dictionary, car: int, paint: int)
signal denied(sender: int)
signal leave_requested(guest: String)
signal retire_requested

var settings: Dictionary = {}
var verifier := TicketVerifier.new()
var heartbeat := HTTPRequest.new()
var state_provider: Callable
var healthy: bool = false
var retired: bool = false
var last_success: int = -1
var next_heartbeat: int = 0
var acknowledged: Array[String] = []
var pending_guests: Dictionary = {}
var requests: Array[HTTPRequest] = []


func configure() -> bool:
	var text := OS.get_environment("PR_WORKER_CONFIG")
	if text.length() > 8192:
		return false
	var parsed: Variant = JSON.parse_string(text)
	if not parsed is Dictionary:
		return false
	settings = parsed
	if not settings.get("worker_id") is String or not settings.get("room_id") is String or not settings.get("token") is String or TicketVerifier.decode64(settings.token).size() != 32 or not NetEvents.integer(settings.get("port"), 1024, 65535) or settings.get("protocol") != NetCodec.PROTOCOL or settings.get("content_hash") != Compatibility.content_hash() or not settings.get("rules") is Dictionary or not LobbyState.valid_rules(settings.rules) or not settings.get("name") is String or not PlayerName.validate(settings.name, 24).valid or not settings.get("private") is bool or not settings.get("code") is String or not PeerAddress.parse_code(settings.code).valid or settings.code.length() != 8 or not settings.get("region") is String or settings.region.length() > 40 or not settings.get("public_key_file") is String or not settings.get("private_url") is String:
		return false
	# URLs and file paths come exclusively from the operator's environment.
	if not (settings.private_url.begins_with("http://127.0.0.1:") or settings.private_url.begins_with("http://[::1]:")) or settings.private_url.length() > 128:
		return false
	return verifier.configure(FileAccess.get_file_as_string(settings.public_key_file), settings.room_id, settings.worker_id)


func _ready() -> void:
	add_child(heartbeat)
	heartbeat.timeout = 3
	heartbeat.body_size_limit = 8192
	heartbeat.request_completed.connect(heartbeat_complete)


func _process(_dt: float) -> void:
	var now := Time.get_ticks_msec()
	if last_success >= 0 and now - last_success >= 15000:
		healthy = false
	if now >= next_heartbeat and heartbeat.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED and state_provider.is_valid():
		next_heartbeat = now + 5000
		var body: Dictionary = state_provider.call()
		body.acknowledged = acknowledged.duplicate()
		var error := heartbeat.request(endpoint("heartbeat"), headers(), HTTPClient.METHOD_POST, JSON.stringify(body))
		if error != OK:
			healthy = false


func endpoint(operation: String) -> String:
	return str(settings.private_url).trim_suffix("/") + "/workers/" + str(settings.worker_id) + "/" + operation


func headers() -> PackedStringArray:
	return PackedStringArray(["Content-Type: application/json", "Authorization: Bearer " + str(settings.token)])


func heartbeat_complete(result: int, status: int, _headers: PackedStringArray, bytes: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or status != 200:
		if status in [401, 404]:
			healthy = false
			retired = true
			retire_requested.emit()
		return
	var response: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	if not response is Dictionary or not response.get("commands") is Array or response.commands.size() > 16 or not response.get("drain") is bool:
		return
	last_success = Time.get_ticks_msec()
	healthy = not retired
	acknowledged.clear()
	for command: Variant in response.commands:
		if not command is Dictionary or not command.get("id") is String or command.id.length() > 64 or not command.get("guest_id") is String or not TicketVerifier.uuid(command.guest_id) or command.get("kind") != "leave":
			continue
		leave_requested.emit(command.guest_id)
		acknowledged.append(command.id)
	if not acknowledged.is_empty(): next_heartbeat = 0
	if response.drain:
		retired = true
		healthy = false
		retire_requested.emit()


func admit(sender: int, event: Dictionary) -> void:
	if not healthy or retired or not event.get("ticket") is String or not NetEvents.integer(event.get("car"), 0, 3) or not NetEvents.integer(event.get("paint"), 0, 7) or requests.size() >= 8:
		denied.emit(sender)
		return
	var now := int(Time.get_unix_time_from_system())
	var claims := verifier.verify(event.ticket, now)
	if claims.is_empty() or pending_guests.has(claims.g) or not verifier.claim_nonce(claims, now):
		denied.emit(sender)
		return
	var request := HTTPRequest.new()
	request.timeout = 3
	request.body_size_limit = 8192
	add_child(request)
	requests.append(request)
	pending_guests[claims.g] = true
	request.request_completed.connect(func(result: int, status: int, _response_headers: PackedStringArray, bytes: PackedByteArray) -> void:
		var response: Variant = JSON.parse_string(bytes.get_string_from_utf8())
		pending_guests.erase(claims.g)
		requests.erase(request)
		request.queue_free()
		if result == HTTPRequest.RESULT_SUCCESS and status == 200 and response is Dictionary and response.get("accepted") == true and int(claims.e) > int(Time.get_unix_time_from_system()):
			admitted.emit(sender, claims, int(event.car), int(event.paint))
		else:
			denied.emit(sender)
	)
	var error := request.request(endpoint("consume"), headers(), HTTPClient.METHOD_POST, JSON.stringify({"guest_id":claims.g, "nonce":claims.x}))
	if error != OK:
		pending_guests.erase(claims.g)
		requests.erase(request)
		request.queue_free()
		denied.emit(sender)

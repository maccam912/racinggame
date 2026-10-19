class_name DirectoryClient
extends Node
## Bounded HTTPS-only client. Identity secrets and session tokens never emit/log.
signal completed(result: Dictionary)
signal status_changed(state: String)

var identity_service: GuestIdentityService
var data: AppData
var base: String = ""
var certificate: X509Certificate
var session_token: String = ""
var session_expiry: int = 0
var session_name: String = ""
var generation: int = 0
var request: HTTPRequest
var job: Dictionary = {}
var phase: String = ""
var deadline: int = 0
var pending_session: Dictionary = {}
var request_timeout: float = 8.0
var departures: Dictionary = {}

func configure(app_data: AppData, service: GuestIdentityService, url: String, ca: X509Certificate = null) -> Error:
	if busy():
		return ERR_BUSY
	var canonical := DirectorySchema.base_url(url)
	if canonical.is_empty():
		return ERR_INVALID_PARAMETER
	if is_instance_valid(identity_service) and identity_service.completed.is_connected(identity_completed):
		identity_service.completed.disconnect(identity_completed)
	data = app_data
	identity_service = service
	identity_service.completed.connect(identity_completed)
	base = canonical
	certificate = ca
	session_token = ""
	session_expiry = 0
	session_name = ""
	return OK

func busy() -> bool:
	return not job.is_empty()

func online() -> bool:
	return not session_token.is_empty() and int(Time.get_unix_time_from_system())<session_expiry and data!=null and session_name==data.profile.display_name

func begin(kind: String, payload: Dictionary = {}) -> Error:
	if busy() or not is_instance_valid(identity_service) or identity_service.busy() and kind not in ["rooms","regions"]:
		return ERR_BUSY
	if base.is_empty() or data==null or not kind in ["authenticate","regions","rooms","create","join","code","leave","deletion_request"]:
		return ERR_INVALID_PARAMETER
	if kind=="deletion_request" and data.profile.guest_reference.is_empty() and (not is_instance_valid(identity_service.identity) or not identity_service.identity.registered(base)):
		return ERR_DOES_NOT_EXIST
	if kind=="create" and not DirectorySchema.create_request(payload):
		return ERR_INVALID_DATA
	if kind in ["join","leave"] and (not payload.get("room_id") is String or not GuestIdentity.valid_uuid(payload.room_id)):
		return ERR_INVALID_DATA
	if kind=="rooms" and not payload.get("show_in_race",false) is bool:
		return ERR_INVALID_DATA
	if kind=="code" and (not payload.get("code") is String or not PeerAddress.parse_code(payload.code).valid or payload.code.is_empty()):
		return ERR_INVALID_DATA
	if kind=="join" and departures.has(str(payload.room_id)):
		return ERR_BUSY
	var checked := PlayerName.validate(data.profile.display_name)
	if not checked.valid:
		return ERR_INVALID_DATA
	job = {"kind":kind,"payload":payload.duplicate(true),"name":checked.value,"retried":false}
	deadline = Time.get_ticks_msec()+10000
	status_changed.emit("connecting")
	if kind in ["rooms","regions"] or online():
		perform_job()
	else:
		load_identity()
	return OK

func load_identity() -> void:
	phase = "identity_load"
	if identity_service.begin()!=OK:
		finish(false,"storage_busy")

func identity_completed(result: Dictionary) -> void:
	if job.is_empty() or not phase in ["identity_load","identity_register"]:
		return
	if not result.get("ok",false):
		finish(false,"identity_"+str(result.get("state","unavailable")))
		return
	if phase=="identity_register":
		install_session(pending_session)
		pending_session.clear()
		perform_job()
		return
	var identity := identity_service.identity
	if identity.registered(base):
		phase = "challenge"
		send("/v1/auth/challenge",HTTPClient.METHOD_POST,{"guest_id":identity.guest_id})
	elif job.kind=="deletion_request":
		finish(false,"no_registered_identity")
	else:
		phase = "register"
		send("/v1/guests",HTTPClient.METHOD_POST,{"guest_id":identity.guest_id,"secret":TicketVerifier.encode64(identity.secret),"display_name":job.name})

func install_session(payload: Dictionary) -> void:
	session_token = payload.session_token
	session_expiry = int(payload.expires_at)
	session_name = payload.display_name

func perform_job() -> void:
	phase = "operation"
	var payload: Dictionary = job.payload
	match str(job.kind):
		"authenticate": finish(true,"ok",{"session_only":not identity_service.identity.persistent})
		"deletion_request": send("/v1/data/deletion-request",HTTPClient.METHOD_POST,{},true)
		"regions": send("/v1/regions",HTTPClient.METHOD_GET)
		"rooms": send("/v1/rooms?protocol=%d&content_hash=%s&show_in_race=%s" % [NetCodec.PROTOCOL,Compatibility.content_hash(),"true" if bool(payload.get("show_in_race",false)) else "false"],HTTPClient.METHOD_GET)
		"create": send("/v1/rooms",HTTPClient.METHOD_POST,payload,true)
		"join","leave":
			if not payload.get("room_id") is String or not GuestIdentity.valid_uuid(payload.room_id):
				finish(false,"invalid_room")
			else:
				send("/v1/rooms/"+str(payload.room_id)+"/"+str(job.kind),HTTPClient.METHOD_POST,compatibility() if job.kind=="join" else {},true)
		"code":
			var code := PeerAddress.parse_code(str(payload.get("code","")))
			if not code.valid or code.value.is_empty():
				finish(false,"room_unavailable")
			else:
				var body := compatibility()
				body.code = code.value
				send("/v1/rooms/code/join",HTTPClient.METHOD_POST,body,true)

static func compatibility() -> Dictionary:
	return {"protocol":NetCodec.PROTOCOL,"content_hash":Compatibility.content_hash()}

func send(path: String, method: HTTPClient.Method, body: Dictionary = {}, authorized: bool = false) -> void:
	if Time.get_ticks_msec()>=deadline:
		finish(false,"timeout")
		return
	var current := HTTPRequest.new()
	current.use_threads = true
	current.timeout = minf(request_timeout,maxf(.1,float(deadline-Time.get_ticks_msec())/1000.0))
	current.max_redirects = 0
	current.body_size_limit = 262144
	current.download_chunk_size = 4096
	if certificate!=null:
		current.set_tls_options(TLSOptions.client(certificate))
	add_child(current)
	request = current
	var active_generation := generation
	current.request_completed.connect(func(result: int, status: int, _headers: PackedStringArray, bytes: PackedByteArray) -> void:
		current.queue_free()
		if active_generation!=generation or job.is_empty():
			return
		request = null
		response(result,status,bytes))
	var headers := PackedStringArray(["Content-Type: application/json","Accept: application/json"])
	if authorized:
		headers.append("Authorization: Bearer "+session_token)
	if current.request(base+path,headers,method,"" if method==HTTPClient.METHOD_GET else JSON.stringify(body))!=OK:
		current.queue_free()
		request = null
		finish(false,"unreachable")

func response(result: int, status: int, bytes: PackedByteArray) -> void:
	if result!=HTTPRequest.RESULT_SUCCESS:
		finish(false,"timeout" if result==HTTPRequest.RESULT_TIMEOUT else "unreachable")
		return
	var payload: Dictionary = {}
	if status!=204:
		var parser := JSON.new()
		if bytes.size()>262144 or parser.parse(bytes.get_string_from_utf8())!=OK or not parser.data is Dictionary:
			finish(false,"invalid_response")
			return
		payload = parser.data
	if status==401 and phase=="operation" and job.kind in ["create","join","code","leave","deletion_request"] and not job.retried:
		job.retried = true
		session_token = ""
		load_identity()
		return
	if status<200 or status>=300:
		var code := "service_unavailable"
		if payload.get("error") is Dictionary and payload.error.get("code") is String and payload.error.code in ["rate_limited","room_unavailable","room_full","invalid_name","invalid_rules","invalid_auth","invalid_guest","incompatible","no_capacity","capacity"]:
			code = payload.error.code
		finish(false,"room_unavailable" if job.kind=="code" and status!=429 else code)
		return
	var now := int(Time.get_unix_time_from_system())
	match phase:
		"challenge":
			if not payload.get("nonce") is String or payload.nonce.length()!=43 or TicketVerifier.decode64(payload.nonce).size()!=32 or not NetEvents.integer(payload.get("expires_at"),now+1,now+90):
				finish(false,"invalid_response")
				return
			phase = "session"
			var identity := identity_service.identity
			send("/v1/auth/session",HTTPClient.METHOD_POST,{"guest_id":identity.guest_id,"nonce":payload.nonce,"proof":DirectorySchema.auth_proof(identity.secret,identity.guest_id,payload.nonce,job.name),"display_name":job.name})
		"register","session":
			if not DirectorySchema.session(payload,identity_service.identity.guest_id,job.name,now):
				finish(false,"invalid_response")
				return
			if phase=="register":
				pending_session = payload
				phase = "identity_register"
				if identity_service.begin("register",base)!=OK:
					finish(false,"storage_busy")
			else:
				install_session(payload)
				perform_job()
		"operation":
			var valid := true
			match str(job.kind):
				"rooms": valid = DirectorySchema.rooms(payload)
				"regions": valid = DirectorySchema.regions(payload)
				"deletion_request": valid = DirectorySchema.deletion_request(payload,now)
				"create","join","code": valid = DirectorySchema.admission(payload,now)
			finish(valid,"ok" if valid else "invalid_response",payload if valid else {})

func finish(ok: bool, state: String, payload: Dictionary = {}) -> void:
	var kind: String = job.get("kind","")
	generation += 1
	if is_instance_valid(request):
		request.cancel_request()
		request.queue_free()
	request = null
	job.clear()
	phase = ""
	pending_session.clear()
	status_changed.emit("online" if online() else "offline")
	completed.emit({"ok":ok,"state":state,"kind":kind,"payload":payload})

func cancel() -> void:
	generation += 1
	if is_instance_valid(request):
		request.cancel_request()
		request.queue_free()
	request = null
	job.clear()
	phase = ""
	pending_session.clear()
	if is_instance_valid(identity_service):
		identity_service.cancel()
	status_changed.emit("online" if online() else "offline")

func depart(room: String) -> void:
	# A best-effort HTTPS leave survives ordinary menu cancellation. ENet also
	# flushes its leave packet; this path releases directory reservations.
	if base.is_empty() or session_token.is_empty() or not GuestIdentity.valid_uuid(room) or departures.has(room):
		return
	var current := HTTPRequest.new()
	current.use_threads = true
	current.timeout = 3.0
	current.max_redirects = 0
	current.body_size_limit = 8192
	if certificate!=null: current.set_tls_options(TLSOptions.client(certificate))
	add_child(current)
	departures[room] = current
	current.request_completed.connect(func(_result: int,_status: int,_headers: PackedStringArray,_bytes: PackedByteArray) -> void:
		if departures.get(room)==current: departures.erase(room)
		current.queue_free())
	if current.request(base+"/v1/rooms/"+room+"/leave",PackedStringArray(["Content-Type: application/json","Authorization: Bearer "+session_token]),HTTPClient.METHOD_POST,"{}")!=OK:
		departures.erase(room)
		current.queue_free()

func forget_session() -> void:
	cancel()
	session_token = ""
	session_expiry = 0
	session_name = ""
	status_changed.emit("offline")

func _process(_delta: float) -> void:
	if busy() and Time.get_ticks_msec()>=deadline:
		if is_instance_valid(identity_service):
			identity_service.cancel()
		finish(false,"timeout")

func _exit_tree() -> void:
	cancel()

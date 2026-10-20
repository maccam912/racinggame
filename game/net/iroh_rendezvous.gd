class_name IrohRendezvous
extends Node
## The same short-code service used by Mega Chamomile. Tokens stay in memory.

const URL: String = "https://iroh-rendezvous.maccam912.workers.dev"
const PATH: String = "/v1/join-codes"
const ALPHABET: String = "23456789ABCDEFGHJKMNPQRSTVWXYZ"


static func normalize(value: String) -> String:
	return value.strip_edges().to_upper()


static func valid_code(value: String) -> bool:
	var code := normalize(value)
	if code.length()!=4: return false
	for character in code:
		if not character in ALPHABET: return false
	return true


static func session_id() -> String:
	return "pacific-rush/%d/%s" % [NetCodec.PROTOCOL,Compatibility.content_hash()]


func register(endpoint: String) -> Dictionary:
	return await request(PATH,HTTPClient.METHOD_POST,{"endpoint_id":endpoint,"session_id":session_id(),"expires_in":600})


func resolve(code: String) -> Dictionary:
	if not valid_code(code): return {"ok":false,"message":I18n.t("online.iroh_code_error")}
	var reply := await request(PATH+"/"+normalize(code))
	if not reply.ok: return reply
	if reply.payload.get("session_id")!=session_id():
		return {"ok":false,"message":I18n.t("online.iroh_incompatible")}
	if not IrohTransport.valid_endpoint(str(reply.payload.get("endpoint_id",""))):
		return {"ok":false,"message":I18n.t("online.iroh_service_error")}
	return reply


func revoke(code: String, token: String) -> void:
	if valid_code(code) and not token.is_empty():
		await request(PATH+"/"+normalize(code),HTTPClient.METHOD_DELETE,{},token)


func request(path: String, method: int = HTTPClient.METHOD_GET, payload: Dictionary = {}, token: String = "") -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 10
	http.body_size_limit = 16384
	http.max_redirects = 0
	add_child(http)
	var headers := PackedStringArray(["Accept: application/json"])
	if method==HTTPClient.METHOD_POST: headers.append("Content-Type: application/json")
	if not token.is_empty(): headers.append("Authorization: Bearer "+token)
	var error := http.request(URL+path,headers,method,JSON.stringify(payload) if method==HTTPClient.METHOD_POST else "")
	if error!=OK:
		http.queue_free()
		return {"ok":false,"message":I18n.t("online.iroh_service_error")}
	var response: Array = await http.request_completed
	http.queue_free()
	if int(response[0])!=HTTPRequest.RESULT_SUCCESS:
		return {"ok":false,"message":I18n.t("online.iroh_service_error")}
	var status := int(response[1])
	if status==404: return {"ok":false,"message":I18n.t("online.iroh_expired")}
	if status==429: return {"ok":false,"message":I18n.t("online.iroh_rate_limit")}
	if status==204: return {"ok":true,"payload":{}}
	if status<200 or status>=300: return {"ok":false,"message":I18n.t("online.iroh_service_error")}
	var parsed: Variant = JSON.parse_string((response[3] as PackedByteArray).get_string_from_utf8())
	if not parsed is Dictionary: return {"ok":false,"message":I18n.t("online.iroh_service_error")}
	return {"ok":true,"payload":parsed}

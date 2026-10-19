class_name DirectorySchema
extends RefCounted
## Validate service data before it reaches menus or an ENet connection.

static func base_url(value: String) -> String:
	var pattern := RegEx.new()
	pattern.compile("\\Ahttps://(\\[[0-9A-Fa-f:]+\\]|[A-Za-z0-9.-]+)(?::([0-9]{1,5}))?/?\\z")
	var match_value := pattern.search(value)
	if match_value==null or value.length()>300:
		return ""
	var host := match_value.get_string(1).to_lower()
	var port := int(match_value.get_string(2)) if not match_value.get_string(2).is_empty() else 443
	if PeerAddress.parse(host+":"+str(port)).is_empty():
		return ""
	return "https://"+host+(":"+str(port) if port!=443 else "")

static func region_id(value: Variant) -> bool:
	if not value is String or value.is_empty() or value.length()>40:
		return false
	for c: String in value:
		if not c in "abcdefghijklmnopqrstuvwxyz0123456789_-":
			return false
	return true

static func regions(payload: Dictionary) -> bool:
	if not payload.get("regions") is Array or payload.regions.size()>8:
		return false
	var seen: Dictionary = {}
	for row: Variant in payload.regions:
		if not row is Dictionary or not region_id(row.get("id")) or seen.has(row.id) or not row.get("name") is String or not PlayerName.validate(row.name,40).valid or not row.get("url") is String or base_url(row.url).is_empty() or not row.get("available") is bool or not NetEvents.integer(row.get("protocol"),NetCodec.PROTOCOL,NetCodec.PROTOCOL) or not row.get("content_hash") is String or row.content_hash!=Compatibility.content_hash():
			return false
		seen[row.id] = true
	return true

static func rooms(payload: Dictionary) -> bool:
	if not payload.get("rooms") is Array or payload.rooms.size()>128:
		return false
	var seen: Dictionary = {}
	for row: Variant in payload.rooms:
		if not row is Dictionary or not row.get("id") is String or not GuestIdentity.valid_uuid(row.id) or seen.has(row.id) or not row.get("name") is String or not PlayerName.validate(row.name,24).valid or not region_id(row.get("region")) or not row.get("rules") is Dictionary or not LobbyState.valid_rules(row.rules) or not NetEvents.integer(row.get("humans"),0,8) or not NetEvents.integer(row.get("capacity"),8,8) or not row.get("state") is String or not row.state in ["Lobby","Loading","InRace","Results"] or not NetEvents.integer(row.get("created_at"),0,9007199254740991):
			return false
		seen[row.id] = true
	return true

static func admission(payload: Dictionary, now: int) -> bool:
	for key: String in ["room_id","worker_id"]:
		if not payload.get(key) is String or not GuestIdentity.valid_uuid(payload[key]):
			return false
	if not payload.get("host") is String or not NetEvents.integer(payload.get("port"),1,65535) or not NetEvents.integer(payload.get("protocol"),NetCodec.PROTOCOL,NetCodec.PROTOCOL) or not payload.get("content_hash") is String or payload.content_hash!=Compatibility.content_hash() or not region_id(payload.get("region")) or not NetEvents.integer(payload.get("expires_at"),now+1,now+60) or not payload.get("ticket") is String or payload.ticket.length()>1100:
		return false
	var host: String = payload.host
	var address := PeerAddress.parse(("["+host+"]" if ":" in host else host)+":"+str(int(payload.port)))
	var pieces: PackedStringArray = payload.ticket.split(".")
	if address.is_empty() or pieces.size()!=2 or TicketVerifier.decode64(pieces[0]).is_empty() or TicketVerifier.decode64(pieces[1]).size()!=256:
		return false
	if payload.has("code") and (not payload.code is String or not PeerAddress.parse_code(payload.code).valid or payload.code.length()!=8):
		return false
	return true

static func create_request(payload: Dictionary) -> bool:
	return payload.size()==6 and payload.get("name") is String and PlayerName.validate(payload.name,24).valid and payload.get("private") is bool and region_id(payload.get("region")) and payload.get("rules") is Dictionary and LobbyState.valid_rules(payload.rules) and NetEvents.integer(payload.get("protocol"),NetCodec.PROTOCOL,NetCodec.PROTOCOL) and payload.get("content_hash") is String and payload.content_hash==Compatibility.content_hash()

static func session(payload: Dictionary, guest: String, name_value: String, now: int) -> bool:
	return payload.get("guest_id") is String and payload.guest_id==guest and payload.get("display_name") is String and payload.display_name==name_value and payload.get("session_token") is String and payload.session_token.length()==43 and TicketVerifier.decode64(payload.session_token).size()==32 and NetEvents.integer(payload.get("expires_at"),now+1,now+3900)

static func auth_proof(secret: PackedByteArray, guest: String, nonce: String, name_value: String) -> String:
	var message := "pacific-rush-auth-v1\n%s\n%s\n%s" % [guest,nonce,PlayerName.nfc(name_value)]
	return TicketVerifier.encode64(Crypto.new().hmac_digest(HashingContext.HASH_SHA256,secret,message.to_utf8_buffer()))

static func deletion_request(payload: Dictionary, now: int) -> bool:
	return payload.size()==3 and payload.get("request_id") is String and GuestIdentity.valid_uuid(payload.request_id) and payload.get("status") is String and payload.status=="pending_operator" and NetEvents.integer(payload.get("created_at"),0,now+60)

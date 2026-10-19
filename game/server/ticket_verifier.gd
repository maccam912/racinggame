class_name TicketVerifier
extends RefCounted
## Fixed RSA-2048/SHA-256 admission format. The signed raw JSON bytes are hashed;
## no JSON reserialization, client algorithm selector or client key is accepted.

var key := CryptoKey.new()
var crypto := Crypto.new()
var ready: bool = false
var room_id: String = ""
var worker_id: String = ""
var seen: Dictionary = {}


func configure(public_pem: String, room: String, worker: String) -> bool:
	room_id = room
	worker_id = worker
	ready = uuid(room) and uuid(worker) and key.load_from_string(public_pem, true) == OK and key.is_public_only()
	return ready


static func uuid(value: String) -> bool:
	if value.length() != 36 or value != value.to_lower() or value[8] != "-" or value[13] != "-" or value[18] != "-" or value[23] != "-" or value[14] != "4" or value[19] not in ["8", "9", "a", "b"]:
		return false
	var compact := value.replace("-", "")
	return compact.length() == 32 and compact.is_valid_hex_number(false)


static func decode64(value: String) -> PackedByteArray:
	if value.is_empty() or value.length() > 1100 or value.length() % 4 == 1:
		return PackedByteArray()
	for character: String in value:
		if not character in "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_":
			return PackedByteArray()
	var standard := value.replace("-", "+").replace("_", "/")
	while standard.length() % 4 != 0:
		standard += "="
	var bytes := Marshalls.base64_to_raw(standard)
	# Reject noncanonical pad bits and alternate encodings of the same nonce.
	return bytes if encode64(bytes) == value else PackedByteArray()


static func encode64(bytes: PackedByteArray) -> String:
	return Marshalls.raw_to_base64(bytes).replace("+", "-").replace("/", "_").replace("=", "")


func verify(ticket: String, now: int) -> Dictionary:
	if not ready or ticket.length() > 1100:
		return {}
	var parts := ticket.split(".")
	if parts.size() != 2:
		return {}
	var payload := decode64(parts[0])
	var signature := decode64(parts[1])
	if payload.is_empty() or signature.size() != 256:
		return {}
	var hasher := HashingContext.new()
	hasher.start(HashingContext.HASH_SHA256)
	hasher.update(payload)
	if not crypto.verify(HashingContext.HASH_SHA256, hasher.finish(), signature, key):
		return {}
	var parsed: Variant = JSON.parse_string(payload.get_string_from_utf8())
	if not parsed is Dictionary:
		return {}
	var claims: Dictionary = parsed
	if claims.size() != 10 or claims.get("v") != 1 or not claims.get("g") is String or not uuid(claims.g) or not claims.get("n") is String or not PlayerName.validate(claims.n).valid or PlayerName.nfc(claims.n) != claims.n or claims.get("r") != room_id or claims.get("w") != worker_id or claims.get("p") != NetCodec.PROTOCOL or claims.get("c") != Compatibility.content_hash() or not NetEvents.integer(claims.get("i"), 0, 9007199254740991) or not NetEvents.integer(claims.get("e"), 0, 9007199254740991) or not claims.get("x") is String or claims.x.length() != 32 or not claims.x.is_valid_hex_number(false) or claims.x != claims.x.to_lower():
		return {}
	if int(claims.i) > now or int(claims.e) <= now or int(claims.e) <= int(claims.i) or int(claims.e) - int(claims.i) > 60:
		return {}
	return claims


func claim_nonce(claims: Dictionary, now: int) -> bool:
	for nonce: String in seen.keys():
		if int(seen[nonce]) <= now:
			seen.erase(nonce)
	if seen.has(claims.x) or seen.size() >= 1024:
		return false
	seen[claims.x] = int(claims.e)
	return true

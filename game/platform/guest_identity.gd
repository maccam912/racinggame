class_name GuestIdentity
extends RefCounted
## Call load_or_create on a worker; commit the public profile reference on main.
## The secret and registration history live only here and in the OS store.

var store: ProtectedGuestStore
var guest_id: String = ""
var secret := PackedByteArray()
var regions: Array[String] = []
var persistent: bool = false
var state: String = "empty"

func _init(protected_store: ProtectedGuestStore) -> void:
	store = protected_store

static func valid_uuid(value: String) -> bool:
	if value.length()!=36 or value[14]!="4" or not value[19] in "89ab":
		return false
	for i in range(36):
		if i in [8,13,18,23]:
			if value[i]!="-":
				return false
		elif not value[i] in "0123456789abcdef":
			return false
	return true

func load_or_create(reference: String) -> Dictionary:
	if not guest_id.is_empty():
		if not reference.is_empty() and reference!=guest_id:
			return {"ok":false,"state":"reference_changed"}
		if state=="write_failed":
			var retried := retry_storage()
			if not retried.ok:
				return retried
		return {"ok":true,"state":state,"persistent":persistent}
	if not reference.is_empty():
		if not valid_uuid(reference):
			return {"ok":false,"state":"invalid_reference"}
		var loaded := store.read_secret("guest:"+reference)
		if not loaded.get("ok",false):
			return {"ok":false,"state":loaded.get("state","unavailable")}
		var parser := JSON.new()
		if parser.parse(loaded.value.get_string_from_utf8())!=OK:
			return {"ok":false,"state":"invalid"}
		var parsed: Variant = parser.data
		if not parsed is Dictionary or parsed.get("version")!=1 or parsed.get("guest_id")!=reference or not parsed.get("secret") is String or not parsed.get("regions") is Array or parsed.regions.size()>16:
			return {"ok":false,"state":"invalid"}
		if parsed.secret.length()!=44 or not parsed.secret.ends_with("="):
			return {"ok":false,"state":"invalid"}
		for i in range(43):
			if not parsed.secret[i] in "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/":
				return {"ok":false,"state":"invalid"}
		var decoded := Marshalls.base64_to_raw(parsed.secret)
		if decoded.size()!=32 or Marshalls.raw_to_base64(decoded)!=parsed.secret:
			return {"ok":false,"state":"invalid"}
		for region: Variant in parsed.regions:
			if not region is String or region.length()!=64 or not region.is_valid_hex_number(false):
				return {"ok":false,"state":"invalid"}
		guest_id = reference
		secret = decoded
		regions.assign(parsed.regions)
		persistent = true
		state = "ready"
		return {"ok":true,"state":state,"persistent":true}
	guest_id = RaceSetup.uuid()
	secret = Crypto.new().generate_random_bytes(32)
	var stored := persist()
	persistent = stored.ok
	# Storage write failures must be retried, not downgraded to a new identity.
	if not stored.ok and stored.state not in ["unavailable","locked"]:
		state = "write_failed"
		return {"ok":false,"state":state}
	state = "ready" if persistent else "session_only"
	return {"ok":true,"state":state,"persistent":persistent}

func persist() -> Dictionary:
	if not valid_uuid(guest_id) or secret.size()!=32:
		return {"ok":false,"state":"invalid"}
	return store.write_secret("guest:"+guest_id,JSON.stringify({"version":1,"guest_id":guest_id,"secret":Marshalls.raw_to_base64(secret),"regions":regions}).to_utf8_buffer())

func retry_storage() -> Dictionary:
	var result := persist()
	if result.ok:
		persistent = true
		state = "ready"
	return result

func commit_reference(data: AppData) -> Error:
	if not persistent:
		return OK if state=="session_only" else ERR_UNAVAILABLE
	var previous: String = data.profile.guest_reference
	if not previous.is_empty() and previous!=guest_id:
		return ERR_INVALID_DATA
	data.profile.guest_reference = guest_id
	var error := data.save_profile()
	if error!=OK:
		data.profile.guest_reference = previous
	return error

func registered(url: String) -> bool:
	return url.sha256_text() in regions

func mark_registered(url: String) -> Dictionary:
	if not valid_uuid(guest_id) or secret.size()!=32:
		return {"ok":false,"state":"empty"}
	var key := url.sha256_text()
	if key in regions:
		return {"ok":true,"state":"ok"}
	if regions.size()>=16:
		return {"ok":false,"state":"region_limit"}
	regions.append(key)
	if persistent:
		var result := persist()
		if not result.ok:
			regions.erase(key)
			return result
	return {"ok":true,"state":"ok"}

func erase(reference: String) -> Dictionary:
	if reference.is_empty():
		reference = guest_id
	if not reference.is_empty():
		if not valid_uuid(reference):
			return {"ok":false,"state":"invalid_reference"}
		var result := store.erase_secret("guest:"+reference)
		if not result.ok:
			return result
	guest_id = ""
	secret.fill(0)
	secret = PackedByteArray()
	regions.clear()
	persistent = false
	state = "empty"
	return {"ok":true,"state":"ok"}

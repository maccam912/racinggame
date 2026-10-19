extends SceneTree

class FakeStore extends RefCounted:
	var backend: String = "Keychain"
	var values: Dictionary = {}
	var ciphers: Dictionary = {}
	var unavailable: bool = false
	var locked: bool = false
	var writes: int = 0
	func backend_name() -> String:
		return backend
	func secret_read(scope: String) -> Dictionary:
		if unavailable or locked:
			return {"ok":false,"state":"locked" if locked else "unavailable"}
		return {"ok":true,"state":"ok","value":values[scope]} if values.has(scope) else {"ok":false,"state":"missing"}
	func secret_write(scope: String, value: PackedByteArray) -> Dictionary:
		writes += 1
		if unavailable or locked:
			return {"ok":false,"state":"locked" if locked else "unavailable"}
		values[scope] = value.duplicate()
		return {"ok":true,"state":"ok"}
	func secret_erase(scope: String) -> Dictionary:
		if unavailable or locked:
			return {"ok":false,"state":"locked" if locked else "unavailable"}
		values.erase(scope)
		return {"ok":true,"state":"ok"}
	func protect(scope: String, value: PackedByteArray) -> Dictionary:
		if unavailable:
			return {"ok":false,"state":"unavailable"}
		var token := Crypto.new().generate_random_bytes(64)
		ciphers[token.hex_encode()] = {"scope":scope,"value":value.duplicate()}
		return {"ok":true,"state":"ok","value":token}
	func unprotect(scope: String, value: PackedByteArray) -> Dictionary:
		var row: Dictionary = ciphers.get(value.hex_encode(),{})
		return {"ok":true,"state":"ok","value":row.value} if row.get("scope")==scope else {"ok":false,"state":"invalid"}

func _initialize() -> void:
	Catalog.load_all()
	var root := "user://identity-tests-"+RaceSetup.uuid()
	var data := AppData.new(root,false)
	var fake := FakeStore.new()
	var protected := ProtectedGuestStore.new(root,fake)
	var identity := GuestIdentity.new(protected)
	assert(identity.load_or_create("").ok and identity.persistent)
	var original := identity.guest_id
	var secret := identity.secret.duplicate()
	assert(GuestIdentity.valid_uuid(original) and secret.size()==32)
	assert(data.profile.guest_reference.is_empty())
	data.store.fail_stage = "before_replace"
	assert(identity.commit_reference(data)!=OK and data.profile.guest_reference.is_empty())
	assert(identity.load_or_create("").ok and identity.guest_id==original and fake.writes==1)
	data.store.fail_stage = ""
	assert(identity.commit_reference(data)==OK and data.profile.guest_reference==original)
	assert(not FileAccess.get_file_as_string(data.store.path("profile")).contains(Marshalls.raw_to_base64(secret)))
	assert(identity.mark_registered("https://test.invalid").ok)
	var cold := GuestIdentity.new(protected)
	assert(cold.load_or_create(original).ok and cold.guest_id==original and cold.secret==secret and cold.registered("https://test.invalid"))
	var saved: PackedByteArray = fake.values["guest:"+original].duplicate()
	var payload: Dictionary = JSON.parse_string(saved.get_string_from_utf8())
	var bad_secret := payload.duplicate(true)
	bad_secret.secret = "?".repeat(43)+"="
	var noncanonical := payload.duplicate(true)
	noncanonical.secret = "A".repeat(42)+"B="
	var future := payload.duplicate(true)
	future.version = 2
	var wrong_id := payload.duplicate(true)
	wrong_id.guest_id = RaceSetup.uuid()
	var bad_regions := payload.duplicate(true)
	bad_regions.regions = [17]
	for corrupt: String in ["{", "[]", "{}", JSON.stringify(bad_secret), JSON.stringify(noncanonical), JSON.stringify(future), JSON.stringify(wrong_id), JSON.stringify(bad_regions)]:
		fake.values["guest:"+original] = corrupt.to_utf8_buffer()
		var rejected := GuestIdentity.new(protected)
		assert(not rejected.load_or_create(original).ok and rejected.guest_id.is_empty() and rejected.secret.is_empty())
	fake.values["guest:"+original] = saved
	fake.locked = true
	var blocked := GuestIdentity.new(protected)
	assert(not blocked.load_or_create(original).ok and blocked.guest_id.is_empty())
	assert(fake.writes==2)
	fake.locked = false
	assert(not blocked.load_or_create(RaceSetup.uuid()).ok and blocked.guest_id.is_empty())
	assert(not blocked.load_or_create("bad/ref").ok)
	assert(data.reset_local(false)==OK and data.profile.guest_reference==original)
	assert(protected.read_secret("guest:"+original).ok)
	assert(cold.erase(original).ok and not protected.read_secret("guest:"+original).ok)
	assert(cold.secret.is_empty() and cold.guest_id.is_empty())
	fake.unavailable = true
	var ephemeral := GuestIdentity.new(protected)
	assert(ephemeral.load_or_create("").ok and not ephemeral.persistent and ephemeral.state=="session_only")
	var ephemeral_id := ephemeral.guest_id
	assert(ephemeral.load_or_create("").ok and ephemeral.guest_id==ephemeral_id)
	assert(ephemeral.commit_reference(data)==OK and data.profile.guest_reference==original)
	fake.unavailable = false
	assert(ephemeral.retry_storage().ok and ephemeral.persistent)
	assert(ephemeral.commit_reference(data)==ERR_INVALID_DATA)
	assert(ephemeral.erase("").ok)
	# Only ciphertext goes to a file, and a failed replacement preserves the prior blob.
	fake.backend = "DPAPI"
	var encrypted := ProtectedGuestStore.new(root,fake)
	var scope := "test:"+RaceSetup.uuid()
	assert(encrypted.write_secret(scope,secret).ok)
	var file := encrypted.encrypted_file(scope)
	var prior := FileAccess.get_file_as_bytes(file)
	assert(prior!=secret and encrypted.read_secret(scope).value==secret)
	encrypted.fail_write = true
	assert(not encrypted.write_secret(scope,PackedByteArray([1,2,3])).ok)
	assert(FileAccess.get_file_as_bytes(file)==prior and encrypted.read_secret(scope).value==secret)
	assert(not FileAccess.file_exists(file+".tmp"))
	encrypted.fail_write = false
	assert(encrypted.erase_secret(scope).ok and not FileAccess.file_exists(file))
	var failed := GuestIdentity.new(encrypted)
	encrypted.fail_write = true
	assert(not failed.load_or_create("").ok and failed.state=="write_failed")
	var failed_id := failed.guest_id
	assert(not failed.load_or_create("").ok and failed.guest_id==failed_id)
	encrypted.fail_write = false
	assert(failed.load_or_create("").ok and failed.persistent and failed.guest_id==failed_id)
	assert(failed.erase("").ok)
	assert(AppData.remove_tree(ProjectSettings.globalize_path(root))==OK)
	print("GUEST_IDENTITY_TRANSACTION_PASS")
	quit()

extends Node
## Exported-package, random test namespace only. Never prints protected values.
var worker := Thread.new()
var outcome: bool = false

func _ready() -> void:
	worker.start(run_probe)

func _process(_delta: float) -> void:
	if worker.is_started() and not worker.is_alive():
		outcome = worker.wait_to_finish()
		print("PROTECTED_STORE_PROBE_PASS" if outcome else "PROTECTED_STORE_PROBE_FAIL")
		get_tree().quit(0 if outcome else 1)

func run_probe() -> bool:
	var scope := ""
	var action := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--probe-scope="):
			scope = arg.trim_prefix("--probe-scope=")
		if arg.begins_with("--probe-action="):
			action = arg.trim_prefix("--probe-action=")
	if not scope.begins_with("test:") or not GuestIdentity.valid_uuid(scope.trim_prefix("test:")) or not action in ["write","read","replace","read_replaced","erase","cleanup"]:
		return false
	var store := ProtectedGuestStore.new("user://diagnostic_profiles/protected_store_probe")
	if action=="cleanup":
		return store.erase_secret(scope).ok and not store.read_secret(scope).ok
	var value := PackedByteArray()
	for i in range(64):
		value.append(i)
	if action in ["replace","read_replaced","erase"]:
		if action=="replace":
			var before := store.read_secret(scope)
			if not before.ok or before.value!=value:
				return false
		value.reverse()
	if action in ["write","replace"]:
		if store.provider is AndroidKeyStoreAdapter:
			var key: Variant = store.provider.get_key(store.provider.key_store(),scope,true)
			if key==null or key.getAlgorithm()!="AES" or key.getEncoded()!=null:
				return false
		var written := store.write_secret(scope,value)
		if not written.ok:
			print("PROTECTED_STORE_PROBE_WRITE_",str(written.state),"_",store.provider.failure_step if store.provider is AndroidKeyStoreAdapter else store.backend)
			return false
	var loaded := store.read_secret(scope)
	if not loaded.ok or loaded.value!=value:
		print("PROTECTED_STORE_PROBE_READ_",str(loaded.state),"_",store.provider.failure_step if store.provider is AndroidKeyStoreAdapter else store.backend)
		return false
	if store.backend in ["DPAPI","AndroidKeyStore"]:
		var file: PackedByteArray = store.provider.cipher_read(scope).value if store.backend=="AndroidKeyStore" else FileAccess.get_file_as_bytes(store.encrypted_file(scope))
		if file==value or file.is_empty():
			return false
		var tampered := file.duplicate()
		tampered[tampered.size()-1] = tampered[tampered.size()-1]^1
		if store.provider.unprotect(scope,tampered).ok:
			return false
	if action=="erase":
		return store.erase_secret(scope).ok and not store.read_secret(scope).ok
	return true

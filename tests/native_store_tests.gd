extends SceneTree

func _initialize() -> void:
	assert(ClassDB.class_exists("PacificPlatform"),"build the native platform adapter first")
	var platform: Object = ClassDB.instantiate("PacificPlatform")
	var scope := "test:"+RaceSetup.uuid()
	var value := Crypto.new().generate_random_bytes(64)
	assert(not platform.secret_read("invalid/scope").ok)
	assert(not platform.secret_write(scope,PackedByteArray()).ok)
	var oversized := PackedByteArray()
	oversized.resize(4097)
	assert(not platform.secret_write(scope,oversized).ok)
	if platform.backend_name()=="DPAPI":
		var protected: Dictionary = platform.protect(scope,value)
		assert(protected.ok and protected.value!=value)
		var opened: Dictionary = platform.unprotect(scope,protected.value)
		assert(opened.ok and opened.value==value)
		assert(not platform.unprotect("different",protected.value).ok)
		print("NATIVE_STORE_DPAPI_ROUNDTRIP_PASS")
	else:
		var before: Dictionary = platform.secret_read(scope)
		var stored: Dictionary = platform.secret_write(scope,value)
		var loaded: Dictionary = platform.secret_read(scope)
		var replacement := Crypto.new().generate_random_bytes(72)
		var replaced: Dictionary = platform.secret_write(scope,replacement)
		var updated: Dictionary = platform.secret_read(scope)
		var erased: Dictionary = platform.secret_erase(scope)
		var absent: Dictionary = platform.secret_read(scope)
		# Cleanup happens before assertions, including on a failed OS operation.
		assert(not before.ok and before.state=="missing")
		assert(stored.ok,"OS protected store unavailable: "+str(stored.state))
		assert(loaded.ok and loaded.value==value)
		assert(replaced.ok and updated.ok and updated.value==replacement)
		assert(erased.ok and not absent.ok and absent.state=="missing")
		print("NATIVE_STORE_",platform.backend_name().to_upper(),"_ROUNDTRIP_DELETE_PASS")
	platform = null
	quit()

class_name AndroidKeyStoreAdapter
extends RefCounted
## Java calls stay on one serialized worker; exceptions never enter logs/diagnostics.

static var java_mutex := Mutex.new()
var wrapper: Object
var failed: bool = false
var failure_step: String = ""
var phase: String = ""

func _init() -> void:
	if Engine.has_singleton("JavaClassWrapper"):
		wrapper = Engine.get_singleton("JavaClassWrapper")

func backend_name() -> String:
	return "AndroidKeyStore"

func invoke(target: Variant, method: String, args: Array = []) -> Variant:
	if failed or target == null:
		failed = true
		return null
	var value: Variant = target.callv(method,args)
	var exception: Variant = wrapper.get_exception()
	if exception != null:
		failure_step = phase+"_"+method
		failed = true
		return null
	return value

func java_class(name: String) -> Variant:
	if failed or wrapper == null:
		failed = true
		return null
	var value: Variant = wrapper.wrap(name)
	if value == null:
		failure_step = name
		failed = true
		return null
	return value

func storage_directory() -> String:
	if wrapper==null or not Engine.has_singleton("AndroidRuntime"):
		return ""
	java_mutex.lock()
	failed = false
	var runtime: Object = Engine.get_singleton("AndroidRuntime")
	var directory: Variant = invoke(runtime.getApplicationContext(),"getNoBackupFilesDir")
	var path: Variant = invoke(directory,"getAbsolutePath")
	var result: String = path if not failed and path is String and path.begins_with("/") else ""
	java_mutex.unlock()
	return result

func alias_for(scope: String) -> String:
	return "dev.pacificrush.guest."+scope.sha256_text()

func key_store() -> Variant:
	var store: Variant = invoke(java_class("java.security.KeyStore"),"getInstance",["AndroidKeyStore"])
	invoke(store,"load",[null])
	return store

func get_key(store: Variant, scope: String, create: bool) -> Variant:
	var alias := alias_for(scope)
	var exists: Variant = invoke(store,"containsAlias",[alias])
	if failed or not (exists is bool or exists is int and int(exists) in [0,1]):
		failed = true
		return null
	# JNI jboolean is returned as an integer by the pinned engine.
	if bool(exists):
		var existing: Variant = invoke(store,"getKey",[alias,PackedByteArray()])
		return existing
	if not create:
		return null
	var builder: Variant = invoke(java_class("android.security.keystore.KeyGenParameterSpec$Builder"),"KeyGenParameterSpec$Builder",[alias,3])
	invoke(builder,"setBlockModes",[PackedStringArray(["GCM"])])
	invoke(builder,"setEncryptionPaddings",[PackedStringArray(["NoPadding"])])
	invoke(builder,"setKeySize",[256])
	invoke(builder,"setRandomizedEncryptionRequired",[true])
	invoke(builder,"setUserAuthenticationRequired",[false])
	var spec: Variant = invoke(builder,"build")
	var generator: Variant = invoke(java_class("javax.crypto.KeyGenerator"),"getInstance",["AES","AndroidKeyStore"])
	phase = "key_generator"
	invoke(generator,"init",[spec])
	var generated: Variant = invoke(generator,"generateKey")
	return generated

func protect(scope: String, value: PackedByteArray) -> Dictionary:
	if not ProtectedGuestStore.valid_scope(scope) or value.is_empty() or value.size()>4096:
		return {"ok":false,"state":"invalid"}
	java_mutex.lock()
	failed = wrapper == null
	failure_step = "wrapper_missing" if failed else ""
	var key: Variant = get_key(key_store(),scope,true)
	if key==null:
		java_mutex.unlock()
		return {"ok":false,"state":"unavailable"}
	var cipher: Variant = invoke(java_class("javax.crypto.Cipher"),"getInstance",["AES/GCM/NoPadding"])
	phase = "encrypt"
	invoke(cipher,"init",[1,key])
	invoke(cipher,"updateAAD",[scope.to_utf8_buffer()])
	var iv: Variant = invoke(cipher,"getIV")
	var encrypted: Variant = invoke(cipher,"doFinal",[value])
	var output := PackedByteArray()
	if not failed and iv is PackedByteArray and iv.size()==12 and encrypted is PackedByteArray and encrypted.size()==value.size()+16:
		output = PackedByteArray([80,82,75,83,1])+iv+encrypted
	java_mutex.unlock()
	return {"ok":true,"state":"ok","value":output} if not output.is_empty() else {"ok":false,"state":"unavailable"}

func unprotect(scope: String, value: PackedByteArray) -> Dictionary:
	if not ProtectedGuestStore.valid_scope(scope) or value.size()<34 or value.size()>4129 or value.slice(0,5)!=PackedByteArray([80,82,75,83,1]):
		return {"ok":false,"state":"invalid"}
	java_mutex.lock()
	failed = wrapper == null
	failure_step = "wrapper_missing" if failed else ""
	var key: Variant = get_key(key_store(),scope,false)
	if key == null:
		java_mutex.unlock()
		return {"ok":false,"state":"unavailable" if failed else "missing"}
	var spec: Variant = invoke(java_class("javax.crypto.spec.GCMParameterSpec"),"GCMParameterSpec",[128,value.slice(5,17)])
	var cipher: Variant = invoke(java_class("javax.crypto.Cipher"),"getInstance",["AES/GCM/NoPadding"])
	phase = "decrypt"
	invoke(cipher,"init",[2,key,spec])
	invoke(cipher,"updateAAD",[scope.to_utf8_buffer()])
	var plain: Variant = invoke(cipher,"doFinal",[value.slice(17)])
	var result := {"ok":true,"state":"ok","value":plain} if not failed and plain is PackedByteArray and not plain.is_empty() and plain.size()<=4096 else {"ok":false,"state":"invalid"}
	java_mutex.unlock()
	return result

func secret_erase(scope: String) -> Dictionary:
	if not ProtectedGuestStore.valid_scope(scope):
		return {"ok":false,"state":"invalid"}
	java_mutex.lock()
	failed = wrapper == null
	failure_step = "wrapper_missing" if failed else ""
	invoke(key_store(),"deleteEntry",[alias_for(scope)])
	var result := {"ok":not failed,"state":"unavailable" if failed else "ok"}
	java_mutex.unlock()
	return cipher_erase(scope) if result.ok else result

func cipher_path(scope: String) -> String:
	var root := storage_directory()
	return "" if root.is_empty() else root.path_join("pacific_guest").path_join(scope.sha256_text()+".bin")

func atomic_file(path: String) -> Variant:
	return invoke(java_class("android.util.AtomicFile"),"AtomicFile",[invoke(java_class("java.io.File"),"File",[path])])

func cipher_read(scope: String) -> Dictionary:
	if not ProtectedGuestStore.valid_scope(scope):
		return {"ok":false,"state":"invalid"}
	var path := cipher_path(scope)
	if path.is_empty():
		return {"ok":false,"state":"unavailable"}
	java_mutex.lock()
	failed = false
	var found := false
	var oversized := false
	for suffix: String in ["",".bak"]:
		var file: Variant = invoke(java_class("java.io.File"),"File",[path+suffix])
		if bool(invoke(file,"exists")):
			found = true
			var size: Variant = invoke(file,"length")
			oversized = oversized or size==null or int(size)<1 or int(size)>16384
	if failed or oversized or not found:
		var state := "unavailable" if failed else ("invalid" if oversized else "missing")
		java_mutex.unlock()
		return {"ok":false,"state":state}
	var bytes: Variant = invoke(atomic_file(path),"readFully")
	var result := {"ok":true,"state":"ok","value":bytes} if not failed and bytes is PackedByteArray and not bytes.is_empty() and bytes.size()<=16384 else {"ok":false,"state":"invalid"}
	java_mutex.unlock()
	return result

func cipher_write(scope: String, bytes: PackedByteArray) -> Dictionary:
	if not ProtectedGuestStore.valid_scope(scope) or bytes.is_empty() or bytes.size()>16384:
		return {"ok":false,"state":"invalid"}
	var path := cipher_path(scope)
	if path.is_empty():
		return {"ok":false,"state":"unavailable"}
	java_mutex.lock()
	failed = false
	var atomic: Variant = atomic_file(path)
	var stream: Variant = invoke(atomic,"startWrite")
	invoke(stream,"write",[bytes])
	if failed:
		failed = false
		if stream!=null:
			invoke(atomic,"failWrite",[stream])
		java_mutex.unlock()
		return {"ok":false,"state":"write_failed"}
	invoke(atomic,"finishWrite",[stream])
	var verified: Variant = invoke(atomic,"readFully")
	var ok: bool = not failed and verified is PackedByteArray and verified==bytes
	java_mutex.unlock()
	return {"ok":ok,"state":"ok" if ok else "write_failed"}

func cipher_erase(scope: String) -> Dictionary:
	if not ProtectedGuestStore.valid_scope(scope):
		return {"ok":false,"state":"invalid"}
	var path := cipher_path(scope)
	if path.is_empty():
		return {"ok":false,"state":"unavailable"}
	java_mutex.lock()
	failed = false
	invoke(atomic_file(path),"delete")
	for suffix: String in ["",".bak",".new"]:
		var file: Variant = invoke(java_class("java.io.File"),"File",[path+suffix])
		if bool(invoke(file,"exists")):
			failed = true
	var ok := not failed
	java_mutex.unlock()
	return {"ok":ok,"state":"ok" if ok else "write_failed"}

class_name ProtectedGuestStore
extends RefCounted
## Only OS-protected blobs reach disk. An unavailable backend has no file fallback.

var provider: Object
var folder: String
var backend: String = "Unavailable"
var fail_write: bool = false # Transaction fixture.

func _init(root: String, adapter: Object = null) -> void:
	provider = adapter
	folder = ProjectSettings.globalize_path(root).path_join("protected_guest")
	if provider == null:
		if OS.has_feature("android"):
			provider = AndroidKeyStoreAdapter.new()
			# Ciphertext is deliberately excluded from Android cloud/device backup.
			var no_backup: String = provider.storage_directory()
			if no_backup.is_empty():
				provider = null
				return
			folder = no_backup.path_join("pacific_guest")
		elif ClassDB.class_exists("PacificPlatform"):
			provider = ClassDB.instantiate("PacificPlatform")
	if provider != null:
		backend = str(provider.backend_name())

static func valid_scope(scope: String) -> bool:
	if scope.is_empty() or scope.length()>96:
		return false
	for c: String in scope:
		if not c in "abcdefghijklmnopqrstuvwxyz0123456789.-_:":
			return false
	return true

func encrypted_file(scope: String) -> String:
	return folder.path_join(scope.sha256_text()+".bin")

func read_secret(scope: String) -> Dictionary:
	if not valid_scope(scope):
		return {"ok":false,"state":"invalid"}
	if provider == null:
		return {"ok":false,"state":"unavailable"}
	if backend in ["Keychain","SecretService"]:
		return provider.secret_read(scope)
	if backend=="AndroidKeyStore":
		var blob: Dictionary = provider.cipher_read(scope)
		return provider.unprotect(scope,blob.value) if blob.ok else blob
	if backend!="DPAPI":
		return {"ok":false,"state":"unavailable"}
	var path := encrypted_file(scope)
	if not FileAccess.file_exists(path):
		return {"ok":false,"state":"missing"}
	var file := FileAccess.open(path,FileAccess.READ)
	if file == null:
		return {"ok":false,"state":"unavailable"}
	if file.get_length()<1 or file.get_length()>16384:
		return {"ok":false,"state":"invalid"}
	return provider.unprotect(scope,file.get_buffer(file.get_length()))

func write_secret(scope: String, value: PackedByteArray) -> Dictionary:
	if not valid_scope(scope) or value.is_empty() or value.size()>4096:
		return {"ok":false,"state":"invalid"}
	if provider == null:
		return {"ok":false,"state":"unavailable"}
	if backend in ["Keychain","SecretService"]:
		return provider.secret_write(scope,value)
	if not backend in ["DPAPI","AndroidKeyStore"]:
		return {"ok":false,"state":"unavailable"}
	var protected: Dictionary = provider.protect(scope,value)
	if not protected.get("ok",false):
		return protected
	if not protected.get("value") is PackedByteArray or protected.value.is_empty() or protected.value.size()>16384:
		return {"ok":false,"state":"invalid"}
	if backend=="AndroidKeyStore":
		return {"ok":false,"state":"write_failed"} if fail_write else provider.cipher_write(scope,protected.value)
	if DirAccess.make_dir_recursive_absolute(folder)!=OK:
		return {"ok":false,"state":"write_failed"}
	var path := encrypted_file(scope)
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if file == null:
		return {"ok":false,"state":"write_failed"}
	file.store_buffer(protected.value)
	file.flush()
	var error := file.get_error()
	file.close()
	if error!=OK or fail_write or DirAccess.rename_absolute(path+".tmp",path)!=OK:
		DirAccess.remove_absolute(path+".tmp")
		return {"ok":false,"state":"write_failed"}
	return {"ok":true,"state":"ok"}

func erase_secret(scope: String) -> Dictionary:
	if not valid_scope(scope):
		return {"ok":false,"state":"invalid"}
	if provider == null:
		return {"ok":false,"state":"unavailable"}
	if backend in ["Keychain","SecretService"]:
		return provider.secret_erase(scope)
	if not backend in ["DPAPI","AndroidKeyStore"]:
		return {"ok":false,"state":"unavailable"}
	if backend=="AndroidKeyStore":
		return provider.secret_erase(scope)
	for suffix: String in ["",".tmp"]:
		var path := encrypted_file(scope)+suffix
		if FileAccess.file_exists(path) and DirAccess.remove_absolute(path)!=OK:
			return {"ok":false,"state":"write_failed"}
	return {"ok":true,"state":"ok"}

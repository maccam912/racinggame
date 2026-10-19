class_name GuestIdentityService
extends Node
## OS keychain/crypto work never blocks a menu frame. One operation at a time.
signal completed(result: Dictionary)
var identity: GuestIdentity
var worker := Thread.new()
var data: AppData
var operation: String = ""
var generation: int = 0
var job_generation: int = 0

func configure(app_data: AppData) -> Error:
	if busy():
		return ERR_BUSY
	data = app_data
	return OK

func busy() -> bool:
	return worker.is_started()

func begin(action: String = "load", url: String = "") -> Error:
	if busy() or data==null:
		return ERR_BUSY
	if not data.store.writable:
		return ERR_BUSY # Loading may create a secret; every identity operation needs ownership.
	if not action in ["load","register","erase"]:
		return ERR_INVALID_PARAMETER
	operation = action
	job_generation = generation
	var reference: String = data.profile.guest_reference
	var root := data.store.root_path
	return worker.start(func() -> Dictionary:
		if identity==null:
			if action=="erase" and reference.is_empty():
				return {"ok":true,"state":"ok"}
			identity = GuestIdentity.new(ProtectedGuestStore.new(root))
		match action:
			"load": return identity.load_or_create(reference)
			"register": return identity.mark_registered(url)
			"erase": return identity.erase(reference)
		return {"ok":false,"state":"invalid"})

func cancel() -> void:
	generation += 1

func _process(_delta: float) -> void:
	if not worker.is_started() or worker.is_alive():
		return
	var result: Dictionary = worker.wait_to_finish()
	if job_generation!=generation:
		return
	if operation=="load" and result.get("ok",false) and identity.commit_reference(data)!=OK:
		result = {"ok":false,"state":"profile_save_failed"}
	completed.emit(result)

func _exit_tree() -> void:
	if worker.is_started():
		worker.wait_to_finish()

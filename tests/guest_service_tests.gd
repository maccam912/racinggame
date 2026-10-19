extends SceneTree

class SlowStore extends RefCounted:
	var values: Dictionary = {}
	func backend_name() -> String:
		return "Keychain"
	func secret_write(scope: String, value: PackedByteArray) -> Dictionary:
		OS.delay_msec(40)
		values[scope] = value.duplicate()
		return {"ok":true,"state":"ok"}
	func secret_read(scope: String) -> Dictionary:
		return {"ok":true,"state":"ok","value":values[scope]} if values.has(scope) else {"ok":false,"state":"missing"}
	func secret_erase(scope: String) -> Dictionary:
		values.erase(scope)
		return {"ok":true,"state":"ok"}

var completions: int = 0
func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	Catalog.load_all()
	var folder := "user://guest-service-tests-"+RaceSetup.uuid()
	var data := AppData.new(folder,false)
	var service := GuestIdentityService.new()
	service.configure(data)
	service.identity = GuestIdentity.new(ProtectedGuestStore.new(folder,SlowStore.new()))
	root.add_child(service)
	service.completed.connect(func(_result: Dictionary) -> void: completions += 1)
	assert(service.begin()==OK)
	assert(service.begin()==ERR_BUSY)
	service.cancel()
	var frames := 0
	while service.busy():
		await process_frame
		frames += 1
	assert(frames>1 and completions==0 and data.profile.guest_reference.is_empty())
	var original := service.identity.guest_id
	data.store.fail_stage = "before_replace"
	assert(service.begin()==OK)
	var result: Dictionary = await service.completed
	assert(not result.ok and result.state=="profile_save_failed")
	assert(data.profile.guest_reference.is_empty() and service.identity.guest_id==original)
	data.store.fail_stage = ""
	assert(service.begin()==OK)
	result = await service.completed
	assert(result.ok and data.profile.guest_reference==original)
	assert(service.begin("invalid")==ERR_INVALID_PARAMETER)
	assert(service.begin("register","https://example.invalid")==OK)
	result = await service.completed
	assert(result.ok and service.identity.registered("https://example.invalid"))
	assert(service.begin("erase")==OK)
	result = await service.completed
	assert(result.ok and service.identity.secret.is_empty())
	service.queue_free()
	await process_frame
	assert(AppData.remove_tree(ProjectSettings.globalize_path(folder))==OK)
	print("GUEST_SERVICE_ASYNC_CANCEL_RETRY_PASS")
	quit()

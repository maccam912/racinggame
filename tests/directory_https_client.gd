extends SceneTree
## Real HTTPS/auth/allocator/ENet fixture. OS persistence has independent native gates.
class MemoryAdapter extends RefCounted:
	var values: Dictionary = {}
	func backend_name() -> String: return "Keychain"
	func secret_write(scope: String, value: PackedByteArray) -> Dictionary:
		values[scope] = value.duplicate()
		return {"ok":true,"state":"ok"}
	func secret_read(scope: String) -> Dictionary:
		return {"ok":true,"state":"ok","value":values[scope]} if values.has(scope) else {"ok":false,"state":"missing"}
	func secret_erase(scope: String) -> Dictionary:
		values.erase(scope)
		return {"ok":true,"state":"ok"}

var directory := DirectoryClient.new()
var service := GuestIdentityService.new()
var link := NetworkClient.new()
var data: AppData
var folder: String
var logs: String
var snapshots: Array[String] = []

func _initialize() -> void:
	call_deferred("run_fixture")

func api(kind: String, payload: Dictionary = {}) -> Dictionary:
	assert(directory.begin(kind,payload)==OK,"request did not start: "+kind)
	var result: Dictionary = await directory.completed
	assert(result.ok,"request failed: "+kind+"/"+str(result.state))
	return result.payload

func run_fixture() -> void:
	Catalog.load_all()
	var url := ""
	var ca_path := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--directory-url="): url = arg.trim_prefix("--directory-url=")
		if arg.begins_with("--directory-ca="): ca_path = arg.trim_prefix("--directory-ca=")
		if arg.begins_with("--logs="): logs = arg.trim_prefix("--logs=")
	assert(not url.is_empty() and not ca_path.is_empty() and not logs.is_empty())
	folder = "user://directory-https-"+RaceSetup.uuid()
	data = AppData.new(folder,false)
	data.profile.display_name = "Café Driver"
	var adapter := MemoryAdapter.new()
	service.configure(data)
	service.identity = GuestIdentity.new(ProtectedGuestStore.new(folder,adapter))
	root.add_child(service)
	root.add_child(directory)
	var ca := X509Certificate.new()
	assert(ca.load(ca_path)==OK)
	assert(directory.configure(data,service,url,ca)==OK)
	var listed := await api("regions")
	assert(listed.regions.size()==1 and listed.regions[0].id=="test")
	await api("authenticate")
	var guest := service.identity.guest_id
	assert(data.profile.guest_reference==guest and directory.online())
	snapshots.append(directory.session_token)
	assert(not FileAccess.get_file_as_string(data.store.path("profile")).contains(snapshots[0]))
	directory.forget_session()
	# Reload the protected payload into a new identity object, retaining public profile.
	service.identity = GuestIdentity.new(ProtectedGuestStore.new(folder,adapter))
	await api("authenticate")
	assert(service.identity.guest_id==guest and directory.online() and directory.session_token!=snapshots[0])
	snapshots.append(directory.session_token)
	listed = await api("rooms")
	assert(listed.rooms.is_empty())
	var rules := {"track":0,"laps":1,"bot_fill":false,"difficulty":1,"contact":true}
	var create := DirectoryClient.compatibility()
	create.merge({"name":"HTTPS Coast","private":false,"region":"test","rules":rules})
	var admission := await api("create",create)
	listed = await api("rooms")
	assert(listed.rooms.size()==1 and listed.rooms[0].id==admission.room_id and listed.rooms[0].humans==1)
	link.admission_ticket = admission.ticket
	root.add_child(link)
	assert(link.connect_to(admission.host,int(admission.port),data.profile.display_name)==OK)
	var until := Time.get_ticks_msec()+5000
	while link.lobby.is_empty() and Time.get_ticks_msec()<until:
		await process_frame
	assert(not link.lobby.is_empty() and link.official and link.guest_id==guest)
	# A deliberately stale bearer gets one challenge/auth retry using the same UUID.
	directory.session_token = TicketVerifier.encode64(Crypto.new().generate_random_bytes(32))
	await api("leave",{"room_id":admission.room_id})
	assert(service.identity.guest_id==guest and directory.online())
	snapshots.append(directory.session_token)
	link.leave_room()
	await create_timer(.25).timeout
	link.queue_free()
	await process_frame
	create.private = true
	create.name = "Private Coast"
	var private_admission := await api("create",create)
	assert(private_admission.code.length()==8)
	listed = await api("rooms",{"show_in_race":true})
	for room: Dictionary in listed.rooms:
		assert(room.id!=private_admission.room_id)
	assert(directory.begin("code",{"code":"ZZZZ-ZZZZ"})==OK)
	var denied: Dictionary = await directory.completed
	assert(not denied.ok and denied.state=="room_unavailable")
	var by_code := await api("code",{"code":private_admission.code.substr(0,4)+"-"+private_admission.code.substr(4)})
	assert(by_code.room_id==private_admission.room_id)
	await api("leave",{"room_id":private_admission.room_id})
	# Neither operational logs nor the ordinary save file may contain credentials.
	var private_values: Array[String] = [TicketVerifier.encode64(service.identity.secret),Marshalls.raw_to_base64(service.identity.secret)]
	private_values.append_array(snapshots)
	private_values.append(admission.ticket)
	private_values.append(private_admission.ticket)
	for name: String in DirAccess.get_files_at(logs):
		var text := FileAccess.get_file_as_string(logs.path_join(name))
		for value: String in private_values:
			assert(not text.contains(value),"credential appeared in operational log")
	var profile_text := FileAccess.get_file_as_string(data.store.path("profile"))
	for value: String in private_values: assert(not profile_text.contains(value))
	assert(service.begin("erase")==OK)
	var erased: Dictionary = await service.completed
	assert(erased.ok)
	directory.queue_free()
	service.queue_free()
	await process_frame
	assert(AppData.remove_tree(ProjectSettings.globalize_path(folder))==OK)
	print("DIRECTORY_HTTPS_CLIENT_AUTH_ALLOCATE_ENET_CODE_REAUTH_PASS")
	quit()

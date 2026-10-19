extends SceneTree
## Full menu callbacks against the real HTTPS directory and allocated ENet workers.
var app: Node
var outsider := DirectoryClient.new()
var outside_service := GuestIdentityService.new()
var outside_data: AppData
var outside_folder: String
var scene_folder: String
var url: String
var ca: X509Certificate
var visual_dir: String = ""

func _initialize() -> void: call_deferred("run_fixture")
func settle() -> void:
	await process_frame
	await process_frame
	await process_frame

func wait_lobby() -> void:
	var until := Time.get_ticks_msec()+12000
	while app.page not in ["lobby","online_error"] and Time.get_ticks_msec()<until:
		await process_frame
	assert(app.page=="lobby","menu join failed: "+str(app.page))
	assert(app.network.official)

func capture(name_value: String) -> void:
	if visual_dir.is_empty(): return
	await settle()
	await RenderingServer.frame_post_draw
	assert(app.get_viewport().get_texture().get_image().save_png(visual_dir.path_join(name_value+".png"))==OK)

func button(name_value: String) -> Button:
	for control: Button in app.menu.root.find_children("*","Button",true,false):
		if control.text==name_value: return control
	return null

func outside_api(kind: String, payload: Dictionary = {}) -> Dictionary:
	assert(outsider.begin(kind,payload)==OK)
	var result: Dictionary = await outsider.completed
	assert(result.ok,"outside fixture failed: "+kind+"/"+str(result.state))
	return result.payload

func leave_lobby() -> void:
	app.network.leave_room()
	await create_timer(.2).timeout
	app.show_menu()
	await settle()

func run_fixture() -> void:
	Catalog.load_all()
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--visual-dir="): visual_dir = arg.trim_prefix("--visual-dir=")
		if arg.begins_with("--directory-url="): url = arg.trim_prefix("--directory-url=")
		if arg.begins_with("--directory-ca="):
			ca = X509Certificate.new()
			assert(ca.load(arg.trim_prefix("--directory-ca="))==OK)
	assert(not url.is_empty() and ca!=null)
	app = load("res://game/client_app.gd").new()
	app.capture_path = "reports/unused-menu-fixture.png"
	app.capture_frame = 1000000
	root.add_child(app)
	await settle()
	scene_folder = app.data.store.root_path
	if not visual_dir.is_empty(): app.data.settings.ui_scale = 150
	app.show_menu()
	app.show_online()
	var until := Time.get_ticks_msec()+8000
	while app.regions.probing and Time.get_ticks_msec()<until: await process_frame
	assert(not app.regions.selected().is_empty() and app.regions.selected().id=="test")
	assert(app.regions.regions[0].samples.size()==3)
	assert(app.online_page.hub_buttons.all(func(control: Button) -> bool: return not control.disabled))
	await capture("hub-150")
	app.online_page.hub_buttons[2].pressed.emit()
	await settle()
	assert(app.page=="online_create")
	app.online_page.draft.merge({"name":"Menu Coast","private":false,"rules":{"track":5,"laps":3,"bot_fill":false,"difficulty":2,"contact":false}},true)
	app.online_page.show_create()
	await settle()
	await capture("create-150")
	var start: Button = app.menu.root.find_child("create_room_start",true,false)
	assert(not start.disabled)
	start.pressed.emit()
	await wait_lobby()
	assert(app.network.lobby.rules.track==5 and app.network.lobby.rules.laps==3 and not app.network.lobby.rules.contact)
	print("MENU_IDENTITY_BACKEND "+app.guest_service.identity.store.backend)
	await capture("lobby-150")
	var guest: String = app.network.guest_id
	assert(GuestIdentity.valid_uuid(guest) and app.guest_service.identity.guest_id==guest)
	if app.guest_service.identity.persistent: assert(app.data.profile.guest_reference==guest)
	# Actual menu -> worker lock -> staged local world -> collision-ready ACK.
	app.network.command("ready",{"value":true})
	until = Time.get_ticks_msec()+3000
	while not app.network.lobby.members[0].ready and Time.get_ticks_msec()<until: await process_frame
	assert(app.network.lobby.members[0].ready)
	app.network.command("start")
	until = Time.get_ticks_msec()+10000
	while app.page!="race" and Time.get_ticks_msec()<until: await process_frame
	assert(app.page=="race" and app.drive.network==app.network and app.drive.track==Catalog.tracks[5])
	assert(app.track_loader==null and app.prepared_world==null and app.network.loaded_race==app.network.loading_race)
	assert(app.loading_bar.value==1.0,"only completed local work fills the progress bar")
	await leave_lobby()
	# A second client creates public/private rooms so browser and code flows have targets.
	outside_folder = "user://outside-menu-fixture-"+RaceSetup.uuid()
	outside_data = AppData.new(outside_folder,false)
	outside_service.configure(outside_data)
	outside_service.identity = GuestIdentity.new(ProtectedGuestStore.new(outside_folder,load("res://tests/directory_https_client.gd").MemoryAdapter.new()))
	root.add_child(outside_service)
	root.add_child(outsider)
	assert(outsider.configure(outside_data,outside_service,url,ca)==OK)
	var body := DirectoryClient.compatibility()
	body.merge({"name":"Browser Coast","private":false,"region":"test","rules":{"track":0,"laps":2,"bot_fill":true,"difficulty":1,"contact":true}})
	var public_room := await outside_api("create",body)
	app.show_online()
	await settle()
	app.online_page.hub_buttons[1].pressed.emit()
	until = Time.get_ticks_msec()+5000
	while app.online_page.pending=="browse" and Time.get_ticks_msec()<until: await process_frame
	assert(app.page=="online_rooms")
	var join: Button = app.online_page.room_list.find_child("join_"+str(public_room.room_id).replace("-","_"),true,false)
	assert(join!=null and not join.disabled)
	await capture("browser-150")
	join.pressed.emit()
	await wait_lobby()
	assert(app.network.guest_id==guest and app.network.port==int(public_room.port))
	await leave_lobby()
	body.private = true
	body.name = "Code Coast"
	var private_room := await outside_api("create",body)
	app.show_online()
	await settle()
	app.online_page.hub_buttons[3].pressed.emit()
	await settle()
	var edit: LineEdit = app.menu.root.find_child("room_code",true,false)
	edit.text = str(private_room.code).substr(0,4)+"-"+str(private_room.code).substr(4)
	app.menu.root.find_child("join_code_start",true,false).pressed.emit()
	await wait_lobby()
	assert(app.network.guest_id==guest and app.network.port==int(private_room.port) and app.network.lobby.private)
	assert(not app.lobby_page.code_visible)
	var show_code: Button = button(I18n.t("online.show"))
	assert(show_code!=null)
	show_code.pressed.emit()
	await settle()
	assert(app.lobby_page.code_visible and button(I18n.t("online.hide"))!=null)
	await capture("private-lobby-150")
	await leave_lobby()
	# Quick Join selects the remaining public lobby and preserves the identity.
	await create_timer(3.1).timeout
	app.show_online()
	await settle()
	app.online_page.hub_buttons[0].pressed.emit()
	await wait_lobby()
	assert(app.network.guest_id==guest and not app.network.lobby.private)
	await leave_lobby()
	# The real Data action must erase protected identity before resetting the profile.
	app.settings_page.show_tab("data",app.show_menu)
	app.settings_page.reset_data(true)
	until = Time.get_ticks_msec()+12000
	while app.page!="name" and Time.get_ticks_msec()<until: await process_frame
	assert(app.page=="name" and app.data.profile.guest_reference.is_empty() and app.guest_service.identity.secret.is_empty())
	assert(outside_service.begin("erase")==OK)
	var erased: Dictionary = await outside_service.completed
	assert(erased.ok)
	outsider.queue_free()
	outside_service.queue_free()
	app.queue_free()
	await settle()
	assert(AppData.remove_tree(ProjectSettings.globalize_path(outside_folder))==OK)
	assert(AppData.remove_tree(scene_folder)==OK)
	print("ONLINE_HTTPS_MENU_COMPLETE_PASS")
	await create_timer(.5).timeout # Retire stopped menu/voice playback on every driver.
	quit()

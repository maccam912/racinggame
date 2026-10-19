extends SceneTree
class EraseAdapter extends RefCounted:
	var locked: bool = true
	var erased: int = 0
	func backend_name() -> String: return "Keychain"
	func secret_erase(_scope: String) -> Dictionary:
		if locked: return {"ok":false,"state":"locked"}
		erased += 1
		return {"ok":true,"state":"ok"}

func _initialize() -> void: call_deferred("run_tests")
func settle() -> void:
	await process_frame
	await process_frame

func run_tests() -> void:
	var app: Node = load("res://game/client_app.gd").new()
	root.add_child(app)
	await settle()
	var folder := "user://identity-reset-ui-"+RaceSetup.uuid()
	var data := AppData.new(folder,false)
	var reference := RaceSetup.uuid()
	data.profile.guest_reference = reference
	data.records.times["reset_fixture"] = {"time":12.0}
	assert(data.save_profile()==OK,"profile save failed: "+data.store.last_error)
	assert(data.store.save_component("records",data.records)==OK,"record save failed: "+data.store.last_error)
	var before := FileAccess.get_file_as_bytes(data.store.path("records"))
	app.data = data
	assert(app.guest_service.configure(data)==OK)
	var adapter := EraseAdapter.new()
	app.guest_service.identity = GuestIdentity.new(ProtectedGuestStore.new(folder,adapter))
	app.settings_page.show_tab("data",app.show_menu)
	app.settings_page.reset_data(true)
	while app.settings_page.reset_pending: await process_frame
	assert(app.page=="settings" and app.settings_page.status.text==I18n.t("online.identity_unavailable"))
	assert(data.profile.guest_reference==reference and data.records.times.has("reset_fixture"))
	assert(FileAccess.get_file_as_bytes(data.store.path("records"))==before and adapter.erased==0)
	var back_found := false
	for control: Button in app.menu.root.find_children("*","Button",true,false):
		if control.text==I18n.t("button.back"):
			back_found = true
			assert(not control.disabled)
	assert(back_found and app.back_action==app.show_menu)
	adapter.locked = false
	var remapped := BindingBook.defaults()
	remapped.keyboard.ui_accept = [BindingBook.key(KEY_F),null]
	data.settings.bindings = remapped
	BindingBook.apply(remapped)
	app.settings_page.reset_data(true)
	while app.settings_page.reset_pending: await process_frame
	assert(app.page=="name" and adapter.erased==1 and data.profile.guest_reference.is_empty() and data.records.times.is_empty())
	assert(InputMap.action_get_events("ui_accept").any(func(event: InputEvent) -> bool: return event is InputEventKey and event.physical_keycode==KEY_ENTER),"Reset All restores essential default bindings")
	app.queue_free()
	await settle()
	assert(AppData.remove_tree(data.store.root_path)==OK)
	print("IDENTITY_RESET_UI_FAILURE_PRESERVES_DATA_RETRY_ERASES_PASS")
	await create_timer(.5).timeout # Retire stopped audio on the mixer thread.
	quit()

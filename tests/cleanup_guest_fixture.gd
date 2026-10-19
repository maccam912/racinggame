extends SceneTree
## Cleanup only the exact generated diagnostic profile named by the fixture.
func _initialize() -> void:
	var profile := ""
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--profile="): profile = arg.trim_prefix("--profile=")
	if not profile.begins_with("menu_https_") or not GhostCodec.valid_id(profile):
		quit(1)
		return
	var folder := ProjectSettings.globalize_path("user://diagnostic_profiles/"+profile)
	if not DirAccess.dir_exists_absolute(folder):
		quit()
		return
	var store := SaveStore.new(folder)
	var envelope := store.read_envelope(store.path("profile"))
	if envelope.get("valid",false):
		var reference: Variant = envelope.payload.get("guest_reference","")
		if not reference is String or not reference.is_empty() and not GuestIdentity.valid_uuid(reference):
			quit(1)
			return
		if not reference.is_empty() and not ProtectedGuestStore.new(folder).erase_secret("guest:"+reference).ok:
			quit(1)
			return
	if AppData.remove_tree(folder)!=OK:
		quit(1)
		return
	print("FIXTURE_GUEST_CLEANUP_PASS")
	quit()

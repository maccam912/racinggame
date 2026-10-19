extends SceneTree
class Bridge extends RefCounted:
	var focus: int = 1
	var route: int = 101
	var kind: String = "wifi"
	var active: bool = true
	var retries: int = 0
	func setActive(value: bool) -> void: active = value
	func retryAudioFocus() -> void: retries += 1
	func getFocusState() -> int: return focus
	func getRouteHandle() -> int: return route
	func getRouteKind() -> String: return kind
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var folder := "user://tests/mobile-services-"+RaceSetup.uuid()
	var app: Node = load("res://game/client_app.gd").new()
	root.add_child(app)
	await process_frame
	app.data = AppData.new(folder,true)
	app.menu.mobile_override = true
	app.menu.logical_unit_override = 1.0
	app.data.profile.first_run_complete = true
	app.touch_demo = true
	var bridge := Bridge.new()
	app.mobile_runtime.bridge = bridge
	app.mobile_runtime.service_wait = 0
	app.mobile_runtime.set_process(false)
	app.mobile_runtime.refresh_services(.25)
	app.start_drive({"mode":"quick","track":0,"car":1,"opponents":2})
	app.drive.set_physics_process(false)
	for index in range(420): app.drive._physics_process(1.0/60)
	app.drive._process(.016)
	app.game_audio._process(.016)
	var id: String = app.drive.session.race_uuid
	var time: int = app.drive.session.elapsed_ticks
	var position: Vector3 = app.drive.state.position
	app.drive.touch.pointer_down(44,app.drive.touch.controls.brake.get_center())
	assert(app.drive.touch.captures.has(44))
	app.game_audio.say("three")
	bridge.focus = -2
	app.mobile_runtime.refresh_services(.25)
	assert(not app.foreground and app.mobile_runtime.audio_blocked and app.drive.paused and app.drive.touch.captures.is_empty())
	assert(AudioServer.is_bus_mute(0) and app.local_checkpoint().payload.session.race_uuid==id)
	app.game_audio._process(.016)
	await create_timer(.05).timeout
	assert(app.game_audio.suspended and app.game_audio.music[app.game_audio.music_slot].stream_paused and not app.game_audio.voice.playing)
	var played: Dictionary = app.game_audio.played.duplicate()
	app.game_audio.effect("go")
	app.game_audio.say("go")
	assert(app.game_audio.played==played,"interrupted one-shot cues are discarded rather than replayed later")
	app.resume_drive()
	assert(app.drive.paused and app.drive.session.elapsed_ticks==time,"a visible Resume action cannot bypass lost OS audio focus")
	var bytes := FileAccess.get_file_as_bytes(app.data.store.path("suspended_race"))
	app.mobile_runtime.refresh_services(.25)
	assert(FileAccess.get_file_as_bytes(app.data.store.path("suspended_race"))==bytes)
	bridge.focus = 1
	app.mobile_runtime.refresh_services(.25)
	app.game_audio._process(.016)
	assert(app.foreground and app.drive.paused and not app.game_audio.suspended and not AudioServer.is_bus_mute(0),"OS audio gain restores music but never resumes driving automatically")
	app.resume_drive()
	assert(app.drive.resume_ticks==180)
	for index in range(180): app.drive._physics_process(1.0/60)
	assert(app.drive.session.elapsed_ticks==time and app.drive.state.position==position)
	bridge.focus = -1
	app.mobile_runtime.refresh_services(.25)
	assert(app.page=="pause" and not app.foreground)
	assert(app.menu_repeat.allowed.call(),"keyboard/controller can reach Retry Audio while the visible app has lost audio focus")
	var retry: Button
	for button: Button in app.menu.root.find_children("*","Button",true,false):
		if button.text==I18n.t("pause.retry_audio"): retry = button
	assert(retry!=null)
	retry.pressed.emit()
	assert(bridge.retries==1 and not app.foreground)
	app.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert(not app.menu_repeat.allowed.call(),"an actual background window cannot navigate the interruption menu")
	bridge.focus = 1
	app.mobile_runtime.refresh_services(.25)
	assert(not app.foreground and not bridge.active,"audio gain alone cannot foreground a background window")
	app.notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	app.mobile_runtime.refresh_services(.25)
	assert(app.foreground and bridge.active and app.drive.paused)
	app.show_menu()
	var calls := [0]
	var proceed := func() -> void: calls[0] += 1
	bridge.kind = "cellular"
	app.show_connection_form()
	await process_frame
	var field: LineEdit = app.menu.root.find_children("*","LineEdit",true,false)[0]
	field.grab_focus()
	assert(not app.mobile_runtime.allow_online(proceed) and calls[0]==0)
	assert(not field.has_focus(),"consent releases the text field so the IME cannot cover Continue/Cancel")
	assert(app.menu.modal.get_ok_button().custom_minimum_size.y>=48*app.menu.ui.unit and app.menu.modal.get_cancel_button().custom_minimum_size.y>=48*app.menu.ui.unit,"mobile confirmation actions keep at least 48-point targets")
	if DisplayServer.get_name()!="headless": assert(app.menu.modal.borderless)
	app.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	await process_frame
	assert(not app.menu.modal.visible and app.page=="connect","Android Back cancels the modal without navigating behind it or reopening consent")
	assert(calls[0]==0 and not app.data.profile.get("cellular_notice_accepted",false),"Cancel starts no online operation and writes no consent")
	app.data.store.fail_component = "profile"
	app.data.store.fail_stage = "before_replace"
	assert(not app.mobile_runtime.allow_online(proceed))
	app.menu.modal.confirmed.emit()
	assert(calls[0]==1 and app.mobile_runtime.allow_online(proceed),"a failed preference save still remembers explicit consent for this process")
	assert(not AppData.new(folder,true).profile.get("cellular_notice_accepted",false))
	app.data.store.fail_component = ""
	app.data.store.fail_stage = ""
	app.data = AppData.new(folder,true)
	app.mobile_runtime.cellular_session_accepted = false
	assert(not app.mobile_runtime.allow_online(proceed))
	app.menu.modal.confirmed.emit()
	assert(calls[0]==2 and AppData.new(folder,true).profile.cellular_notice_accepted)
	app.mobile_runtime.cellular_session_accepted = false
	assert(not app.mobile_runtime.needs_cellular_notice(),"successful consent survives a cold component reload")
	var legacy: Dictionary = app.data.profile.duplicate(true)
	legacy.erase("cellular_notice_accepted")
	assert(AppData.validate_profile(legacy))
	legacy["cellular_notice_accepted"] = 1
	assert(not AppData.validate_profile(legacy))
	app.queue_free()
	await create_timer(.5).timeout
	assert(AppData.remove_tree(ProjectSettings.globalize_path(folder))==OK)
	print("MOBILE_AUDIO_FOCUS_TOUCH_CHECKPOINT_MUSIC_PAUSE_NO_AUTO_DRIVE_EXPLICIT_RETRY_WINDOW_GUARD_CELLULAR_CANCEL_CONTINUE_COLD_CONSENT_PASS")
	quit()

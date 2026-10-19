class_name MobileRuntime
extends Node
## Owns only OS foreground resource policy; never drives race simulation.
var app: Node
var awake: bool = false
var applied_awake: Variant = null
var memory_warnings: int = 0
var bridge: Object
var window_active: bool = true
var audio_blocked: bool = false
var focus_state: int = 1
var service_wait: float = 0
var route_wait: float = 0
var route_handle: int = -1
var route_kind: String = "unknown"
var cellular_session_accepted: bool = false

func _ready() -> void:
	if OS.has_feature("android") and Engine.has_singleton("PacificMobile"):
		bridge = Engine.get_singleton("PacificMobile")
		bridge.setActive(true)
		app.audio_mix.focus_allowed = false
		service_wait = .15

func window_changed(value: bool) -> bool:
	window_active = value
	if bridge==null: return false
	bridge.setActive(value)
	app.audio_mix.focus_allowed = false
	app.audio_mix.apply_levels()
	service_wait = .1
	return true

func apply_focus(value: int) -> void:
	var changed := audio_blocked!=(window_active and value!=1) or focus_state!=value
	focus_state = value
	audio_blocked = window_active and value!=1
	app.audio_mix.focus_allowed = window_active and value==1
	app.audio_mix.apply_levels()
	if not window_active: return
	if audio_blocked: app.handle_background()
	else: app.handle_foreground()
	if changed and app.page=="pause": app.show_pause()

func retry_audio_focus() -> void:
	if bridge!=null and window_active: bridge.retryAudioFocus()

func refresh_services(dt: float) -> void:
	if bridge==null: return
	service_wait -= dt
	if service_wait>0: return
	apply_focus(int(bridge.getFocusState()))
	route_wait -= dt
	if route_wait>0 or not window_active: return
	route_wait = .25
	var handle := int(bridge.getRouteHandle())
	route_kind = str(bridge.getRouteKind())
	if not route_kind in ["wifi","cellular","ethernet","other","none","unknown"]: route_kind = "unknown"
	if route_handle!=-1 and route_handle!=handle and app.foreground and is_instance_valid(app.network): app.network.route_changed()
	route_handle = handle

func needs_cellular_notice() -> bool:
	if not app.data.mobile or cellular_session_accepted or bool(app.data.profile.get("cellular_notice_accepted",false)): return false
	if bridge!=null: route_kind = str(bridge.getRouteKind())
	return route_kind=="cellular"

func allow_online(proceed: Callable) -> bool:
	if not needs_cellular_notice(): return true
	app.menu.confirm(I18n.t("online.cellular_notice"),func() -> void:
		cellular_session_accepted = true
		app.data.profile["cellular_notice_accepted"] = true
		if app.data.save_profile()!=OK: app.data.store.notice("data.save_failed")
		proceed.call())
	app.menu.modal.ok_button_text = I18n.t("online.cellular_continue")
	return false

static func should_keep_awake(owner_app: Node) -> bool:
	if not owner_app.foreground: return false
	if owner_app.page=="loading": return true
	if owner_app.page=="touch_layout" and is_instance_valid(owner_app.touch_editor): return owner_app.touch_editor.previewing
	return owner_app.page=="race" and is_instance_valid(owner_app.drive) and not owner_app.drive.paused and not owner_app.drive.result_sent

func refresh() -> void:
	if not is_instance_valid(app) or app.data==null: return
	awake = should_keep_awake(app)
	if applied_awake==awake: return
	applied_awake = awake
	if app.data.mobile and DisplayServer.get_name()!="headless": DisplayServer.screen_set_keep_on(awake)

func _process(dt: float) -> void:
	refresh_services(dt)
	refresh()

func release_inactive_assets() -> void:
	if not is_instance_valid(app): return
	memory_warnings += 1
	if is_instance_valid(app.stage):
		app.remove_child(app.stage)
		app.stage.queue_free()
		app.stage = null
	# Active scene/player references retain resources. These dictionaries own
	# only reusable cosmetic references; collision/catalog/race data stay live.
	CourseArt.meshes.clear()
	CourseArt.materials.clear()
	TrackWorld.skies.clear()
	AudioLibrary.streams.clear()
	# Canvas draw commands retain texture RIDs rather than Resource objects.
	# The bounded shared icon atlas/cache must outlive those active commands.

func _exit_tree() -> void:
	if is_instance_valid(app) and app.data!=null and app.data.mobile and DisplayServer.get_name()!="headless": DisplayServer.screen_set_keep_on(false)

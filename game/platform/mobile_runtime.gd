class_name MobileRuntime
extends Node
## Owns only OS foreground resource policy; never drives race simulation.
var app: Node
var awake: bool = false
var applied_awake: Variant = null
var memory_warnings: int = 0

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

func _process(_dt: float) -> void: refresh()

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

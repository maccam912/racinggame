class_name TrackLoader
extends Node
## One completed world-construction unit per frame, with explicit ownership.
signal progress(value: float)
signal completed
signal failed
var world: TrackWorld
var cancelled: bool = false
var done: bool = false
var first_frame: bool = true
var settings: Dictionary = {}
var active: Callable
var warming: bool = false
var graphics_error: bool = false
var gpu_warmed: bool = false
var warmer: ShaderWarmup
var warm_evidence: Dictionary = {}

func begin(track: TrackDefinition) -> void:
	world = TrackWorld.new()
	world.begin_build(track)

func _process(_dt: float) -> void:
	if cancelled or done or world==null or warming or graphics_error: return
	# Let the postcard/Cancel render before doing the first construction unit.
	if first_frame:
		first_frame = false
		return
	var built := world.advance_build()
	var headless := DisplayServer.get_name()=="headless"
	progress.emit(float(world.build_stage)/(world.build_steps()+(0 if headless else 1)))
	if built:
		if headless:
			warm_evidence = {"gpu_warmed":false,"reason":"headless renderer","submissions":0,"rendered_frames":0}
			world.shader_warmup = warm_evidence.duplicate(true)
			finish()
		else: begin_graphics()

func begin_graphics() -> void:
	if cancelled or world==null: return
	graphics_error = false
	warming = true
	warmer = ShaderWarmup.new()
	warmer.active = active
	warmer.prepare(world,settings)
	var expected := warmer
	expected.completed.connect(func() -> void:
		if cancelled or warmer!=expected: return
		warm_evidence = {"gpu_warmed":true,"submissions":expected.submissions,"rendered_frames":expected.rendered_frames,"visible_objects":expected.visible_objects,"draw_calls":expected.draw_calls,"image_size":[expected.image_size.x,expected.image_size.y],"shader_paths":expected.shader_paths.keys()}
		world.warmed_resources.assign(expected.retained_resources)
		world.shader_warmup = warm_evidence.duplicate(true)
		gpu_warmed = true
		print("PACIFIC_RUSH_GRAPHICS_PREPARED submissions="+str(expected.submissions)+" frames="+str(expected.rendered_frames)+" draws="+str(expected.draw_calls))
		warming = false
		dispose_warmer()
		progress.emit(1.0)
		finish())
	expected.failed.connect(func() -> void:
		if cancelled or warmer!=expected: return
		graphics_error = true
		warming = false
		dispose_warmer()
		failed.emit())
	add_child(expected)

func dispose_warmer() -> void:
	if is_instance_valid(warmer):
		warmer.cancel()
		remove_child(warmer)
		warmer.queue_free()
	warmer = null

func retry_graphics() -> void:
	if graphics_error and not cancelled and not done: begin_graphics()

func finish() -> void:
	done = true
	set_process(false)
	completed.emit()

func take_world() -> TrackWorld:
	if not done or cancelled: return null
	var result := world
	world = null
	return result

func cancel() -> void:
	cancelled = true
	set_process(false)
	dispose_warmer()
	if is_instance_valid(world): world.queue_free()
	world = null

func _exit_tree() -> void: cancel()

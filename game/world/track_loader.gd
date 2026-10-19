class_name TrackLoader
extends Node
## One completed world-construction unit per frame, with explicit ownership.
signal progress(value: float)
signal completed
var world: TrackWorld
var cancelled: bool = false
var done: bool = false
var first_frame: bool = true

func begin(track: TrackDefinition) -> void:
	world = TrackWorld.new()
	world.begin_build(track)

func _process(_dt: float) -> void:
	if cancelled or done or world==null: return
	# Let the postcard/Cancel render before doing the first construction unit.
	if first_frame:
		first_frame = false
		return
	done = world.advance_build()
	progress.emit(float(world.build_stage)/world.build_steps())
	if done:
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
	if is_instance_valid(world): world.queue_free()
	world = null

func _exit_tree() -> void: cancel()

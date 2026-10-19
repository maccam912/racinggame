class_name MenuStage
extends Node3D

var car: CarVisual
var camera := Camera3D.new()
var elapsed: float = 0
var reduce_motion: bool = false
var rotation_offset: float = 0
var paint_index: int = 0
var car_index: int = 0
var center := Vector3.ZERO
var interactive: bool = false


func _ready() -> void:
	var world := TrackWorld.new()
	world.build(Catalog.tracks[0])
	add_child(world)
	var pose := Catalog.tracks[0].pose(45, 15)
	center = pose.origin
	world.box(center - Vector3.UP * .1, Vector3(20, .2, 20), Color("d8bd86"))
	clear_turnout_grass(world)
	add_child(camera)
	camera.current = true
	camera.fov = 48
	set_selection(car_index,paint_index)

func clear_turnout_grass(world: TrackWorld) -> void:
	for batch: MultiMeshInstance3D in world.find_children("grass_Batch_*","MultiMeshInstance3D",true,false):
		var count := 0
		for index in range(batch.multimesh.instance_count):
			var transform := batch.multimesh.get_instance_transform(index)
			var at := batch.global_transform*transform.origin
			if Vector2(at.x-center.x,at.z-center.z).length()<14: continue
			batch.multimesh.set_instance_transform(count,transform)
			count += 1
		batch.multimesh.visible_instance_count = count


func set_paint(index: int) -> void:
	set_selection(car_index,index)

func set_selection(car_id: int,paint_id: int) -> void:
	if car_id==car_index and paint_id==paint_index and is_instance_valid(car):
		return
	car_index = car_id
	paint_index = paint_id
	if is_instance_valid(car) and car.is_inside_tree():
		remove_child(car)
		car.queue_free()
	car = CarVisual.new()
	car.build(Catalog.paints[paint_id],Catalog.cars[car_id].mesh_id)
	car.position = center + Vector3.UP * .35
	add_child(car)


func _process(dt: float) -> void:
	if interactive:
		for device: int in Input.get_connected_joypads():
			var axis := Input.get_joy_axis(device,JOY_AXIS_RIGHT_X)
			if absf(axis)>.2: rotation_offset -= axis*1.5*dt
	if not reduce_motion:
		elapsed += dt
	var angle := elapsed * TAU / 20 + .8 + rotation_offset
	camera.position = center + Vector3(sin(angle) * 8, 3.1, cos(angle) * 8)
	camera.look_at(center + Vector3.UP * .9)
	camera.h_offset = -2.5


func _unhandled_input(event: InputEvent) -> void:
	if not interactive: return
	preview_input(event)

func preview_input(event: InputEvent) -> void:
	if not interactive: return
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		rotation_offset -= event.relative.x * .008
	if event is InputEventScreenDrag and absf(event.relative.x)>absf(event.relative.y):
		rotation_offset -= event.relative.x*.008

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


func _ready() -> void:
	var world := TrackWorld.new()
	world.build(Catalog.tracks[0])
	add_child(world)
	var pose := Catalog.tracks[0].pose(45, 15)
	center = pose.origin
	world.box(center - Vector3.UP * .1, Vector3(20, .2, 20), Color("d8bd86"))
	add_child(camera)
	camera.current = true
	camera.fov = 48
	set_selection(car_index,paint_index)


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
	if not reduce_motion:
		elapsed += dt
	var angle := elapsed * TAU / 20 + .8 + rotation_offset
	camera.position = center + Vector3(sin(angle) * 8, 3.1, cos(angle) * 8)
	camera.look_at(center + Vector3.UP * .9)
	camera.h_offset = -2.5


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_LEFT:
		rotation_offset -= event.relative.x * .008
	if event is InputEventJoypadMotion and event.axis == JOY_AXIS_RIGHT_X and absf(event.axis_value) > .2:
		rotation_offset += event.axis_value * .05

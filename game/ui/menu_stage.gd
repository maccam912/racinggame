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
	center = Catalog.tracks[0].pose(45,27).origin
	var world := TrackWorld.new()
	# Exclude source placements before creating either billboard faces or their
	# footprints. No GPU instance readback, shared meshes or driving world edits.
	world.scenery_clearings = [{"center":center,"radius":14.0}]
	world.build(Catalog.tracks[0])
	add_child(world)
	# The display apron sits beside the road. Its old 15 m offset put
	# five metres of coplanar sand on the asphalt, causing visible z-fighting.
	var floor_y := -INF
	var bottom_y := INF
	for x: float in [-10,0,10]:
		for z: float in [-10,0,10]:
			var at := center+Vector3(x,0,z)
			var y := AuthoredCourseScenery.height(world,at,AuthoredCourseScenery.nearest(world,at))
			floor_y = maxf(floor_y,y)
			bottom_y = minf(bottom_y,y)
	center.y = floor_y+.12
	var depth := maxf(.4,center.y-bottom_y+.25)
	var apron := world.box(center-Vector3.UP*depth*.5,Vector3(20,depth,20),Color("d8bd86"))
	apron.name = "ShowroomApron"
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

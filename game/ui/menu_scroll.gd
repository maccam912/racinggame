class_name MenuScroll
extends ScrollContainer
## Capture a finger before child widgets consume its emulated mouse events.
## Only a stationary release becomes a click; keyboard and real mice stay native.

const TAP_DEVICE: int = -2026
var unit: float = 1.0
var finger: int = -1
var origin := Vector2.ZERO
var previous := Vector2.ZERO
var dragged: bool = false
var double_tap: bool = false
var generation: int = 0

func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not get_tree().get_nodes_in_group("mobile_choice_sheets").is_empty():
		cancel_gesture()
		return
	if event is InputEventMouse and event.device==-1:
		if finger!=-1 or get_global_rect().has_point(event.position):
			get_viewport().set_input_as_handled()
		return
	if event is InputEventScreenTouch:
		if event.pressed and not event.canceled and finger==-1 and get_global_rect().has_point(event.position):
			finger = event.index
			origin = event.position
			previous = origin
			dragged = false
			double_tap = event.double_tap
		elif finger==event.index and (not event.pressed or event.canceled):
			var tap: bool = not dragged and not event.canceled and event.position.distance_to(origin)<=10*unit and get_global_rect().has_point(event.position)
			finger = -1
			if tap: deliver_tap.call_deferred(origin,event.position,double_tap,generation)
		else:
			return
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and finger==event.index:
		if event.position.distance_to(origin)>10*unit: dragged = true
		if dragged: scroll_vertical -= roundi(event.position.y-previous.y)
		previous = event.position
		get_viewport().set_input_as_handled()

func deliver_tap(start: Vector2, finish: Vector2, twice: bool, token: int) -> void:
	if token!=generation or not is_visible_in_tree(): return
	var viewport := get_viewport()
	for pressed: bool in [true,false]:
		var click := InputEventMouseButton.new()
		click.device = TAP_DEVICE
		click.button_index = MOUSE_BUTTON_LEFT
		click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		click.position = start if pressed else finish
		click.global_position = click.position
		click.double_click = twice
		click.pressed = pressed
		viewport.push_input(click,true)

func cancel_gesture() -> void:
	finger = -1
	generation += 1

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED,NOTIFICATION_EXIT_TREE]: cancel_gesture()
	elif what==NOTIFICATION_VISIBILITY_CHANGED and is_inside_tree() and not is_visible_in_tree(): cancel_gesture()

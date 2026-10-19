class_name SchoolLesson
extends RefCounted
## Objective state is independent of racing/records and has no deadline.

var index: int = 0
var stage: int = 0
var done: bool = false
var marker_index: int = 0
var markers: Array[Vector3] = []
var spawn_s: float = 35
var turn_s: float = 0
var slide_ticks: int = 0


func configure(lesson: int, track: TrackDefinition) -> void:
	index = clampi(lesson, 0, 4)
	if index in [1, 2, 3]:
		var desired := .005 if index == 1 else .012
		for i in range(50, track.points.size() - 100):
			if absf(track.bake.samples[i][6]) > desired:
				turn_s = i * 2.0
				break
		if turn_s <= 0:
			turn_s = 400
		spawn_s = maxf(20, turn_s - (60 if index == 2 else 25))
	if index == 1:
		for distance: float in [20.0, 45.0, 70.0]:
			markers.append(track.pose(spawn_s + distance).origin)


func update(state: VehicleState, input: InputFrame, track: TrackDefinition) -> void:
	if done:
		return
	match index:
		0:
			if state.speed() >= 12:
				stage = 1
			done = stage == 1 and state.speed() < .5 and input.brake > .5
		1:
			if marker_index < markers.size() and state.position.distance_to(markers[marker_index] + Vector3.UP * .35) < 7:
				marker_index += 1
			done = marker_index == markers.size()
		2:
			if state.speed() >= 10:
				stage = maxi(stage, 1)
			if stage == 1 and input.brake > .5 and state.route_s >= turn_s - 35 and state.route_s <= turn_s + 5 and state.speed() <= 14:
				stage = 2
			done = stage == 2 and state.route_s >= turn_s + 10 and absf(state.position.y - track.pose(state.route_s).origin.y) < 2
		3:
			if state.drift_phase == 1:
				slide_ticks += 1
			if slide_ticks >= 12:
				stage = 1
			done = stage == 1 and not input.handbrake and state.drift_phase == 0
		4:
			done = "recovery" in state.events

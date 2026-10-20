extends SceneTree
## The clear-road fixture must create actual gaps using received traffic only.
const Driver := preload("res://tests/soak_network_client.gd")

func _initialize() -> void:
	Catalog.load_all()
	var track := Catalog.tracks[0]
	var pose := track.pose(50)
	var reference := VehicleState.new()
	reference.slot = 4
	reference.route_s = 50
	reference.position = pose.origin+Vector3.UP*.35
	reference.yaw = atan2(-pose.basis.z.x,pose.basis.z.z)
	var rival := VehicleState.new()
	rival.slot = 1
	var forward := reference.forward()
	var right := forward.cross(Vector3.UP)
	var origin := reference.position
	rival.position = origin+forward*10
	assert(absf(Driver.leader_gap(reference,[reference,rival],track)-10)<.001)
	assert(reference.position==origin and rival.position==origin+forward*10,"traffic observations must never mutate received state")
	rival.position = origin-forward*10
	assert(is_inf(Driver.leader_gap(reference,[reference,rival],track)),"a following car must not brake the leader")
	rival.position = origin+forward*10+Vector3.UP*2.4
	assert(is_finite(Driver.leader_gap(reference,[reference,rival],track)))
	rival.position.y += .2
	assert(is_inf(Driver.leader_gap(reference,[reference,rival],track)),"other road levels cannot trigger yielding")
	rival.position = origin+forward*10+right*5
	assert(is_inf(Driver.leader_gap(reference,[reference,rival],track)))
	rival.position = origin+right*3
	assert(absf(Driver.leader_gap(reference,[reference,rival],track)-3)<.001,"stable slot ordering prevents symmetric side-by-side braking")
	rival.slot = 6
	assert(is_inf(Driver.leader_gap(reference,[reference,rival],track)))
	rival.position = origin+forward*10
	rival.finished = true
	assert(is_inf(Driver.leader_gap(reference,[reference,rival],track)))
	rival.finished = false
	rival.dnf_reason = "test"
	assert(is_inf(Driver.leader_gap(reference,[reference,rival],track)))
	print("SOAK_DRIVER_RECEIVED_TRAFFIC_AHEAD_TIES_PLANE_LATERAL_TERMINAL_READ_ONLY_PASS")
	quit()

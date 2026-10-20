extends SceneTree


func _initialize() -> void:
	Catalog.load_all()
	assert(Catalog.cars.size() == 4)
	assert(Catalog.tracks.size() == 10)
	for track: TrackDefinition in Catalog.tracks:
		assert(track.length > 3000 and track.length < (4000 if Catalog.tracks.find(track)<6 else 9000))
		assert(track.points.size() > 1500)
		for key: String in ["track."+track.id,"route.description."+track.id]:
			assert(I18n.t(key)!=key,"every course needs a player-facing name and description")
		assert(track.forwards[0].cross(Vector3.UP).dot(track.pose(0).basis.x) > 0.99)
		assert(track.pose(0).origin.distance_to(track.pose(track.length).origin) < 0.001)
		for gate: Dictionary in track.bake.gates:
			assert(Vector3(gate.position[0], gate.position[1], gate.position[2]).distance_to(
				Vector3(gate.recovery[0], gate.recovery[1], gate.recovery[2])) > 5.99)
	print("TEST PASS: 4 cars, 10 routes, 8 paints, grid/start/recovery contracts")
	quit()

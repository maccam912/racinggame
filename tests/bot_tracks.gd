extends SceneTree

var failures: int = 0
var results: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("run")

func flat_reference(source: TrackDefinition) -> TrackDefinition:
	var track := TrackDefinition.from_data(source.definition)
	for index in range(track.points.size()):
		track.points[index] = Vector3(track.points[index].x,4,track.points[index].z)
		track.forwards[index] = Vector3(track.forwards[index].x,0,track.forwards[index].z).normalized()
		var row: Array = track.bake.samples[index]
		row[1] = 4.0
		row[3] = track.forwards[index].x
		row[4] = 0.0
		row[5] = track.forwards[index].z
		row[9] = 0.0
		row[10] = 0.0
	for gate: Dictionary in track.bake.gates:
		gate.position[1] = 4.0
		gate.recovery[1] = 4.0
		var forward := Vector3(gate.forward[0],0,gate.forward[2]).normalized()
		gate.forward = [forward.x,0.0,forward.z]
	return track


func run() -> void:
	Catalog.load_all()
	var seed_count := 1
	var track_filter: String = ""
	var report_path: String = "res://reports/bot_tracks.json"
	var solo: bool = false
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="):
			seed_count = clampi(int(arg.trim_prefix("--seeds=")), 1, 20)
		elif arg.begins_with("--track="): track_filter = arg.trim_prefix("--track=")
		elif arg.begins_with("--report="): report_path = arg.trim_prefix("--report=")
		elif arg=="--solo": solo = true
	for track: TrackDefinition in Catalog.tracks:
		if not track_filter.is_empty() and track.id!=track_filter: continue
		if solo: track = flat_reference(track)
		var scene := Node3D.new()
		root.add_child(scene)
		var collision := RouteCollision.new()
		collision.build(track)
		scene.add_child(collision)
		await physics_frame
		await physics_frame
		for difficulty in range(3):
			for seed_index in range(seed_count):
				var roster := RaceSetup.roster(0 if solo else 7,seed_index%4,0,"Reference")
				for row: Dictionary in roster:
					row.bot = true
				var race := RaceSession.new()
				race.seed = 104729 + seed_index
				race.setup(track, RaceSetup.car_indices(roster), scene.get_world_3d(), 1)
				race.configure_bots(roster, -1, difficulty)
				race.contact_enabled = not solo
				race.phase = RaceSession.Phase.RACING
				for state: VehicleState in race.states:
					state.ghost_ticks = 90
				var recoveries := 0
				for tick in range(36000):
					race.step({})
					for state: VehicleState in race.states:
						if "recovery" in state.events:
							recoveries += 1
					if race.phase == RaceSession.Phase.RESULTS:
						break
				var times: Array[float] = []
				var dnfs: Array[String] = []
				for state: VehicleState in race.states:
					if not state.finished:
						dnfs.append("%s: %s gate=%d" % [roster[state.slot].name, state.dnf_reason, state.last_gate])
					else:
						times.append(state.finish_time)
				if not dnfs.is_empty():
					failures += 1
					push_error("TEST FAIL: " + track.id + " " + str(difficulty) + " " + str(dnfs))
				results.append({"track":track.id,"difficulty":difficulty,"seed":race.seed,"reference_car":seed_index%4,"times":times,"dnfs":dnfs,"recoveries":recoveries})
				print("AI %s difficulty=%d seed=%d finished=%d/%d recoveries=%d times=%s" % [track.id,difficulty,race.seed,times.size(),roster.size(),recoveries,str(times)])
				race = null
				await process_frame
		scene.queue_free()
		await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://reports"))
	assert(not results.is_empty(),"selected track must exist")
	var file := FileAccess.open(report_path,FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failures==0,"seeds_per_case":seed_count,"content_hash":Compatibility.content_hash(),"boundary":"Deterministic bots use no random reaction/line variation; seeds rotate the autopiloted reference car among four legal choices. Human Medium difficulty acceptance remains separate.","results":results},"\t"))
	file.close()
	quit(1 if failures else 0)

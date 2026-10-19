extends SceneTree

var failures: int = 0
var results: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	Catalog.load_all()
	var seed_count := 1
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with("--seeds="):
			seed_count = clampi(int(arg.trim_prefix("--seeds=")), 1, 20)
	for track: TrackDefinition in Catalog.tracks:
		var scene := Node3D.new()
		root.add_child(scene)
		var collision := RouteCollision.new()
		collision.build(track)
		scene.add_child(collision)
		await physics_frame
		await physics_frame
		for difficulty in range(3):
			for seed_index in range(seed_count):
				var roster := RaceSetup.roster(7, 0, 0, "Reference")
				for row: Dictionary in roster:
					row.bot = true
				var race := RaceSession.new()
				race.seed = 104729 + seed_index
				race.setup(track, RaceSetup.car_indices(roster), scene.get_world_3d(), 1)
				race.configure_bots(roster, -1, difficulty)
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
				results.append({"track":track.id, "difficulty":difficulty, "seed":race.seed, "times":times, "dnfs":dnfs, "recoveries":recoveries})
				print("AI %s difficulty=%d seed=%d finished=%d/8 recoveries=%d times=%s" % [track.id, difficulty, race.seed, times.size(), recoveries, str(times)])
				race = null
				await process_frame
		scene.queue_free()
		await process_frame
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://reports"))
	var file := FileAccess.open("res://reports/bot_tracks.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"passed":failures == 0, "results":results}, "\t"))
	file.close()
	quit(1 if failures else 0)

extends SceneTree
## Slow digital decisions exercise the Relaxed preset against real Easy rivals.
## Synthetic regression only; no claim about a child or physical device.
func _initialize() -> void: call_deferred("run")
func run() -> void:
	Catalog.load_all()
	var results: Array[Dictionary] = []
	for track: TrackDefinition in Catalog.tracks.filter(func(t: TrackDefinition) -> bool: return t.smooth_road()):
		var collision := RouteCollision.new()
		collision.build(track)
		root.add_child(collision)
		await physics_frame
		await physics_frame
		for car_index in range(Catalog.cars.size()) if "--all-cars" in OS.get_cmdline_user_args() else [0]:
			var delay := 54
			var race := RaceSession.new()
			race.setup(track,[car_index,1,2,3],root.world_3d,1)
			race.mode = "quick"
			race.contact_enabled = false
			race.driving_assists[0] = 2
			race.corner_braking[0] = true
			for slot in range(1,4):
				var bot := BotDriver.new()
				bot.difficulty = 0
				race.bots[slot] = bot
			var pilot := BotDriver.new()
			var frame := InputFrame.make(0,1)
			var near_ticks := 0
			var count := 0
			var lead_max := 0.0
			var ranks: Array[int] = []
			for tick in range(24000):
				var state: VehicleState = race.states[0]
				var desired := pilot.sample(state,race.cars[0],track,race.queries[0])
				if tick%delay==0: frame = InputFrame.make(signf(desired.steer)*.75 if absf(desired.steer)>.18 else 0,1)
				race.step({0:frame})
				if tick>600 and not state.finished:
					var human_s := ProgressTracker.race_progress(state,track)
					var nearest := INF
					for rival: VehicleState in race.states.slice(1):
						var gap := ProgressTracker.race_progress(rival,track)-human_s
						nearest = minf(nearest,absf(gap))
						lead_max = maxf(lead_max,gap)
					if nearest<100: near_ticks += 1
					count += 1
					var rank := race.standings().find(state)+1
					if not rank in ranks: ranks.append(rank)
				if state.finished or state.dnf_reason!="": break
			var finish_times: Array = race.states.map(func(s: VehicleState) -> float: return s.finish_time)
			var row := {"track":track.id,"car":Catalog.cars[car_index].id,"delay":delay,"finished":race.states[0].finished,"time":race.states[0].finish_time,"rank":race.standings().find(race.states[0])+1,"near_percent":100.0*near_ticks/maxi(count,1),"max_lead_m":lead_max,"ranks":ranks,"times":finish_times}
			assert(race.states[0].finished,"Relaxed driver finishes "+track.id+" in "+Catalog.cars[car_index].id)
			results.append(row)
			print(row)
			race = null
		collision.queue_free()
		await physics_frame
		await physics_frame
	FileAccess.open("res://reports/relaxed-"+("allcars" if "--all-cars" in OS.get_cmdline_user_args() else "field")+"21.json",FileAccess.WRITE).store_string(JSON.stringify(results,"\t"))
	print("RELAXED_PRESET_SLOW_DIGITAL_DRIVER_SIX_SMOOTH_COURSES_FINISH_PASS")
	quit()

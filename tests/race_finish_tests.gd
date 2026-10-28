extends SceneTree
## Advance the real shared authority clock; finish marks are fixture inputs.
func _initialize() -> void: call_deferred("run")

func race_for(mode: String, humans: Array[int], count: int = 3) -> RaceSession:
	var race := RaceSession.new()
	var indices: Array[int] = []
	var records: Array[Dictionary] = []
	for slot in range(count):
		indices.append(0)
		records.append({"id":"driver_"+str(slot),"name":"Driver "+str(slot),"car":0,"paint":slot,"bot":slot not in humans})
	race.setup(Catalog.tracks[0],indices,root.world_3d,1)
	race.configure_bots(records,humans[0] if not humans.is_empty() else -1,0)
	race.mode = mode
	race.contact_enabled = false
	race.phase = RaceSession.Phase.GRACE
	race.elapsed_ticks = 100
	race.first_finish_tick = 100
	return race

func finish(state: VehicleState, time: float = 1.5) -> void:
	state.finished = true
	state.finish_time = time
	state.laps = 1

func advance(race: RaceSession, ticks: int) -> void:
	for tick in range(ticks): race.step({})

func run() -> void:
	Catalog.load_all()
	var road := RouteCollision.new()
	road.build(Catalog.tracks[0])
	root.add_child(road)
	await physics_frame
	await physics_frame
	# The single human may be in any grid slot; assists cannot extend AI waiting.
	for mode: String in ["quick","cup"]:
		for assisted: bool in [false,true]:
			var race := race_for(mode,[1])
			if assisted:
				race.driving_assists[1] = DrivingAssist.RELAXED
				race.corner_braking[1] = true
			finish(race.states[1],1.23456789)
			advance(race,299)
			assert(race.phase==RaceSession.Phase.GRACE and race.states[0].dnf_reason=="")
			race.step({})
			assert(race.phase==RaceSession.Phase.RESULTS and race.elapsed_ticks==400)
			assert(race.states[0].dnf_reason=="Race complete" and race.states[2].dnf_reason=="Race complete")
			assert(race.standings()[0]==race.states[1] and race.states[1].finish_time==1.23456789)
			race.step({})
			assert(race.elapsed_ticks==400,"results are terminal")
	# An actual swept human finish starts the wrap-up on the crossing tick.
	var crossing := race_for("quick",[1])
	crossing.phase = RaceSession.Phase.RACING
	crossing.first_finish_tick = -1
	var human := crossing.states[1]
	var gate: Dictionary = crossing.track.bake.gates[0]
	var forward := ProgressTracker.vector(gate.forward)
	human.position = ProgressTracker.vector(gate.position)-forward*.2+Vector3.UP*.35
	human.yaw = atan2(forward.x,-forward.z)
	human.velocity = forward*30
	human.last_gate = crossing.track.bake.gates.size()-1
	crossing.queries[1].hint = crossing.track.points.size()-1
	crossing.step({1:InputFrame.make(0,1)})
	assert(human.finished and crossing.first_finish_tick==101 and crossing.settled_ticks==1)
	advance(crossing,299)
	assert(crossing.phase==RaceSession.Phase.RESULTS)
	# The first human's finish does not begin the short timer for other humans.
	var online := race_for("online",[0,1])
	finish(online.states[0])
	online.driving_assists[1] = DrivingAssist.RELAXED
	advance(online,600)
	assert(online.phase==RaceSession.Phase.GRACE and online.settled_ticks==0 and online.states[1].dnf_reason=="")
	finish(online.states[1],10.5)
	advance(online,299)
	assert(online.phase==RaceSession.Phase.GRACE)
	online.step({})
	assert(online.phase==RaceSession.Phase.RESULTS and online.states[2].dnf_reason=="Race complete")
	# Finishers can still beat the wrap-up: keep their real time and finishing rank.
	var late_bot := race_for("quick",[1])
	finish(late_bot.states[1])
	advance(late_bot,200)
	finish(late_bot.states[0],4.9)
	advance(late_bot,100)
	assert(late_bot.phase==RaceSession.Phase.RESULTS and late_bot.states[0].dnf_reason=="" and late_bot.states[0].finish_time==4.9)
	# Leaving/expiry/inactivity count as terminal, preserving the original reason.
	for reason: String in ["Left race","Reconnect expired","Input inactive"]:
		var retired := race_for("online",[0,1])
		finish(retired.states[0])
		retired.states[1].dnf_reason = reason
		advance(retired,300)
		assert(retired.phase==RaceSession.Phase.RESULTS and retired.states[1].dnf_reason==reason)
	# Any first finisher starts the online 60 s deadline, including a bot.
	for winner in [0,2]:
		for assisted: bool in [false,true]:
			var deadline := race_for("online",[0,1])
			finish(deadline.states[winner])
			if assisted: deadline.driving_assists[1] = DrivingAssist.RELAXED
			advance(deadline,3599)
			assert(deadline.phase==RaceSession.Phase.GRACE and deadline.states[1].dnf_reason=="")
			deadline.step({})
			assert(deadline.phase==RaceSession.Phase.RESULTS and deadline.elapsed_ticks==3700)
			assert(deadline.states[1].dnf_reason=="Finish grace expired")
			assert(deadline.states[winner].finished and deadline.states[winner].dnf_reason=="")
	# A finish just before the deadline cannot extend it by another five seconds.
	var capped := race_for("online",[0,1])
	finish(capped.states[0])
	capped.elapsed_ticks = 3699
	finish(capped.states[1])
	capped.step({})
	assert(capped.phase==RaceSession.Phase.RESULTS and capped.states[2].dnf_reason=="Finish grace expired")
	# Full fields still settle sooner; bot-only fixtures do not vacuously wrap up.
	var complete := race_for("online",[0,1],2)
	for state: VehicleState in complete.states: finish(state)
	advance(complete,119)
	assert(complete.phase==RaceSession.Phase.GRACE)
	complete.step({})
	assert(complete.phase==RaceSession.Phase.RESULTS)
	var bots := race_for("quick",[])
	finish(bots.states[0])
	advance(bots,300)
	assert(bots.phase==RaceSession.Phase.GRACE and bots.settled_ticks==0)
	var hard := race_for("online",[0,1])
	finish(hard.states[0])
	hard.elapsed_ticks = 35999
	hard.first_finish_tick = 35900
	hard.step({})
	assert(hard.phase==RaceSession.Phase.RESULTS and hard.states[1].dnf_reason=="Time limit")
	crossing = null
	online = null
	late_bot = null
	capped = null
	complete = null
	bots = null
	hard = null
	road.queue_free()
	await process_frame
	print("HUMAN_FINISH_5S_QUICK_CUP_ASSISTS_REAL_CROSSING_ONLINE_60S_HUMAN_BOT_WINNER_DNF_HARD_LIMIT_PASS")
	quit()

class_name RaceAudio
extends Node3D
## Reads authoritative events once per tick. Ghosts are absent from this roster.
var drive: RaceDrive
var engines: Dictionary = {}
var surfaces: Dictionary = {}
var cooldowns: Dictionary = {}
var last_count: String = ""
var last_snapshot: int = -1
var last_laps: int = 0
var finished: bool = false
var wrong_episode: bool = false
var wrong_until: float = -10
var elapsed: float = 0
var previous_speeds: Dictionary = {}
var was_resuming: bool = false
var feedback_cursor: int = 0

func _ready() -> void:
	add_to_group("audio_transports")
	AudioMix.ensure_buses()
	for index in range(drive.session.states.size()):
		var engine := EngineAudio.new()
		engine.own = index==drive.local_slot
		engine.profile = drive.session.cars[index].audio_profile_id
		engines[index] = engine
		add_child(engine)
	for id: String in ["asphalt_squeal","sand_rumble","grass_rumble"]:
		var player := AudioStreamPlayer.new()
		player.stream = AudioLibrary.stream("effect_"+id)
		player.bus = &"Effects"
		player.volume_db = -80
		surfaces[id] = player
		add_child(player)
		player.play()

func _physics_process(dt: float) -> void:
	var suspended := drive.paused and drive.network==null or drive.result_sent
	for index: int in engines:
		var state: VehicleState = drive.state if index==drive.local_slot else drive.session.states[index]
		var input := drive.frame if index==drive.local_slot else drive.session.inputs[index]
		var throttle := input.throttle
		if drive.network and index!=drive.local_slot:
			throttle = 1.0 if state.speed()>=float(previous_speeds.get(index,0)) else 0.0
		previous_speeds[index] = state.speed()
		engines[index].position = state.position
		engines[index].update(state.speed(),throttle,drive.session.cars[index].top_speed,dt,suspended or not engines[index].own and state.position.distance_to(drive.camera.global_position)>=120)
	var own: EngineAudio = engines[drive.local_slot]
	drive.hud.gear = own.gear
	drive.hud.rpm = own.rpm
	for id: String in surfaces:
		var active := not suspended and drive.state.grounded and drive.state.speed()>3
		if id=="asphalt_squeal": active = active and drive.state.surface=="asphalt" and drive.state.drift_phase==1
		else: active = active and drive.state.surface==id.trim_suffix("_rumble")
		surfaces[id].volume_db = move_toward(surfaces[id].volume_db,-12.0 if active else -80.0,dt*160)
		surfaces[id].stream_paused = suspended
	if suspended: return
	elapsed += dt
	var phase := "Countdown" if drive.resume_ticks>0 else drive.phase
	var ticks := 180-drive.resume_ticks if drive.resume_ticks>0 else drive.phase_ticks
	var count := str(clampi(3-ticks/60,1,3)) if phase=="Countdown" else "go" if phase=="Racing" and drive.race_ticks<36 else ""
	if was_resuming and drive.resume_ticks==0 and phase=="Racing": count = "go"
	was_resuming = drive.resume_ticks>0
	if count!=last_count:
		if not count.is_empty():
			cue("go" if count=="go" else "countdown")
			say({"3":"three","2":"two","1":"one","go":"go"}[count])
		last_count = count
	var wrong := drive.state.wrong_way_ticks>=60
	if wrong and not wrong_episode and elapsed>=wrong_until:
		say("wrong_way")
		wrong_until = elapsed+10
	wrong_episode = wrong
	if drive.state.laps>last_laps:
		last_laps = drive.state.laps
		if not drive.state.finished:
			cue("lap")
			if last_laps==drive.lap_count-1: say("final_lap")
	if drive.state.finished and not finished:
		finished = true
		cue("finish")
		say("finish")
	if drive.network:
		for event_state: VehicleState in drive.network.feedback_since(feedback_cursor): consume(event_state)
		feedback_cursor = drive.network.feedback_sequence
		return
	for state: VehicleState in drive.session.states: consume(state)

func consume(state: VehicleState) -> void:
	# Rival impacts outside the audible radius never enter the shared pool.
	if state.slot!=drive.local_slot and state.position.distance_to(drive.state.position)>=120: return
	for event: String in state.events:
		var key := event+":"+str(state.slot)
		var duration := .15 if event=="wall" else .5 if event=="land" else .2
		if event=="bump":
			var closest: VehicleState
			var distance := 6.0
			for other: VehicleState in drive.session.states:
				if other.slot==state.slot or not "bump" in other.events: continue
				var separation := state.position.distance_to(other.position)
				if separation<distance:
					distance = separation
					closest = other
			if closest: key = "bump:%d:%d"%[mini(state.slot,closest.slot),maxi(state.slot,closest.slot)]
		if elapsed<float(cooldowns.get(key,-1)): continue
		cooldowns[key] = elapsed+duration
		match event:
			"wall": cue("wall_heavy" if state.speed()>20 else "wall_light")
			"land": cue("landing")
			"bump": cue("bump")
			"recovery": cue("recovery")

func cue(id: String) -> void: get_tree().call_group("game_audio","effect",id)
func say(id: String) -> void: get_tree().call_group("game_audio","say",id)

func stop_audio() -> void:
	for player: AudioStreamPlayer in surfaces.values():
		player.stream_paused = false
		player.stop()
		player.stream = null

func _exit_tree() -> void: stop_audio()

class_name EngineAudio
extends Node3D

const LAYERS: Array[String] = ["idle","low","high","coast"]
const UP: Array[float] = [12.0,25.0,40.0]
var own: bool = false
var profile: String = "comet"
var players: Array[Node] = []
var gear: int = 1
var rpm: float = 0
var pitch: float = .8
var shift_remaining: float = 0
var weights := PackedFloat32Array([1,0,0,0])

func _ready() -> void:
	add_to_group("audio_transports")
	for layer: String in LAYERS:
		var player: Node = AudioStreamPlayer.new() if own else AudioStreamPlayer3D.new()
		player.stream = AudioLibrary.stream("engine_"+profile+"_"+layer)
		player.bus = &"Engine"
		player.volume_db = -80
		if not own:
			player.max_distance = 120
			player.unit_size = 10
			player.max_db = -6
			player.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		add_child(player)
		players.append(player)
		player.play()

func update(speed: float, throttle: float, top_speed: float, dt: float, suspended: bool = false) -> void:
	var previous := gear
	while gear<4 and speed>=UP[gear-1]: gear += 1
	while gear>1 and speed<UP[gear-2]-3: gear -= 1
	if previous!=gear: shift_remaining = .10
	var lower := 0.0 if gear==1 else UP[gear-2]-3
	var upper := top_speed if gear==4 else UP[gear-1]
	rpm = clampf((speed-lower)/maxf(1,upper-lower),0,1)
	var target := lerpf(.8,1.6,rpm)
	if shift_remaining>0: target = maxf(.8,target-.12*shift_remaining/.10)
	shift_remaining = maxf(0,shift_remaining-dt)
	pitch = move_toward(pitch,target,5*dt)
	var idle := 1.0-smoothstep(0.0,4.0,speed)
	var coast := (1.0-throttle)*(1.0-idle)
	var load := throttle*(1.0-idle)
	var next := PackedFloat32Array([idle,load*(1-rpm),load*rpm,coast])
	for index in range(4):
		weights[index] = move_toward(weights[index],next[index],dt*7)
	var total := maxf(.0001,weights[0]+weights[1]+weights[2]+weights[3])
	for index in range(4):
		weights[index] /= total
		players[index].pitch_scale = pitch
		players[index].volume_db = linear_to_db(maxf(.0001,weights[index]))+(-4.0 if own else -9.0)
		players[index].stream_paused = suspended

func stop_audio() -> void:
	for player: Node in players:
		player.stream_paused = false
		player.stop()
		player.stream = null

func _exit_tree() -> void: stop_audio()

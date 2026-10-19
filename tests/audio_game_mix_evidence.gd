extends SceneTree
## Actual decoded game music, 8 four-layer engines, impacts and voice through DSP.
var app: Node
var capture := AudioEffectCapture.new()
var samples := PackedVector2Array()
var marks: Array[Dictionary] = []
var active: bool = false
var elapsed: float = 0
var impact_clock: float = 0

func _initialize() -> void: call_deferred("run")
func drain() -> void:
	var count := capture.get_frames_available()
	if count>0: samples.append_array(capture.get_buffer(count))

func frame(dt: float) -> void:
	if not active: return
	elapsed += dt
	impact_clock += dt
	var drive: RaceDrive = app.drive
	for index: int in drive.audio.engines:
		var engine: EngineAudio = drive.audio.engines[index]
		engine.position = drive.camera.global_position+Vector3((index-4)*1.5,0,-4)
		var speed := 2+fmod(elapsed*10+index*7,58)
		engine.update(speed,.5+.5*sin(elapsed*2+index),drive.session.cars[index].top_speed,dt)
	if impact_clock>=.5:
		impact_clock = 0
		for index in range(8): app.game_audio.effect("wall_heavy")
		app.game_audio.effect("landing")
		app.game_audio.effect("bump")
	drain()

func section(label: String, seconds: float) -> void:
	marks.append({"label":label,"start_frame":samples.size(),"seconds":seconds})
	await create_timer(seconds).timeout
	drain()

func run() -> void:
	app = load("res://game/client_app.gd").new()
	root.add_child(app)
	await process_frame
	app.start_drive({"mode":"quick","track":0,"car":0,"paint":0,"opponents":7})
	await process_frame
	app.set_process(false)
	app.drive.set_physics_process(false)
	app.drive.audio.set_physics_process(false)
	app.game_audio.set_process(false)
	var values: Dictionary = app.data.settings.duplicate(true)
	for key in ["master","music","engine","effects_volume","announcer"]: values[key] = 100
	values.background_audio = true
	values.dynamic_range = "standard"
	app.audio_mix.configure(values)
	capture.buffer_length = 2
	AudioServer.add_bus_effect(0,capture)
	process_frame.connect(func() -> void: frame(minf(.05,root.get_process_delta_time())))
	active = true
	for id: String in ["palm_bay","citrus_pass","marina_lights","redwood_run","sunstone_canyon","pacific_summit","menu"]:
		app.game_audio.set_music("music_"+id)
		app.game_audio.say("new_best_time")
		await section("standard_"+id,4)
		if id=="palm_bay" and "--movie" in OS.get_cmdline_user_args():
			app.game_audio.say("final_lap")
			app.game_audio._process(.016)
			await RenderingServer.frame_post_draw
			root.get_texture().get_image().save_png("res://reports/audio-game-native.png")
	values.dynamic_range = "night"
	app.audio_mix.configure(values)
	await section("night",3)
	# Capture is a Master *effect*, before the Master fader/mute. Muting the
	# contributing buses is observable here; final Master mute needs output capture.
	for key in ["music","engine","effects_volume","announcer"]: values[key] = 0
	app.audio_mix.configure(values)
	await create_timer(.3).timeout
	drain()
	var mute_start := samples.size()
	await section("all_channels_muted",1)
	var peak := 0.0
	for index in range(mute_start,samples.size()): peak = maxf(peak,maxf(absf(samples[index].x),absf(samples[index].y)))
	assert(peak<.0001,"channel zero must silence actual decoded music, eight engines, effects and voice")
	if "--movie" in OS.get_cmdline_user_args():
		for key in ["music","engine","effects_volume","announcer"]: values[key] = 100
		values.master = 0
		app.audio_mix.configure(values)
		await section("final_output_master_muted",1)
	active = false
	var wave := AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.stereo = true
	wave.mix_rate = int(AudioServer.get_mix_rate())
	var bytes := PackedByteArray()
	bytes.resize(samples.size()*4)
	for index in range(samples.size()):
		bytes.encode_s16(index*4,roundi(clampf(samples[index].x,-1,1)*32767))
		bytes.encode_s16(index*4+2,roundi(clampf(samples[index].y,-1,1)*32767))
	wave.data = bytes
	assert(wave.save_to_wav("res://reports/audio-game-mix.wav")==OK)
	var file := FileAccess.open("res://reports/audio-game-mix.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"driver":AudioServer.get_driver_name(),"sample_rate":wave.mix_rate,"frames":samples.size(),"engines":8,"layers_per_engine":4,"impact_burst":8,"sections":marks,"all_channels_muted_peak":peak,"boundary":"Actual Godot decoded-stream/DSP capture at unity Master, before its fader/mute; human listening and physical speaker/device mix review remain separate"},"  "))
	file.close()
	for index in range(AudioServer.get_bus_effect_count(0)-1,-1,-1):
		if AudioServer.get_bus_effect(0,index)==capture: AudioServer.remove_bus_effect(0,index)
	app.queue_free()
	await create_timer(.2).timeout
	print("ACTUAL_EIGHT_ENGINE_MUSIC_IMPACT_VOICE_CAPTURE_PASS")
	quit()

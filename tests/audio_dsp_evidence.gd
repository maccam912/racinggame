extends SceneTree
var mix := AudioMix.new()
var capture := AudioEffectCapture.new()
var player := AudioStreamPlayer.new()
var values: Dictionary
func _initialize() -> void: call_deferred("run")
func measure() -> Dictionary:
	capture.clear_buffer()
	var until := Time.get_ticks_msec()+3000
	while capture.get_frames_available()<4096 and Time.get_ticks_msec()<until:
		await process_frame
	assert(capture.get_frames_available()>=4096,"audio driver must actually process DSP samples")
	var frames := capture.get_buffer(capture.get_frames_available())
	var squared := 0.0
	var peak := 0.0
	for frame: Vector2 in frames:
		squared += frame.length_squared()/2
		peak = maxf(peak,maxf(absf(frame.x),absf(frame.y)))
	return {"rms":sqrt(squared/frames.size()),"peak":peak,"frames":frames.size()}
func run() -> void:
	root.add_child(mix)
	values = SettingsCatalog.defaults(false)
	values.master = 100
	values.engine = 100
	mix.configure(values)
	var wave := AudioStreamWAV.new()
	wave.format = AudioStreamWAV.FORMAT_16_BITS
	wave.mix_rate = 48000
	wave.loop_mode = AudioStreamWAV.LOOP_FORWARD
	wave.loop_end = 48000
	var bytes := PackedByteArray()
	bytes.resize(96000)
	for index in range(48000): bytes.encode_s16(index*2,roundi(sin(TAU*600*index/48000.0)*.4*32767))
	wave.data = bytes
	player.stream = wave
	player.bus = &"Engine"
	root.add_child(player)
	AudioServer.add_bus_effect(0,capture)
	player.play()
	await create_timer(.3).timeout
	var full := await measure()
	values.engine = 50
	mix.configure(values)
	await create_timer(.3).timeout
	var half := await measure()
	assert(half.rms/full.rms>.46 and half.rms/full.rms<.54,"the engine channel must affect actual samples")
	values.engine = 100
	mix.configure(values)
	player.volume_db = 6
	await create_timer(.3).timeout
	var loud_reference := await measure()
	values.dynamic_range = "night"
	mix.configure(values)
	await create_timer(.4).timeout
	var night := await measure()
	assert(night.rms<loud_reference.rms*.7 and night.rms>loud_reference.rms*.2,"Night must compress loud samples without silencing the mix")
	values.engine = 0
	mix.configure(values)
	await create_timer(.4).timeout
	var muted := await measure()
	assert(muted.peak<.0001,"zero engine level must silence actual samples")
	values.engine = 100
	values.dynamic_range = "standard"
	mix.configure(values)
	var rivals: Array[AudioStreamPlayer] = []
	for index in range(3):
		var rival := AudioStreamPlayer.new()
		rival.stream = wave
		rival.bus = &"Engine"
		root.add_child(rival)
		rival.play()
		rivals.append(rival)
	await create_timer(.3).timeout
	var limited := await measure()
	assert(limited.peak<=db_to_linear(-5.0)+.002 and limited.rms>.35,"summed loud sources must respect the actual output limiter")
	var report := {"driver":AudioServer.get_driver_name(),"sample_rate":AudioServer.get_mix_rate(),"full":full,"half":half,"loud_reference":loud_reference,"night":night,"muted":muted,"summed_limited":limited,"boundary":"Synthetic gain/Night fixture; actual decoded eight-engine/music/impact/voice output is separately validated by tools/audio_acceptance.py"}
	var file := FileAccess.open("res://reports/audio-dsp.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"  "))
	file.close()
	player.stop()
	player.stream = null
	for rival: AudioStreamPlayer in rivals:
		rival.stop()
		rival.stream = null
		rival.queue_free()
	for index in range(AudioServer.get_bus_effect_count(0)-1,-1,-1):
		if AudioServer.get_bus_effect(0,index)==capture: AudioServer.remove_bus_effect(0,index)
	player.queue_free()
	mix.queue_free()
	await create_timer(.1).timeout
	print("AUDIO_ACTUAL_DSP_GAIN_NIGHT_MUTE_PASS "+JSON.stringify(report))
	quit()

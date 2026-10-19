extends SceneTree
func _initialize() -> void: call_deferred("run")
func run() -> void:
	var mix := AudioMix.new()
	root.add_child(mix)
	mix.set_process(false)
	var values := SettingsCatalog.defaults(false)
	mix.configure(values)
	var buses := AudioServer.bus_count
	var effects := AudioServer.get_bus_effect_count(0)
	mix.configure(values)
	assert(AudioServer.bus_count==buses and AudioServer.get_bus_effect_count(0)==effects,"reapplying settings cannot duplicate buses or processors")
	var music := AudioServer.get_bus_index("Music")
	var engine := AudioServer.get_bus_index("Engine")
	assert(AudioServer.get_bus_send(music)==&"Master" and AudioServer.get_bus_send(engine)==&"Master")
	values.music = 35
	values.engine = 0
	values.effects_volume = 25
	values.announcer = 45
	mix.configure(values)
	assert(is_equal_approx(db_to_linear(AudioServer.get_bus_volume_db(music)),.35))
	assert(AudioServer.is_bus_mute(engine) and not AudioServer.is_bus_mute(music))
	values.music = 100
	values.engine = 100
	mix.configure(values)
	mix.context(true,false)
	mix._process(.01)
	assert(mix.movement_suspended and is_equal_approx(AudioServer.get_bus_volume_db(music),-8))
	assert(is_zero_approx(AudioServer.get_bus_volume_db(engine)),"offline pause leaves engine gain for the movement-suspension owner")
	mix.context(false,true)
	mix._process(.3)
	assert(not mix.movement_suspended and is_equal_approx(AudioServer.get_bus_volume_db(music),-4))
	mix.duck_for_cue(.1)
	assert(is_equal_approx(AudioServer.get_bus_volume_db(music),-7))
	assert(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Announcer")),linear_to_db(.45)-3))
	mix.cue_until_ms = 0
	mix.context(false,false)
	mix._process(.3)
	assert(is_zero_approx(AudioServer.get_bus_volume_db(music)),"pause/cue ducking restores the selected level after 0.3 seconds")
	mix.notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert(AudioServer.is_bus_mute(0))
	values.background_audio = true
	mix.configure(values)
	assert(not AudioServer.is_bus_mute(0),"background preference applies while focus is already lost")
	values.master = 0
	mix.configure(values)
	assert(AudioServer.is_bus_mute(0),"master zero stays silent even with background audio enabled")
	values.master = 80
	values.dynamic_range = "night"
	mix.configure(values)
	assert(AudioServer.is_bus_effect_enabled(0,AudioMix.effect_index("PacificNight")))
	values.dynamic_range = "standard"
	mix.configure(values)
	assert(not AudioServer.is_bus_effect_enabled(0,AudioMix.effect_index("PacificNight")))
	assert(AudioServer.is_bus_effect_enabled(0,AudioMix.effect_index("PacificCeiling")))
	mix.queue_free()
	await process_frame
	print("AUDIO_CHANNEL_MUTE_DUCK_RESTORE_FOCUS_NIGHT_PASS")
	quit()

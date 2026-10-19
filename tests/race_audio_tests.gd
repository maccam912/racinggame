extends SceneTree
var app: Node
func _initialize() -> void: call_deferred("run")
func run() -> void:
	Catalog.load_all()
	for row: Dictionary in AudioLibrary.entries().values():
		var stream := AudioLibrary.stream(row.id)
		assert(stream!=null and stream.loop==bool(row.loop),row.id)
		assert(absf(stream.get_length()-float(row.duration_seconds))<.003,row.id)
	app = load("res://game/client_app.gd").new()
	root.add_child(app)
	await process_frame
	app.start_drive({"mode":"trial","track":0,"car":0,"paint":0,"opponents":7})
	await process_frame
	var drive: RaceDrive = app.drive
	var audio: RaceAudio = drive.audio
	audio.set_physics_process(false)
	assert(audio.engines.size()==8,"only actual roster cars get engines; ghosts never enter this map")
	for index: int in audio.engines:
		var engine: EngineAudio = audio.engines[index]
		assert(engine.own==(index==drive.local_slot) and engine.players.size()==4)
		if not engine.own:
			assert(engine.players[0] is AudioStreamPlayer3D and engine.players[0].max_distance==120)
	var own: EngineAudio = audio.engines[drive.local_slot]
	own.update(12,1,58,.01)
	assert(own.gear==2 and own.shift_remaining>0)
	own.update(10,1,58,.01)
	assert(own.gear==2,"hysteresis prevents gear chatter")
	own.update(8,0,58,.01)
	assert(own.gear==1)
	own.update(50,1,58,1)
	assert(own.gear==4 and own.pitch>=.8 and own.pitch<=1.6)
	var state := drive.state
	var unchanged := state.copy()
	for index in range(100): own.update(index*.6,1,58,1.0/60)
	assert(state.position==unchanged.position and state.velocity==unchanged.velocity,"audio cannot write handling state")
	state.events.assign(["wall","land"])
	audio.consume(state)
	var wall: int = app.game_audio.played.get("wall_light",0)
	var land: int = app.game_audio.played.get("landing",0)
	audio.consume(state)
	assert(app.game_audio.played.wall_light==wall and app.game_audio.played.landing==land)
	audio.elapsed += .16
	audio.consume(state)
	assert(app.game_audio.played.wall_light==wall+1 and app.game_audio.played.landing==land)
	audio.elapsed += .5
	audio.consume(state)
	assert(app.game_audio.played.landing==land+1)
	var other: VehicleState = drive.session.states[(state.slot+1)%8]
	other.position = state.position+Vector3.RIGHT*2
	state.events.assign(["bump"])
	other.events.assign(["bump"])
	audio.consume(state)
	audio.consume(other)
	assert(app.game_audio.played.bump==1,"two sides of one collision play one impact")
	app.data.settings.announcer = 0
	app.data.settings.captions = true
	app.audio_mix.configure(app.data.settings)
	drive.hud.phase = "Racing"
	drive.hud.ticks = 60
	app.game_audio.say("wrong_way")
	app.game_audio._process(.016)
	assert(app.game_audio.caption.visible and app.game_audio.caption.text=="Wrong way")
	assert(AudioServer.is_bus_mute(AudioServer.get_bus_index("Announcer")))
	drive.set_physics_process(false)
	state.events.clear()
	other.events.clear()
	state.wrong_way_ticks = 60
	app.game_audio._process(.016)
	assert(not app.game_audio.caption.visible and drive.hud.banner_text()==I18n.t("hud.wrong_way"),"one visible prioritized cue still works with announcer muted")
	audio._physics_process(.016)
	var wrong: int = app.game_audio.played.voice_wrong_way
	audio._physics_process(12)
	assert(app.game_audio.played.voice_wrong_way==wrong,"one line per continuous wrong-way episode")
	state.wrong_way_ticks = 0
	audio._physics_process(.016)
	state.wrong_way_ticks = 60
	audio._physics_process(.016)
	assert(app.game_audio.played.voice_wrong_way==wrong+1)
	state.wrong_way_ticks = 0
	drive.phase = "Racing"
	drive.race_ticks = 100
	audio.last_count = ""
	var go_before: int = app.game_audio.played.get("voice_go",0)
	for remaining in [180,180,120,60,0]:
		drive.resume_ticks = remaining
		audio._physics_process(.016)
	assert(app.game_audio.played.voice_three==1 and app.game_audio.played.voice_two==1 and app.game_audio.played.voice_one==1)
	assert(app.game_audio.played.voice_go==go_before+1,"offline resume gets one GO after its frozen countdown")
	var wire := NetworkClient.new()
	drive.network = wire
	wire.connected = true
	wire.start_tick = 0
	wire.config = {"track":0,"laps":2}
	wire.latest_snapshot_tick = 19
	state.events.assign(["wall"])
	wire.observe_feedback({"tick":20,"states":[state]})
	audio.elapsed += 1
	audio._physics_process(.016)
	wall = app.game_audio.played.wall_light
	audio._physics_process(.5)
	assert(app.game_audio.played.wall_light==wall,"render/physics ticks cannot replay an old snapshot event")
	wire.observe_feedback({"tick":23,"states":[state]})
	audio._physics_process(.016)
	assert(app.game_audio.played.wall_light==wall+1)
	drive.network = null
	wire.wire.close() # This isolated stub never entered the scene tree.
	wire.free()
	state.events.clear()
	app.result_receipt = ResultReceipt.capture(drive.session,[])
	app.page = "results"
	app.result_summary = {"saved":false,"new_best":false}
	app.game_audio._process(.016)
	assert(not app.game_audio.played.has("voice_new_best_time"),"failed saves cannot announce a saved record")
	app.result_summary = {"saved":true,"new_best":true}
	app.game_audio._process(.016)
	app.game_audio._process(.016)
	assert(app.game_audio.played.voice_new_best_time==1,"save retries/screen refresh cannot duplicate the best-time line")
	app.page = "race"
	drive.paused = true
	audio._physics_process(.016)
	assert(own.players[0].stream_paused)
	app.show_menu()
	await process_frame
	app.queue_free()
	await process_frame
	await create_timer(.5).timeout
	print("ORIGINAL_AUDIO_IMPORT_ENGINE_GEARS_GHOST_COOLDOWNS_CAPTIONS_PAUSE_PASS")
	quit()

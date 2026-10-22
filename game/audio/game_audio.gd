class_name GameAudio
extends Node
## One music transport and a bounded effect pool survive screen changes.
var app: Node
var music: Array[AudioStreamPlayer] = []
var music_id: String = ""
var music_slot: int = 0
var blend: Tween
var effects: Array[AudioStreamPlayer] = []
var effect_cursor: int = 0
var voice := AudioStreamPlayer.new()
var caption_layer := CanvasLayer.new()
var caption := Label.new()
var caption_until: int = 0
var played: Dictionary = {} # Numeric fixture counters, no player identifiers.
var last_ui_move: int = -1000
var last_result: String = ""
var best_announced: Dictionary = {}
var caption_style: String = ""
var suspended: bool = false

func _ready() -> void:
	add_to_group("game_audio")
	add_to_group("audio_transports")
	AudioMix.ensure_buses()
	for index in range(2):
		var player := AudioStreamPlayer.new()
		player.bus = &"Music"
		add_child(player)
		music.append(player)
	for index in range(12):
		var player := AudioStreamPlayer.new()
		player.bus = &"Effects"
		add_child(player)
		effects.append(player)
	voice.bus = &"Announcer"
	add_child(voice)
	caption_layer.layer = 8
	add_child(caption_layer)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.add_theme_font_override("font",load("res://assets/fonts/body.tres"))
	caption.add_theme_color_override("font_color",UIFactory.CREAM)
	caption.add_theme_color_override("font_outline_color",UIFactory.NAVY)
	caption.add_theme_constant_override("outline_size",6)
	caption_layer.add_child(caption)

func _process(_dt: float) -> void:
	if app==null or app.data==null: return
	set_suspended(app.data.mobile and not app.foreground)
	if suspended: return
	if app.page=="installation_error": return
	var active := is_instance_valid(app.drive)
	var id: String = "music_"+str(app.drive.track.definition.environment_id) if active and app.page!="results" else "music_menu"
	if active and app.page!="results" and CourseArt.spec(app.drive.track.id).has("music_family"):
		id = "music_"+str(CourseArt.spec(app.drive.track.id).music_family)
	set_music(id)
	if app.page=="results" and app.result_receipt!=null:
		var race_id: String = app.result_receipt.session.race_uuid
		if last_result!=race_id:
			last_result = race_id
			effect("results")
		if app.result_summary.get("saved",false) and app.result_summary.get("new_best",false) and not best_announced.has(race_id):
			best_announced[race_id] = true
			say("new_best_time")
	var caption_context: bool = app.page=="results" or active and app.page=="race" and not app.drive.paused
	caption.visible = caption_context and bool(app.data.settings.captions) and Time.get_ticks_msec()<caption_until
	if active and app.page=="race" and app.drive.hud.is_visible_in_tree() and not app.drive.hud.banner_text().is_empty():
		caption.hide() # The prioritized HUD already provides the visible race cue.
	var size := get_viewport().get_visible_rect().size
	var style := str(app.data.settings.ui_scale)+str(size)
	if style!=caption_style:
		caption_style = style
		var ui := UIFactory.new(get_viewport(),app.data.settings)
		caption.add_theme_font_size_override("font_size",ui.font_size(24))
	var caption_top := size.y*.19
	if active and app.page=="race":
		for area: Rect2 in app.drive.hud.timing_rects().values():
			caption_top = maxf(caption_top,area.end.y*app.drive.hud.ui_scale+8)
	caption.position = Vector2(size.x*.1,caption_top)
	caption.size = Vector2(size.x*.8,64)

func set_music(id: String) -> void:
	if id==music_id: return
	music_id = id
	if blend: blend.kill()
	var old := music[music_slot]
	music_slot = 1-music_slot
	var next := music[music_slot]
	next.stop()
	next.stream = AudioLibrary.stream(id)
	next.volume_db = -60
	next.play()
	blend = create_tween().set_parallel(true)
	blend.tween_property(old,"volume_db",-60.0,.5)
	blend.tween_property(next,"volume_db",-4.0,.5)
	blend.chain().tween_callback(old.stop)

func effect(id: String) -> void:
	if app!=null and app.data.mobile and not app.foreground: return
	if id=="ui_confirm" and app!=null and app.foreground: DrivingHaptics.touch("ui",app.data.settings,app.data.mobile)
	if id=="ui_move":
		if Time.get_ticks_msec()-last_ui_move<80: return
		last_ui_move = Time.get_ticks_msec()
	var player := effects[effect_cursor]
	effect_cursor = (effect_cursor+1)%effects.size()
	player.stop()
	player.stream = AudioLibrary.stream("effect_"+id)
	player.volume_db = -5
	player.play()
	played[id] = int(played.get(id,0))+1
	if id in ["countdown","go","finish"]:
		get_tree().call_group("audio_mixes","duck_for_cue",.4 if id!="finish" else .8)

func say(id: String) -> void:
	if app!=null and app.data.mobile and not app.foreground: return
	voice.stop()
	voice.stream = AudioLibrary.stream("voice_"+id)
	voice.volume_db = -2
	voice.play()
	caption.text = str(AudioLibrary.entries()["voice_"+id].text)
	caption_until = Time.get_ticks_msec()+maxi(1200,roundi(voice.stream.get_length()*1000)+300)
	played["voice_"+id] = int(played.get("voice_"+id,0))+1

func set_suspended(value: bool) -> void:
	if suspended==value: return
	suspended = value
	for player: AudioStreamPlayer in music: player.stream_paused = value
	if value:
		for player: AudioStreamPlayer in effects+[voice]: player.stop()
		caption_until = 0
		caption.hide()

func stop_audio() -> void:
	for player: AudioStreamPlayer in music+effects+[voice]:
		player.stream_paused = false
		player.stop()
		player.stream = null

func _exit_tree() -> void: stop_audio()

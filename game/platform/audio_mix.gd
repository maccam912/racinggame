class_name AudioMix
extends Node
## Game-wide buses; sound assets and players are authored in M4.
const CHANNELS: Dictionary = {"music":"Music","engine":"Engine","effects_volume":"Effects","announcer":"Announcer"}
var settings: Dictionary = {}
var foreground: bool = true
var mobile: bool = OS.has_feature("mobile")
var focus_allowed: bool = true
var offline_paused: bool = false
var online_overlay: bool = false
var movement_suspended: bool = false
var music_duck_db: float = 0
var cue_duck_db: float = 0
var cue_until_ms: int = 0

func _ready() -> void:
	add_to_group("audio_mixes")
	ensure_buses()

static func effect_index(label: String) -> int:
	for index in range(AudioServer.get_bus_effect_count(0)):
		if AudioServer.get_bus_effect(0,index).resource_name==label: return index
	return -1

static func ensure_buses() -> void:
	for channel: String in CHANNELS.values():
		if AudioServer.get_bus_index(channel)<0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count-1,channel)
		AudioServer.set_bus_send(AudioServer.get_bus_index(channel),"Master")
	if effect_index("PacificNight")<0:
		var night := AudioEffectCompressor.new()
		night.resource_name = "PacificNight"
		night.threshold = -8
		night.ratio = 3
		night.attack_us = 2000
		night.release_ms = 120
		AudioServer.add_bus_effect(0,night)
	if effect_index("PacificCeiling")<0:
		var limiter := AudioEffectHardLimiter.new()
		limiter.resource_name = "PacificCeiling"
		# Decoded correlated impact bursts can reconstruct above sample peaks.
		# -5 dB sample ceiling leaves measured true-peak headroom below -1 dBFS.
		limiter.ceiling_db = -5.0
		AudioServer.add_bus_effect(0,limiter)

func configure(values: Dictionary) -> void:
	settings = values.duplicate(true)
	ensure_buses()
	AudioServer.set_bus_effect_enabled(0,effect_index("PacificNight"),settings.dynamic_range=="night")
	AudioServer.set_bus_effect_enabled(0,effect_index("PacificCeiling"),true)
	apply_levels()

func context(paused_offline: bool, overlay_online: bool) -> void:
	offline_paused = paused_offline
	online_overlay = overlay_online
	movement_suspended = offline_paused

func duck_for_cue(duration: float) -> void:
	cue_until_ms = maxi(cue_until_ms,Time.get_ticks_msec()+roundi(maxf(0,duration)*1000))
	cue_duck_db = -3
	apply_levels()

func _process(dt: float) -> void:
	var pause_target := -8.0 if offline_paused else -4.0 if online_overlay else 0.0
	music_duck_db = pause_target if pause_target<music_duck_db else move_toward(music_duck_db,pause_target,8*dt/.3)
	if Time.get_ticks_msec()>=cue_until_ms: cue_duck_db = move_toward(cue_duck_db,0,3*dt/.3)
	apply_levels()

func apply_levels() -> void:
	if settings.is_empty(): return
	var master := float(settings.master)/100
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(master,.0001)))
	AudioServer.set_bus_mute(0,master<=0 or not focus_allowed or not foreground and (mobile or not bool(settings.background_audio)))
	for key: String in CHANNELS:
		var index := AudioServer.get_bus_index(CHANNELS[key])
		var level := float(settings[key])/100
		var duck := music_duck_db+cue_duck_db if key=="music" else cue_duck_db if key=="announcer" else 0.0
		AudioServer.set_bus_volume_db(index,linear_to_db(maxf(level,.0001))+duck)
		AudioServer.set_bus_mute(index,level<=0)

func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_PAUSED]: foreground = false
	elif what in [NOTIFICATION_APPLICATION_FOCUS_IN,NOTIFICATION_APPLICATION_RESUMED]: foreground = true
	else: return
	apply_levels()

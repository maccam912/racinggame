class_name RaceArchive
extends RefCounted
## Full-precision local state, never an online authority or a transform replay.
const FORMAT: int = 1
const CONFIG_FIELDS: Array[String] = ["mode","track","car","paint","laps","opponents","difficulty","contact","ghost","seed","roster","cup_id","cup_event","lesson"]
const SESSION_FIELDS: Array[String] = ["race_id","seed","phase","phase_ticks","elapsed_ticks","lap_count","contact_enabled","first_finish_tick","settled_ticks","human_slot","mode","race_uuid","event_uuid","cup_event"]

static func variables(object: Object) -> Array[String]:
	var names: Array[String] = []
	for property: Dictionary in object.get_property_list():
		if property.usage & PROPERTY_USAGE_SCRIPT_VARIABLE: names.append(property.name)
	return names

static func pack(object: Object) -> Dictionary:
	var result: Dictionary = {}
	for key: String in variables(object):
		var value: Variant = object.get(key)
		if value is Vector3:
			var bytes := PackedByteArray()
			bytes.resize(12)
			for axis in range(3): bytes.encode_float(axis*4,value[axis])
			result[key] = {"v3":bytes.hex_encode()}
		elif value is float:
			var bytes := PackedByteArray()
			bytes.resize(8)
			bytes.encode_double(0,value)
			result[key] = {"f64":bytes.hex_encode()}
		elif value is InputFrame: result[key] = pack(value)
		elif value is Array: result[key] = value.duplicate()
		else: result[key] = value
	return result

static func fixed_bytes(value: Variant, tag: String, size: int) -> PackedByteArray:
	if not value is Dictionary or value.size()!=1 or not value.get(tag) is String or value[tag].length()!=size*2: return PackedByteArray()
	for character: String in value[tag]:
		if not character in "0123456789abcdef": return PackedByteArray()
	return str(value[tag]).hex_decode()

static func unpack(value: Variant, object: Object) -> bool:
	if not value is Dictionary: return false
	var names := variables(object)
	if value.size()!=names.size(): return false
	for key: String in names:
		if not value.has(key): return false
		var saved: Variant = value[key]
		var original: Variant = object.get(key)
		match typeof(original):
			TYPE_VECTOR3:
				var bytes := fixed_bytes(saved,"v3",12)
				if bytes.size()!=12: return false
				var vector := Vector3(bytes.decode_float(0),bytes.decode_float(4),bytes.decode_float(8))
				if not vector.is_finite(): return false
				for part: float in [vector.x,vector.y,vector.z]:
					if absf(part)>100000: return false
				object.set(key,vector)
			TYPE_INT:
				if not integer(saved) or absf(float(saved))>4294967295: return false
				object.set(key,int(saved))
			TYPE_FLOAT:
				var bytes := fixed_bytes(saved,"f64",8)
				if bytes.size()!=8: return false
				var scalar := bytes.decode_double(0)
				if not is_finite(scalar) or absf(scalar)>1000000: return false
				object.set(key,scalar)
			TYPE_BOOL, TYPE_STRING:
				if typeof(saved)!=typeof(original): return false
				object.set(key,saved)
			TYPE_ARRAY:
				if not saved is Array or not saved.is_empty(): return false
				# Vehicle events are transient presentation cues, not resumable state.
				object.get(key).clear()
			TYPE_OBJECT:
				if not original is InputFrame or not unpack(saved,original) or not valid_input(original): return false
			_: return false
	return true

static func number(value: Variant) -> bool:
	return (value is int or value is float) and is_finite(float(value))

static func integer(value: Variant) -> bool:
	return number(value) and float(value)==floorf(float(value))

static func bounded(value: Variant, low: int, high: int) -> bool:
	return integer(value) and float(value)>=low and float(value)<=high

static func valid_input(frame: InputFrame) -> bool:
	return frame.sequence>=0 and frame.tick>=0 and absf(frame.steer)<=1 and frame.throttle>=0 and frame.throttle<=1 and frame.brake>=0 and frame.brake<=1

static func valid_bot(bot: BotDriver) -> bool:
	return bot.planning_ticks>=0 and bot.planning_ticks<=12 and bot.difficulty in [0,1,2] and absf(bot.offset)<=3.001 and bot.stuck_ticks>=0 and bot.stuck_ticks<=240 and bot.recover_hold_ticks>=0 and bot.recover_hold_ticks<=30

static func capture(drive: RaceDrive) -> Dictionary:
	if drive.network!=null: return {}
	var session := drive.session
	var config := {"mode":session.mode,"track":Catalog.tracks.find(session.track),"car":Catalog.cars.find(drive.car),"paint":int(drive.config.get("paint",0)),"laps":session.lap_count,"opponents":session.states.size()-1,"difficulty":int(drive.config.get("difficulty",1)),"contact":session.contact_enabled,"ghost":drive.show_ghost,"seed":session.seed,"roster":session.roster.duplicate(true),"cup_id":session.event_uuid,"cup_event":session.cup_event,"lesson":drive.lesson.index if drive.lesson else 0}
	var archive := {"format":FORMAT,"content_hash":Compatibility.content_hash(),"config":config,"session":{},"states":[],"inputs":[],"queries":[],"bots":{},"finish_drivers":[],"lesson":{}}
	for field: String in SESSION_FIELDS: archive.session[field] = session.get(field)
	for index in range(session.states.size()):
		var car := pack(session.states[index])
		car.events = []
		archive.states.append(car)
		archive.inputs.append(pack(session.inputs[index]))
		archive.queries.append(session.queries[index].hint)
		archive.finish_drivers.append(pack(session.finish_drivers[index]))
	for slot: int in session.bots: archive.bots[str(slot)] = pack(session.bots[slot])
	if drive.lesson:
		for field: String in ["stage","done","marker_index","slide_ticks"]: archive.lesson[field] = drive.lesson.get(field)
	return archive

static func valid_roster(value: Variant, human: int) -> bool:
	if not value is Array or value.is_empty() or value.size()>8 or human<0 or human>=value.size(): return false
	var ids: Array[String] = []
	for index in range(value.size()):
		var row: Variant = value[index]
		if not row is Dictionary or not row.get("id") is String or not row.get("name") is String or not row.get("bot") is bool: return false
		if not bounded(row.get("car"), 0, Catalog.car_count()-1) or not bounded(row.get("paint"),0,7): return false
		if not PlayerName.validate(row.name).valid or row.id in ids: return false
		if index==human:
			if row.id!="local" or row.bot: return false
		elif not row.bot or not row.id in RaceSetup.BOT_NAMES.map(func(name: String) -> String: return "bot_"+name.to_lower()): return false
		ids.append(row.id)
	return true

static func valid(value: Dictionary) -> bool:
	# Preserve unfamiliar payload formats/content byte-for-byte for explicit discard.
	if integer(value.get("format")) and int(value.format)>FORMAT: return true
	if value.get("format")!=FORMAT or not value.get("content_hash") is String or value.content_hash.length()!=64: return false
	if value.content_hash!=Compatibility.content_hash(): return true
	var config: Variant = value.get("config")
	var session: Variant = value.get("session")
	if not config is Dictionary or not session is Dictionary or session.size()!=SESSION_FIELDS.size(): return false
	if config.size()!=CONFIG_FIELDS.size(): return false
	for field: String in CONFIG_FIELDS:
		if not config.has(field): return false
	for field: String in SESSION_FIELDS:
		if not session.has(field): return false
	if not session.mode in ["quick","trial","cup","school"] or config.get("mode")!=session.mode: return false
	for field: String in ["race_id","seed","phase","phase_ticks","elapsed_ticks","lap_count","first_finish_tick","settled_ticks","human_slot","cup_event"]:
		if not integer(session[field]): return false
	if not bounded(session.race_id,1,4294967295) or not bounded(session.seed,0,4294967295) or not bounded(session.phase,2,6): return false
	if not bounded(session.phase_ticks,0,36000) or not bounded(session.elapsed_ticks,0,36000) or not bounded(session.lap_count,1,3) or not bounded(session.settled_ticks,0,120): return false
	if not bounded(session.first_finish_tick,-1,int(session.elapsed_ticks)) or not session.contact_enabled is bool or not GuestIdentity.valid_uuid(str(session.race_uuid)): return false
	if not bounded(config.get("track"),0,Catalog.track_count()-1) or not bounded(config.get("car"), 0, Catalog.car_count()-1) or not bounded(config.get("paint"),0,7) or not bounded(config.get("difficulty"),0,2) or not bounded(config.get("lesson"),0,4): return false
	if config.get("laps")!=session.lap_count or config.get("seed")!=session.seed or config.get("contact")!=session.contact_enabled or not config.get("ghost") is bool: return false
	if config.get("cup_id")!=session.event_uuid or config.get("cup_event")!=session.cup_event or not config.contact is bool: return false
	if not valid_roster(config.get("roster"),int(session.human_slot)): return false
	var roster: Array = config.roster
	if config.get("opponents")!=roster.size()-1 or config.car!=roster[int(session.human_slot)].car or config.paint!=roster[int(session.human_slot)].paint: return false
	if session.mode=="cup":
		if not GuestIdentity.valid_uuid(str(session.event_uuid)) or not bounded(session.cup_event,0,5) or config.get("cup_id")!=session.event_uuid or config.get("cup_event")!=session.cup_event: return false
	elif session.event_uuid!="" or session.cup_event!=-1: return false
	for field: String in ["states","inputs","queries","finish_drivers"]:
		if not value.get(field) is Array or value[field].size()!=roster.size(): return false
	if not value.get("bots") is Dictionary or value.bots.size()!=roster.size()-1: return false
	var decoded := RaceSession.new()
	decoded.phase = int(session.phase)
	decoded.race_id = int(session.race_id)
	decoded.elapsed_ticks = int(session.elapsed_ticks)
	var track: TrackDefinition = Catalog.tracks[int(config.track)]
	for index in range(roster.size()):
		var state := VehicleState.new()
		if not unpack(value.states[index],state) or state.slot!=index or not state.events.is_empty(): return false
		if state.dnf_reason.length()>160: return false
		var car: CarDefinition = Catalog.cars[int(roster[index].car)]
		if state.boost_charges > car.boost_charges or car.boost_charges == 0 and state.boost_ticks != 0: return false
		if state.recovery_rank < -1 or state.recovery_rank >= roster.size() or state.recovery_progress < -6 or state.recovery_progress > (int(session.lap_count)+1)*track.length or state.recovery_speed < 0 or state.recovery_speed > 100: return false
		if state.last_gate>=track.bake.gates.size() or state.laps>int(session.lap_count) or state.laps<0 or state.ground_normal.y<0 or absf(state.ground_normal.length()-1)>.01: return false
		decoded.states.append(state)
		var input := InputFrame.new()
		if not unpack(value.inputs[index],input) or not valid_input(input) or not bounded(value.queries[index],0,track.points.size()-1): return false
		var finisher := BotDriver.new()
		if not unpack(value.finish_drivers[index],finisher) or not valid_bot(finisher): return false
		if roster[index].bot:
			var bot := BotDriver.new()
			if not value.bots.has(str(index)) or not unpack(value.bots[str(index)],bot) or not valid_bot(bot): return false
	var bytes := NetCodec.encode_snapshot(decoded,0,Compatibility.content_hash().hex_decode())
	if bytes.is_empty() or NetCodec.decode_snapshot(bytes,decoded.race_id,Compatibility.content_hash().hex_decode()).is_empty(): return false
	if not value.get("lesson") is Dictionary: return false
	if session.mode=="school":
		if roster.size()!=1 or config.track!=0 or not bounded(value.lesson.get("stage"),0,2) or not value.lesson.get("done") is bool or not bounded(value.lesson.get("marker_index"),0,3) or not bounded(value.lesson.get("slide_ticks"),0,36000): return false
	elif not value.lesson.is_empty(): return false
	return true

static func compatible(value: Dictionary, data: AppData) -> bool:
	if value.get("format")!=FORMAT or value.get("content_hash")!=Compatibility.content_hash(): return false
	if not valid(value): return false
	if value.session.mode=="cup":
		return data.cup.compatible(Compatibility.content_hash()) and data.cup.data.id==value.session.event_uuid and int(data.cup.data.next_event)==int(value.session.cup_event)
	return true

static func restore(drive: RaceDrive, value: Dictionary) -> bool:
	if not compatible(value,drive.app_data) or drive.network!=null or drive.session.mode=="trial": return false
	var session := drive.session
	if session.mode!=value.session.mode or session.states.size()!=value.states.size() or session.human_slot!=int(value.session.human_slot) or session.track!=Catalog.tracks[int(value.config.track)]: return false
	for field: String in SESSION_FIELDS: session.set(field,value.session[field])
	for index in range(session.states.size()):
		if not unpack(value.states[index],session.states[index]) or not unpack(value.inputs[index],session.inputs[index]) or not unpack(value.finish_drivers[index],session.finish_drivers[index]): return false
		session.queries[index].hint = int(value.queries[index])
	for slot: int in session.bots:
		if not unpack(value.bots[str(slot)],session.bots[slot]): return false
	if drive.lesson:
		for field: String in ["stage","done","marker_index","slide_ticks"]: drive.lesson.set(field,value.lesson[field])
	drive.race_ticks = session.elapsed_ticks
	drive.phase = ["Lobby","Loading","Grid","Countdown","Racing","Finish Grace","Results"][session.phase]
	drive.phase_ticks = session.phase_ticks
	drive.hud.ticks = session.elapsed_ticks
	drive.hud.phase = drive.phase
	drive.hud.phase_ticks = session.phase_ticks
	drive.frame = InputFrame.make()
	drive.camera.initialized = false
	return true

class_name LobbyState
extends RefCounted
## Room administration only. Race simulation always stays on the dedicated worker.

enum Phase { LOBBY, LOADING, ACTIVE, RESULTS, CLOSED }
var phase: Phase = Phase.LOBBY
var members: Array[Dictionary] = []
var host_id: String = ""
var rules: Dictionary = {"track":0, "laps":2, "bot_fill":true, "difficulty":1, "contact":true}
var name_value: String = "Driver's Race"
var region: String = "Community server"
var private_room: bool = false
var code: String = ""
var revision: int = 0
var countdown_tick: int = -1
var loading_tick: int = -1
var results_tick: int = -1
var bans: Dictionary = {}
var excluded: Array[String] = []


func member(id: String) -> Dictionary:
	for row: Dictionary in members:
		if row.id == id:
			return row
	return {}


func join(id: String, name_string: String, tick: int, car: int = 0, paint: int = 0) -> Dictionary:
	if phase != Phase.LOBBY or members.size() >= 8 or int(bans.get(id, -1)) > tick or not member(id).is_empty() or not PlayerName.validate(name_string).valid or car < 0 or car > 3 or paint < 0 or paint > 7:
		return {}
	var row := {"id":id, "name":PlayerName.nfc(name_string), "car":car, "paint":paint, "ready":false, "connected":true, "joined_tick":tick, "loaded":false, "return_ready":false, "slot":members.size(), "ping":0}
	members.append(row)
	if host_id == "":
		host_id = id
	changed()
	return row


func changed() -> void:
	revision += 1
	countdown_tick = -1


func set_ready(id: String, ready: bool) -> bool:
	var row := member(id)
	if phase != Phase.LOBBY or row.is_empty() or not row.connected:
		return false
	if row.ready != ready:
		row.ready = ready
		changed()
	return true


func select_car(id: String, car: int, paint: int) -> bool:
	var row := member(id)
	if phase != Phase.LOBBY or row.is_empty() or car < 0 or car > 3 or paint < 0 or paint > 7:
		return false
	if int(row.car) != car or int(row.paint) != paint:
		row.car = car
		row.paint = paint
		row.ready = false
		changed()
	return true


func set_rules(id: String, values: Dictionary) -> bool:
	if phase != Phase.LOBBY or id != host_id or not valid_rules(values):
		return false
	var normalized := normalize_rules(values)
	if normalized != rules:
		rules = normalized
		for row: Dictionary in members:
			row.ready = false
		changed()
	return true


static func normalize_rules(values: Dictionary) -> Dictionary:
	return {"track":int(values.track), "laps":int(values.laps), "bot_fill":bool(values.bot_fill), "difficulty":int(values.difficulty), "contact":bool(values.contact)}


static func valid_rules(values: Dictionary) -> bool:
	return values.size() == 5 and NetEvents.integer(values.get("track"), 0, Catalog.track_count()-1) and NetEvents.integer(values.get("laps"), 1, 3) and values.get("bot_fill") is bool and NetEvents.integer(values.get("difficulty"), 0, 2) and values.get("contact") is bool


func leave(id: String) -> bool:
	var row := member(id)
	if row.is_empty():
		return false
	members.erase(row)
	for index in range(members.size()):
		members[index].slot = index
	if id == host_id:
		transfer_host()
	if members.is_empty():
		phase = Phase.CLOSED
	changed()
	return true


func transfer_host() -> void:
	var candidates := members.filter(func(row: Dictionary) -> bool: return row.connected)
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.joined_tick) < int(b.joined_tick) if int(a.joined_tick) != int(b.joined_tick) else str(a.id) < str(b.id))
	host_id = "" if candidates.is_empty() else candidates[0].id
	revision += 1


func kick(actor: String, target: String, tick: int) -> bool:
	if phase != Phase.LOBBY or actor != host_id or target == actor or member(target).is_empty():
		return false
	bans[target] = tick + 36000
	return leave(target)


func all_ready() -> bool:
	return not members.is_empty() and members.all(func(row: Dictionary) -> bool: return row.connected and row.ready)


func request_start(id: String, tick: int) -> bool:
	if phase != Phase.LOBBY or id != host_id or not all_ready():
		return false
	begin_loading(tick)
	return true


func begin_loading(tick: int) -> void:
	phase = Phase.LOADING
	loading_tick = tick
	countdown_tick = -1
	excluded.clear()
	for row: Dictionary in members:
		row.loaded = false
	revision += 1


func step(tick: int) -> String:
	if tick % 300 == 0:
		for id: String in bans.keys():
			if int(bans[id]) <= tick:
				bans.erase(id)
	if phase == Phase.LOBBY:
		var ready_count := members.filter(func(row: Dictionary) -> bool: return row.connected and row.ready).size()
		if ready_count < 2:
			countdown_tick = -1
		else:
			var duration := 300 if all_ready() else 1200
			if countdown_tick < 0:
				countdown_tick = tick + duration
				revision += 1
			elif all_ready():
				countdown_tick = mini(countdown_tick, tick + 300)
			if tick >= countdown_tick:
				begin_loading(tick)
				return "load"
	elif phase == Phase.LOADING:
		if tick - loading_tick >= 1800:
			for row: Dictionary in members.duplicate():
				if not row.connected or not row.loaded:
					excluded.append(row.name)
					members.erase(row)
			if member(host_id).is_empty():
				transfer_host()
			for index in range(members.size()):
				members[index].slot = index
			if members.is_empty():
				phase = Phase.CLOSED
				return "close"
		if not members.is_empty() and members.all(func(row: Dictionary) -> bool: return row.connected and row.loaded):
			phase = Phase.ACTIVE
			revision += 1
			return "start"
	elif phase == Phase.RESULTS:
		if tick - results_tick >= 1200 or members.filter(func(row: Dictionary) -> bool: return row.connected).all(func(row: Dictionary) -> bool: return row.return_ready):
			for row: Dictionary in members.duplicate():
				if not row.connected:
					members.erase(row)
			for index in range(members.size()):
				members[index].slot = index
				members[index].ready = false
				members[index].loaded = false
				members[index].return_ready = false
			phase = Phase.CLOSED if members.is_empty() else Phase.LOBBY
			if member(host_id).is_empty():
				transfer_host()
			changed()
			return "lobby" if phase == Phase.LOBBY else "close"
	return ""


func finish(tick: int) -> void:
	phase = Phase.RESULTS
	results_tick = tick
	for row: Dictionary in members:
		row.return_ready = false
	revision += 1


func roster() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for human: Dictionary in members:
		rows.append({"id":human.id, "name":human.name, "car":int(human.car), "paint":int(human.paint), "bot":false})
	var bot_index := 0
	while rules.bot_fill and rows.size() < 8:
		var slot := rows.size()
		rows.append({"id":"bot_" + RaceSetup.BOT_NAMES[bot_index].to_lower(), "name":RaceSetup.BOT_NAMES[bot_index], "car":RaceSetup.BOT_CARS[slot % 4], "paint":slot % 8, "bot":true})
		bot_index += 1
	return rows


func public_state(tick: int) -> Dictionary:
	var rows: Array[Dictionary] = []
	for row: Dictionary in members:
		rows.append({"id":row.id, "name":row.name, "slot":int(row.slot), "car":int(row.car), "paint":int(row.paint), "ready":bool(row.ready), "connected":bool(row.connected), "ping":int(row.ping), "loaded":bool(row.loaded)})
	return {"type":"lobby", "revision":revision, "tick":tick, "phase":phase, "host":host_id, "members":rows, "rules":rules.duplicate(true), "name":name_value, "region":region, "private":private_room, "code":code, "countdown_tick":countdown_tick}

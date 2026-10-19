class_name NetEvents
extends RefCounted
## Validate reliable community-server messages before indexing or typed conversion.


static func integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and float(value) >= minimum and float(value) <= maximum


static func number(value: Variant, minimum: float, maximum: float) -> bool:
	return (value is float or value is int) and is_finite(float(value)) and float(value) >= minimum and float(value) <= maximum


static func roster_valid(value: Variant, allow_empty: bool = false, members: bool = false) -> bool:
	if not value is Array or value.size() > 8 or (value.is_empty() and not allow_empty):
		return false
	var seen: Dictionary = {}
	for row: Variant in value:
		if not row is Dictionary or not row.get("id") is String or row.id.length() > 64 or seen.has(row.id) or not row.get("name") is String or not PlayerName.validate(row.name).valid or not integer(row.get("car"), 0, 3) or not integer(row.get("paint"), 0, 7):
			return false
		seen[row.id] = true
		if members and (not row.get("ready") is bool or not row.get("connected") is bool or not integer(row.get("slot"), 0, 7) or not integer(row.get("ping"), 0, 60000) or not row.get("loaded") is bool):
			return false
		if not members and not row.get("bot") is bool:
			return false
	return true


static func server_event(event: Dictionary) -> bool:
	match event.get("type", ""):
		"welcome":
			return event.get("official", false) is bool and integer(event.get("ack", 0), 0, 0xffffffff) and event.get("id") is String and event.id.length() == 36 and integer(event.get("slot"), 0, 7) and integer(event.get("race"), 0, 0xffffffff) and integer(event.get("tick"), 0, 0xffffffff) and event.get("token") is String and event.token.length() == 64 and event.token.is_valid_hex_number(false)
		"lobby":
			return integer(event.get("revision"), 0, 0xffffffff) and integer(event.get("tick"), 0, 0xffffffff) and integer(event.get("phase"), 0, 4) and integer(event.get("countdown_tick"), -1, 0xffffffff) and event.get("host") is String and event.host.length() <= 64 and roster_valid(event.get("members"), true, true) and event.get("rules") is Dictionary and LobbyState.valid_rules(event.rules) and event.get("name") is String and PlayerName.validate(event.name, 24).valid and event.get("region") is String and event.region.length() <= 40 and event.get("private") is bool and event.get("code") is String and event.code.length() <= 32
		"loading":
			return integer(event.get("race"), 1, 0xffffffff) and integer(event.get("track"), 0, 5) and integer(event.get("laps"), 1, 3) and roster_valid(event.get("roster")) and event.get("contact") is bool
		"start":
			return integer(event.get("race"), 1, 0xffffffff) and event.get("race_uuid") is String and event.race_uuid.length() == 36 and integer(event.get("slot"), 0, 7) and integer(event.get("start_tick"), 0, 0xffffffff) and integer(event.get("control_tick"), 0, 0xffffffff) and integer(event.get("count"), 1, 8) and integer(event.get("track"), 0, 5) and integer(event.get("laps"), 1, 3) and roster_valid(event.get("roster")) and event.roster.size() == int(event.count) and int(event.slot) < int(event.count) and event.get("contact") is bool
		"presence":
			if not integer(event.get("race"), 1, 0xffffffff) or not integer(event.get("revision"), 0, 0xffffffff) or not integer(event.get("tick"), 0, 0xffffffff) or not integer(event.get("host_slot"), -1, 7) or not event.get("members") is Array or event.members.size() > 8:
				return false
			var slots: Dictionary = {}
			for row: Variant in event.members:
				if not row is Array or row.size() != 3 or not integer(row[0], 0, 7) or slots.has(int(row[0])) or not row[1] is bool or not integer(row[2], 0, 60000):
					return false
				slots[int(row[0])] = true
			return int(event.host_slot) == -1 or slots.has(int(event.host_slot))
		"resume":
			if not integer(event.get("race"), 1, 0xffffffff) or not event.get("race_uuid") is String or event.race_uuid.length() != 36 or not integer(event.get("slot"), 0, 7) or not integer(event.get("start_tick"), 0, 0xffffffff) or not integer(event.get("control_tick"), 0, 0xffffffff) or not integer(event.get("count"), 1, 8) or not integer(event.get("track"), 0, 5) or not integer(event.get("laps"), 1, 3) or not event.get("contact") is bool or not event.get("cars") is Array or event.cars.size() != int(event.count) or int(event.slot) >= int(event.count):
				return false
			var ids: Dictionary = {}
			for row: Variant in event.cars:
				if not row is Array or row.size() != 4 or not row[0] is String or row[0].is_empty() or row[0].length() > 64 or ids.has(row[0]) or not integer(row[1], 0, 3) or not integer(row[2], 0, 7) or not row[3] is bool:
					return false
				ids[row[0]] = true
			return true
		"pong":
			return integer(event.get("sent"), 0, 9007199254740991) and integer(event.get("tick"), 0, 0xffffffff)
		"error":
			return event.get("message") is String and event.message.length() <= 160
		"results":
			if not integer(event.get("race"), 1, 0xffffffff) or not event.get("race_uuid") is String or event.race_uuid.length() != 36 or not integer(event.get("return_tick"), 0, 0xffffffff) or not event.get("results") is Array or event.results.size() < 1 or event.results.size() > 8:
				return false
			var seen: Dictionary = {}
			for row: Variant in event.results:
				if not row is Dictionary or not integer(row.get("slot"), 0, 7) or seen.has(int(row.slot)) or not row.get("name") is String or not PlayerName.validate(row.name).valid or not row.get("dnf") is String or row.dnf.length() > 64 or not number(row.get("time"), -1, 600) or not number(row.get("best_lap"), -1, 600) or not number(row.get("distance_m"), 0, 100000) or not integer(row.get("car"), 0, 3) or not integer(row.get("paint"), 0, 7) or not row.get("bot") is bool:
					return false
				seen[int(row.slot)] = true
			return true
	return false

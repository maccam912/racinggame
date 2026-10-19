class_name NetEvents
extends RefCounted
## Validate reliable community-server messages before indexing or typed conversion.


static func integer(value: Variant, minimum: int, maximum: int) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) == floorf(float(value)) and float(value) >= minimum and float(value) <= maximum


static func server_event(event: Dictionary) -> bool:
	match event.get("type", ""):
		"welcome":
			if event.has("ack") and not integer(event.ack, 0, 0xffffffff):
				return false
			return integer(event.get("slot"), 0, 7) and integer(event.get("race"), 0, 0xffffffff) and integer(event.get("tick"), 0, 0xffffffff) and event.get("token") is String and event.token.length() == 64 and event.token.is_valid_hex_number(false)
		"start":
			return integer(event.get("race"), 0, 0xffffffff) and integer(event.get("start_tick"), 0, 0xffffffff) and integer(event.get("control_tick"), 0, 0xffffffff) and integer(event.get("count"), 1, 8) and integer(event.get("track"), 0, 5) and integer(event.get("laps"), 1, 3)
		"pong":
			return integer(event.get("sent"), 0, 9007199254740991) and integer(event.get("tick"), 0, 0xffffffff)
		"error":
			return event.get("message") is String and event.message.length() <= 160
		"results":
			if not event.get("results") is Array or event.results.size() < 1 or event.results.size() > 8:
				return false
			var seen: Dictionary = {}
			for row: Variant in event.results:
				if not row is Dictionary or not integer(row.get("slot"), 0, 7) or seen.has(int(row.slot)) or not row.get("name") is String or row.name.length() > 16 or not row.get("dnf") is String or row.dnf.length() > 64 or not row.get("time") is float or not is_finite(row.time):
					return false
				seen[int(row.slot)] = true
			return true
	return false

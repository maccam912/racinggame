class_name CupBook
extends RefCounted

const POINTS: Array[int] = [10, 8, 6, 5, 4, 3, 2, 1]
var data: Dictionary = {}


func start(car: int, paint: int, name_value: String, content_hash: String) -> void:
	var seed_bytes := Crypto.new().generate_random_bytes(4)
	var seed_value := int(seed_bytes.decode_u32(0))
	data = {"id":RaceSetup.uuid(), "seed":seed_value, "difficulty":1, "car":car, "roster":RaceSetup.roster(7, car, paint, name_value), "results":[], "next_event":0, "content_hash":content_hash, "seeds":[]}
	var random := RandomNumberGenerator.new()
	random.seed = seed_value
	for event in range(6):
		data.seeds.append(random.randi())


func compatible(content_hash: String) -> bool:
	return not data.is_empty() and data.get("content_hash", "") == content_hash


func commit(event_index: int, race_id: String, order: Array[Dictionary]) -> bool:
	if data.is_empty() or event_index != int(data.next_event) or event_index < 0 or event_index >= 6 or order.size() != 8:
		return false
	var known: Array[String] = []
	for record: Dictionary in data.roster:
		known.append(record.id)
	var seen: Dictionary = {}
	for row: Dictionary in order:
		if not row.get("id") is String or not row.id in known or seen.has(row.id) or not row.get("dnf") is String:
			return false
		seen[row.id] = true
	data.results.append({"event":event_index, "race_id":race_id, "order":order.duplicate(true)})
	data.next_event = event_index + 1
	return true


func standings() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for record: Dictionary in data.roster:
		rows.append({"id":record.id, "name":record.name, "points":0, "places":[0, 0, 0, 0, 0, 0, 0, 0], "last_place":8})
	for event: Dictionary in data.results:
		for place in range(event.order.size()):
			var finish: Dictionary = event.order[place]
			for row: Dictionary in rows:
				if row.id == finish.id:
					row.last_place = place
					if finish.get("dnf", "") == "":
						row.points += POINTS[place]
						row.places[place] += 1
	rows.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a.points != b.points:
			return a.points > b.points
		for index in range(8):
			if a.places[index] != b.places[index]:
				return a.places[index] > b.places[index]
		if a.last_place != b.last_place:
			return a.last_place < b.last_place
		return str(a.id) < str(b.id))
	return rows


func grid() -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	if int(data.next_event) == 0:
		for record: Dictionary in data.roster:
			result.append(record.duplicate(true))
		return result
	var ranking := standings()
	ranking.reverse()
	for row: Dictionary in ranking:
		for record: Dictionary in data.roster:
			if row.id == record.id:
				result.append(record.duplicate(true))
	return result


static func validate_data(value: Dictionary) -> bool:
	if value.is_empty():
		return true
	if not NetEvents.integer(value.get("car"), 0, Catalog.car_count()-1) or not NetEvents.integer(value.get("seed"), 0, 0xffffffff) or not NetEvents.integer(value.get("difficulty"), 1, 1):
		return false
	if not value.get("id") is String or value.id.length() != 36 or not value.get("content_hash") is String or value.content_hash.length() != 64 or not value.get("roster") is Array or value.roster.size() != 8 or not value.get("results") is Array or not value.get("seeds") is Array or value.seeds.size() != 6 or not NetEvents.integer(value.get("next_event"), 0, 6) or value.results.size() != int(value.next_event):
		return false
	var ids: Dictionary = {}
	for row: Variant in value.roster:
		if not row is Dictionary or not row.get("id") is String or ids.has(row.id) or not row.get("name") is String or not row.get("bot") is bool or not NetEvents.integer(row.get("car"), 0, Catalog.car_count()-1) or not NetEvents.integer(row.get("paint"), 0, 7):
			return false
		ids[row.id] = true
	if not ids.has("local") or value.roster.filter(func(row: Dictionary) -> bool: return not row.bot).size() != 1:
		return false
	for seed_value: Variant in value.seeds:
		if not NetEvents.integer(seed_value, 0, 0xffffffff):
			return false
	for index in range(value.results.size()):
		var event: Variant = value.results[index]
		if not event is Dictionary or not NetEvents.integer(event.get("event"), index, index) or not event.get("race_id") is String or not event.get("order") is Array or event.order.size() != 8:
			return false
		var seen: Dictionary = {}
		for row: Variant in event.order:
			if not row is Dictionary or not row.get("id") is String or not ids.has(row.id) or seen.has(row.id) or not row.get("dnf") is String:
				return false
			for key in ["time", "best_lap", "distance_m"]:
				if not (row.get(key) is float or row.get(key) is int) or not is_finite(float(row[key])) or float(row[key]) < -1 or float(row[key]) > 100000:
					return false
			seen[row.id] = true
	return true
